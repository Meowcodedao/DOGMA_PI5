#!/bin/bash
set -e

echo "=== Bắt đầu cài đặt môi trường phát video cho Raspberry Pi ==="

# -------------------------------
# 1️⃣ Cập nhật hệ thống
# -------------------------------
sudo apt update && sudo apt full-upgrade -y
sudo apt autoremove -y
sudo apt install -y software-properties-common apt-transport-https ca-certificates gnupg curl wget unzip

# -------------------------------
# 2️⃣ Cài công cụ phát triển cơ bản
# -------------------------------
sudo apt install -y \
  build-essential \
  cmake \
  git \
  pkg-config \
  htop \
  screen \
  vim \
  net-tools \
  tailscale

# -------------------------------
# 3️⃣ Cài thư viện multimedia và SRT
# -------------------------------
sudo apt install -y \
  ffmpeg \
  libsdl2-dev \
  libsdl2-ttf-dev \
  libsdl2-image-dev \
  libsdl2-mixer-dev \
  libavcodec-dev \
  libavformat-dev \
  libavutil-dev \
  libswscale-dev \
  libavfilter-dev \
  libsrt-dev \
  libdrm-dev \
  libv4l-dev \
  libx264-dev \
  libx265-dev \
  libfdk-aac-dev \
  libopus-dev \
  libass-dev

# -------------------------------
# 4️⃣ Cài thêm công cụ tối ưu cho video / streaming
# -------------------------------
sudo apt install -y \
  v4l-utils \
  gstreamer1.0-tools \
  gstreamer1.0-plugins-base \
  gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad \
  gstreamer1.0-libav \
  mesa-utils \
  x11-xserver-utils \
  unclutter   # ẩn chuột khi full screen

# -------------------------------
# 5️⃣ Tối ưu hệ thống cho phát video
# -------------------------------
echo "=== ⚙️ Cấu hình GPU memory và HDMI ==="
sudo sed -i '/^gpu_mem/d' /boot/config.txt
echo "gpu_mem=256" | sudo tee -a /boot/config.txt > /dev/null

# Bật cả 2 HDMI output
sudo sed -i '/^hdmi_force_hotplug/d' /boot/config.txt
echo "hdmi_force_hotplug=1" | sudo tee -a /boot/config.txt > /dev/null

# -------------------------------
# 6️⃣ Kiểm tra cài đặt
# -------------------------------
echo
echo "===  Kiểm tra nhanh ==="
echo "ffmpeg version:"
ffmpeg -version | head -n 1
echo
echo "srt-live-transmit version:"
srt-live-transmit --version 2>/dev/null || echo "SRT tool chưa có (thư viện vẫn ổn)"
echo
echo "tailscale status:"
sudo tailscale status || echo "Chưa đăng nhập Tailscale (chạy 'sudo tailscale up' sau khi cài)"

# -------------------------------
# 7️⃣ Tạo thư mục làm việc và log
# -------------------------------
mkdir -p ~/video_stream/logs
sudo touch /var/log/dual_srt_display.log
sudo chmod 666 /var/log/dual_srt_display.log

echo
echo "=== Hoàn tất cài đặt toàn bộ gói cần thiết! ==="
echo "Bạn có thể biên dịch chương trình C hoặc chạy ffplay/ffmpeg để test luồng SRT."
echo
echo "Ví dụ test nhận luồng SRT:"
echo "  ffplay -fflags nobuffer -flags low_delay -vf 'scale=1920:1080' srt://<OBS_IP>:9000"
echo
echo "Hoặc để xem HDMI:"
echo "  export DISPLAY=:0 && ffplay -fs srt://<OBS_IP>:9001"
echo
echo "File log: /var/log/dual_srt_display.log"

