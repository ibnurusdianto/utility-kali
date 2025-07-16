#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   Kali Linux OOM Killer Fix Script              ${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[ERROR] Script ini harus dijalankan sebagai root!${NC}"
        echo -e "${YELLOW}Gunakan: sudo bash $0${NC}"
        exit 1
    fi
}
backup_config() {
    local file=$1
    if [[ -f "$file" ]]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${GREEN}[OK] Backup dibuat untuk: $file${NC}"
    fi
}
show_memory_info() {
    echo -e "${YELLOW}=== Informasi Memory Saat Ini ===${NC}"
    free -h
    echo ""
    echo -e "${YELLOW}=== Swap Information ===${NC}"
    swapon --show
    echo ""
}
create_swap() {
    echo -e "${BLUE}[INFO] Membuat swap file...${NC}"
    if [[ $(swapon --show | wc -l) -gt 0 ]]; then
        echo -e "${YELLOW}[WARNING] Swap sudah aktif. Skip pembuatan swap baru.${NC}"
        return
    fi
    SWAP_SIZE="4G"
    SWAP_FILE="/swapfile"
    echo -e "${BLUE}[INFO] Membuat swap file ukuran $SWAP_SIZE...${NC}"
    fallocate -l $SWAP_SIZE $SWAP_FILE
    chmod 600 $SWAP_FILE
    mkswap $SWAP_FILE
    swapon $SWAP_FILE
    if ! grep -q "$SWAP_FILE" /etc/fstab; then
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
        echo -e "${GREEN}[OK] Swap file ditambahkan ke /etc/fstab${NC}"
    fi
    echo -e "${GREEN}[OK] Swap file berhasil dibuat dan diaktifkan${NC}"
}
optimize_swappiness() {
    echo -e "${BLUE}[INFO] Mengoptimalkan swappiness...${NC}"
    backup_config "/etc/sysctl.conf"
    echo "vm.swappiness=10" >> /etc/sysctl.conf
    echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
    sysctl -p
    echo -e "${GREEN}[OK] Swappiness dioptimalkan${NC}"
}
configure_oom_killer() {
    echo -e "${BLUE}[INFO] Mengkonfigurasi OOM Killer...${NC}"
    echo "vm.oom_kill_allocating_task=0" >> /etc/sysctl.conf
    echo "vm.panic_on_oom=0" >> /etc/sysctl.conf
    echo "vm.overcommit_memory=1" >> /etc/sysctl.conf
    echo "vm.overcommit_ratio=80" >> /etc/sysctl.conf
    sysctl -p
    echo -e "${GREEN}[OK] OOM Killer dikonfigurasi${NC}"
}
clear_memory_cache() {
    echo -e "${BLUE}[INFO] Membersihkan cache memory...${NC}"
    sync
    echo 3 > /proc/sys/vm/drop_caches
    echo -e "${GREEN}[OK] Cache memory dibersihkan${NC}"
}
disable_unnecessary_services() {
    echo -e "${BLUE}[INFO] Menonaktifkan service yang tidak perlu...${NC}"
    SERVICES=(
        "bluetooth.service"
        "cups.service"
        "cups-browsed.service"
        "avahi-daemon.service"
        "ModemManager.service"
    )
    for service in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$service"; then
            systemctl stop "$service"
            systemctl disable "$service"
            echo -e "${GREEN}[OK] Disabled: $service${NC}"
        fi
    done
}
create_memory_monitor() {
    echo -e "${BLUE}[INFO] Membuat script monitoring memory...${NC}"
    cat > /usr/local/bin/memory_monitor.sh << 'EOF'
#!/bin/bash

# Memory threshold (dalam persen)
THRESHOLD=85

while true; do
    # Get memory usage percentage
    MEMORY_USAGE=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
    
    if [ $MEMORY_USAGE -gt $THRESHOLD ]; then
        echo "[WARNING] Memory usage is at ${MEMORY_USAGE}%"
        
        # Clear cache if memory usage is high
        sync
        echo 3 > /proc/sys/vm/drop_caches
        
        # Kill process yang menggunakan memory terbanyak (optional)
        # ps aux --sort=-%mem | head -n 5
    fi
    
    sleep 60
done
EOF
    chmod +x /usr/local/bin/memory_monitor.sh
    cat > /etc/systemd/system/memory-monitor.service << EOF
[Unit]
Description=Memory Monitor Service
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/memory_monitor.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable memory-monitor.service
    systemctl start memory-monitor.service
    echo -e "${GREEN}[OK] Memory monitor service dibuat dan diaktifkan${NC}"
}
optimize_zsh() {
    echo -e "${BLUE}[INFO] Mengoptimalkan ZSH...${NC}"
    if [[ -f ~/.zshrc ]]; then
        backup_config ~/.zshrc
        echo "HISTSIZE=1000" >> ~/.zshrc
        echo "SAVEHIST=1000" >> ~/.zshrc
    fi
    if [[ -f ~/.zshrc ]]; then
        sed -i 's/plugins=(.*)/plugins=(git sudo)/' ~/.zshrc
    fi
    echo -e "${GREEN}[OK] ZSH dioptimalkan${NC}"
}
create_helpful_aliases() {
    echo -e "${BLUE}[INFO] Membuat alias untuk monitoring...${NC}"
    cat >> ~/.bashrc << 'EOF'

# Memory monitoring aliases
alias meminfo='free -h'
alias memtop='ps aux --sort=-%mem | head -20'
alias clearcache='sudo sync && sudo echo 3 > /proc/sys/vm/drop_caches'
alias swapinfo='swapon --show'
EOF
    if [[ -f ~/.zshrc ]]; then
        cat >> ~/.zshrc << 'EOF'

# Memory monitoring aliases
alias meminfo='free -h'
alias memtop='ps aux --sort=-%mem | head -20'
alias clearcache='sudo sync && sudo echo 3 > /proc/sys/vm/drop_caches'
alias swapinfo='swapon --show'
EOF
    fi
    echo -e "${GREEN}[OK] Aliases dibuat${NC}"
}
main() {
    check_root
    echo -e "${YELLOW}Script ini akan melakukan:${NC}"
    echo "1. Membuat swap file (4GB)"
    echo "2. Mengoptimalkan swappiness"
    echo "3. Mengkonfigurasi OOM Killer"
    echo "4. Membersihkan cache memory"
    echo "5. Menonaktifkan service yang tidak perlu"
    echo "6. Membuat memory monitor service"
    echo "7. Mengoptimalkan ZSH"
    echo "8. Membuat helpful aliases"
    echo ""
    read -p "Lanjutkan? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}[INFO] Script dibatalkan${NC}"
        exit 0
    fi
    echo ""
    show_memory_info
    create_swap
    optimize_swappiness
    configure_oom_killer
    clear_memory_cache
    disable_unnecessary_services
    create_memory_monitor
    optimize_zsh
    create_helpful_aliases
    echo ""
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}   Optimasi Selesai!                           ${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    show_memory_info
    echo -e "${YELLOW}Tips tambahan:${NC}"
    echo "1. Restart sistem untuk memastikan semua perubahan aktif"
    echo "2. Gunakan 'meminfo' untuk cek memory"
    echo "3. Gunakan 'memtop' untuk melihat proses yang menggunakan memory terbanyak"
    echo "4. Gunakan 'clearcache' untuk membersihkan cache jika diperlukan"
    echo "5. Pertimbangkan untuk menambah RAM VM menjadi 4GB jika memungkinkan"
    echo ""
    echo -e "${BLUE}Reboot sekarang? (y/n):${NC} "
    read -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        reboot
    fi
}
main