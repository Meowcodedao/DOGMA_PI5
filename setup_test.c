#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <string.h>
#include <errno.h>
#include <time.h>

#define PORT1 1935
#define PORT2 1936
#define IP_ADDR "0.0.0.0"
#define TIMEOUT_SEC 10

// Kiểm tra HDMI có hoạt động không
int check_hdmi_outputs() {
    printf("🖥️  Kiểm tra màn hình HDMI...\n");
    FILE *fp = popen("xrandr | grep ' connected' | awk '{print $1}'", "r");
    if (!fp) {
        perror("Không thể kiểm tra HDMI");
        return 0;
    }

    char output[256];
    int count = 0;
    while (fgets(output, sizeof(output), fp) != NULL) {
        count++;
        printf("   ➜ %s", output);
    }
    pclose(fp);

    if (count == 0)
        printf("⚠️  Không phát hiện màn hình nào.\n");
    else
        printf("✅ Đã phát hiện %d màn hình HDMI.\n", count);

    return count;
}

// Chờ luồng SRT đến
int wait_for_stream(int port) {
    int sockfd;
    struct sockaddr_in addr;
    int result = 0;

    sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sockfd < 0) {
        perror("socket");
        return 0;
    }

    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = inet_addr(IP_ADDR);

    if (bind(sockfd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("bind");
        close(sockfd);
        return 0;
    }

    struct timeval tv = {TIMEOUT_SEC, 0};
    setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

    printf("⏳ Đang chờ luồng SRT trên cổng %d (tối đa %d giây)...\n", port, TIMEOUT_SEC);
    fflush(stdout);

    char buffer[64];
    struct sockaddr_in sender;
    socklen_t sender_len = sizeof(sender);

    int bytes = recvfrom(sockfd, buffer, sizeof(buffer), 0, (struct sockaddr*)&sender, &sender_len);
    if (bytes > 0) {
        printf("✅ Đã phát hiện luồng đến từ %s:%d\n", inet_ntoa(sender.sin_addr), ntohs(sender.sin_port));
        result = 1;
    } else {
        printf("⚠️  Không thấy luồng trên cổng %d sau %d giây.\n", port, TIMEOUT_SEC);
    }

    close(sockfd);
    return result;
}

// Chạy MPV tối ưu
void launch_mpv(int screen, int port) {
    char cmd[1024];
    snprintf(cmd, sizeof(cmd),
             "mpv --fs --screen=%d --profile=low-latency "
             "--hwdec=v4l2m2m --vo=gpu --gpu-context=drm "
             "--gpu-api=opengl --gpu-dither-depth=auto "
             "--scale=bilinear --cscale=bilinear "
             "--vf=scale=1024:600:force_original_aspect_ratio=decrease,format=yuv420p "
             "--deband --video-sync=audio --dither-depth=8 "
             "--no-border --geometry=0:0 "
             "--audio-buffer=0.05 --cache=no --demuxer-lavf-o=fflags=+nobuffer "
             "--keep-open=always --idle=once "
             "srt://:%d?mode=listener &",
             screen, port);

    printf("🎬 Mở MPV cho màn hình %d (cổng %d)\n", screen, port);
    fflush(stdout);
    system(cmd);
}

int main() {
    setenv("DISPLAY", ":0", 1);

    printf("🚀 DOGMA Dual HDMI Stream Receiver (Optimized)\n");
    printf("-------------------------------------------------\n");

    int hdmi_count = check_hdmi_outputs();
    if (hdmi_count == 0)
        return 1;

    int has_stream1 = wait_for_stream(PORT1);
    int has_stream2 = wait_for_stream(PORT2);

    if (has_stream1) launch_mpv(0, PORT1);
    if (has_stream2 && hdmi_count > 1) launch_mpv(1, PORT2);

    if (!has_stream1 && !has_stream2)
        printf("😴 Không có luồng nào được phát. Kết thúc.\n");
    else
        printf("✅ Đang phát các luồng video.\n");

    return 0;
}

