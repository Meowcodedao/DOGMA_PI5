#!/bin/bash
# =========================================================
# DOGMA Control Center - Ultimate (Merged & Detailed)
# Quản lý 9 Raspberry Pi + 2 Windows PC (qua SSH) + OBS CONTROL
# - Gộp chi tiết nhất từ: dongma_test.sh
# - Gộp tổ chức menu + THAO TAC LAPTOP/PC từ: dogma_control.sh
# - Thêm OBS CONTROL (Windows): xem trạng thái, restart, start/stop streaming
# - Giữ mức chi tiết CAO NHẤT cho từng chức năng nhưng dễ dùng
# =========================================================

# ============================================
# CẤU HÌNH PI / PC
# ============================================

# Danh sách Pi (user@tailscale-ip:alias)
PI_LIST=(
    "ltr12@100.88.81.125:ltr01"
    "ltr34@100.79.62.19:ltr02"
    "ltr56@100.74.119.77:ltr03"
    "ltr78@100.101.23.34:ltr04"
    "ltr910@100.88.124.67:ltr05"
    "ltr1112@100.81.164.10:ltr06"
    "ltr1314@100.122.129.109:ltr07"
    "ltr1516@100.92.7.127:ltr08"
    "ltr1718@100.67.216.95:ltr09"
)

# Danh sách Laptop/PC (user@tailscale-ip:alias)
PC_LIST=(
    "pc@100.89.227.12:laptop"
    "admin@100.122.249.33:pc"
)

# Tùy chọn hiển thị/ẩn chức năng Shutdown toàn bộ (an toàn mặc định là ẩn)
SHOW_SHUTDOWN_ALL=0

# ============================================
# OBS CONTROL - CONFIG
# ============================================

# alias|user|ip|ssh_password|obs_path|ws_port|ws_password
OBS_HOSTS=(
  "laptop|pc|100.89.227.12|123|C:\Program Files\obs-studio\bin\64bit\obs64.exe|4455|YOUR_WS_PASS_LAPTOP"
  "pc|admin|100.122.249.33|123|C:\Program Files\obs-studio\bin\64bit\obs64.exe|4455|YOUR_WS_PASS_PC"
)

# Tuỳ chọn khi mở OBS (nếu muốn auto load)
OBS_COLLECTION=""   # ví dụ: "MyCollection"
OBS_PROFILE=""      # ví dụ: "Default"
OBS_SCENE=""        # ví dụ: "Scene 1"

# ============================================
# MÀU SẮC / TIỆN ÍCH CHUNG
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

press_enter() { echo ""; read -p "Nhấn Enter để tiếp tục..."; }
have() { command -v "$1" >/dev/null 2>&1; }

need_cmds=(ssh ping awk sed grep cut sort head tail date bc timeout)
opt_cmds=(vnstat ifstat iostat mpstat lsof ss traceroute)

check_prereqs() {
    local missing=()
    for c in "${need_cmds[@]}"; do
        command -v "$c" >/dev/null 2>&1 || missing+=("$c")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}Cảnh báo:${NC} Thiếu lệnh bắt buộc: ${missing[*]}"
        echo "Vui lòng cài thêm để có đầy đủ tính năng."
    fi

    local opt_missing=()
    for c in "${opt_cmds[@]}"; do
        command -v "$c" >/dev/null 2>&1 || opt_missing+=("$c")
    done
    if [ ${#opt_missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}Gợi ý:${NC} Nên cài thêm: ${opt_missing[*]} (để có thống kê chi tiết hơn)"
        echo "Ví dụ Debian/Ubuntu: sudo apt install -y ${opt_missing[*]} (bỏ các lệnh không có trong repo)"
    fi

    if ! command -v sshpass >/dev/null 2>&1; then
        echo -e "${YELLOW}Gợi ý:${NC} Thiếu sshpass (cần cho SSH Windows với password). Cài: sudo apt install -y sshpass"
    fi
    if ! command -v obs-cli >/dev/null 2>&1; then
        echo -e "${YELLOW}Gợi ý:${NC} Thiếu obs-cli (điều khiển Start/Stop stream qua WebSocket)."
        echo "  Cài nhanh (đã có Go): go install github.com/muesli/obs-cli@latest && export PATH=\"\$PATH:\$(go env GOPATH)/bin\""
    fi
    echo ""
}

print_header() {
    clear
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${CYAN}                      DOGMA Control Center${NC}"
    echo -e "${CYAN}               Quản lý 9 Raspberry Pi + 2 Windows PC${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_subsection() {
    echo ""
    echo -e "${CYAN}━━━ $1 ━━━${NC}"
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p $pid >/dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Lấy chuỗi "user@ip" theo index
pi_userhost_by_index() {
    local idx=$1
    local entry="${PI_LIST[$idx]}"
    echo "$entry" | cut -d: -f1
}
# Lấy alias theo index
pi_name_by_index() {
    local idx=$1
    local entry="${PI_LIST[$idx]}"
    echo "$entry" | cut -d: -f2
}

# ============================================
# MENU CHÍNH
# ============================================

show_menu() {
    print_header
    echo -e "${GREEN}1) GIÁM SÁT HỆ THỐNG PI (chi tiết cao nhất)${NC}"
    echo "   1  - Trạng thái tổng quan đầy đủ"
    echo "   2  - Luồng stream SRT chi tiết"
    echo "   3  - Screenshot (mới nhất trên mỗi Pi)"
    echo "   4  - Wallpaper (service + lần chạy gần nhất)"
    echo "   5  - Kết nối SSH & Ping"
    echo "   6  - Đồng bộ rclone (trạng thái)"
    echo "   7  - Nhiệt độ & phần cứng chi tiết"
    echo "   8  - Log chi tiết từng Pi"
    echo ""
    echo -e "${YELLOW}2) THAO TÁC HỆ THỐNG PI${NC}"
    echo "   11 - Update & Upgrade tất cả"
    echo "   12 - Reboot tất cả Pi"
    [ "$SHOW_SHUTDOWN_ALL" -eq 1 ] && echo "   12s- Shutdown tất cả Pi (rất nguy hiểm)"
    echo "   13 - Cập nhật wallpaper tất cả Pi"
    echo "   14 - Restart service (dogma-dual / wallpaper)"
    echo "   15 - Redeploy lại scripts (chạy ~/deploy_all_9pi.sh nếu có)"
    echo "   16 - Backup config/log từ tất cả Pi"
    echo ""
    echo -e "${CYAN}3) THAO TÁC LAPTOP/PC (nhập mật khẩu thủ công)${NC}"
    echo "   21 - SSH vào Laptop (pc@100.89.227.12)"
    echo "   22 - SSH vào PC (admin@100.122.249.33)"
    echo "   23 - Kiểm tra trạng thái Laptop/PC"
    echo "   24 - Chạy lệnh trên tất cả Laptop/PC"
    echo ""
    echo -e "${MAGENTA}4) CÔNG CỤ${NC}"
    echo "   31 - SSH vào một Pi cụ thể"
    echo "   32 - Xuất báo cáo HTML CHI TIẾT"
    echo "   33 - Xem log realtime (dual_stream.log)"
    echo ""
    echo -e "${MAGENTA}5) OBS CONTROL${NC}"
    echo "   41 - OBS: Thông tin các luồng & trạng thái"
    echo "   42 - OBS: Restart OBS (Run in normal mode)"
    echo "   43 - OBS: Start streaming tất cả"
    echo "   44 - OBS: Stop streaming tất cả (safe, auto-recover)"
    echo ""
    echo "   0  - Thoát"
    echo ""
    echo -n "➤ Chọn chức năng: "
}

# ============================================
# 1. GIÁM SÁT HỆ THỐNG PI (Chi tiết cao)
# ============================================

check_overview() {
    print_section "TRẠNG THÁI TỔNG QUAN 9 PI"

    local online=0 offline=0
    printf "%-8s %-18s %-10s %-12s %-10s %-12s %-10s\n" \
        "Pi" "IP" "Status" "Wallpaper" "Stream" "GPU" "Temp"
    echo "─────────────────────────────────────────────────────────────────────────────"

    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo "$entry" | cut -d: -f1)
        local name=$(echo "$entry" | cut -d: -f2)
        local host=$(echo "$pi" | cut -d'@' -f2)

        printf "%-8s %-18s " "$name" "$host"

        if timeout 3 ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no "$pi" "exit" 2>/dev/null; then
            echo -ne "${GREEN}Online${NC}    "; ((online++))
            # Wallpaper
            local wp=$(timeout 2 ssh "$pi" 'systemctl is-active dogma-wallpaper 2>/dev/null')
            if [[ "$wp" == "active" || "$wp" == "inactive" ]]; then
                echo -ne "${GREEN}✓${NC}           "
            else
                echo -ne "${RED}✗${NC}           "
            fi
            # Stream
            local stream=$(timeout 2 ssh "$pi" 'systemctl is-active dogma-dual 2>/dev/null')
            if [[ "$stream" == "active" ]]; then
                echo -ne "${GREEN}✓${NC}        "
            else
                echo -ne "${RED}✗${NC}        "
            fi
            # GPU
            local gpu=$(timeout 2 ssh "$pi" 'vcgencmd get_mem gpu 2>/dev/null' | cut -d= -f2)
            printf "%-12s " "${gpu:-N/A}"
            # Temp
            local temp=$(timeout 2 ssh "$pi" 'vcgencmd measure_temp 2>/dev/null' | cut -d= -f2)
            echo "${temp:-N/A}"
        else
            echo -e "${RED}Offline${NC}   ${RED}✗${NC}           ${RED}✗${NC}        ${RED}N/A${NC}          ${RED}N/A${NC}"
            ((offline++))
        fi
    done

    echo ""
    echo -e "📊 Tổng kết: ${GREEN}${online} Online${NC} | ${RED}${offline} Offline${NC}"
    press_enter
}

check_stream() {
    print_section "LUỒNG STREAM SRT CHI TIẾT"

    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo "$entry" | cut -d: -f1)
        local name=$(echo "$entry" | cut -d: -f2)

        print_subsection "$name"

        if ! timeout 5 ssh -o ConnectTimeout=3 "$pi" "exit" 2>/dev/null; then
            echo -e "${RED}Pi offline${NC}"
            continue
        fi

        # Service status
        local service_status=$(ssh "$pi" 'systemctl is-active dogma-dual 2>/dev/null')
        local service_enabled=$(ssh "$pi" 'systemctl is-enabled dogma-dual 2>/dev/null')
        echo "=== SERVICE STATUS ==="
        echo "Status  : $service_status"
        echo "Enabled : $service_enabled"
        echo ""
        echo "Service details (tóm tắt):"
        ssh "$pi" 'systemctl status dogma-dual --no-pager -l 2>/dev/null' | head -n 12 | sed 's/^/  /'

        if [ "$service_status" != "active" ]; then
            echo ""
            echo -e "${RED}Service không hoạt động. Nhật ký gần đây:${NC}"
            ssh "$pi" 'journalctl -u dogma-dual -n 20 --no-pager 2>/dev/null' | sed 's/^/  /'
            echo ""
            continue
        fi

        # FFplay processes
        echo ""
        echo "=== FFPLAY PROCESSES ==="
        local ffplay_pids=$(ssh "$pi" 'pgrep ffplay' 2>/dev/null)
        local ffplay_count=$(echo "$ffplay_pids" | grep -c . 2>/dev/null || echo 0)
        echo "Active processes: $ffplay_count/2"
        echo ""

        local srt_url_first=""
        local i=0
        for pid in $ffplay_pids; do
            i=$((i+1))
            echo "--- Stream $i (PID: $pid) ---"
            local cpu=$(ssh "$pi" "ps -p $pid -o %cpu --no-headers" | xargs)
            local mem=$(ssh "$pi" "ps -p $pid -o %mem --no-headers" | xargs)
            local vsz=$(ssh "$pi" "ps -p $pid -o vsz --no-headers" | xargs)
            local rss=$(ssh "$pi" "ps -p $pid -o rss --no-headers" | xargs)
            local etime=$(ssh "$pi" "ps -p $pid -o etime --no-headers" | xargs)
            local stat=$(ssh "$pi" "ps -p $pid -o stat --no-headers" | xargs)
            echo "CPU: ${cpu}% | MEM: ${mem}% | VSZ: $((vsz/1024))MB | RSS: $((rss/1024))MB | Time: $etime | State: $stat"

            local cmdline=$(ssh "$pi" "ps -p $pid -o args --no-headers 2>/dev/null")
            echo "Command:"
            echo "$cmdline" | fold -w 100 | sed 's/^/  /'

            # Extract SRT URL + port
            local srt_url=$(echo "$cmdline" | grep -oE 'srt://[^ ]+')
            if [ -n "$srt_url" ]; then
                echo "SRT URL: $srt_url"
                [ -z "$srt_url_first" ] && srt_url_first="$srt_url"
                local port=$(echo "$srt_url" | grep -oE ':[0-9]+' | head -1 | sed 's/://')
                [ -n "$port" ] && echo "Port   : $port"
            fi

            echo ""
            echo "Network sockets (UDP) của PID:"
            if command -v lsof >/dev/null 2>&1; then
                ssh "$pi" "lsof -p $pid -a -i UDP 2>/dev/null" | grep -v COMMAND | sed 's/^/  /' || echo "  (none)"
            else
                echo "  (lsof chưa cài)"
            fi
            echo ""
        done

        # Stream log analysis
        echo "=== STREAM LOG ANALYSIS ==="
        local log_file="/opt/DOGMA/logs/dual_stream.log"
        if ssh "$pi" "[ -f $log_file ]" 2>/dev/null; then
            local log_size=$(ssh "$pi" "du -h $log_file | awk '{print \$1}'")
            local error_count=$(ssh "$pi" "grep -icE \"error|failed|timeout|refused\" $log_file 2>/dev/null" || echo "0")
            local warning_count=$(ssh "$pi" "grep -ic \"warning\" $log_file 2>/dev/null" || echo "0")
            echo "Log file : $log_file ($log_size)"
            echo "Errors   : $error_count"
            echo "Warnings : $warning_count"
            echo ""
            [ "$error_count" -gt 0 ] && echo "Last 5 errors:" && ssh "$pi" "grep -iE \"error|failed|timeout|refused\" $log_file 2>/dev/null | tail -5" | sed 's/^/  /'
            echo ""
            echo "Last 10 lines:"
            ssh "$pi" "tail -10 $log_file" | sed 's/^/  /'
        else
            echo "Không tồn tại $log_file"
        fi

        # Network stats & bandwidth
        echo ""
        echo "=== NETWORK STATS & BANDWIDTH ==="
        echo "Active SRT connections:"
        if command -v ss >/dev/null 2>&1; then
            ssh "$pi" "ss -u -n 2>/dev/null | grep -E ':(193[5-9]|194[0-9]|195[0-9])'" | sed 's/^/  /' || echo "  (none)"
        else
            ssh "$pi" "netstat -anu 2>/dev/null | grep -E ':(193[5-9]|194[0-9]|195[0-9])'" | sed 's/^/  /' || echo "  (none)"
        fi

        echo ""
        local interface=$(ssh "$pi" "ip route | grep default | awk '{print \$5}' | head -1")
        [ -z "$interface" ] && interface="eth0"
        echo "Interface: $interface"
        local bandwidth_done=0
        if ssh "$pi" 'command -v vnstat' >/dev/null 2>&1; then
            echo "vnstat sample (2s):"
            ssh "$pi" "vnstat -i $interface -tr 2 2>/dev/null" | sed 's/^/  /'
            bandwidth_done=1
        elif ssh "$pi" 'command -v ifstat' >/dev/null 2>&1; then
            echo "ifstat sample (3s):"
            ssh "$pi" "ifstat -i $interface 1 3 2>/dev/null | tail -1" | awk '{printf "  RX: %.2f KB/s | TX: %.2f KB/s\n", $1, $2}'
            bandwidth_done=1
        fi
        if [ $bandwidth_done -eq 0 ]; then
            # Fallback /proc/net/dev (2s delta)
            local stats1=$(ssh "$pi" "cat /proc/net/dev | grep '$interface' | awk '{print \$2, \$10}'")
            if [ -n "$stats1" ]; then
                sleep 2
                local stats2=$(ssh "$pi" "cat /proc/net/dev | grep '$interface' | awk '{print \$2, \$10}'")
                if [ -n "$stats2" ]; then
                    local rx1=$(echo "$stats1" | awk '{print $1}')
                    local tx1=$(echo "$stats1" | awk '{print $2}')
                    local rx2=$(echo "$stats2" | awk '{print $1}')
                    local tx2=$(echo "$stats2" | awk '{print $2}')
                    local rx_rate=$(( (rx2 - rx1) / 2 / 1024 ))
                    local tx_rate=$(( (tx2 - tx1) / 2 / 1024 ))
                    echo "RX: ${rx_rate} KB/s | TX: ${tx_rate} KB/s"
                fi
            fi
        fi

        # Connection quality to OBS if parsed from SRT URL
        echo ""
        echo "=== CONNECTION QUALITY (OBS target) ==="
        local obs_ip=""
        if [ -n "$srt_url_first" ]; then
            obs_ip=$(echo "$srt_url_first" | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | head -1)
        fi
        if [ -n "$obs_ip" ]; then
            echo "Target: $obs_ip"
            local ping_result=$(ssh "$pi" "ping -c 3 -W 2 $obs_ip 2>/dev/null")
            if [ -n "$ping_result" ]; then
                local packet_loss=$(echo "$ping_result" | grep "packet loss" | grep -oE '[0-9]+%' | tr -d '%')
                local rtt_line=$(echo "$ping_result" | grep -E "rtt|round-trip")
                local avg_rtt=$(echo "$rtt_line" | tr '/' '\n' | sed -n '2p' | grep -oE '[0-9]+(\.[0-9]+)?')
                echo "Packet loss: ${packet_loss:-N/A}% | RTT avg: ${avg_rtt:-N/A} ms"
            else
                echo "Không ping được $obs_ip"
            fi
        else
            echo "Không trích xuất được OBS IP từ SRT URL"
        fi

        echo ""
    done

    press_enter
}

check_screenshot() {
    print_section "KIỂM TRA SCREENSHOT"

    printf "%-8s %-25s %-15s %s\n" "Pi" "Latest Screenshot" "Size" "Modified"
    echo "────────────────────────────────────────────────────────────────────────"
    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo "$entry" | cut -d: -f1)
        local name=$(echo "$entry" | cut -d: -f2)
        printf "%-8s " "$name"
        if timeout 3 ssh -o ConnectTimeout=2 "$pi" "exit" 2>/dev/null; then
            local latest=$(ssh "$pi" 'find ~/Pictures -maxdepth 1 -type f \( -name "*.png" -o -name "*.jpg" \) -printf "%T@ %f %s\n" 2>/dev/null | sort -rn | head -1')
            if [ -n "$latest" ]; then
                local filename=$(echo "$latest" | awk '{print $2}')
                local size=$(echo "$latest" | awk '{printf "%.1fMB", $3/1024/1024}')
                local timestamp=$(echo "$latest" | awk '{print $1}')
                local modified=$(date -d @${timestamp%.*} '+%Y-%m-%d %H:%M' 2>/dev/null || echo "Unknown")
                printf "%-25s %-15s %s\n" "${filename:0:25}" "$size" "$modified"
            else
                echo -e "${YELLOW}No screenshots found${NC}"
            fi
        else
            echo -e "${RED}Pi offline${NC}"
        fi
    done
    press_enter
}

check_wallpaper() {
    print_section "KIỂM TRA WALLPAPER"

    printf "%-8s %-12s %-25s %s\n" "Pi" "Service" "Last Run" "Status"
    echo "────────────────────────────────────────────────────────────────────────"
    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo "$entry" | cut -d: -f1)
        local name=$(echo "$entry" | cut -d: -f2)
        printf "%-8s " "$name"
        if timeout 3 ssh -o ConnectTimeout=2 "$pi" "exit" 2>/dev/null; then
            local service=$(ssh "$pi" 'systemctl is-enabled dogma-wallpaper 2>/dev/null')
            if [ "$service" = "enabled" ]; then echo -ne "${GREEN}Enabled${NC}     "; else echo -ne "${RED}Disabled${NC}    "; fi
            local last_run=$(ssh "$pi" 'grep "Hoàn tất" /opt/DOGMA/logs/wallpaper.log 2>/dev/null | tail -1')
            if [ -n "$last_run" ]; then
                local timestamp=$(echo "$last_run" | grep -oE "\[[^]]+\]" | head -1 | sed 's/\[//;s/\]//')
                printf "%-25s %s\n" "${timestamp:0:25}" "${GREEN}Success${NC}"
            else
                printf "%-25s %s\n" "Never run" "${YELLOW}No log${NC}"
            fi
        else
            echo -e "${RED}N/A         Pi offline${NC}"
        fi
    done
    press_enter
}

check_connection() {
    print_section "KẾT NỐI SSH & PING"

    printf "%-8s %-18s %-10s %-15s %s\n" "Pi" "IP" "SSH" "Ping (ms)" "Uptime"
    echo "────────────────────────────────────────────────────────────────────────"
    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo "$entry" | cut -d: -f1)
        local name=$(echo "$entry" | cut -d: -f2)
        local host=$(echo "$pi" | cut -d'@' -f2)
        printf "%-8s %-18s " "$name" "$host"

        # Ping
        local ping_ms=$(ping -c 1 -W 1 "$host" 2>/dev/null | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}')
        if [ -n "$ping_ms" ]; then
            echo -ne "${GREEN}✓${NC}         "; printf "%-15s " "${ping_ms} ms"
            local uptime=$(timeout 3 ssh -o ConnectTimeout=2 "$pi" 'uptime -p 2>/dev/null')
            if [ -n "$uptime" ]; then echo -e "${GREEN}$uptime${NC}"; else echo -e "${RED}SSH failed${NC}"; fi
        else
            echo -e "${RED}✗${NC}         N/A             Ping failed"
        fi
    done
    press_enter
}

check_rclone() {
    print_section "ĐỒNG BỘ RCLONE"

    printf "%-8s %-12s %-25s %s\n" "Pi" "Status" "Last Sync" "Files"
    echo "────────────────────────────────────────────────────────────────────────"
    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo "$entry" | cut -d: -f1)
        local name=$(echo "$entry" | cut -d: -f2)
        printf "%-8s " "$name"
        if timeout 3 ssh -o ConnectTimeout=2 "$pi" "exit" 2>/dev/null; then
            if ssh "$pi" 'command -v rclone' &>/dev/null; then
                echo -ne "${GREEN}Installed${NC}   "
                local last_sync=$(ssh "$pi" 'find /var/log -type f -name "*rclone*.log" -o -name "*sync*.log" 2>/dev/null | xargs -r tail -1 2>/dev/null | head -1')
                if [ -n "$last_sync" ]; then
                    printf "%-25s %s\n" "$(echo "$last_sync" | cut -c1-25)" "${GREEN}Active${NC}"
                else
                    printf "%-25s %s\n" "No recent sync" "${YELLOW}Unknown${NC}"
                fi
            else
                echo -e "${RED}Not installed${NC}"
            fi
        else
            echo -e "${RED}Pi offline${NC}"
        fi
    done
    press_enter
}

check_hardware() {
    print_section "NHIỆT ĐỘ & PHẦN CỨNG CHI TIẾT"

    local total_temp=0 count=0 max_temp=0 min_temp=100

    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo "$entry" | cut -d: -f1)
        local name=$(echo "$entry" | cut -d: -f2)
        print_subsection "$name"

        if ! timeout 3 ssh -o ConnectTimeout=2 "$pi" "exit" 2>/dev/null; then
            echo -e "${RED}Pi offline${NC}"
            continue
        fi

        echo "=== TEMPERATURE ==="
        local temp=$(ssh "$pi" 'vcgencmd measure_temp 2>/dev/null' | cut -d= -f2 | sed "s/'C//")
        if [ -n "$temp" ]; then
            if (( $(echo "$temp > 70" | bc -l 2>/dev/null || echo 0) )); then
                echo -e "Current: ${RED}${temp}°C (HIGH)${NC}"
            elif (( $(echo "$temp > 60" | bc -l 2>/dev/null || echo 0) )); then
                echo -e "Current: ${YELLOW}${temp}°C (Warm)${NC}"
            else
                echo -e "Current: ${GREEN}${temp}°C (Normal)${NC}"
            fi
            total_temp=$(echo "$total_temp + $temp" | bc 2>/dev/null || echo "$total_temp")
            ((count++))
            (( $(echo "$temp > $max_temp" | bc -l 2>/dev/null || echo 0) )) && max_temp=$temp
            (( $(echo "$temp < $min_temp" | bc -l 2>/dev/null || echo 0) )) && min_temp=$temp
        else
            echo "Current: N/A"
        fi

        echo ""
        echo "=== CPU INFO ==="
        local cpu_freq=$(ssh "$pi" 'vcgencmd measure_clock arm 2>/dev/null' | awk -F= '{printf "%.0f", $2/1000000}')
        local cpu_max=$(ssh "$pi" 'cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null' | awk '{printf "%.0f", $1/1000}')
        local cpu_gov=$(ssh "$pi" 'cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null')
        echo "Frequency:  ${cpu_freq} MHz"
        echo "Max Freq :  ${cpu_max:-N/A} MHz"
        echo "Governor :  ${cpu_gov:-N/A}"

        echo ""
        echo "CPU usage per core (nếu có mpstat):"
        if ssh "$pi" 'command -v mpstat' &>/dev/null; then
            ssh "$pi" 'mpstat -P ALL 1 1 2>/dev/null | tail -n +4' | sed 's/^/  /'
        else
            echo "  mpstat chưa cài"
        fi

        echo ""
        echo "=== MEMORY ==="
        ssh "$pi" 'free -h' | sed 's/^/  /'

        echo ""
        echo "=== GPU/ARM MEMORY ==="
        local gpu_mem=$(ssh "$pi" 'vcgencmd get_mem gpu 2>/dev/null' | cut -d= -f2)
        local arm_mem=$(ssh "$pi" 'vcgencmd get_mem arm 2>/dev/null' | cut -d= -f2)
        echo "GPU: ${gpu_mem:-N/A} | ARM: ${arm_mem:-N/A}"

        echo ""
        echo "=== VOLTAGE & THROTTLING ==="
        local core_volt=$(ssh "$pi" 'vcgencmd measure_volts core 2>/dev/null' | cut -d= -f2)
        local sdram_c=$(ssh "$pi" 'vcgencmd measure_volts sdram_c 2>/dev/null' | cut -d= -f2)
        local throttled=$(ssh "$pi" 'vcgencmd get_throttled 2>/dev/null' | cut -d= -f2)
        echo "Core Volt: ${core_volt:-N/A} | SDRAM C: ${sdram_c:-N/A}"
        echo -n "Throttled: "
        if [ "$throttled" = "0x0" ]; then echo -e "${GREEN}No${NC}"; else echo -e "${RED}Yes ($throttled)${NC}"; fi

        echo ""
        echo "=== DISK I/O (nếu có iostat) ==="
        if ssh "$pi" 'command -v iostat' &>/dev/null; then
            ssh "$pi" 'iostat -x 1 2 2>/dev/null | tail -n +4' | sed 's/^/  /'
        else
            echo "  iostat chưa cài"
        fi

        echo ""
        echo "=== TOP PROCESSES BY CPU ==="
        ssh "$pi" 'ps aux --sort=-%cpu | head -6' | sed 's/^/  /'

        echo ""
        echo "=== TOP PROCESSES BY MEMORY ==="
        ssh "$pi" 'ps aux --sort=-%mem | head -6' | sed 's/^/  /'

        echo ""
    done

    if [ $count -gt 0 ]; then
        local avg_temp=$(echo "scale=1; $total_temp / $count" | bc 2>/dev/null || echo "N/A")
        print_subsection "TỔNG KẾT NHIỆT ĐỘ"
        echo "Trung bình: ${avg_temp}°C | Cao nhất: ${max_temp}°C | Thấp nhất: ${min_temp}°C"
    fi
    press_enter
}

check_detailed_log() {
    print_section "LOG CHI TIẾT THEO PI"

    echo "Chọn Pi:"
    local i=1
    for entry in "${PI_LIST[@]}"; do
        echo "  $i) $(echo "$entry" | cut -d: -f2)"; ((i++))
    done
    echo "  0) Quay lại"
    echo ""
    echo -n "➤ Chọn [0-9]: "
    read ch
    if [ "$ch" -ge 1 ] && [ "$ch" -le 9 ]; then
        local idx=$((ch-1))
        local pi=$(pi_userhost_by_index "$idx")
        local name=$(pi_name_by_index "$idx")
        clear
        echo -e "${CYAN}━━━ LOG: $name ━━━${NC}"
        echo ""
        echo "[1] Wallpaper log (tail -20)"
        ssh "$pi" 'tail -20 /opt/DOGMA/logs/wallpaper.log 2>/dev/null' || echo "No log"
        echo ""
        echo "[2] Stream log (tail -20)"
        ssh "$pi" 'tail -20 /opt/DOGMA/logs/dual_stream.log 2>/dev/null' || echo "No log"
        echo ""
        echo "[3] System error (journalctl -p err -n 10)"
        ssh "$pi" 'journalctl -p err -n 10 --no-pager 2>/dev/null' || echo "No errors"
        echo ""
        echo "[4] Disk usage (df -h | root)"
        ssh "$pi" 'df -h | grep -E "Filesystem|/$"'
        echo ""
        echo "[5] Memory usage (free -h)"
        ssh "$pi" 'free -h'
        echo ""
        press_enter
    fi
}

# ============================================
# 2. THAO TÁC HỆ THỐNG PI
# ============================================

update_upgrade_all() {
    print_section "UPDATE & UPGRADE TẤT CẢ PI"
    echo -e "${YELLOW}Thao tác này có thể mất 5-10 phút cho mỗi Pi${NC}"
    echo -n "Xác nhận tiếp tục? (yes/no): "
    read confirm
    [ "$confirm" != "yes" ] && echo "Đã hủy." && sleep 1 && return

    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo "$entry" | cut -d: -f1)
        local name=$(echo "$entry" | cut -d: -f2)
        echo -ne "[$name] "
        if timeout 3 ssh -o ConnectTimeout=2 "$pi" "exit" 2>/dev/null; then
            ssh "$pi" 'export DEBIAN_FRONTEND=noninteractive; sudo apt update -qq && sudo apt -y upgrade' &>/dev/null &
            spinner $!; wait $!
            echo -e " ${GREEN}Done${NC}"
        else
            echo -e "${RED}Offline${NC}"
        fi
    done
    echo ""
    press_enter
}

reboot_all() {
    print_section "REBOOT TẤT CẢ PI"
    echo -e "${RED}Tất cả Pi sẽ bị reboot!${NC}"
    echo -n "Xác nhận (yes/no): "
    read confirm
    [ "$confirm" != "yes" ] && echo "Đã hủy." && sleep 1 && return

    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo "$entry" | cut -d: -f1)
        local name=$(echo "$entry" | cut -d: -f2)
        echo -ne "[$name] "
        if timeout 3 ssh -o ConnectTimeout=2 "$pi" "exit" 2>/dev/null; then
            ssh "$pi" 'sudo reboot' &>/dev/null &
            echo -e "${GREEN}Rebooting${NC}"
        else
            echo -e "${RED}Offline${NC}"
        fi
    done
    echo ""
    echo -e "${YELLOW}Chờ 2-3 phút để các Pi khởi động lại${NC}"
    press_enter
}

shutdown_all() {
    print_section "SHUTDOWN TẤT CẢ PI"
    echo -e "${RED}CẢNH BÁO: Tất cả Pi sẽ TẮT HOÀN TOÀN!${NC}"
    echo "Bạn cần bật lại nguồn thủ công để khởi động."
    echo -n "Gõ 'SHUTDOWN' (viết hoa) để xác nhận: "
    read c1
    [ "$c1" != "SHUTDOWN" ] && echo "Đã hủy." && sleep 1 && return
    echo -n "Xác nhận lần cuối (yes/no): "
    read c2
    [ "$c2" != "yes" ] && echo "Đã hủy." && sleep 1 && return

    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo "$entry" | cut -d: -f1)
        local name=$(echo "$entry" | cut -d: -f2)
        printf "%-6s:  " "$name"
        if timeout 5 ssh -o ConnectTimeout=3 "$pi" "exit" 2>/dev/null; then
            ssh "$pi" 'sudo shutdown -h now' &>/dev/null &
            echo -e "${RED}Shutting down...${NC}"
        else
            echo -e "${YELLOW}Already offline${NC}"
        fi
    done
    echo ""
    press_enter
}

update_wallpaper_all() {
    print_section "CẬP NHẬT WALLPAPER TẤT CẢ PI"
    echo "Đang cập nhật wallpaper..."
    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo "$entry" | cut -d: -f1)
        local name=$(echo "$entry" | cut -d: -f2)
        echo -ne "[$name] "
        if timeout 3 ssh -o ConnectTimeout=2 "$pi" "exit" 2>/dev/null; then
            ssh "$pi" '/opt/DOGMA/set_daily_wallpaper.sh' &>/dev/null &
            spinner $!; wait $!
            echo -e " ${GREEN}Done${NC}"
        else
            echo -e "${RED}Offline${NC}"
        fi
    done
    echo ""
    press_enter
}

restart_services() {
    print_section "RESTART SERVICE"
    echo "Chọn service:"
    echo "  1) dogma-wallpaper"
    echo "  2) dogma-dual"
    echo "  3) Tất cả"
    echo "  0) Quay lại"
    echo -n "➤ Chọn: "
    read sc
    local svcs=""
    case "$sc" in
        1) svcs="dogma-wallpaper";;
        2) svcs="dogma-dual";;
        3) svcs="dogma-wallpaper dogma-dual";;
        0) return;;
        *) echo "Lựa chọn không hợp lệ."; sleep 1; return;;
    esac
    echo ""
    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo "$entry" | cut -d: -f1)
        local name=$(echo "$entry" | cut -d: -f2)
        echo -ne "[$name] "
        if timeout 3 ssh -o ConnectTimeout=2 "$pi" "exit" 2>/dev/null; then
            for s in $svcs; do
                ssh "$pi" "sudo systemctl restart $s" &>/dev/null
                sleep 1
                local st=$(ssh "$pi" "systemctl is-active $s 2>/dev/null")
                echo -n "$s: "
                if [ "$st" = "active" ]; then echo -n "${GREEN}active${NC}  "; else echo -n "${RED}$st${NC}  "; fi
            done
            echo ""
        else
            echo -e "${RED}Offline${NC}"
        fi
    done
    press_enter
}

redeploy_scripts() {
    print_section "DEPLOY LẠI SCRIPTS"
    echo -e "${YELLOW}Chức năng này sẽ chạy ~/deploy_all_9pi.sh nếu tồn tại${NC}"
    echo -n "Tiếp tục? (yes/no): "
    read c
    [ "$c" != "yes" ] && return
    if [ -f ~/deploy_all_9pi.sh ]; then
        bash ~/deploy_all_9pi.sh
    else
        echo -e "${RED}Không tìm thấy ~/deploy_all_9pi.sh${NC}"
    fi
    press_enter
}

backup_config() {
    print_section "BACKUP CONFIG TẤT CẢ PI"
    local backup_dir=~/dogma_backup_$(date +%Y%m%d_%H%M%S)
    mkdir -p "$backup_dir"
    echo "Thư mục backup: $backup_dir"
    echo ""
    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo "$entry" | cut -d: -f1)
        local name=$(echo "$entry" | cut -d: -f2)
        echo -ne "[$name] "
        if timeout 3 ssh -o ConnectTimeout=2 "$pi" "exit" 2>/dev/null; then
            local pi_dir="$backup_dir/$name"
            mkdir -p "$pi_dir"
            # File quan trọng
            scp -q "$pi":/opt/DOGMA/*.sh "$pi_dir/" 2>/dev/null
            scp -q "$pi":/etc/systemd/system/dogma-*.service "$pi_dir/" 2>/dev/null
            scp -q "$pi":/opt/DOGMA/logs/*.log "$pi_dir/" 2>/dev/null
            scp -q "$pi":/boot/config.txt "$pi_dir/config.txt" 2>/dev/null
            # Thêm system info
            ssh "$pi" 'uname -a; uptime; df -h; free -h' > "$pi_dir/system_info.txt"
            echo -e "${GREEN}Done${NC}"
        else
            echo -e "${RED}Offline${NC}"
        fi
    done
    echo ""
    echo "Tạo README tổng hợp..."
    {
        echo "DOGMA Backup"
        echo "============"
        echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Location: $backup_dir"
        echo ""
        ls -lh "$backup_dir"
    } > "$backup_dir/README.txt"
    echo -e "${GREEN}Hoàn tất backup${NC}"
    press_enter
}

# ============================================
# 3. THAO TÁC LAPTOP/PC
# ============================================

ssh_to_laptop() {
    print_section "SSH VÀO LAPTOP"
    echo -e "${YELLOW}Bạn sẽ cần nhập mật khẩu thủ công.${NC}"
    echo ""
    ssh pc@100.89.227.12
}

ssh_to_pc() {
    print_section "SSH VÀO PC"
    echo -e "${YELLOW}Bạn sẽ cần nhập mật khẩu thủ công.${NC}"
    echo ""
    ssh admin@100.122.249.33
}

check_pc_status() {
    print_section "TRẠNG THÁI LAPTOP/PC"
    printf "%-10s %-25s %-10s %-12s\n" "Device" "IP" "Status" "Ping(ms)"
    echo "────────────────────────────────────────────────────────"
    for entry in "${PC_LIST[@]}"; do
        local user_host=$(echo "$entry" | cut -d: -f1)
        local name=$(echo "$entry" | cut -d: -f2)
        local host=$(echo "$user_host" | cut -d'@' -f2)
        printf "%-10s %-25s " "$name" "$host"
        if timeout 3 ping -c 1 -W 1 "$host" &>/dev/null; then
            local ms=$(ping -c 1 -W 1 "$host" 2>/dev/null | grep time= | cut -d= -f4 | cut -d' ' -f1)
            echo -e "${GREEN}Online${NC}    ${ms:-N/A}"
        else
            echo -e "${RED}Offline${NC}   N/A"
        fi
    done
    press_enter
}

run_command_pc() {
    print_section "CHẠY LỆNH TRÊN TẤT CẢ LAPTOP/PC"
    echo -e "${YELLOW}Bạn sẽ cần nhập mật khẩu cho từng thiết bị (nếu được hỏi).${NC}"
    echo -n "Nhập lệnh cần chạy (ví dụ: hostname, ipconfig, systeminfo): "
    read command
    [ -z "$command" ] && echo "Không có lệnh." && sleep 1 && return
    echo ""
    for entry in "${PC_LIST[@]}"; do
        local user_host=$(echo "$entry" | cut -d: -f1)
        local name=$(echo "$entry" | cut -d: -f2)
        echo "=== $name ==="
        ssh "$user_host" "$command"
        echo ""
    done
    read -p "Nhấn Enter để tiếp tục..."
}

# ============================================
# 4. CÔNG CỤ
# ============================================

ssh_to_pi() {
    print_section "SSH VÀO PI CỤ THỂ"
    echo "Chọn Pi:"
    local i=1
    for entry in "${PI_LIST[@]}"; do
        local name=$(echo "$entry" | cut -d: -f2)
        local host=$(echo "$entry" | cut -d: -f1 | cut -d'@' -f2)
        echo "  $i) $name ($host)"
        ((i++))
    done
    echo "  0) Quay lại"
    echo ""
    echo -n "➤ Chọn [0-9]: "
    read ch
    if [ "$ch" -ge 1 ] && [ "$ch" -le 9 ]; then
        local idx=$((ch-1))
        local pi=$(pi_userhost_by_index "$idx")
        local name=$(pi_name_by_index "$idx")
        echo ""
        echo -e "${CYAN}Đang SSH vào $name...${NC}"
        echo -e "${YELLOW}(Gõ 'exit' để quay lại menu)${NC}"
        echo ""
        sleep 1
        ssh "$pi"
    fi
}

view_realtime_log() {
    print_section "LOG REALTIME (dual_stream.log)"
    echo "Chọn Pi:"
    local i=1
    for entry in "${PI_LIST[@]}"; do
        echo "  $i) $(echo "$entry" | cut -d: -f2)"; ((i++))
    done
    echo "  0) Quay lại"
    echo ""
    echo -n "Chọn: "
    read ch
    if [ "$ch" -ge 1 ] && [ "$ch" -le 9 ]; then
        local idx=$((ch-1))
        local pi=$(pi_userhost_by_index "$idx")
        local name=$(pi_name_by_index "$idx")
        echo ""
        echo "Log realtime của $name (Ctrl+C để thoát)"
        echo ""
        ssh "$pi" 'tail -f /opt/DOGMA/logs/dual_stream.log 2>/dev/null'
    fi
}

# ============================================
# 5. XUẤT BÁO CÁO HTML CHI TIẾT (đã sửa quote)
# ============================================

export_report() {
    print_section "XUẤT BÁO CÁO HTML CHI TIẾT"

    local report_file=~/dogma_report_$(date +%Y%m%d_%H%M%S).html
    echo "Đang thu thập dữ liệu từ 9 Pi..."
    echo ""

    declare -A pi_data
    local idx=0
    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo "$entry" | cut -d: -f1)
        local name=$(echo "$entry" | cut -d: -f2)
        local host=$(echo "$pi" | cut -d'@' -f2)
        echo -ne "[$name] "
        if timeout 5 ssh -o ConnectTimeout=3 "$pi" "exit" 2>/dev/null; then
            echo -ne "Collecting..."
            # System
            local temp=$(ssh "$pi" 'vcgencmd measure_temp 2>/dev/null' | cut -d= -f2 | sed "s/'C//")
            local freq=$(ssh "$pi" 'vcgencmd measure_clock arm 2>/dev/null' | awk -F= '{printf "%.0f", $2/1000000}')
            local gpu=$(ssh "$pi" 'vcgencmd get_mem gpu 2>/dev/null' | cut -d= -f2)
            local uptime=$(ssh "$pi" 'uptime -p 2>/dev/null')
            # load avg (1min) bằng sed để tránh nested quote
            local load=$(ssh "$pi" 'uptime 2>/dev/null | sed -e "s/.*load average: *//" -e "s/,.*//"')
            # Stream
            local stream_status=$(ssh "$pi" 'systemctl is-active dogma-dual 2>/dev/null')
            local ffplay_count=$(ssh "$pi" 'pgrep ffplay 2>/dev/null | wc -l' 2>/dev/null || echo "0")
            local stream_errors=$(ssh "$pi" 'grep -icE "error|failed|timeout|refused" /opt/DOGMA/logs/dual_stream.log 2>/dev/null' || echo "0")
            # Wallpaper
            local wp_status=$(ssh "$pi" 'systemctl is-enabled dogma-wallpaper 2>/dev/null')
            local wp_last=$(ssh "$pi" 'grep "Hoàn tất" /opt/DOGMA/logs/wallpaper.log 2>/dev/null | tail -1 | grep -oE "\[[^]]+\]" | head -1 | sed "s/\[//;s/\]//"')
            # Screenshot
            local screenshot_latest=$(ssh "$pi" 'find ~/Pictures -maxdepth 1 -type f \( -name "*.png" -o -name "*.jpg" \) -printf "%T@ %f\n" 2>/dev/null | sort -rn | head -1')
            local screenshot_name=$(echo "$screenshot_latest" | awk '{print $2}')
            local screenshot_time=$(echo "$screenshot_latest" | awk '{print $1}')
            [ -n "$screenshot_time" ] && screenshot_time=$(date -d @${screenshot_time%.*} '+%Y-%m-%d %H:%M' 2>/dev/null)
            # rclone
            local rclone_installed="No"; ssh "$pi" 'command -v rclone' &>/dev/null && rclone_installed="Yes"
            # Network
            local interface=$(ssh "$pi" "ip route | grep default | awk '{print \$5}' | head -1")
            [ -z "$interface" ] && interface="eth0"
            local bandwidth_rx="N/A" bandwidth_tx="N/A"
            if ssh "$pi" 'command -v vnstat' &>/dev/null; then
                local bw=$(ssh "$pi" "vnstat -i $interface -tr 2 2>/dev/null")
                if echo "$bw" | grep -q "rx\|tx"; then
                    bandwidth_rx=$(echo "$bw" | grep 'rx' | awk '{print $2, $3}')
                    bandwidth_tx=$(echo "$bw" | grep 'tx' | awk '{print $2, $3}')
                fi
            fi
            # Disk & Mem (đơn giản, tránh nested quote)
            local disk_usage=$(ssh "$pi" 'df -h / 2>/dev/null | tail -1 | tr -s " " | cut -d" " -f5' 2>/dev/null)
            local mem_usage=$(ssh "$pi" 'free | awk "/Mem:/ {printf \"%.1f\", ($3/$2)*100}"' 2>/dev/null)

            pi_data[$name]="online|$host|$temp|$freq|$gpu|$uptime|$load|$stream_status|$ffplay_count|$stream_errors|$wp_status|$wp_last|$screenshot_name|$screenshot_time|$rclone_installed|$interface|$bandwidth_rx|$bandwidth_tx|$disk_usage|$mem_usage"
            echo " OK"
        else
            pi_data[$name]="offline|$host||||||||||||||||"
            echo " Offline"
        fi
        ((idx++))
    done

    echo ""
    echo "Đang tạo báo cáo HTML..."

    # HTML HEADER
    cat > "$report_file" << 'HTMLHEAD'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DOGMA System Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px; color: #333;
        }
        .container { max-width: 1600px; margin: 0 auto; background: white; border-radius: 15px; box-shadow: 0 20px 60px rgba(0,0,0,0.3); overflow: hidden; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px; text-align: center; }
        .header h1 { font-size: 2.8em; margin-bottom: 10px; text-shadow: 2px 2px 4px rgba(0,0,0,0.3); }
        .timestamp { opacity: 0.9; font-size: 1em; margin-top: 10px; }
        .content { padding: 40px; }
        h2 { color: #667eea; margin: 40px 0 20px 0; padding-bottom: 10px; border-bottom: 3px solid #667eea; font-size: 2em; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 25px; margin: 30px 0; }
        .summary-card { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 15px; text-align: center; box-shadow: 0 8px 20px rgba(102, 126, 234, 0.4); transition: transform 0.3s; }
        .summary-card h3 { font-size: 3em; margin-bottom: 10px; font-weight: bold; }
        .summary-card p { opacity: 0.95; font-size: 1.1em; text-transform: uppercase; letter-spacing: 1px; }
        table { width: 100%; border-collapse: collapse; margin: 25px 0; background: white; box-shadow: 0 4px 15px rgba(0,0,0,0.1); border-radius: 10px; overflow: hidden; }
        th { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 18px 15px; text-align: left; font-weight: 600; font-size: 0.95em; }
        td { padding: 15px; border-bottom: 1px solid #e0e0e0; font-size: 0.95em; }
        tr:last-child td { border-bottom: none; }
        tr:hover { background: #f8f9ff; }
        .status-online { color: #10b981; font-weight: bold; }
        .status-offline { color: #ef4444; font-weight: bold; }
        .status-warning { color: #f59e0b; font-weight: bold; }
        .badge { display: inline-block; padding: 6px 14px; border-radius: 20px; font-size: 0.85em; font-weight: 600; }
        .badge-success { background: #d1fae5; color: #065f46; }
        .badge-danger { background: #fee2e2; color: #991b1b; }
        .badge-warning { background: #fef3c7; color: #92400e; }
        .footer { text-align: center; padding: 30px; color: #666; font-size: 0.9em; border-top: 1px solid #e0e0e0; background: #f9fafb; }
        .pi-name { font-weight: bold; color: #667eea; font-size: 1.1em; }
        .temp-normal { color: #10b981; font-weight: bold; }
        .temp-warm { color: #f59e0b; font-weight: bold; }
        .temp-hot { color: #ef4444; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>DOGMA System Report</h1>
HTMLHEAD
    echo "            <p class=\"timestamp\">Generated: $(date '+%Y-%m-%d %H:%M:%S')</p>" >> "$report_file"
    echo "            <p class=\"timestamp\">Generated by: $(whoami)@$(hostname)</p>" >> "$report_file"
    cat >> "$report_file" << 'HTMLBODY'
        </div>
        <div class="content">
HTMLBODY

    # SUMMARY CARDS
    local total_pi=9 online_count=0 offline_count=0 total_temp=0 temp_count=0 stream_active=0 total_errors=0
    PI_NAMES=(ltr01 ltr02 ltr03 ltr04 ltr05 ltr06 ltr07 ltr08 ltr09)
    for name in "${PI_NAMES[@]}"; do
        local data="${pi_data[$name]}"
        if [[ "$data" =~ ^online ]]; then
            ((online_count++))
            local temp=$(echo "$data" | cut -d'|' -f3)
            [ -n "$temp" ] && total_temp=$(echo "$total_temp + $temp" | bc 2>/dev/null || echo "$total_temp") && ((temp_count++))
            local stream=$(echo "$data" | cut -d'|' -f8)
            [ "$stream" = "active" ] && ((stream_active++))
            local errs=$(echo "$data" | cut -d'|' -f10); errs=${errs:-0}; total_errors=$((total_errors + errs))
        else
            ((offline_count++))
        fi
    done
    local avg_temp="N/A"
    [ $temp_count -gt 0 ] && avg_temp="$(echo "scale=1; $total_temp / $temp_count" | bc 2>/dev/null)°C"

    cat >> "$report_file" << SUMMARY
            <div class="summary">
                <div class="summary-card">
                    <h3>$online_count/$total_pi</h3>
                    <p>Pi Online</p>
                </div>
                <div class="summary-card">
                    <h3>$stream_active</h3>
                    <p>Streams Active</p>
                </div>
                <div class="summary-card">
                    <h3>$avg_temp</h3>
                    <p>Avg Temperature</p>
                </div>
                <div class="summary-card">
                    <h3>$total_errors</h3>
                    <p>Total Errors</p>
                </div>
                <div class="summary-card">
                    <h3>$offline_count</h3>
                    <p>Pi Offline</p>
                </div>
            </div>
SUMMARY

    # TABLE 1: SYSTEM OVERVIEW
    cat >> "$report_file" << 'TABLE1'
            <h2>📊 System Overview</h2>
            <table>
                <thead>
                    <tr>
                        <th>Pi</th><th>IP Address</th><th>Status</th><th>Temperature</th><th>CPU Freq</th><th>GPU Memory</th><th>Load Avg</th><th>Uptime</th>
                    </tr>
                </thead>
                <tbody>
TABLE1
    for name in "${PI_NAMES[@]}"; do
        local data="${pi_data[$name]}"
        if [[ "$data" =~ ^online ]]; then
            IFS='|' read -r status host temp freq gpu uptime load stream_status ffplay_count stream_errors wp_status wp_last screenshot_name screenshot_time rclone_installed interface bandwidth_rx bandwidth_tx disk_usage mem_usage <<< "$data"
            local temp_class="temp-normal"
            if [ -n "$temp" ]; then
                if (( $(echo "$temp > 70" | bc -l 2>/dev/null || echo 0) )); then temp_class="temp-hot";
                elif (( $(echo "$temp > 60" | bc -l 2>/dev/null || echo 0) )); then temp_class="temp-warm"; fi
            fi
            cat >> "$report_file" << TR1
                    <tr>
                        <td class="pi-name">$name</td><td>$host</td><td><span class="status-online">● Online</span></td>
                        <td class="$temp_class">${temp}°C</td><td>${freq} MHz</td><td>$gpu</td><td>$load</td><td>$uptime</td>
                    </tr>
TR1
        else
            local host=$(echo "$data" | cut -d'|' -f2)
            cat >> "$report_file" << TR2
                    <tr>
                        <td class="pi-name">$name</td><td>$host</td><td><span class="status-offline">● Offline</span></td>
                        <td>-</td><td>-</td><td>-</td><td>-</td><td>-</td>
                    </tr>
TR2
        fi
    done
    echo "                </tbody></table>" >> "$report_file"

    # TABLE 2: STREAM STATUS
    cat >> "$report_file" << 'TABLE2'
            <h2>📺 Stream Status</h2>
            <table>
                <thead>
                    <tr><th>Pi</th><th>Service Status</th><th>Active Streams</th><th>Log Errors</th><th>Overall Status</th></tr>
                </thead><tbody>
TABLE2
    for name in "${PI_NAMES[@]}"; do
        local data="${pi_data[$name]}"
        if [[ "$data" =~ ^online ]]; then
            IFS='|' read -r _ host _ _ _ _ _ stream_status ffplay_count stream_errors _ _ _ _ _ _ _ _ _ _ <<< "$data"
            local service_badge="badge-danger"; local service_text="Inactive"
            [ "$stream_status" = "active" ] && service_badge="badge-success" && service_text="Active"
            local stream_badge="badge-success"; [ "$ffplay_count" != "2" ] && stream_badge="badge-warning"
            local error_badge="badge-success"; local error_text="${stream_errors} errors"
            [ "$stream_errors" -gt 10 ] && error_badge="badge-danger" || { [ "$stream_errors" -gt 0 ] && error_badge="badge-warning"; }
            local overall="✅ OK"; { [ "$ffplay_count" != "2" ] || [ "$stream_status" != "active" ]; } && overall="⚠️ Check Required"
            cat >> "$report_file" << TR3
                    <tr>
                        <td class="pi-name">$name</td>
                        <td><span class="badge $service_badge">$service_text</span></td>
                        <td><span class="badge $stream_badge">$ffplay_count/2</span></td>
                        <td><span class="badge $error_badge">$error_text</span></td>
                        <td>$overall</td>
                    </tr>
TR3
        else
            cat >> "$report_file" << TR4
                    <tr><td class="pi-name">$name</td><td><span class="badge badge-danger">Offline</span></td><td>-</td><td>-</td><td>❌ Pi Offline</td></tr>
TR4
        fi
    done
    echo "                </tbody></table>" >> "$report_file"

    # TABLE 3: WALLPAPER STATUS
    cat >> "$report_file" << 'TABLE3'
            <h2>🖼️ Wallpaper Status</h2>
            <table>
                <thead>
                    <tr><th>Pi</th><th>Service</th><th>Last Run</th><th>Status</th></tr>
                </thead><tbody>
TABLE3
    for name in "${PI_NAMES[@]}"; do
        local data="${pi_data[$name]}"
        if [[ "$data" =~ ^online ]]; then
            IFS='|' read -r _ _ _ _ _ _ _ _ _ _ wp_status wp_last _ _ _ _ _ _ _ _ <<< "$data"
            local wp_badge="badge-danger"; local wp_text="Disabled"
            [ "$wp_status" = "enabled" ] && wp_badge="badge-success" && wp_text="Enabled"
            local last_run="${wp_last:-Never run}"
            local status_icon="⚠️ No log"; [ -n "$wp_last" ] && status_icon="✅ OK"
            cat >> "$report_file" << TR5
                    <tr><td class="pi-name">$name</td><td><span class="badge $wp_badge">$wp_text</span></td><td>$last_run</td><td>$status_icon</td></tr>
TR5
        else
            cat >> "$report_file" << TR6
                    <tr><td class="pi-name">$name</td><td><span class="badge badge-danger">Offline</span></td><td>-</td><td>❌ Pi Offline</td></tr>
TR6
        fi
    done
    echo "                </tbody></table>" >> "$report_file"

    # TABLE 4: SCREENSHOT STATUS
    cat >> "$report_file" << 'TABLE4'
            <h2>📸 Screenshot Status</h2>
            <table>
                <thead>
                    <tr><th>Pi</th><th>Latest Screenshot</th><th>Captured Time</th><th>Status</th></tr>
                </thead><tbody>
TABLE4
    for name in "${PI_NAMES[@]}"; do
        local data="${pi_data[$name]}"
        if [[ "$data" =~ ^online ]]; then
            IFS='|' read -r _ _ _ _ _ _ _ _ _ _ _ _ screenshot_name screenshot_time _ _ _ _ _ _ <<< "$data"
            local disp="${screenshot_name:-No screenshot}"
            local stime="${screenshot_time:-N/A}"
            local st="⚠️ No file"; [ -n "$screenshot_name" ] && st="✅ OK"
            cat >> "$report_file" << TR7
                    <tr><td class="pi-name">$name</td><td>$disp</td><td>$stime</td><td>$st</td></tr>
TR7
        else
            cat >> "$report_file" << TR8
                    <tr><td class="pi-name">$name</td><td>-</td><td>-</td><td>❌ Pi Offline</td></tr>
TR8
        fi
    done
    echo "                </tbody></table>" >> "$report_file"

    # TABLE 5: NETWORK & RESOURCES
    cat >> "$report_file" << 'TABLE5'
            <h2>🌐 Network & Resources</h2>
            <table>
                <thead>
                    <tr><th>Pi</th><th>Interface</th><th>Bandwidth RX</th><th>Bandwidth TX</th><th>Disk Usage</th><th>Memory Usage</th></tr>
                </thead><tbody>
TABLE5
    for name in "${PI_NAMES[@]}"; do
        local data="${pi_data[$name]}"
        if [[ "$data" =~ ^online ]]; then
            IFS='|' read -r _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ interface bandwidth_rx bandwidth_tx disk_usage mem_usage <<< "$data"
            local disk_class=""; if [ -n "$disk_usage" ]; then dnum=$(echo "$disk_usage" | sed 's/%//'); [ "$dnum" -gt 80 ] && disk_class='class="status-offline"' || { [ "$dnum" -gt 60 ] && disk_class='class="status-warning"'; }; fi
            local mem_class=""; if [ -n "$mem_usage" ]; then if (( $(echo "$mem_usage > 80" | bc -l 2>/dev/null || echo 0) )); then mem_class='class="status-offline"'; elif (( $(echo "$mem_usage > 60" | bc -l 2>/dev/null || echo 0) )); then mem_class='class="status-warning"'; fi; fi
            cat >> "$report_file" << TR9
                    <tr>
                        <td class="pi-name">$name</td><td>$interface</td><td>$bandwidth_rx</td><td>$bandwidth_tx</td>
                        <td $disk_class>$disk_usage</td><td $mem_class>${mem_usage}%</td>
                    </tr>
TR9
        else
            cat >> "$report_file" << TR10
                    <tr><td class="pi-name">$name</td><td>-</td><td>-</td><td>-</td><td>-</td><td>-</td></tr>
TR10
        fi
    done
    echo "                </tbody></table>" >> "$report_file"

    # TABLE 6: RCLONE & MISC
    cat >> "$report_file" << 'TABLE6'
            <h2>☁️ Rclone & Miscellaneous</h2>
            <table>
                <thead>
                    <tr><th>Pi</th><th>Rclone Installed</th><th>Status</th></tr>
                </thead><tbody>
TABLE6
    for name in "${PI_NAMES[@]}"; do
        local data="${pi_data[$name]}"
        if [[ "$data" =~ ^online ]]; then
            IFS='|' read -r _ _ _ _ _ _ _ _ _ _ _ _ _ _ rclone_installed _ _ _ _ _ <<< "$data"
            local badge="badge-danger"; local text="❌ Not installed"
            [ "$rclone_installed" = "Yes" ] && badge="badge-success" && text="✅ Installed"
            cat >> "$report_file" << TR11
                    <tr><td class="pi-name">$name</td><td><span class="badge $badge">$rclone_installed</span></td><td>$text</td></tr>
TR11
        else
            cat >> "$report_file" << TR12
                    <tr><td class="pi-name">$name</td><td><span class="badge badge-danger">Offline</span></td><td>❌ Pi Offline</td></tr>
TR12
        fi
    done
    echo "                </tbody></table>" >> "$report_file"

    # FOOTER
    cat >> "$report_file" << FOOTER
        </div>
        <div class="footer">
            <p><strong>DOGMA Control Center</strong> | © $(date +%Y)</p>
            <p>Generated by: $(whoami)@$(hostname)</p>
            <p>Report file: $(basename $report_file)</p>
        </div>
    </div>
</body>
</html>
FOOTER

    echo ""
    echo -e "${GREEN}✅ Báo cáo đã được tạo: $report_file${NC}"
    echo -n "Mở báo cáo ngay? (y/n): "
    read open_now
    if [ "$open_now" = "y" ]; then
        xdg-open "$report_file" 2>/dev/null || open "$report_file" 2>/dev/null || firefox "$report_file" 2>/dev/null || echo "Vui lòng mở file thủ công: $report_file"
    fi
    press_enter
}

# ============================================
# OBS CONTROL – FUNCTIONS
# ============================================

# Utils cho OBS hosts
_obs_get_host_line_by_alias() {
    local alias="$1"
    for line in "${OBS_HOSTS[@]}"; do
        IFS='|' read -r a _ _ _ _ _ _ <<<"$line"
        [[ "$a" == "$alias" ]] && echo "$line" && return 0
    done
    return 1
}

_obs_for_each_host() {
    local target="${1:-all}"; shift || true
    local cb="$1"; shift || true
    if [[ "$target" == "all" ]]; then
        for line in "${OBS_HOSTS[@]}"; do "$cb" "$line" "$@"; done
    else
        local line; line=$(_obs_get_host_line_by_alias "$target") || { echo "Không tìm thấy target: $target"; return 1; }
        "$cb" "$line" "$@"
    fi
}

_obs_require_sshpass() {
    if ! command -v sshpass >/dev/null 2>&1; then
        echo -e "${RED}Thiếu sshpass. Cài: sudo apt install -y sshpass${NC}"
        return 1
    fi
}

# SSH Windows với password
_obs_ssh_win() {
    local user="$1" ip="$2" pass="$3" cmd="$4"
    local base=(-o StrictHostKeyChecking=no -o ConnectTimeout=8 -o BatchMode=no)
    sshpass -p "$pass" ssh "${base[@]}" "$user@$ip" "$cmd"
}

# Kiểm tra OBS process có chạy không (Windows)
_win_obs_running() {
    local user="$1" ip="$2" pass="$3"
    _obs_ssh_win "$user" "$ip" "$pass" "powershell -NoProfile -Command \"(Get-Process obs64 -ErrorAction SilentlyContinue) -ne \$null\"" \
        | grep -qi "True"
}

# Kill OBS (force)
_win_kill_obs() {
    local user="$1" ip="$2" pass="$3"
    _obs_ssh_win "$user" "$ip" "$pass" "powershell -NoProfile -Command \"Get-Process obs64 -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep -Seconds 1; taskkill /IM obs64.exe /F >NUL 2>&1\"" || true
}

# Start OBS "Run in normal mode"
_win_start_obs_normal() {
    local user="$1" ip="$2" pass="$3" obs_path="$4"
    local ps="Start-Process -FilePath '$obs_path' -WindowStyle Normal"
    # Tuỳ chọn load profile/scene
    local arglist=()
    [[ -n "$OBS_COLLECTION" ]] && arglist+=( "--collection" "$OBS_COLLECTION" )
    [[ -n "$OBS_PROFILE"    ]] && arglist+=( "--profile"    "$OBS_PROFILE" )
    [[ -n "$OBS_SCENE"      ]] && arglist+=( "--scene"      "$OBS_SCENE" )
    if ((${#arglist[@]})); then
        local quoted
        quoted=$(printf "'%s'," "${arglist[@]}"; printf "\n" | sed 's/,$//')
        ps="Start-Process -FilePath '$obs_path' -ArgumentList $quoted -WindowStyle Normal"
    fi
    _obs_ssh_win "$user" "$ip" "$pass" "powershell -NoProfile -Command \"$ps\"" || return 1
}

# Start OBS + streaming (fallback khi không có WebSocket và OBS chưa chạy)
_win_start_obs_with_stream() {
    local user="$1" ip="$2" pass="$3" obs_path="$4"
    local arglist=( "--startstreaming" )
    [[ -n "$OBS_COLLECTION" ]] && arglist+=( "--collection" "$OBS_COLLECTION" )
    [[ -n "$OBS_PROFILE"    ]] && arglist+=( "--profile"    "$OBS_PROFILE" )
    [[ -n "$OBS_SCENE"      ]] && arglist+=( "--scene"      "$OBS_SCENE" )
    local quoted
    quoted=$(printf "'%s'," "${arglist[@]}"; printf "\n" | sed 's/,$//')
    local ps="Start-Process -FilePath '$obs_path' -ArgumentList $quoted -WindowStyle Normal"
    _obs_ssh_win "$user" "$ip" "$pass" "powershell -NoProfile -Command \"$ps\"" || return 1
}

# WebSocket wrappers (obs-cli)
_ws_ok() { command -v obs-cli >/dev/null 2>&1; }

_ws_exec() { # host:port pass method
    local hostport="$1" pass="$2" method="$3"
    OBS_WS_HOST="$hostport" OBS_WS_PASSWORD="$pass" obs-cli "$method"
}

_ws_stream_status() { # return text status
    local hostport="$1" pass="$2"
    if ! _ws_ok || [[ -z "$pass" ]]; then
        echo "WS: (unavailable)"
        return 1
    fi
    local out
    if out=$(_ws_exec "$hostport" "$pass" GetStreamStatus 2>/dev/null); then
        echo "$out"
        return 0
    elif out=$(_ws_exec "$hostport" "$pass" GetStreamingStatus 2>/dev/null); then
        echo "$out"
        return 0
    else
        echo "WS: error"
        return 1
    fi
}

_ws_start_stream() {
    local hostport="$1" pass="$2"
    _ws_ok && [[ -n "$pass" ]] && _ws_exec "$hostport" "$pass" StartStream
}
_ws_stop_stream() {
    local hostport="$1" pass="$2"
    _ws_ok && [[ -n "$pass" ]] && _ws_exec "$hostport" "$pass" StopStream
}

# 41) Thông tin các luồng & trạng thái
obs_info_streams() {
    print_section "OBS: THÔNG TIN CÁC LUỒNG & TRẠNG THÁI"
    _obs_require_sshpass || { press_enter; return; }

    printf "%-10s %-18s %-10s %-12s %-s\n" "Alias" "IP" "OBS Proc" "WS" "Stream status/raw"
    echo "────────────────────────────────────────────────────────────────────────────"
    for line in "${OBS_HOSTS[@]}"; do
        IFS='|' read -r alias user ip pass obs_path ws_port ws_pass <<<"$line"
        # OBS process
        local proc="No"
        if _win_obs_running "$user" "$ip" "$pass"; then proc="Yes"; fi
        # WS check
        local ws="No"
        if _ws_ok && [[ -n "$ws_pass" ]]; then
            if _ws_exec "$ip:$ws_port" "$ws_pass" GetVersion >/dev/null 2>&1; then ws="Yes"; fi
        fi
        # Stream status (in ra raw – để bạn nhìn chi tiết)
        local status="(unknown)"
        if [[ "$ws" == "Yes" ]]; then
            status=$(_ws_stream_status "$ip:$ws_port" "$ws_pass")
        fi
        printf "%-10s %-18s %-10s %-12s %s\n" "$alias" "$ip" "$proc" "$ws" "$status"
    done
    press_enter
}

# 42) Restart OBS (Run in normal mode)
obs_restart_normal() {
    print_section "OBS: RESTART (RUN IN NORMAL MODE)"
    _obs_require_sshpass || { press_enter; return; }

    for line in "${OBS_HOSTS[@]}"; do
        IFS='|' read -r alias user ip pass obs_path ws_port ws_pass <<<"$line"
        echo -ne "[$alias] Killing OBS... "
        _win_kill_obs "$user" "$ip" "$pass"
        echo -e "${GREEN}OK${NC}"
        echo -ne "[$alias] Starting OBS (normal mode)... "
        if _win_start_obs_normal "$user" "$ip" "$pass" "$obs_path"; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}Failed${NC}"
        fi
    done
    press_enter
}

# 43) Start streaming tất cả
obs_start_all_streams() {
    print_section "OBS: START STREAMING TẤT CẢ"
    _obs_require_sshpass || { press_enter; return; }

    for line in "${OBS_HOSTS[@]}"; do
        IFS='|' read -r alias user ip pass obs_path ws_port ws_pass <<<"$line"
        echo "[$alias] Start streaming..."
        local ws_used=0
        if _ws_ok && [[ -n "$ws_pass" ]]; then
            if _ws_start_stream "$ip:$ws_port" "$ws_pass" >/dev/null 2>&1; then
                echo -e "  ${GREEN}WS: StartStream OK${NC}"
                ws_used=1
            else
                echo -e "  ${YELLOW}WS: StartStream failed, fallback${NC}"
            fi
        else
            echo "  WS unavailable (no obs-cli or password). Fallback."
        fi

        if [[ $ws_used -eq 0 ]]; then
            # Fallback: chỉ hoạt động nếu OBS chưa chạy
            if _win_obs_running "$user" "$ip" "$pass"; then
                echo -e "  ${YELLOW}OBS đang chạy → CLI fallback không thể start stream. Bật WebSocket để điều khiển instance đang chạy.${NC}"
            else
                if _win_start_obs_with_stream "$user" "$ip" "$pass" "$obs_path"; then
                    echo -e "  ${GREEN}Start OBS + --startstreaming OK${NC}"
                else
                    echo -e "  ${RED}Fallback failed${NC}"
                fi
            fi
        fi
    done
    press_enter
}

# 44) Stop streaming tất cả (safe + auto-recover theo lưu ý của bạn)
obs_stop_all_streams() {
    print_section "OBS: STOP STREAMING TẤT CẢ (SAFE)"
    _obs_require_sshpass || { press_enter; return; }

    for line in "${OBS_HOSTS[@]}"; do
        IFS='|' read -r alias user ip pass obs_path ws_port ws_pass <<<"$line"
        echo "[$alias] Stop streaming..."
        local ok=0
        if _ws_ok && [[ -n "$ws_pass" ]]; then
            if _ws_stop_stream "$ip:$ws_port" "$ws_pass" >/dev/null 2>&1; then
                # Poll trạng thái tắt hẳn (tối đa 10s)
                for i in {1..10}; do
                    sleep 1
                    local st=$(_ws_stream_status "$ip:$ws_port" "$ws_pass")
                    if echo "$st" | grep -qi '"outputActive": *false\|streaming.*false'; then
                        echo -e "  ${GREEN}WS: StopStream OK${NC}"
                        ok=1
                        break
                    fi
                done
            fi
        fi

        if [[ $ok -eq 0 ]]; then
            # Theo lưu ý: "Stop All" khiến OBS treo → xử lý cứng: kill + mở lại normal mode
            echo -e "  ${YELLOW}WS không khả dụng/không phản hồi. Áp dụng auto-recover (kill + start normal).${NC}"
            _win_kill_obs "$user" "$ip" "$pass"
            sleep 2
            if _win_start_obs_normal "$user" "$ip" "$pass" "$obs_path"; then
                echo -e "  ${GREEN}Auto-recover: Restart normal OK${NC}"
            else
                echo -e "  ${RED}Auto-recover failed${NC}"
            fi
        fi
    done
    press_enter
}

# ============================================
# MAIN LOOP
# ============================================

main() {
    check_prereqs
    while true; do
        show_menu
        read choice
        case "$choice" in
            # Nhóm 1
            1) check_overview ;;
            2) check_stream ;;
            3) check_screenshot ;;
            4) check_wallpaper ;;
            5) check_connection ;;
            6) check_rclone ;;
            7) check_hardware ;;
            8) check_detailed_log ;;
            # Nhóm 2
            11) update_upgrade_all ;;
            12) reboot_all ;;
            12s) [ "$SHOW_SHUTDOWN_ALL" -eq 1 ] && shutdown_all || echo -e "${YELLOW}Chức năng tắt (SHOW_SHUTDOWN_ALL=0).${NC}" ;;
            13) update_wallpaper_all ;;
            14) restart_services ;;
            15) redeploy_scripts ;;
            16) backup_config ;;
            # Nhóm 3
            21) ssh_to_laptop ;;
            22) ssh_to_pc ;;
            23) check_pc_status ;;
            24) run_command_pc ;;
            # Nhóm 4
            31) ssh_to_pi ;;
            32) export_report ;;
            33) view_realtime_log ;;
            # OBS CONTROL
            41) obs_info_streams ;;
            42) obs_restart_normal ;;
            43) obs_start_all_streams ;;
            44) obs_stop_all_streams ;;
            # Khác
            0)
                clear
                echo -e "${CYAN}Cảm ơn đã sử dụng DOGMA Control Center!${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}Lựa chọn không hợp lệ!${NC}"
                sleep 1
                ;;
        esac
    done
}

# ============================================
# RUN
# ============================================

main
