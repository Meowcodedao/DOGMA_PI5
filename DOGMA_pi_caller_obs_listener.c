// gcc dual_srt_display.c -o dual_srt_display -lavformat -lavcodec -lavutil -lswscale -lsdl2 -pthread
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <time.h>
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswscale/swscale.h>
#include <SDL2/SDL.h>

#define LOGFILE "/var/log/dual_srt_display.log"
#define STREAM1_URL "srt://TAILSCALE_IP:9999?mode=caller"
#define STREAM2_URL "srt://TAILSCALE_IP:10000?mode=caller"

void log_msg(const char *fmt, ...) {
    FILE *f = fopen(LOGFILE, "a");
    if (!f) return;
    time_t t = time(NULL);
    fprintf(f, "[%s] ", ctime(&t));
    va_list args;
    va_start(args, fmt);
    vfprintf(f, fmt, args);
    va_end(args);
    fprintf(f, "\n");
    fclose(f);
}

typedef struct {
    const char *url;
    int display_index;
} StreamTask;

void *stream_thread(void *arg) {
    StreamTask *task = (StreamTask *)arg;
    const char *url = task->url;
    int display_index = task->display_index;

    AVFormatContext *fmt = NULL;
    AVCodecContext *dec_ctx = NULL;
    AVCodec *dec = NULL;
    struct SwsContext *sws = NULL;
    AVPacket pkt;
    AVFrame *frame, *yuv;
    SDL_Window *win;
    SDL_Renderer *ren;
    SDL_Texture *tex;
    uint8_t *buffer;
    int ret;

    log_msg("[Display %d] Connecting to %s ...", display_index, url);
    if ((ret = avformat_open_input(&fmt, url, NULL, NULL)) < 0) {
        log_msg("[Display %d] Failed to connect (%d)", display_index, ret);
        return NULL;
    }

    avformat_find_stream_info(fmt, NULL);
    int vid_index = av_find_best_stream(fmt, AVMEDIA_TYPE_VIDEO, -1, -1, &dec, 0);
    if (vid_index < 0) {
        log_msg("[Display %d] No video stream", display_index);
        return NULL;
    }

    dec_ctx = avcodec_alloc_context3(dec);
    avcodec_parameters_to_context(dec_ctx, fmt->streams[vid_index]->codecpar);
    avcodec_open2(dec_ctx, dec, NULL);

    SDL_Init(SDL_INIT_VIDEO);
    SDL_ShowCursor(SDL_DISABLE);
    SDL_Rect display_bounds;
    SDL_GetDisplayBounds(display_index, &display_bounds);
    win = SDL_CreateWindow(url,
                           display_bounds.x, display_bounds.y,
                           display_bounds.w, display_bounds.h,
                           SDL_WINDOW_FULLSCREEN);
    ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);
    tex = SDL_CreateTexture(ren, SDL_PIXELFORMAT_YV12, SDL_TEXTUREACCESS_STREAMING,
                            dec_ctx->width, dec_ctx->height);

    frame = av_frame_alloc();
    yuv = av_frame_alloc();
    int bufsize = av_image_get_buffer_size(AV_PIX_FMT_YUV420P,
                                           dec_ctx->width, dec_ctx->height, 1);
    buffer = av_malloc(bufsize);
    av_image_fill_arrays(yuv->data, yuv->linesize, buffer,
                         AV_PIX_FMT_YUV420P, dec_ctx->width, dec_ctx->height, 1);

    sws = sws_getContext(dec_ctx->width, dec_ctx->height, dec_ctx->pix_fmt,
                         dec_ctx->width, dec_ctx->height, AV_PIX_FMT_YUV420P,
                         SWS_BILINEAR, NULL, NULL, NULL);

    while (av_read_frame(fmt, &pkt) >= 0) {
        if (pkt.stream_index == vid_index) {
            avcodec_send_packet(dec_ctx, &pkt);
            while (avcodec_receive_frame(dec_ctx, frame) == 0) {
                sws_scale(sws, (const uint8_t *const *)frame->data, frame->linesize,
                          0, dec_ctx->height, yuv->data, yuv->linesize);
                SDL_UpdateYUVTexture(tex, NULL,
                                     yuv->data[0], yuv->linesize[0],
                                     yuv->data[1], yuv->linesize[1],
                                     yuv->data[2], yuv->linesize[2]);
                SDL_RenderClear(ren);
                SDL_RenderCopy(ren, tex, NULL, NULL);
                SDL_RenderPresent(ren);
            }
        }
        av_packet_unref(&pkt);
    }

    av_free(buffer);
    av_frame_free(&frame);
    av_frame_free(&yuv);
    sws_freeContext(sws);
    SDL_DestroyTexture(tex);
    SDL_DestroyRenderer(ren);
    SDL_DestroyWindow(win);
    SDL_Quit();
    avcodec_free_context(&dec_ctx);
    avformat_close_input(&fmt);

    log_msg("[Display %d] Thread exit", display_index);
    return NULL;
}

int main() {
    log_msg("Starting dual SRT display... Waiting 30s before connect.");
    sleep(30);

    StreamTask t1 = { STREAM1_URL, 0 };
    StreamTask t2 = { STREAM2_URL, 1 };

    pthread_t th1, th2;
    pthread_create(&th1, NULL, stream_thread, &t1);
    pthread_create(&th2, NULL, stream_thread, &t2);
    pthread_join(th1, NULL);
    pthread_join(th2, NULL);

    log_msg("Program finished.");
    return 0;
}


