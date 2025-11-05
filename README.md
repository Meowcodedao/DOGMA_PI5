# DOGMA_PI5 - Hướng dẫn chi tiết

Dự án phát video 2 luồng SRT nhận từ OBS qua Tailscale, xuất ra 2 màn hình HDMI trên Raspberry Pi 4/5.

## 1. Chuẩn bị môi trường

### 1.1. Cài đặt Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
```

Ghi lại IP Tailscale của Pi (sẽ cần để cấu hình):
```bash
tailscale ip -4
```

---

````markdown
# DOGMA_PI5 - Hướng dẫn sử dụng

Dự án phát video 2 luồng SRT nhận từ OBS qua Tailscale, xuất ra 2 màn hình HDMI trên Raspberry Pi 4/5.

---

## 1. Mở cổng & tắt tường lửa trên Raspberry Pi

Để đảm bảo Raspberry Pi nhận được luồng video từ OBS qua mạng Tailscale (hoặc mạng LAN), bạn cần mở cổng và tắt tường lửa.

### Tắt tường lửa (nếu có):

```bash
sudo systemctl stop ufw
sudo systemctl disable ufw
````

### Mở cổng cho giao thức SRT (port mặc định trong code là 9999 và 10000):

```bash
sudo iptables -A INPUT -p udp --dport 9999 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 10000 -j ACCEPT
```

Kiểm tra lại:

```bash
sudo iptables -L -v -n | grep 9999
sudo iptables -L -v -n | grep 10000
```

**Lưu ý:** Nếu bạn sử dụng firewall khác, vui lòng cấu hình tương tự cho 2 port UDP trên.

---

## 2. Cách chạy file `.sh` và `.c`

### 2.1. Chạy script cài đặt thư viện và công cụ (`install_requirement_lib.sh`)

1. Clone repo về Pi:

```bash
git clone git@github.com:Meowcodedao/DOGMA_PI5.git
cd DOGMA_PI5
```

2. Cấp quyền và chạy script:

```bash
chmod +x install_requirement_lib.sh
sudo ./install_requirement_lib.sh
```

3. Sau khi chạy xong, **khởi động lại Pi** để áp dụng thay đổi:

```bash
sudo reboot
```

---

### 2.2. Biên dịch file C nguồn (`DOGMA_pi_caller_obs_listener.c`)

Sau khi Pi đã khởi động lại và vào lại thư mục dự án:

```bash
gcc DOGMA_pi_caller_obs_listener2.c -o DOGMA_pi_caller_obs_listener2 $(pkg-config --cflags --libs libavformat libavcodec libavutil libswscale sdl2) -lpthread
```

### 2.3. Chạy chương trình

```bash
sudo touch /var/log/dual_srt_display.log
sudo chmod 666 /var/log/dual_srt_display.log
./dual_srt_display
```

* Chương trình sẽ chờ 30 giây trước khi kết nối stream.
* 2 luồng video sẽ được nhận qua giao thức SRT và hiển thị trên 2 màn hình HDMI.
* Log lỗi và thông tin được ghi vào file `/var/log/dual_srt_display.log`.

---

## 3. Cách đọc log để biết lỗi

### Xem log realtime (để theo dõi lỗi, trạng thái):

```bash
tail -f /var/log/dual_srt_display.log
```

### Xem toàn bộ log:

```bash
cat /var/log/dual_srt_display.log
```

### Kiểm tra lỗi hệ thống:

```bash
sudo dmesg | grep -i error
```

Nếu chạy chương trình dưới dạng `systemd service`, xem log:

```bash
sudo journalctl -u dual_srt_display.service -f
```

---

## 4. Cấu hình OBS và Raspberry Pi để truyền qua giao thức SRT

### 4.1. Trên máy Windows chạy OBS

1. Cài Tailscale, đăng nhập cùng tài khoản với Pi.

2. Mở OBS → **Settings → Stream**

3. Chọn `Custom Streaming Server`

4. Cấu hình URL:

```
srt://<PI_TAILSCALE_IP>:9999?mode=listener
```

và luồng thứ 2:

```
srt://<PI_TAILSCALE_IP>:10000?mode=listener
```

> Thay `<PI_TAILSCALE_IP>` bằng địa chỉ IP của Raspberry Pi trong mạng Tailscale (kiểm tra bằng `tailscale ip -4` trên Pi).

5. Stream key có thể để trống hoặc theo cấu hình riêng.

6. Thiết lập 2 stream OBS riêng biệt để phát ra 2 cổng tương ứng.

---

### 4.2. Trên Raspberry Pi

* Đảm bảo đã chạy chương trình `dual_srt_display` để Pi là **caller**, kết nối tới 2 luồng SRT của OBS đang ở chế độ **listener**.

* Pi sẽ nhận và hiển thị 2 luồng video trên 2 màn hình HDMI.

---

## 5. Các lưu ý bổ sung

* Để ẩn chuột khi phát full screen, bạn có thể chạy:

```bash
unclutter -idle 0 &
```

* Nếu muốn giảm độ trễ, có thể thêm tham số `-fflags nobuffer -flags low_delay -framedrop` khi test stream bằng `ffplay`.

* Đảm bảo trong `/boot/config.txt` có:

```
hdmi_force_hotplug=1
gpu_mem=256
```

để bật HDMI và cấp đủ RAM GPU cho video playback.


```

gcc DOGMA_pi_caller_obs_listener2.c -o DOGMA_pi_caller_obs_listener2 $(pkg-config --cflags --libs libavformat libavcodec libavutil libswscale sdl2) -lpthread


SERVICE


File /etc/systemd/system/dogma_stream.service

[Unit]
Description=DOGMA Dual HDMI Stream Service
After=network.target

[Service]
Type=simple
ExecStart=/home/danivan/Documents/DOGMA/dogma_stream
Restart=on-failure
User=danivan
WorkingDirectory=/home/danivan/Documents/DOGMA
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target

---

### Hướng dẫn cài đặt nhanh:

1. Tạo file service:

```bash
sudo nano /etc/systemd/system/dogma_stream.service
```

2. Dán nội dung trên vào rồi lưu lại.

3. Tải lại systemd config:

```bash
sudo systemctl daemon-reload
```

4. Bật service tự khởi động cùng máy:

```bash
sudo systemctl enable dogma_stream.service
```

5. Khởi động service ngay:

```bash
sudo systemctl start dogma_stream.service
```

6. Kiểm tra trạng thái service:

```bash
sudo systemctl status dogma_stream.service
```

7. Xem log realtime:

```bash
journalctl -u dogma_stream.service -f
```

---
