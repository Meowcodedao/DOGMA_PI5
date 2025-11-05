#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <time.h>
#include <stdarg.h>
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswscale/swscale.h>
#include <libavutil/imgutils.h>
#include <SDL2/SDL.h>

#define LOGFILE "/var/log/dogma_stream.log"

// Thay IP Tailscale thật của OBS
#define OBS_IP_ADDR "100.x.x.x"

#define STREAM1_SRT_URL "srt://" OBS_IP_ADDR ":9999?mode=caller"
#define STREAM2_SRT_URL "srt://" OBS_IP_ADDR ":10000?mode=caller"

// Caller video devices (Pi nguồn)
#define VIDEO_DEV1 "/dev/video0"
#define VIDEO_DEV2 "/dev/video1"

// Caller ports
#define PORT1 9999
#define PORT2 10000

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

// Caller: gửi camera qua SRT
void* caller_thread(void* arg) {
    const char* device = (const char*)arg;
    int port = (device == VIDEO_DEV1) ? PORT1 : PORT2;

    char cmd[512];
    snprintf(cmd, sizeof(cmd),
        "ffmpeg -f v4l2 -i %s -c:v h264_omx -preset ultrafast "
        "-b:v 4000k -g 60 -tune zerolatency -pix_fmt yuv420p -f mpegts "
        "srt://%s:%d?mode=caller&latency=120&transtype=live > /dev/null 2>&1 &",
        device, OBS_IP_ADDR, port);

    log_msg("Caller started: %s", cmd);
    system(cmd);
    return NULL;
}

// Receiver: nhận luồng SRT và phát trên màn hình
typedef struct {
    const char *url;
    int display_index;
} StreamTask;

void *receiver_thread(void *arg) {
    StreamTask *task = (StreamTask *)arg;
    const char *url = task->url;
    int display_index = task->display_index;

    AVFormatContext *fmt_ctx = NULL;
    AVCodecContext *dec_ctx = NULL;
    const AVCodec *dec = NULL;
    struct SwsContext *sws_ctx = NULL;
    AVPacket pkt;
    AVFrame *frame = NULL, *frame_yuv = NULL;
    SDL_Window *window = NULL;
    SDL_Renderer *renderer = NULL;
    SDL_Texture *texture = NULL;
    uint8_t *buffer = NULL;
    int ret, video_stream_index = -1;

    log_msg("[Receiver %d] Connecting to %s", display_index, url);

    if ((ret = avformat_open_input(&fmt_ctx, url, NULL, NULL)) < 0) {
        log_msg("[Receiver %d] Cannot open input: %d", display_index, ret);
        return NULL;
    }
    if ((ret = avformat_find_stream_info(fmt_ctx, NULL)) < 0) {
        log_msg("[Receiver %d] Cannot find stream info: %d", display_index, ret);
        return NULL;
    }
    video_stream_index = av_find_best_stream(fmt_ctx, AVMEDIA_TYPE_VIDEO, -1, -1, &dec, 0);
    if (video_stream_index < 0) {
        log_msg("[Receiver %d] Cannot find video stream", display_index);
        return NULL;
    }

    dec_ctx = avcodec_alloc_context3(dec);
    avcodec_parameters_to_context(dec_ctx, fmt_ctx->streams[video_stream_index]->codecpar);
    if ((ret = avcodec_open2(dec_ctx, dec, NULL)) < 0) {
        log_msg("[Receiver %d] Failed to open codec: %d", display_index, ret);
        return NULL;
    }

    SDL_Init(SDL_INIT_VIDEO);
    SDL_ShowCursor(SDL_DISABLE);

    SDL_Rect display_bounds;
    SDL_GetDisplayBounds(display_index, &display_bounds);
    window = SDL_CreateWindow(url, display_bounds.x, display_bounds.y,
                            display_bounds.w, display_bounds.h,
                            SDL_WINDOW_FULLSCREEN);

    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    texture = SDL_CreateTexture(renderer,
                              SDL_PIXELFORMAT_YV12,
                              SDL_TEXTUREACCESS_STREAMING,
                              dec_ctx->width,
                              dec_ctx->height);

    frame = av_frame_alloc();
    frame_yuv = av_frame_alloc();

    int num_bytes = av_image_get_buffer_size(AV_PIX_FMT_YUV420P, dec_ctx->width,
                                           dec_ctx->height, 1);
    buffer = (uint8_t*)av_malloc(num_bytes * sizeof(uint8_t));
    av_image_fill_arrays(frame_yuv->data, frame_yuv->linesize, buffer,
                       AV_PIX_FMT_YUV420P, dec_ctx->width, dec_ctx->height, 1);

    sws_ctx = sws_getContext(dec_ctx->width, dec_ctx->height, dec_ctx->pix_fmt,
                           dec_ctx->width, dec_ctx->height, AV_PIX_FMT_YUV420P,
                           SWS_BILINEAR, NULL, NULL, NULL);

    while (av_read_frame(fmt_ctx, &pkt) >= 0) {
        if (pkt.stream_index == video_stream_index) {
            avcodec_send_packet(dec_ctx, &pkt);
            while (avcodec_receive_frame(dec_ctx, frame) == 0) {
                sws_scale(sws_ctx, (const uint8_t *const *)frame->data, frame->linesize,
                        0, dec_ctx->height, frame_yuv->data, frame_yuv->linesize);
                SDL_UpdateYUVTexture(texture, NULL,
                                   frame_yuv->data[0], frame_yuv->linesize[0],
                                   frame_yuv->data[1], frame_yuv->linesize[1],
                                   frame_yuv->data[2], frame_yuv->linesize[2]);

                SDL_RenderClear(renderer);
                SDL_RenderCopy(renderer, texture, NULL, NULL);
                SDL_RenderPresent(renderer);
            }
        }
        av_packet_unref(&pkt);
    }

    av_free(buffer);
    av_frame_free(&frame);
    av_frame_free(&frame_yuv);
    sws_freeContext(sws_ctx);
    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    avcodec_free_context(&dec_ctx);
    avformat_close_input(&fmt_ctx);

    log_msg("[Receiver %d] Thread ended", display_index);
    return NULL;
}

int main() {
    log_msg("Program start. Waiting 30s before connecting...");
    sleep(30);

    // Khởi Caller 2 luồng từ camera Pi lên OBS qua SRT
    pthread_t caller1, caller2;
    pthread_create(&caller1, NULL, caller_thread, (void*)VIDEO_DEV1);
    pthread_create(&caller2, NULL, caller_thread, (void*)VIDEO_DEV2);

    // Khởi Receiver 2 luồng SRT từ OBS về Pi, phát ra 2 màn hình HDMI
    pthread_t receiver1, receiver2;
    StreamTask t1 = { STREAM1_SRT_URL, 0 };
    StreamTask t2 = { STREAM2_SRT_URL, 1 };
    pthread_create(&receiver1, NULL, receiver_thread, &t1);
    pthread_create(&receiver2, NULL, receiver_thread, &t2);

    pthread_join(caller1, NULL);
    pthread_join(caller2, NULL);
    pthread_join(receiver1, NULL);
    pthread_join(receiver2, NULL);

    log_msg("Program finished.");
    return 0;
}