#!/bin/bash
# =========================================================
# 🎯 DOGMA Control Center
# Quản lý tập trung 9 Raspberry Pi + 2 Windows PC
# =========================================================

# ============================================
# CẤU HÌNH
# ============================================

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

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================
# HÀM TIỆN ÍCH
# ============================================

print_header() {
    clear
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}       🎯 DOGMA Control Center${NC}"
    echo -e "${CYAN}       Quản lý 9 Raspberry Pi${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo ""
}

print_section() {
    echo -e "\n${BLUE}━━━ $1 ━━━${NC}\n"
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# ============================================
# MENU CHÍNH
# ============================================

show_menu() {
    print_header
    echo -e "${GREEN}📊 GIÁM SÁT HỆ THỐNG: ${NC}"
    echo "  1) 🔍 Kiểm tra trạng thái tổng quan"
    echo "  2) 📺 Kiểm tra luồng stream SRT"
    echo "  3) 📸 Kiểm tra screenshot"
    echo "  4) 🖼️  Kiểm tra wallpaper"
    echo "  5) 🌐 Kiểm tra kết nối SSH"
    echo "  6) ☁️  Kiểm tra đồng bộ rclone"
    echo "  7) 🌡️  Thống kê nhiệt độ & phần cứng"
    echo "  8) 📋 Log chi tiết từng Pi"
    echo ""
    echo -e "${YELLOW}⚙️  THAO TÁC HỆ THỐNG:${NC}"
    echo "  11) 📦 Update & Upgrade tất cả Pi"
    echo "  12) 🔄 Reboot tất cả Pi"
    echo "  12s) 🔴 Shutdown tất cả Pi"
    echo "  13) 🖼️  Cập nhật wallpaper tất cả Pi"
    echo "  14) 🔧 Restart service systemd"
    echo "  15) 🚀 Deploy lại scripts"
    echo "  16) 💾 Backup config tất cả Pi"
    echo ""
    echo -e "${RED}🛠️  CÔNG CỤ: ${NC}"
    echo "  21) 🖥️  SSH vào Pi cụ thể"
    echo "  22) 📊 Xuất báo cáo HTML"
    echo "  23) ⚙️  Cấu hình script"
    echo ""
    echo "  0) ❌ Thoát"
    echo ""
    echo -n "➤ Chọn chức năng [0-23, 12s]:  "
}

# ============================================
# 1. KIỂM TRA TRẠNG THÁI TỔNG QUAN
# ============================================

check_overview() {
    print_section "🔍 TRẠNG THÁI TỔNG QUAN 9 PI"
    
    local online=0
    local offline=0
    
    printf "%-8s %-18s %-10s %-12s %-10s %-12s %-10s\n" \
        "Pi" "IP" "Status" "Wallpaper" "Stream" "GPU" "Temp"
    echo "─────────────────────────────────────────────────────────────────────────────"
    
    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo $entry | cut -d: -f1)
        local name=$(echo $entry | cut -d: -f2)
        local host=$(echo $pi | cut -d'@' -f2)
        
        printf "%-8s %-18s " "$name" "$host"
        
        if timeout 3 ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no $pi "exit" 2>/dev/null; then
            echo -ne "${GREEN}Online${NC}    "
            ((online++))
            
            # Wallpaper service
            local wp=$(timeout 2 ssh $pi 'systemctl is-active dogma-wallpaper 2>/dev/null')
            if [[ "$wp" == "active" ]] || [[ "$wp" == "inactive" ]]; then
                echo -ne "${GREEN}✓${NC}           "
            else
                echo -ne "${RED}✗${NC}           "
            fi
            
            # Stream service
            local stream=$(timeout 2 ssh $pi 'systemctl is-active dogma-dual 2>/dev/null')
            if [[ "$stream" == "active" ]]; then
                echo -ne "${GREEN}✓${NC}        "
            else
                echo -ne "${RED}✗${NC}        "
            fi
            
            # GPU
            local gpu=$(timeout 2 ssh $pi 'vcgencmd get_mem gpu 2>/dev/null' | cut -d= -f2)
            printf "%-12s " "$gpu"
            
            # Temp
            local temp=$(timeout 2 ssh $pi 'vcgencmd measure_temp 2>/dev/null' | cut -d= -f2)
            echo "$temp"
            
        else
            echo -e "${RED}Offline${NC}   ${RED}✗${NC}           ${RED}✗${NC}        ${RED}N/A${NC}          ${RED}N/A${NC}"
            ((offline++))
        fi
    done
    
    echo ""
    echo -e "📊 Tổng kết: ${GREEN}${online} Online${NC} | ${RED}${offline} Offline${NC}"
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
}

# ============================================
# 2. KIỂM TRA LUỒNG STREAM SRT - CHI TIẾT ĐẦY ĐỦ
# ============================================

check_stream() {
    print_section "📺 KIỂM TRA LUỒNG STREAM SRT CHI TIẾT"
    
    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo $entry | cut -d: -f1)
        local name=$(echo $entry | cut -d:  -f2)
        
        echo -e "\n${CYAN}━━━ $name ━━━${NC}"
        
        if timeout 5 ssh -o ConnectTimeout=3 $pi "exit" 2>/dev/null; then
            # Service status
            local service_status=$(ssh $pi 'systemctl is-active dogma-dual 2>/dev/null')
            
            echo -ne "Service Status:         "
            if [ "$service_status" = "active" ]; then
                echo -e "${GREEN}Active${NC}"
            else
                echo -e "${RED}Inactive${NC}"
                
                # Hiển thị lý do service không chạy
                local service_failed=$(ssh $pi 'systemctl status dogma-dual 2>/dev/null | grep -i "failed\|error" | head -3' 2>/dev/null)
                if [ -n "$service_failed" ]; then
                    echo -e "${RED}Service Error: ${NC}"
                    echo "$service_failed" | sed 's/^/  /'
                fi
                continue
            fi
            
            # Đếm số ffplay processes
            local ffplay_pids=$(ssh $pi 'pgrep ffplay' 2>/dev/null)
            local ffplay_count=$(echo "$ffplay_pids" | grep -c .  2>/dev/null || echo 0)
            
            echo -ne "Active Streams:      "
            if [ $ffplay_count -eq 2 ]; then
                echo -e "${GREEN}$ffplay_count/2${NC}"
            elif [ $ffplay_count -eq 1 ]; then
                echo -e "${YELLOW}$ffplay_count/2${NC} ${RED}⚠️ Missing 1 stream! ${NC}"
            else
                echo -e "${RED}$ffplay_count/2${NC} ${RED}⚠️ No streams running!${NC}"
            fi
            
            if [ $ffplay_count -eq 0 ]; then
                echo -e "${RED}⚠️ No ffplay process running! ${NC}"
                
                # Kiểm tra lý do
                echo ""
                echo "Checking why streams not running..."
                
                # Check X display
                if !  ssh $pi 'DISPLAY=:0 xset q' &>/dev/null; then
                    echo -e "  ${RED}✗ X server not available${NC}"
                fi
                
                # Check recent service logs
                local recent_errors=$(ssh $pi 'journalctl -u dogma-dual -n 5 --no-pager 2>/dev/null' 2>/dev/null)
                if [ -n "$recent_errors" ]; then
                    echo -e "\n  Recent service logs:"
                    echo "$recent_errors" | sed 's/^/    /'
                fi
                
                continue
            fi
            
            echo ""
            
            # Chi tiết từng stream
            local stream_num=0
            local log_file="/opt/DOGMA/logs/dual_stream. log"
            local cmdline=""
            
            for pid in $ffplay_pids; do
                stream_num=$((stream_num + 1))
                echo -e "${YELLOW}  [Stream $stream_num - PID:  $pid]${NC}"
                
                # Lấy command line để biết URL
                cmdline=$(ssh $pi "ps -p $pid -o args --no-headers 2>/dev/null" | grep -oE 'srt://[^ ]+')
                
                if [ -n "$cmdline" ]; then
                    echo "  URL:                $cmdline"
                    
                    # Lấy port từ URL
                    local port=$(echo "$cmdline" | grep -oE ':[0-9]+' | head -1 | sed 's/://')
                    if [ -n "$port" ]; then
                        echo "  Port:            $port"
                    fi
                else
                    echo "  URL:              (Unable to parse)"
                fi
                
                # CPU usage
                local cpu=$(ssh $pi "ps -p $pid -o %cpu --no-headers 2>/dev/null" | xargs)
                if [ -n "$cpu" ]; then
                    # Colorize CPU usage
                    if (( $(echo "$cpu > 80" | bc -l 2>/dev/null || echo 0) )); then
                        echo -e "  CPU Usage:       ${RED}${cpu}%${NC} (High! )"
                    elif (( $(echo "$cpu > 50" | bc -l 2>/dev/null || echo 0) )); then
                        echo -e "  CPU Usage:       ${YELLOW}${cpu}%${NC}"
                    else
                        echo -e "  CPU Usage:       ${GREEN}${cpu}%${NC}"
                    fi
                fi
                
                # Memory usage
                local mem=$(ssh $pi "ps -p $pid -o %mem --no-headers 2>/dev/null" | xargs)
                if [ -n "$mem" ]; then
                    echo "  Memory:             ${mem}%"
                fi
                
                # Uptime của process
                local etime=$(ssh $pi "ps -p $pid -o etime --no-headers 2>/dev/null" | xargs)
                if [ -n "$etime" ]; then
                    echo "  Running Time:    $etime"
                    
                    # Cảnh báo nếu running time quá ngắn (< 1 phút)
                    if [[ "$etime" =~ ^00:00: ]] || [[ "$etime" =~ ^0:  ]]; then
                        echo -e "  ${YELLOW}⚠️ Just started/restarted recently${NC}"
                    fi
                fi
                
                # FPS & Frame info từ log
                if [ -n "$port" ]; then
                    # Tìm thông tin stream dựa trên port
                    local stream_info=$(ssh $pi "grep '$port' $log_file 2>/dev/null | grep -iE 'Stream #|fps|bitrate|Video:  ' | tail -3" 2>/dev/null)
                    
                    if [ -n "$stream_info" ]; then
                        echo "  Stream Info:"
                        echo "$stream_info" | sed 's/^/    /'
                    fi
                fi
                
                echo ""
            done
            
            # ━━━ ERRORS - Chi tiết theo từng stream ━━━
            echo -e "${RED}━━━ ERRORS (Last 10) ━━━${NC}"
            
            local errors=$(ssh $pi "grep -iE 'error|failed|connection.*failed|timeout|refused|Input/output error' $log_file 2>/dev/null | tail -10" 2>/dev/null)
            
            if [ -n "$errors" ]; then
                local has_error=0
                
                echo "$errors" | while IFS= read -r line; do
                    has_error=1
                    
                    # Parse timestamp
                    local timestamp=$(echo "$line" | grep -oE '\[[^]]+\]' | head -1 | sed 's/\[//;s/\]//')
                    local message=$(echo "$line" | sed 's/\[.*\] //')
                    
                    # Xác định stream dựa vào port (lẻ = Stream 1, chẵn = Stream 2)
                    local detected_port=$(echo "$message" | grep -oE ':[0-9]{4}' | sed 's/://' | head -1)
                    local stream_label="General"
                    
                    if [ -n "$detected_port" ]; then
                        # Check nếu port lẻ hay chẵn
                        if [ $((detected_port % 2)) -eq 1 ]; then
                            stream_label="Stream 1"
                        else
                            stream_label="Stream 2"
                        fi
                    elif echo "$message" | grep -qi "STREAM. 1\|first"; then
                        stream_label="Stream 1"
                    elif echo "$message" | grep -qi "STREAM.2\|second"; then
                        stream_label="Stream 2"
                    fi
                    
                    # Colorize theo mức độ nghiêm trọng
                    if echo "$message" | grep -qi "connection.*failed\|refused"; then
                        echo -e "  ${RED}[$stream_label]${NC} ${YELLOW}[$timestamp]${NC} ${RED}$message${NC}"
                    elif echo "$message" | grep -qi "timeout"; then
                        echo -e "  ${YELLOW}[$stream_label]${NC} [$timestamp] ${YELLOW}$message${NC}"
                    else
                        echo -e "  ${CYAN}[$stream_label]${NC} [$timestamp] $message"
                    fi
                done
                
            else
                echo -e "  ${GREEN}✓ No errors in last 100 lines${NC}"
            fi
            
            # ━━━ NETWORK STATS ━━━
            echo ""
            echo -e "${CYAN}━━━ NETWORK STATS ━━━${NC}"
            
            # Active Connections
            echo "  Active SRT Connections:"
            
            # Method 1: ss (socket statistics) - UDP
            local connections=$(ssh $pi "ss -u -n 2>/dev/null | grep -E ':(193[5-9]|194[0-9]|195[0-9])'" 2>/dev/null)
            
            if [ -n "$connections" ]; then
                echo "$connections" | while IFS= read -r line; do
                    local local_addr=$(echo "$line" | awk '{print $5}')
                    local remote_addr=$(echo "$line" | awk '{print $6}')
                    
                    if [ -n "$local_addr" ] && [ -n "$remote_addr" ]; then
                        local port=$(echo "$local_addr" | grep -oE ':[0-9]+$' | sed 's/://')
                        if [ -n "$port" ]; then
                            echo "    Port $port: $local_addr ↔ $remote_addr"
                        else
                            echo "    $local_addr ↔ $remote_addr"
                        fi
                    fi
                done
            else
                # Method 2: netstat
                local netstat_conn=$(ssh $pi "netstat -anu 2>/dev/null | grep -E ':(193[5-9]|194[0-9]|195[0-9])'" 2>/dev/null)
                
                if [ -n "$netstat_conn" ]; then
                    echo "$netstat_conn" | grep -v "^Active" | grep -v "^Proto" | while IFS= read -r line; do
                        local local_addr=$(echo "$line" | awk '{print $4}')
                        local remote_addr=$(echo "$line" | awk '{print $5}')
                        if [ -n "$local_addr" ] && [ "$local_addr" != "0.0.0.0:*" ]; then
                            echo "    $local_addr ↔ $remote_addr"
                        fi
                    done
                else
                    # Method 3: lsof per PID (fallback)
                    if [ -n "$ffplay_pids" ]; then
                        for pid in $ffplay_pids; do
                            local net_info=$(ssh $pi "lsof -p $pid -a -i UDP 2>/dev/null | grep -v COMMAND" 2>/dev/null)
                            
                            if [ -n "$net_info" ]; then
                                echo "$net_info" | while IFS= read -r line; do
                                    local node=$(echo "$line" | awk '{print $9}')
                                    if [ -n "$node" ] && [ "$node" != "*: *" ]; then
                                        echo "    PID $pid: $node"
                                    else
                                        # Get more details
                                        local local_port=$(echo "$line" | awk '{print $8}')
                                        if [ -n "$local_port" ]; then
                                            echo "    PID $pid: Local port $local_port"
                                        fi
                                    fi
                                done
                            else
                                echo "    PID $pid:   (connection info unavailable)"
                            fi
                        done
                    else
                        echo -e "    ${YELLOW}No active connections detected${NC}"
                    fi
                fi
            fi
            
            # Bandwidth Usage
            echo ""
            echo "  Bandwidth Usage:"
            
            # Detect network interface
            local interface=$(ssh $pi "ip route | grep default | awk '{print \$5}' | head -1" 2>/dev/null)
            
            if [ -z "$interface" ]; then
                # Fallback detection
                if ssh $pi "ip link show eth0 2>/dev/null | grep -q 'state UP'" 2>/dev/null; then
                    interface="eth0"
                elif ssh $pi "ip link show wlan0 2>/dev/null | grep -q 'state UP'" 2>/dev/null; then
                    interface="wlan0"
                elif ssh $pi "ip link show end0 2>/dev/null | grep -q 'state UP'" 2>/dev/null; then
                    interface="end0"
                else
                    interface="eth0"
                fi
            fi
            
            echo "    Interface: $interface"
            
            local bandwidth_done=0
            
            # Method 1: vnstat (installed earlier)
            if ssh $pi 'command -v vnstat' &>/dev/null; then
                local bandwidth=$(ssh $pi "vnstat -i $interface -tr 2 2>/dev/null" 2>/dev/null)
                
                if echo "$bandwidth" | grep -q "rx\|tx"; then
                    local rx=$(echo "$bandwidth" | grep 'rx' | awk '{print $2, $3}')
                    local tx=$(echo "$bandwidth" | grep 'tx' | awk '{print $2, $3}')
                    
                    if [ -n "$rx" ] && [ -n "$tx" ] && [ "$rx" != "0 kbit/s" ]; then
                        echo "    RX: $rx"
                        echo "    TX: $tx"
                        bandwidth_done=1
                    fi
                fi
            fi
            
            # Method 2: ifstat
            if [ $bandwidth_done -eq 0 ] && ssh $pi 'command -v ifstat' &>/dev/null; then
                local ifstat_out=$(ssh $pi "timeout 3 ifstat -i $interface 1 1 2>/dev/null | tail -1" 2>/dev/null)
                
                if [ -n "$ifstat_out" ]; then
                    local rx_kb=$(echo "$ifstat_out" | awk '{print $1}')
                    local tx_kb=$(echo "$ifstat_out" | awk '{print $2}')
                    
                    if [ -n "$rx_kb" ] && [ -n "$tx_kb" ]; then
                        # Convert to Mbit/s if > 1000 KB/s
                        if (( $(echo "$rx_kb > 1000" | bc -l 2>/dev/null || echo 0) )); then
                            local rx_mb=$(echo "scale=2; $rx_kb / 1024" | bc 2>/dev/null)
                            echo "    RX: ${rx_mb} MB/s"
                        else
                            echo "    RX: ${rx_kb} KB/s"
                        fi
                        
                        if (( $(echo "$tx_kb > 1000" | bc -l 2>/dev/null || echo 0) )); then
                            local tx_mb=$(echo "scale=2; $tx_kb / 1024" | bc 2>/dev/null)
                            echo "    TX: ${tx_mb} MB/s"
                        else
                            echo "    TX: ${tx_kb} KB/s"
                        fi
                        
                        bandwidth_done=1
                    fi
                fi
            fi
            
            # Method 3: /proc/net/dev (fallback)
            if [ $bandwidth_done -eq 0 ]; then
                local stats1=$(ssh $pi "cat /proc/net/dev | grep '$interface' | awk '{print \$2, \$10}'" 2>/dev/null)
                
                if [ -n "$stats1" ]; then
                    sleep 2
                    local stats2=$(ssh $pi "cat /proc/net/dev | grep '$interface' | awk '{print \$2, \$10}'" 2>/dev/null)
                    
                    if [ -n "$stats2" ]; then
                        local rx1=$(echo "$stats1" | awk '{print $1}')
                        local tx1=$(echo "$stats1" | awk '{print $2}')
                        local rx2=$(echo "$stats2" | awk '{print $1}')
                        local tx2=$(echo "$stats2" | awk '{print $2}')
                        
                        if [ -n "$rx1" ] && [ -n "$rx2" ] && [ "$rx2" -gt "$rx1" ]; then
                            local rx_rate=$(( (rx2 - rx1) / 2 / 1024 ))
                            local tx_rate=$(( (tx2 - tx1) / 2 / 1024 ))
                            
                            # Convert to Mbit/s if > 1024 KB/s
                            if [ $rx_rate -gt 1024 ]; then
                                local rx_mb=$(echo "scale=2; $rx_rate / 1024" | bc 2>/dev/null)
                                echo "    RX: ${rx_mb} MB/s"
                            else
                                echo "    RX: ${rx_rate} KB/s"
                            fi
                            
                            if [ $tx_rate -gt 1024 ]; then
                                local tx_mb=$(echo "scale=2; $tx_rate / 1024" | bc 2>/dev/null)
                                echo "    TX: ${tx_mb} MB/s"
                            else
                                echo "    TX:  ${tx_rate} KB/s"
                            fi
                        else
                            echo -e "    ${YELLOW}RX: 0 KB/s (no traffic detected)${NC}"
                            echo -e "    ${YELLOW}TX: 0 KB/s${NC}"
                        fi
                    fi
                else
                    echo -e "    ${YELLOW}Unable to measure bandwidth${NC}"
                fi
            fi
            
            # Connection Quality
            echo ""
            echo "  Connection Quality:"
            
            # Extract OBS server IP from stream URL
            local obs_ip=""
            
            if [ -n "$cmdline" ]; then
                # Method 1: Parse URL format srt://IP: PORT
                obs_ip=$(echo "$cmdline" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
                
                # Method 2: If no IP found, try hostname
                if [ -z "$obs_ip" ]; then
                    obs_ip=$(echo "$cmdline" | sed 's|srt://||' | sed 's|: .*||' | sed 's|? .*||')
                fi
            fi
            
            # Validate IP
            if [ -n "$obs_ip" ] && [ "$obs_ip" != "*" ] && [[ "$obs_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "    Target:  $obs_ip"
                
                # Ping test
                local ping_result=$(ssh $pi "ping -c 3 -W 2 $obs_ip 2>/dev/null" 2>/dev/null)
                
                if [ -n "$ping_result" ]; then
                    # Parse packet loss - Simple method
                    local packet_loss=$(echo "$ping_result" | grep "packet loss" | grep -oE '[0-9]+%' | head -1 | tr -d '%')
                    
                    # Parse average RTT - Simple method
                    local rtt_line=$(echo "$ping_result" | grep "rtt\|round-trip")
                    local avg_rtt=""
                    
                    if [ -n "$rtt_line" ]; then
                        # Format:  rtt min/avg/max/mdev = 0.234/0.456/0.678/0.123 ms
                        avg_rtt=$(echo "$rtt_line" | tr '/' '\n' | sed -n '2p' | grep -oE '[0-9]+\.[0-9]+' | head -1)
                    fi
                    
                    # Display results
                    if [ -n "$packet_loss" ]; then
                        if [ "$packet_loss" -eq 0 ]; then
                            echo -e "    ${GREEN}✓ 0% packet loss${NC}"
                        elif [ "$packet_loss" -lt 5 ]; then
                            echo -e "    ${YELLOW}⚠️ ${packet_loss}% packet loss (acceptable)${NC}"
                        else
                            echo -e "    ${RED}⚠️ ${packet_loss}% packet loss (high!)${NC}"
                        fi
                    fi
                    
                    if [ -n "$avg_rtt" ]; then
                        # Colorize latency
                        if (( $(echo "$avg_rtt < 10" | bc -l 2>/dev/null || echo 0) )); then
                            echo -e "    Latency: ${GREEN}${avg_rtt} ms (excellent)${NC}"
                        elif (( $(echo "$avg_rtt < 50" | bc -l 2>/dev/null || echo 0) )); then
                            echo -e "    Latency: ${GREEN}${avg_rtt} ms (good)${NC}"
                        elif (( $(echo "$avg_rtt < 100" | bc -l 2>/dev/null || echo 0) )); then
                            echo -e "    Latency: ${YELLOW}${avg_rtt} ms (acceptable)${NC}"
                        else
                            echo -e "    Latency: ${RED}${avg_rtt} ms (high!)${NC}"
                        fi
                    fi
                    
                    # Jitter (if available)
                    local mdev=$(echo "$rtt_line" | tr '/' '\n' | sed -n '4p' | grep -oE '[0-9]+\.[0-9]+' | head -1)
                    if [ -n "$mdev" ]; then
                        echo "    Jitter:   $mdev ms"
                    fi
                    
                else
                    echo -e "    ${YELLOW}⚠️ Unable to ping $obs_ip${NC}"
                    
                    # Try traceroute to see if route exists
                    if ssh $pi 'command -v traceroute' &>/dev/null; then
                        echo "    Running quick traceroute..."
                        local trace=$(ssh $pi "timeout 5 traceroute -m 5 -w 1 $obs_ip 2>/dev/null | tail -3" 2>/dev/null)
                        if [ -n "$trace" ]; then
                            echo "$trace" | sed 's/^/      /'
                        fi
                    fi
                fi
            elif [ -n "$obs_ip" ]; then
                echo "    Detected:  $obs_ip (hostname)"
                echo -e "    ${YELLOW}⚠️ Hostname detected, ping test skipped${NC}"
            else
                echo -e "    ${YELLOW}⚠️ No OBS IP found in stream URL${NC}"
                
                # Debug:  Show what we got
                if [ -n "$cmdline" ]; then
                    echo "    Debug: URL = $cmdline"
                else
                    echo "    Debug:  No stream URL found"
                fi
            fi
            
        else
            echo -e "${RED}Pi offline${NC}"
        fi
        
        echo ""
    done
    
    read -p "Nhấn Enter để tiếp tục..."
}

# ============================================
# 3.  KIỂM TRA SCREENSHOT
# ============================================

check_screenshot() {
    print_section "📸 KIỂM TRA SCREENSHOT"
    
    printf "%-8s %-25s %-15s %s\n" \
        "Pi" "Latest Screenshot" "Size" "Modified"
    echo "────────────────────────────────────────────────────────────────────────"
    
    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo $entry | cut -d:  -f1)
        local name=$(echo $entry | cut -d: -f2)
        
        printf "%-8s " "$name"
        
        if timeout 3 ssh -o ConnectTimeout=2 $pi "exit" 2>/dev/null; then
            local latest=$(ssh $pi 'find ~/Pictures -maxdepth 1 -type f \( -name "*.png" -o -name "*.jpg" \) -printf "%T@ %f %s\n" 2>/dev/null | sort -rn | head -1' 2>/dev/null)
            
            if [ -n "$latest" ]; then
                local filename=$(echo $latest | awk '{print $2}')
                local size=$(echo $latest | awk '{printf "%.1fMB", $3/1024/1024}')
                local timestamp=$(echo $latest | awk '{print $1}')
                local modified=$(date -d @${timestamp%.*} '+%Y-%m-%d %H:%M' 2>/dev/null || echo "Unknown")
                
                printf "%-25s %-15s %s\n" "${filename: 0:25}" "$size" "$modified"
            else
                echo -e "${YELLOW}No screenshots found${NC}"
            fi
        else
            echo -e "${RED}Pi offline${NC}"
        fi
    done
    
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
}

# ============================================
# 4. KIỂM TRA WALLPAPER
# ============================================

check_wallpaper() {
    print_section "🖼️ KIỂM TRA WALLPAPER"
    
    printf "%-8s %-12s %-25s %s\n" \
        "Pi" "Service" "Last Run" "Status"
    echo "────────────────────────────────────────────────────────────────────────"
    
    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo $entry | cut -d: -f1)
        local name=$(echo $entry | cut -d: -f2)
        
        printf "%-8s " "$name"
        
        if timeout 3 ssh -o ConnectTimeout=2 $pi "exit" 2>/dev/null; then
            # Service status
            local service=$(ssh $pi 'systemctl is-enabled dogma-wallpaper 2>/dev/null')
            
            if [ "$service" = "enabled" ]; then
                echo -ne "${GREEN}Enabled${NC}     "
            else
                echo -ne "${RED}Disabled${NC}    "
            fi
            
            # Last run from log
            local last_run=$(ssh $pi 'grep "Hoàn tất" /opt/DOGMA/logs/wallpaper.log 2>/dev/null | tail -1' 2>/dev/null)
            
            if [ -n "$last_run" ]; then
                local timestamp=$(echo $last_run | grep -oE '\[[^]]+\]' | head -1 | sed 's/\[//;s/\]//')
                printf "%-25s " "${timestamp:0:25}"
                echo -e "${GREEN}Success${NC}"
            else
                printf "%-25s " "Never run"
                echo -e "${YELLOW}No log${NC}"
            fi
        else
            echo -e "${RED}N/A         Pi offline${NC}"
        fi
    done
    
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
}

# ============================================
# 5. KIỂM TRA KẾT NỐI SSH
# ============================================

check_connection() {
    print_section "🌐 KIỂM TRA KẾT NỐI SSH"
    
    printf "%-8s %-18s %-10s %-15s %s\n" \
        "Pi" "IP" "SSH" "Ping (ms)" "Uptime"
    echo "────────────────────────────────────────────────────────────────────────"
    
    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo $entry | cut -d: -f1)
        local name=$(echo $entry | cut -d: -f2)
        local host=$(echo $pi | cut -d'@' -f2)
        
        printf "%-8s %-18s " "$name" "$host"
        
        # Ping
        local ping_result=$(ping -c 1 -W 1 $host 2>/dev/null | grep 'time=' | awk -F'time=' '{print $2}' | awk '{print $1}')
        
        if [ -n "$ping_result" ]; then
            echo -ne "${GREEN}✓${NC}         "
            printf "%-15s " "${ping_result} ms"
            
            # SSH & uptime
            local uptime=$(timeout 3 ssh -o ConnectTimeout=2 $pi 'uptime -p 2>/dev/null' 2>/dev/null)
            
            if [ -n "$uptime" ]; then
                echo -e "${GREEN}$uptime${NC}"
            else
                echo -e "${RED}SSH failed${NC}"
            fi
        else
            echo -e "${RED}✗         N/A             Ping failed${NC}"
        fi
    done
    
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
}

# ============================================
# 6. KIỂM TRA ĐỒNG BỘ RCLONE
# ============================================

check_rclone() {
    print_section "☁️ KIỂM TRA ĐỒNG BỘ RCLONE"
    
    printf "%-8s %-12s %-25s %s\n" \
        "Pi" "Status" "Last Sync" "Files"
    echo "────────────────────────────────────────────────────────────────────────"
    
    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo $entry | cut -d: -f1)
        local name=$(echo $entry | cut -d: -f2)
        
        printf "%-8s " "$name"
        
        if timeout 3 ssh -o ConnectTimeout=2 $pi "exit" 2>/dev/null; then
            # Check if rclone is installed
            if ssh $pi 'command -v rclone' &>/dev/null; then
                echo -ne "${GREEN}Installed${NC}   "
                
                # Check for rclone log
                local last_sync=$(ssh $pi 'find /var/log -name "rclone*. log" -o -name "*sync*. log" 2>/dev/null | xargs tail -1 2>/dev/null | head -1' 2>/dev/null)
                
                if [ -n "$last_sync" ]; then
                    printf "%-25s " "$(echo $last_sync | cut -c1-25)"
                    echo -e "${GREEN}Active${NC}"
                else
                    printf "%-25s " "No recent sync"
                    echo -e "${YELLOW}Unknown${NC}"
                fi
            else
                echo -e "${RED}Not installed${NC}"
            fi
        else
            echo -e "${RED}Pi offline${NC}"
        fi
    done
    
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
}

# ============================================
# 7. THỐNG KÊ NHIỆT ĐỘ & PHẦN CỨNG
# ============================================

check_hardware() {
    print_section "🌡️ THỐNG KÊ NHIỆT ĐỘ & PHẦN CỨNG"
    
    printf "%-8s %-10s %-12s %-12s %-12s %s\n" \
        "Pi" "Temp" "CPU Freq" "GPU Mem" "Throttle" "Load"
    echo "────────────────────────────────────────────────────────────────────────"
    
    local total_temp=0
    local count=0
    
    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo $entry | cut -d: -f1)
        local name=$(echo $entry | cut -d: -f2)
        
        printf "%-8s " "$name"
        
        if timeout 3 ssh -o ConnectTimeout=2 $pi "exit" 2>/dev/null; then
            # Temperature
            local temp=$(ssh $pi 'vcgencmd measure_temp 2>/dev/null' | cut -d= -f2 | sed "s/'C//")
            
            if [ -n "$temp" ]; then
                if (( $(echo "$temp > 70" | bc -l 2>/dev/null || echo 0) )); then
                    echo -ne "${RED}${temp}°C${NC}     "
                elif (( $(echo "$temp > 60" | bc -l 2>/dev/null || echo 0) )); then
                    echo -ne "${YELLOW}${temp}°C${NC}     "
                else
                    echo -ne "${GREEN}${temp}°C${NC}     "
                fi
                
                total_temp=$(echo "$total_temp + $temp" | bc 2>/dev/null || echo $total_temp)
                ((count++))
            else
                echo -ne "N/A       "
            fi
            
            # CPU Freq
            local freq=$(ssh $pi 'vcgencmd measure_clock arm 2>/dev/null' | awk -F= '{printf "%.0f MHz", $2/1000000}')
            printf "%-12s " "$freq"
            
            # GPU Memory
            local gpu=$(ssh $pi 'vcgencmd get_mem gpu 2>/dev/null' | cut -d= -f2)
            printf "%-12s " "$gpu"
            
            # Throttling
            local throttle=$(ssh $pi 'vcgencmd get_throttled 2>/dev/null' | cut -d= -f2)
            if [ "$throttle" = "0x0" ]; then
                echo -ne "${GREEN}OK${NC}          "
            else
                echo -ne "${RED}$throttle${NC}  "
            fi
            
            # Load average
            local load=$(ssh $pi 'uptime 2>/dev/null | awk -F"load average:" '"'"'{print $2}'"'"' | awk '"'"'{print $1}'"'"' | sed "s/,//"' 2>/dev/null)
            echo "$load"
            
        else
            echo -e "${RED}Pi offline${NC}"
        fi
    done
    
    if [ $count -gt 0 ]; then
        local avg_temp=$(echo "scale=1; $total_temp / $count" | bc 2>/dev/null || echo "N/A")
        echo ""
        echo -e "📊 Nhiệt độ trung bình: ${CYAN}${avg_temp}°C${NC}"
    fi
    
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
}

# ============================================
# 8. LOG CHI TIẾT TỪNG PI
# ============================================

check_detailed_log() {
    print_section "📋 LOG CHI TIẾT"
    
    echo "Chọn Pi để xem log chi tiết:"
    echo ""
    
    local i=1
    for entry in "${PI_LIST[@]}"; do
        local name=$(echo $entry | cut -d: -f2)
        echo "  $i) $name"
        ((i++))
    done
    
    echo "  0) Quay lại"
    echo ""
    echo -n "➤ Chọn Pi [0-9]: "
    read pi_choice
    
    if [ "$pi_choice" -ge 1 ] && [ "$pi_choice" -le 9 ]; then
        local idx=$((pi_choice - 1))
        local entry="${PI_LIST[$idx]}"
        local pi=$(echo $entry | cut -d: -f1)
        local name=$(echo $entry | cut -d: -f2)
        
        clear
        echo -e "${CYAN}━━━ LOG CHI TIẾT:  $name ━━━${NC}\n"
        
        echo -e "${YELLOW}[1] Wallpaper Log: ${NC}"
        ssh $pi 'tail -20 /opt/DOGMA/logs/wallpaper.log 2>/dev/null' || echo "No log"
        
        echo -e "\n${YELLOW}[2] Stream Log:${NC}"
        ssh $pi 'tail -20 /opt/DOGMA/logs/dual_stream.log 2>/dev/null' || echo "No log"
        
        echo -e "\n${YELLOW}[3] System Log (last 10 errors):${NC}"
        ssh $pi 'sudo journalctl -p err -n 10 --no-pager 2>/dev/null' || echo "No errors"
        
        echo -e "\n${YELLOW}[4] Disk Usage:${NC}"
        ssh $pi 'df -h | grep -E "Filesystem|/$"'
        
        echo -e "\n${YELLOW}[5] Memory Usage:${NC}"
        ssh $pi 'free -h'
        
        echo ""
        read -p "Nhấn Enter để tiếp tục..."
    fi
}

# ============================================
# 11. UPDATE & UPGRADE
# ============================================

update_upgrade_all() {
    print_section "📦 UPDATE & UPGRADE TẤT CẢ PI"
    
    echo -e "${YELLOW}⚠️ Thao tác này sẽ mất 5-10 phút cho mỗi Pi${NC}"
    echo -n "Bạn có chắc chắn muốn tiếp tục? (yes/no): "
    read confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "Đã hủy."
        sleep 2
        return
    fi
    
    echo ""
    echo "Đang update & upgrade..."
    echo ""
    
    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo $entry | cut -d: -f1)
        local name=$(echo $entry | cut -d: -f2)
        
        echo -ne "[$name] "
        
        if timeout 3 ssh -o ConnectTimeout=2 $pi "exit" 2>/dev/null; then
            ssh $pi 'export DEBIAN_FRONTEND=noninteractive; sudo apt update -qq && sudo apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"' &>/dev/null &
            local pid=$!
            
            spinner $pid
            wait $pid
            local status=$?
            
            if [ $status -eq 0 ]; then
                echo -e " ${GREEN}✓ Done${NC}"
            else
                echo -e " ${RED}✗ Failed${NC}"
            fi
        else
            echo -e "${RED}✗ Offline${NC}"
        fi
    done
    
    echo ""
    echo -e "${GREEN}✓ Hoàn tất update & upgrade${NC}"
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
}

# ============================================
# 12. REBOOT ALL
# ============================================

reboot_all() {
    print_section "🔄 REBOOT TẤT CẢ PI"
    
    echo -e "${RED}⚠️ Tất cả Pi sẽ bị reboot! ${NC}"
    echo -n "Bạn có chắc chắn?  (yes/no): "
    read confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "Đã hủy."
        sleep 2
        return
    fi
    
    echo ""
    echo "Đang reboot..."
    
    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo $entry | cut -d: -f1)
        local name=$(echo $entry | cut -d: -f2)
        
        echo -ne "[$name] "
        
        if timeout 3 ssh -o ConnectTimeout=2 $pi "exit" 2>/dev/null; then
            ssh $pi 'sudo reboot' &>/dev/null &
            echo -e "${GREEN}✓ Rebooting${NC}"
        else
            echo -e "${RED}✗ Offline${NC}"
        fi
    done
    
    echo ""
    echo -e "${YELLOW}⏳ Đợi 2-3 phút để Pi boot lại${NC}"
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
}

# ============================================
# 12s. SHUTDOWN ALL
# ============================================

shutdown_all() {
    print_section "🔴 SHUTDOWN TẤT CẢ PI"
    
    echo -e "${RED}⚠️ ⚠️ ⚠️ CẢNH BÁO ⚠️ ⚠️ ⚠️${NC}"
    echo -e "${RED}Tất cả Pi sẽ bị TẮT HOÀN TOÀN!${NC}"
    echo -e "${YELLOW}Bạn sẽ cần VẬT LÝ BẬT LẠI NGUỒN để khởi động lại! ${NC}"
    echo ""
    echo -n "Gõ 'SHUTDOWN' (viết hoa) để xác nhận: "
    read confirm
    
    if [ "$confirm" != "SHUTDOWN" ]; then
        echo "Đã hủy."
        sleep 2
        return
    fi
    
    echo ""
    echo -e "${RED}Xác nhận lần cuối! ${NC}"
    echo -n "Bạn có CHẮC CHẮN muốn shutdown 9 Pi? (yes/no): "
    read confirm2
    
    if [ "$confirm2" != "yes" ]; then
        echo "Đã hủy."
        sleep 2
        return
    fi
    
    echo ""
    echo -e "${CYAN}Đang shutdown...${NC}"
    echo ""
    
    local success=0
    local failed=0
    
    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo $entry | cut -d: -f1)
        local name=$(echo $entry | cut -d: -f2)
        
        printf "%-6s:  " "$name"
        
        if timeout 5 ssh -o ConnectTimeout=3 $pi "exit" 2>/dev/null; then
            # Send shutdown command
            ssh $pi 'sudo shutdown -h now' &>/dev/null &
            
            echo -e "${RED}⚡ Shutting down... ${NC}"
            success=$((success + 1))
        else
            echo -e "${YELLOW}✗ Already offline${NC}"
            failed=$((failed + 1))
        fi
    done
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ Shutdown command sent:  $success Pi${NC}"
    
    if [ $failed -gt 0 ]; then
        echo -e "${YELLOW}⚠️ Already offline: $failed Pi${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}⏳ Pi sẽ tắt trong 5-10 giây${NC}"
    echo -e "${RED}⚠️ Để khởi động lại, bạn cần: ${NC}"
    echo "   1. Rút nguồn điện"
    echo "   2. Cắm lại nguồn điện"
    echo "   3. Hoặc dùng nút nguồn (nếu có)"
    echo ""
    
    # Countdown
    echo -n "Kiểm tra trạng thái sau shutdown trong:  "
    for i in 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1; do
        echo -n "$i "
        sleep 1
    done
    echo ""
    
    # Verify shutdown
    echo ""
    echo -e "${CYAN}━━━ Kiểm tra trạng thái ━━━${NC}"
    echo ""
    
    local offline_count=0
    
    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo $entry | cut -d: -f1)
        local name=$(echo $entry | cut -d: -f2)
        local host=$(echo $pi | cut -d'@' -f2)
        
        printf "%-6s %-18s:  " "$name" "($host)"
        
        if timeout 3 ping -c 1 -W 1 $host &>/dev/null; then
            echo -e "${YELLOW}⚠️ Still online (shutting down...)${NC}"
        else
            echo -e "${GREEN}✓ Offline${NC}"
            offline_count=$((offline_count + 1))
        fi
    done
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✓ Confirmed offline: $offline_count/9 Pi${NC}"
    
    if [ $offline_count -lt 9 ]; then
        echo -e "${YELLOW}⚠️ Some Pi still shutting down...${NC}"
        echo "   Wait 30s and check again with:  tailscale status"
    fi
    
    echo ""
    read -p "Nhấn Enter để quay lại menu..."
}

# ============================================
# 13. CẬP NHẬT WALLPAPER
# ============================================

update_wallpaper_all() {
    print_section "🖼️ CẬP NHẬT WALLPAPER TẤT CẢ PI"
    
    echo "Đang cập nhật wallpaper..."
    echo ""
    
    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo $entry | cut -d: -f1)
        local name=$(echo $entry | cut -d: -f2)
        
        echo -ne "[$name] "
        
        if timeout 3 ssh -o ConnectTimeout=2 $pi "exit" 2>/dev/null; then
            ssh $pi '/opt/DOGMA/set_daily_wallpaper.sh' &>/dev/null &
            local pid=$!
            
            spinner $pid
            wait $pid
            
            echo -e " ${GREEN}✓ Done${NC}"
        else
            echo -e "${RED}✗ Offline${NC}"
        fi
    done
    
    echo ""
    echo -e "${GREEN}✓ Hoàn tất${NC}"
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
}

# ============================================
# 14. RESTART SERVICE
# ============================================

restart_services() {
    print_section "🔧 RESTART SERVICE SYSTEMD"
    
    echo "Chọn service cần restart:"
    echo "  1) dogma-wallpaper.service"
    echo "  2) dogma-dual. service"
    echo "  3) Tất cả services"
    echo "  0) Quay lại"
    echo ""
    echo -n "➤ Chọn [0-3]: "
    read service_choice
    
    local service_name=""
    
    case $service_choice in
        1) service_name="dogma-wallpaper.service" ;;
        2) service_name="dogma-dual.service" ;;
        3) service_name="dogma-wallpaper.service dogma-dual.service" ;;
        0) return ;;
        *) echo "Lựa chọn không hợp lệ"; sleep 2; return ;;
    esac
    
    echo ""
    echo "Đang restart $service_name..."
    echo ""
    
    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo $entry | cut -d: -f1)
        local name=$(echo $entry | cut -d: -f2)
        
        echo -ne "[$name] "
        
        if timeout 3 ssh -o ConnectTimeout=2 $pi "exit" 2>/dev/null; then
            for svc in $service_name; do
                ssh $pi "sudo systemctl restart $svc" &>/dev/null
            done
            echo -e "${GREEN}✓ Done${NC}"
        else
            echo -e "${RED}✗ Offline${NC}"
        fi
    done
    
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
}

# ============================================
# 15. DEPLOY LẠI SCRIPTS
# ============================================

redeploy_scripts() {
    print_section "🚀 DEPLOY LẠI SCRIPTS"
    
    echo -e "${YELLOW}Chức năng này sẽ chạy lại script deploy_all_9pi.sh${NC}"
    echo -n "Tiếp tục? (yes/no): "
    read confirm
    
    if [ "$confirm" = "yes" ]; then
        if [ -f ~/deploy_all_9pi.sh ]; then
            ~/deploy_all_9pi.sh
        else
            echo -e "${RED}Không tìm thấy ~/deploy_all_9pi.sh${NC}"
        fi
    fi
    
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
}

# ============================================
# 16. BACKUP CONFIG
# ============================================

backup_config() {
    print_section "💾 BACKUP CONFIG TẤT CẢ PI"
    
    local backup_dir=~/dogma_backup_$(date +%Y%m%d_%H%M%S)
    mkdir -p "$backup_dir"
    
    echo "Đang backup config vào:  $backup_dir"
    echo ""
    
    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo $entry | cut -d: -f1)
        local name=$(echo $entry | cut -d: -f2)
        
        echo -ne "[$name] "
        
        if timeout 3 ssh -o ConnectTimeout=2 $pi "exit" 2>/dev/null; then
            local pi_dir="$backup_dir/$name"
            mkdir -p "$pi_dir"
            
            # Backup important files
            scp -q $pi:/opt/DOGMA/*. sh "$pi_dir/" 2>/dev/null
            scp -q $pi:/etc/systemd/system/dogma-*. service "$pi_dir/" 2>/dev/null
            scp -q $pi:/boot/config.txt "$pi_dir/config.txt" 2>/dev/null
            
            echo -e "${GREEN}✓ Done${NC}"
        else
            echo -e "${RED}✗ Offline${NC}"
        fi
    done
    
    echo ""
    echo -e "${GREEN}✓ Backup hoàn tất:  $backup_dir${NC}"
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
}

# ============================================
# 21. SSH VÀO PI CỤ THỂ
# ============================================

ssh_to_pi() {
    print_section "🖥️ SSH VÀO PI"
    
    echo "Chọn Pi:"
    echo ""
    
    local i=1
    for entry in "${PI_LIST[@]}"; do
        local name=$(echo $entry | cut -d: -f2)
        local pi=$(echo $entry | cut -d: -f1)
        local host=$(echo $pi | cut -d'@' -f2)
        echo "  $i) $name ($host)"
        ((i++))
    done
    
    echo "  0) Quay lại"
    echo ""
    echo -n "➤ Chọn Pi [0-9]: "
    read pi_choice
    
    if [ "$pi_choice" -ge 1 ] && [ "$pi_choice" -le 9 ]; then
        local idx=$((pi_choice - 1))
        local entry="${PI_LIST[$idx]}"
        local pi=$(echo $entry | cut -d: -f1)
        local name=$(echo $entry | cut -d: -f2)
        
        echo ""
        echo -e "${CYAN}Đang SSH vào $name...${NC}"
        echo -e "${YELLOW}(Gõ 'exit' để quay lại menu)${NC}"
        echo ""
        sleep 1
        
        ssh $pi
    fi
}


# ============================================
# 22.  XUẤT BÁO CÁO HTML ĐẦY ĐỦ
# ============================================

export_report() {
    print_section "📊 XUẤT BÁO CÁO HTML ĐẦY ĐỦ"
    
    local report_file=~/dogma_report_$(date +%Y%m%d_%H%M%S).html
    
    echo "Đang thu thập dữ liệu từ 9 Pi..."
    echo ""
    
    # Thu thập data trước
    declare -A pi_data
    
    local idx=0
    for entry in "${PI_LIST[@]}"; do
        local pi=$(echo $entry | cut -d: -f1)
        local name=$(echo $entry | cut -d: -f2)
        local host=$(echo $pi | cut -d'@' -f2)
        
        echo -ne "[$name] "
        
        if timeout 5 ssh -o ConnectTimeout=3 $pi "exit" 2>/dev/null; then
            echo -ne "Collecting data..."
            
            # Basic info
            local temp=$(ssh $pi 'vcgencmd measure_temp 2>/dev/null' | cut -d= -f2 | sed "s/'C//")
            local freq=$(ssh $pi 'vcgencmd measure_clock arm 2>/dev/null' | awk -F= '{printf "%.0f", $2/1000000}')
            local gpu=$(ssh $pi 'vcgencmd get_mem gpu 2>/dev/null' | cut -d= -f2)
            local uptime=$(ssh $pi 'uptime -p 2>/dev/null')
            local load=$(ssh $pi 'uptime 2>/dev/null | awk -F"load average:" '"'"'{print $2}'"'"' | awk '"'"'{print $1}'"'"' | sed "s/,//"' 2>/dev/null)
            
            # Stream info
            local stream_status=$(ssh $pi 'systemctl is-active dogma-dual 2>/dev/null')
            local ffplay_count=$(ssh $pi 'pgrep ffplay 2>/dev/null | wc -l' 2>/dev/null || echo "0")
            local stream_errors=$(ssh $pi 'grep -icE "error|failed" /opt/DOGMA/logs/dual_stream.log 2>/dev/null' || echo "0")
            
            # Wallpaper info
            local wp_status=$(ssh $pi 'systemctl is-enabled dogma-wallpaper 2>/dev/null')
            local wp_last=$(ssh $pi 'grep "Hoàn tất" /opt/DOGMA/logs/wallpaper.log 2>/dev/null | tail -1' | grep -oE '\[[^]]+\]' | head -1 | sed 's/\[//;s/\]//')
            
            # Screenshot info
            local screenshot_latest=$(ssh $pi 'find ~/Pictures -maxdepth 1 -type f \( -name "*.png" -o -name "*.jpg" \) -printf "%T@ %f\n" 2>/dev/null | sort -rn | head -1' 2>/dev/null)
            local screenshot_name=$(echo "$screenshot_latest" | awk '{print $2}')
            local screenshot_time=$(echo "$screenshot_latest" | awk '{print $1}')
            if [ -n "$screenshot_time" ]; then
                screenshot_time=$(date -d @${screenshot_time%.*} '+%Y-%m-%d %H:%M' 2>/dev/null)
            fi
            
            # Rclone info
            local rclone_installed="No"
            if ssh $pi 'command -v rclone' &>/dev/null; then
                rclone_installed="Yes"
            fi
            
            # Network info
            local interface=$(ssh $pi "ip route | grep default | awk '{print \$5}' | head -1" 2>/dev/null)
            if [ -z "$interface" ]; then
                interface="eth0"
            fi
            
            # Bandwidth
            local bandwidth_rx="N/A"
            local bandwidth_tx="N/A"
            
            if ssh $pi 'command -v vnstat' &>/dev/null; then
                local bw=$(ssh $pi "vnstat -i $interface -tr 2 2>/dev/null" 2>/dev/null)
                if echo "$bw" | grep -q "rx\|tx"; then
                    bandwidth_rx=$(echo "$bw" | grep 'rx' | awk '{print $2, $3}')
                    bandwidth_tx=$(echo "$bw" | grep 'tx' | awk '{print $2, $3}')
                fi
            fi
            
            # Disk usage
            local disk_usage=$(ssh $pi 'df -h / 2>/dev/null | tail -1 | awk '"'"'{print $5}'"'"' 2>/dev/null)
            
            # Memory usage
            local mem_usage=$(ssh $pi 'free | grep Mem | awk '"'"'{printf "%.1f", $3/$2 * 100}'"'"' 2>/dev/null)
            
            # Lưu data (dùng | làm separator)
            pi_data[$name]="online|$host|$temp|$freq|$gpu|$uptime|$load|$stream_status|$ffplay_count|$stream_errors|$wp_status|$wp_last|$screenshot_name|$screenshot_time|$rclone_installed|$interface|$bandwidth_rx|$bandwidth_tx|$disk_usage|$mem_usage"
            
            echo " ✓"
        else
            pi_data[$name]="offline|$host||||||||||||||||"
            echo " Offline"
        fi
        
        ((idx++))
    done
    
    echo ""
    echo "Đang tạo báo cáo HTML..."
    
    # ============================================
    # TẠO HTML
    # ============================================
    
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
            background:  linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            color: #333;
        }
        .container {
            max-width: 1600px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        .header h1 {
            font-size: 2.8em;
            margin-bottom:  10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        .timestamp {
            opacity: 0.9;
            font-size: 1em;
            margin-top: 10px;
        }
        .content {
            padding: 40px;
        }
        h2 {
            color: #667eea;
            margin:  40px 0 20px 0;
            padding-bottom: 10px;
            border-bottom: 3px solid #667eea;
            font-size: 2em;
        }
        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 25px;
            margin:  30px 0;
        }
        .summary-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius:  15px;
            text-align: center;
            box-shadow: 0 8px 20px rgba(102, 126, 234, 0.4);
            transition: transform 0.3s;
        }
        .summary-card:hover {
            transform:  translateY(-5px);
        }
        .summary-card h3 {
            font-size: 3em;
            margin-bottom:  10px;
            font-weight: bold;
        }
        .summary-card p {
            opacity: 0.95;
            font-size: 1.1em;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 25px 0;
            background: white;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
            border-radius: 10px;
            overflow: hidden;
        }
        th {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 18px 15px;
            text-align:  left;
            font-weight:  600;
            font-size:  0.95em;
            text-transform: uppercase;
            letter-spacing: 0.8px;
        }
        td {
            padding: 15px;
            border-bottom: 1px solid #e0e0e0;
            font-size: 0.95em;
        }
        tr:last-child td {
            border-bottom: none;
        }
        tr:hover {
            background: #f8f9ff;
        }
        .status-online {
            color: #10b981;
            font-weight: bold;
        }
        .status-offline {
            color: #ef4444;
            font-weight: bold;
        }
        .status-warning {
            color: #f59e0b;
            font-weight: bold;
        }
        .badge {
            display: inline-block;
            padding: 6px 14px;
            border-radius: 20px;
            font-size: 0.85em;
            font-weight:  600;
        }
        .badge-success {
            background: #d1fae5;
            color:  #065f46;
        }
        .badge-danger {
            background: #fee2e2;
            color:  #991b1b;
        }
        .badge-warning {
            background: #fef3c7;
            color: #92400e;
        }
        .badge-info {
            background: #dbeafe;
            color: #1e40af;
        }
        .footer {
            text-align: center;
            padding: 30px;
            color: #666;
            font-size: 0.9em;
            border-top: 1px solid #e0e0e0;
            background: #f9fafb;
        }
        .pi-name {
            font-weight: bold;
            color: #667eea;
            font-size: 1.1em;
        }
        .temp-normal { color: #10b981; font-weight: bold; }
        .temp-warm { color: #f59e0b; font-weight: bold; }
        .temp-hot { color: #ef4444; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎯 DOGMA System Report</h1>
HTMLHEAD

    echo "            <p class=\"timestamp\">📅 Generated: $(date '+%Y-%m-%d %H:%M:%S')</p>" >> "$report_file"
    echo "            <p class=\"timestamp\">💻 Generated by: $(whoami)@$(hostname)</p>" >> "$report_file"
    
    cat >> "$report_file" << 'HTMLBODY'
        </div>
        <div class="content">
HTMLBODY

    # ============================================
    # SUMMARY CARDS
    # ============================================
    
    local total_pi=9
    local online_count=0
    local offline_count=0
    local total_temp=0
    local temp_count=0
    local stream_active=0
    
    PI_NAMES=(ltr01 ltr02 ltr03 ltr04 ltr05 ltr06 ltr07 ltr08 ltr09)
    
    for name in "${PI_NAMES[@]}"; do
        local data="${pi_data[$name]}"
        if [[ "$data" =~ ^online ]]; then
            ((online_count++))
            
            local temp=$(echo "$data" | cut -d'|' -f3)
            if [ -n "$temp" ] && [ "$temp" != "" ]; then
                total_temp=$(echo "$total_temp + $temp" | bc 2>/dev/null || echo $total_temp)
                ((temp_count++))
            fi
            
            local stream=$(echo "$data" | cut -d'|' -f8)
            [ "$stream" = "active" ] && ((stream_active++))
        else
            ((offline_count++))
        fi
    done
    
    local avg_temp="N/A"
    if [ $temp_count -gt 0 ]; then
        avg_temp=$(echo "scale=1; $total_temp / $temp_count" | bc 2>/dev/null)"°C"
    fi
    
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
                    <h3>$offline_count</h3>
                    <p>Pi Offline</p>
                </div>
            </div>
SUMMARY

    # ============================================
    # TABLE 1: SYSTEM OVERVIEW
    # ============================================
    
    cat >> "$report_file" << 'TABLE1'
            <h2>📊 System Overview</h2>
            <table>
                <thead>
                    <tr>
                        <th>Pi</th>
                        <th>IP Address</th>
                        <th>Status</th>
                        <th>Temperature</th>
                        <th>CPU Freq</th>
                        <th>GPU Memory</th>
                        <th>Load Avg</th>
                        <th>Uptime</th>
                    </tr>
                </thead>
                <tbody>
TABLE1

    for name in "${PI_NAMES[@]}"; do
        local data="${pi_data[$name]}"
        
        if [[ "$data" =~ ^online ]]; then
            IFS='|' read -r status host temp freq gpu uptime load stream_status ffplay_count stream_errors wp_status wp_last screenshot_name screenshot_time rclone_installed interface bandwidth_rx bandwidth_tx disk_usage mem_usage <<< "$data"
            
            local temp_class="temp-normal"
            if [ -n "$temp" ] && [ "$temp" != "" ]; then
                if (( $(echo "$temp > 70" | bc -l 2>/dev/null || echo 0) )); then
                    temp_class="temp-hot"
                elif (( $(echo "$temp > 60" | bc -l 2>/dev/null || echo 0) )); then
                    temp_class="temp-warm"
                fi
            fi
            
            cat >> "$report_file" << TR1
                    <tr>
                        <td class="pi-name">$name</td>
                        <td>$host</td>
                        <td><span class="status-online">● Online</span></td>
                        <td class="$temp_class">${temp}°C</td>
                        <td>${freq} MHz</td>
                        <td>$gpu</td>
                        <td>$load</td>
                        <td>$uptime</td>
                    </tr>
TR1
        else
            local host=$(echo "$data" | cut -d'|' -f2)
            cat >> "$report_file" << TR2
                    <tr>
                        <td class="pi-name">$name</td>
                        <td>$host</td>
                        <td><span class="status-offline">● Offline</span></td>
                        <td>-</td>
                        <td>-</td>
                        <td>-</td>
                        <td>-</td>
                        <td>-</td>
                    </tr>
TR2
        fi
    done
    
    echo "                </tbody>" >> "$report_file"
    echo "            </table>" >> "$report_file"
    
    # ============================================
    # TABLE 2: STREAM STATUS
    # ============================================
    
    cat >> "$report_file" << 'TABLE2'
            <h2>📺 Stream Status</h2>
            <table>
                <thead>
                    <tr>
                        <th>Pi</th>
                        <th>Service Status</th>
                        <th>Active Streams</th>
                        <th>Log Errors</th>
                        <th>Overall Status</th>
                    </tr>
                </thead>
                <tbody>
TABLE2

    for name in "${PI_NAMES[@]}"; do
        local data="${pi_data[$name]}"
        
        if [[ "$data" =~ ^online ]]; then
            IFS='|' read -r status host temp freq gpu uptime load stream_status ffplay_count stream_errors wp_status wp_last screenshot_name screenshot_time rclone_installed interface bandwidth_rx bandwidth_tx disk_usage mem_usage <<< "$data"
            
            local service_badge="badge-danger"
            local service_text="Inactive"
            if [ "$stream_status" = "active" ]; then
                service_badge="badge-success"
                service_text="Active"
            fi
            
            local stream_badge="badge-success"
            local stream_text="$ffplay_count/2"
            if [ "$ffplay_count" != "2" ]; then
                stream_badge="badge-warning"
            fi
            
            local error_badge="badge-success"
            local error_text="$stream_errors errors"
            if [ "$stream_errors" -gt 10 ]; then
                error_badge="badge-danger"
            elif [ "$stream_errors" -gt 0 ]; then
                error_badge="badge-warning"
            fi
            
            local overall_status="✅ OK"
            if [ "$ffplay_count" != "2" ] || [ "$stream_status" != "active" ]; then
                overall_status="⚠️ Check Required"
            fi
            
            cat >> "$report_file" << TR3
                    <tr>
                        <td class="pi-name">$name</td>
                        <td><span class="badge $service_badge">$service_text</span></td>
                        <td><span class="badge $stream_badge">$stream_text</span></td>
                        <td><span class="badge $error_badge">$error_text</span></td>
                        <td>$overall_status</td>
                    </tr>
TR3
        else
            cat >> "$report_file" << TR4
                    <tr>
                        <td class="pi-name">$name</td>
                        <td><span class="badge badge-danger">Offline</span></td>
                        <td>-</td>
                        <td>-</td>
                        <td>❌ Pi Offline</td>
                    </tr>
TR4
        fi
    done
    
    echo "                </tbody>" >> "$report_file"
    echo "            </table>" >> "$report_file"
    
    # ============================================
    # TABLE 3: WALLPAPER STATUS
    # ============================================
    
    cat >> "$report_file" << 'TABLE3'
            <h2>🖼️ Wallpaper Status</h2>
            <table>
                <thead>
                    <tr>
                        <th>Pi</th>
                        <th>Service</th>
                        <th>Last Run</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
TABLE3

    for name in "${PI_NAMES[@]}"; do
        local data="${pi_data[$name]}"
        
        if [[ "$data" =~ ^online ]]; then
            IFS='|' read -r status host temp freq gpu uptime load stream_status ffplay_count stream_errors wp_status wp_last screenshot_name screenshot_time rclone_installed interface bandwidth_rx bandwidth_tx disk_usage mem_usage <<< "$data"
            
            local wp_badge="badge-danger"
            local wp_text="Disabled"
            if [ "$wp_status" = "enabled" ]; then
                wp_badge="badge-success"
                wp_text="Enabled"
            fi
            
            local last_run="${wp_last:-Never run}"
            local status_icon="⚠️ No log"
            if [ -n "$wp_last" ]; then
                status_icon="✅ OK"
            fi
            
            cat >> "$report_file" << TR5
                    <tr>
                        <td class="pi-name">$name</td>
                        <td><span class="badge $wp_badge">$wp_text</span></td>
                        <td>$last_run</td>
                        <td>$status_icon</td>
                    </tr>
TR5
        else
            cat >> "$report_file" << TR6
                    <tr>
                        <td class="pi-name">$name</td>
                        <td><span class="badge badge-danger">Offline</span></td>
                        <td>-</td>
                        <td>❌ Pi Offline</td>
                    </tr>
TR6
        fi
    done
    
    echo "                </tbody>" >> "$report_file"
    echo "            </table>" >> "$report_file"
    
    # ============================================
    # TABLE 4: SCREENSHOT STATUS
    # ============================================
    
    cat >> "$report_file" << 'TABLE4'
            <h2>📸 Screenshot Status</h2>
            <table>
                <thead>
                    <tr>
                        <th>Pi</th>
                        <th>Latest Screenshot</th>
                        <th>Captured Time</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
TABLE4

    for name in "${PI_NAMES[@]}"; do
        local data="${pi_data[$name]}"
        
        if [[ "$data" =~ ^online ]]; then
            IFS='|' read -r status host temp freq gpu uptime load stream_status ffplay_count stream_errors wp_status wp_last screenshot_name screenshot_time rclone_installed interface bandwidth_rx bandwidth_tx disk_usage mem_usage <<< "$data"
            
            local ss_display="${screenshot_name:-No screenshot}"
            local ss_time="${screenshot_time:-N/A}"
            local ss_status="⚠️ No file"
            
            if [ -n "$screenshot_name" ]; then
                ss_status="✅ OK"
            fi
            
            cat >> "$report_file" << TR7
                    <tr>
                        <td class="pi-name">$name</td>
                        <td>$ss_display</td>
                        <td>$ss_time</td>
                        <td>$ss_status</td>
                    </tr>
TR7
        else
            cat >> "$report_file" << TR8
                    <tr>
                        <td class="pi-name">$name</td>
                        <td>-</td>
                        <td>-</td>
                        <td>❌ Pi Offline</td>
                    </tr>
TR8
        fi
    done
    
    echo "                </tbody>" >> "$report_file"
    echo "            </table>" >> "$report_file"
    
    # ============================================
    # TABLE 5: NETWORK & RESOURCES
    # ============================================
    
    cat >> "$report_file" << 'TABLE5'
            <h2>🌐 Network & Resources</h2>
            <table>
                <thead>
                    <tr>
                        <th>Pi</th>
                        <th>Interface</th>
                        <th>Bandwidth RX</th>
                        <th>Bandwidth TX</th>
                        <th>Disk Usage</th>
                        <th>Memory Usage</th>
                    </tr>
                </thead>
                <tbody>
TABLE5

    for name in "${PI_NAMES[@]}"; do
        local data="${pi_data[$name]}"
        
        if [[ "$data" =~ ^online ]]; then
            IFS='|' read -r status host temp freq gpu uptime load stream_status ffplay_count stream_errors wp_status wp_last screenshot_name screenshot_time rclone_installed interface bandwidth_rx bandwidth_tx disk_usage mem_usage <<< "$data"
            
            local disk_class=""
            if [ -n "$disk_usage" ]; then
                local disk_num=$(echo $disk_usage | sed 's/%//')
                if [ "$disk_num" -gt 80 ]; then
                    disk_class="class=\"status-offline\""
                elif [ "$disk_num" -gt 60 ]; then
                    disk_class="class=\"status-warning\""
                fi
            fi
            
            local mem_class=""
            if [ -n "$mem_usage" ]; then
                if (( $(echo "$mem_usage > 80" | bc -l 2>/dev/null || echo 0) )); then
                    mem_class="class=\"status-offline\""
                elif (( $(echo "$mem_usage > 60" | bc -l 2>/dev/null || echo 0) )); then
                    mem_class="class=\"status-warning\""
                fi
            fi
            
            cat >> "$report_file" << TR9
                    <tr>
                        <td class="pi-name">$name</td>
                        <td>$interface</td>
                        <td>$bandwidth_rx</td>
                        <td>$bandwidth_tx</td>
                        <td $disk_class>$disk_usage</td>
                        <td $mem_class>${mem_usage}%</td>
                    </tr>
TR9
        else
            cat >> "$report_file" << TR10
                    <tr>
                        <td class="pi-name">$name</td>
                        <td>-</td>
                        <td>-</td>
                        <td>-</td>
                        <td>-</td>
                        <td>-</td>
                    </tr>
TR10
        fi
    done
    
    echo "                </tbody>" >> "$report_file"
    echo "            </table>" >> "$report_file"
    
    # ============================================
    # TABLE 6: RCLONE & MISC
    # ============================================
    
    cat >> "$report_file" << 'TABLE6'
            <h2>☁️ Rclone & Miscellaneous</h2>
            <table>
                <thead>
                    <tr>
                        <th>Pi</th>
                        <th>Rclone Installed</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
TABLE6

    for name in "${PI_NAMES[@]}"; do
        local data="${pi_data[$name]}"
        
        if [[ "$data" =~ ^online ]]; then
            IFS='|' read -r status host temp freq gpu uptime load stream_status ffplay_count stream_errors wp_status wp_last screenshot_name screenshot_time rclone_installed interface bandwidth_rx bandwidth_tx disk_usage mem_usage <<< "$data"
            
            local rclone_badge="badge-danger"
            local rclone_status="❌ Not installed"
            
            if [ "$rclone_installed" = "Yes" ]; then
                rclone_badge="badge-success"
                rclone_status="✅ Installed"
            fi
            
            cat >> "$report_file" << TR11
                    <tr>
                        <td class="pi-name">$name</td>
                        <td><span class="badge $rclone_badge">$rclone_installed</span></td>
                        <td>$rclone_status</td>
                    </tr>
TR11
        else
            cat >> "$report_file" << TR12
                    <tr>
                        <td class="pi-name">$name</td>
                        <td><span class="badge badge-danger">Offline</span></td>
                        <td>❌ Pi Offline</td>
                    </tr>
TR12
        fi
    done
    
    echo "                </tbody>" >> "$report_file"
    echo "            </table>" >> "$report_file"
    
    # ============================================
    # FOOTER
    # ============================================
    
    cat >> "$report_file" << FOOTER
        </div>
        <div class="footer">
            <p><strong>🎯 DOGMA Control Center</strong> | © $(date +%Y)</p>
            <p>Generated by:  $(whoami)@$(hostname)</p>
            <p>Report file: $(basename $report_file)</p>
        </div>
    </div>
</body>
</html>
FOOTER

    echo ""
    echo -e "${GREEN}✅ Báo cáo đã được tạo:  $report_file${NC}"
    echo ""
    echo -n "Mở báo cáo ngay?  (y/n): "
    read open_now
    
    if [ "$open_now" = "y" ]; then
        xdg-open "$report_file" 2>/dev/null || open "$report_file" 2>/dev/null || firefox "$report_file" 2>/dev/null || echo "Vui lòng mở file thủ công:  $report_file"
    fi
    
    echo ""
    read -p "Nhấn Enter để tiếp tục..."
}


main() {
    while true; do
        show_menu
        read choice
        
        case $choice in
            1) check_overview ;;
            2) check_stream ;;
            3) check_screenshot ;;
            4) check_wallpaper ;;
            5) check_connection ;;
            6) check_rclone ;;
            7) check_hardware ;;
            8) check_detailed_log ;;
            11) update_upgrade_all ;;
            12) reboot_all ;;
            12s) shutdown_all ;;
            13) update_wallpaper_all ;;
            14) restart_services ;;
            15) redeploy_scripts ;;
            16) backup_config ;;
            21) ssh_to_pi ;;
            22) export_report ;;
            0) 
                clear
                echo -e "${CYAN}👋 Cảm ơn đã sử dụng DOGMA Control Center!  ${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}Lựa chọn không hợp lệ!  ${NC}"
                sleep 2
                ;;
        esac
    done
}

# ============================================
# RUN
# ============================================

main
