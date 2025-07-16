#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}   Fix 'No Space Left on Device' Error Tool    ${NC}"
echo -e "${BLUE}            Kali Linux 2025.2                   ${NC}"
echo -e "${BLUE}================================================${NC}\n"
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[ERROR] Script ini harus dijalankan sebagai root!${NC}"
        echo -e "${YELLOW}Gunakan: sudo $0${NC}"
        exit 1
    fi
}
show_disk_info() {
    echo -e "${YELLOW}[INFO] Informasi Disk:${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"
    df -h
    echo -e "${BLUE}----------------------------------------${NC}\n"
}
show_inode_info() {
    echo -e "${YELLOW}[INFO] Informasi Inode:${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"
    df -i
    echo -e "${BLUE}----------------------------------------${NC}\n"
}
clean_temp_files() {
    echo -e "${YELLOW}[PROSES] Membersihkan file temporary...${NC}"
    echo -e "${GREEN}  → Membersihkan /tmp...${NC}"
    find /tmp -type f -atime +7 -delete 2>/dev/null
    find /tmp -type d -empty -delete 2>/dev/null
    echo -e "${GREEN}  → Membersihkan /var/tmp...${NC}"
    find /var/tmp -type f -atime +7 -delete 2>/dev/null
    find /var/tmp -type d -empty -delete 2>/dev/null
    echo -e "${GREEN}  → Membersihkan cache APT...${NC}"
    apt-get clean
    apt-get autoclean
    apt-get autoremove -y
    echo -e "${GREEN}[✓] Pembersihan file temporary selesai!${NC}\n"
}
clean_log_files() {
    echo -e "${YELLOW}[PROSES] Membersihkan file log...${NC}"
    echo -e "${GREEN}  → Membersihkan journal systemd...${NC}"
    journalctl --vacuum-time=3d
    journalctl --vacuum-size=100M
    echo -e "${GREEN}  → Membersihkan log lama...${NC}"
    find /var/log -type f -name "*.log" -mtime +30 -delete 2>/dev/null
    find /var/log -type f -name "*.gz" -mtime +30 -delete 2>/dev/null
    find /var/log -type f -name "*.old" -delete 2>/dev/null
    echo -e "${GREEN}  → Truncate file log besar...${NC}"
    for log in /var/log/*.log; do
        if [[ -f "$log" ]] && [[ $(stat -c%s "$log") -gt 104857600 ]]; then
            echo "    Truncating: $log"
            > "$log"
        fi
    done
    echo -e "${GREEN}[✓] Pembersihan file log selesai!${NC}\n"
}
find_large_files() {
    echo -e "${YELLOW}[INFO] Mencari 20 file terbesar...${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"
    find / -xdev -type f -size +100M -exec ls -lh {} \; 2>/dev/null | sort -k5 -rh | head -20
    echo -e "${BLUE}----------------------------------------${NC}\n"
}
clean_user_cache() {
    echo -e "${YELLOW}[PROSES] Membersihkan cache user...${NC}"
    for user_home in /home/*; do
        if [[ -d "$user_home" ]]; then
            username=$(basename "$user_home")
            echo -e "${GREEN}  → Membersihkan cache untuk user: $username${NC}"
            if [[ -d "$user_home/.cache" ]]; then
                rm -rf "$user_home/.cache/"* 2>/dev/null
            fi
            if [[ -d "$user_home/.thumbnails" ]]; then
                rm -rf "$user_home/.thumbnails/"* 2>/dev/null
            fi
            if [[ -d "$user_home/.local/share/Trash" ]]; then
                rm -rf "$user_home/.local/share/Trash/"* 2>/dev/null
            fi
        fi
    done
    echo -e "${GREEN}  → Membersihkan cache root${NC}"
    rm -rf /root/.cache/* 2>/dev/null
    rm -rf /root/.thumbnails/* 2>/dev/null
    echo -e "${GREEN}[✓] Pembersihan cache user selesai!${NC}\n"
}
fix_inode_issues() {
    echo -e "${YELLOW}[PROSES] Memeriksa masalah inode...${NC}"
    echo -e "${GREEN}  → Mencari direktori dengan banyak file...${NC}"
    echo -e "${BLUE}  Direktori dengan >1000 file:${NC}"
    for dir in /var /tmp /home /opt; do
        if [[ -d "$dir" ]]; then
            find "$dir" -xdev -type d -exec bash -c 'echo -n "{}: "; ls -1 "{}" 2>/dev/null | wc -l' \; 2>/dev/null | awk '$2 > 1000 {print $0}' | head -10
        fi
    done
    echo -e "${GREEN}  → Membersihkan file session lama...${NC}"
    find /var/lib/php/sessions -type f -mtime +7 -delete 2>/dev/null
    find /var/spool/mail -type f -size 0 -delete 2>/dev/null
    echo -e "${GREEN}[✓] Pemeriksaan inode selesai!${NC}\n"
}
clean_docker() {
    if command -v docker &> /dev/null; then
        echo -e "${YELLOW}[PROSES] Membersihkan Docker...${NC}"
        echo -e "${GREEN}  → Membersihkan container yang tidak digunakan...${NC}"
        docker container prune -f 2>/dev/null
        echo -e "${GREEN}  → Membersihkan image yang tidak digunakan...${NC}"
        docker image prune -a -f 2>/dev/null
        echo -e "${GREEN}  → Membersihkan volume yang tidak digunakan...${NC}"
        docker volume prune -f 2>/dev/null
        echo -e "${GREEN}  → Membersihkan network yang tidak digunakan...${NC}"
        docker network prune -f 2>/dev/null
        echo -e "${GREEN}[✓] Pembersihan Docker selesai!${NC}\n"
    fi
}
clean_snap() {
    if command -v snap &> /dev/null; then
        echo -e "${YELLOW}[PROSES] Membersihkan Snap packages lama...${NC}"
        snap list --all | awk '/disabled/{print $1, $3}' |
        while read snapname revision; do
            echo -e "${GREEN}  → Menghapus $snapname revision $revision${NC}"
            snap remove "$snapname" --revision="$revision"
        done
        echo -e "${GREEN}[✓] Pembersihan Snap selesai!${NC}\n"
    fi
}
show_summary() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${YELLOW}[SUMMARY] Status Setelah Pembersihan:${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo -e "\n${YELLOW}Disk Usage:${NC}"
    df -h | grep -E '^/dev/' | awk '{printf "  %-20s %5s / %-5s (%s)\n", $1, $3, $2, $5}'
    echo -e "\n${YELLOW}Inode Usage:${NC}"
    df -i | grep -E '^/dev/' | awk '{printf "  %-20s %s\n", $1, $5}'
    echo -e "${BLUE}================================================${NC}\n"
}
show_menu() {
    echo -e "${YELLOW}Pilih opsi pembersihan:${NC}"
    echo -e "${GREEN}1)${NC} Pembersihan Cepat (Recommended)"
    echo -e "${GREEN}2)${NC} Pembersihan Lengkap"
    echo -e "${GREEN}3)${NC} Analisis Saja"
    echo -e "${GREEN}4)${NC} Custom Pembersihan"
    echo -e "${GREEN}5)${NC} Keluar"
    echo -n "Pilihan Anda [1-5]: "
}
quick_clean() {
    clean_temp_files
    clean_log_files
    clean_user_cache
}
full_clean() {
    clean_temp_files
    clean_log_files
    clean_user_cache
    fix_inode_issues
    clean_docker
    clean_snap
}
analyze_only() {
    show_disk_info
    show_inode_info
    find_large_files
}
custom_clean() {
    echo -e "\n${YELLOW}Pilih pembersihan yang ingin dilakukan:${NC}"
    echo -e "${GREEN}1)${NC} Bersihkan file temporary"
    echo -e "${GREEN}2)${NC} Bersihkan file log"
    echo -e "${GREEN}3)${NC} Bersihkan cache user"
    echo -e "${GREEN}4)${NC} Perbaiki masalah inode"
    echo -e "${GREEN}5)${NC} Bersihkan Docker"
    echo -e "${GREEN}6)${NC} Bersihkan Snap"
    echo -e "${GREEN}7)${NC} Kembali ke menu utama"
    echo -n "Pilihan Anda (bisa multiple, contoh: 1,2,3): "
    read -r choices
    IFS=',' read -ra ADDR <<< "$choices"
    for choice in "${ADDR[@]}"; do
        case $choice in
            1) clean_temp_files ;;
            2) clean_log_files ;;
            3) clean_user_cache ;;
            4) fix_inode_issues ;;
            5) clean_docker ;;
            6) clean_snap ;;
            7) return ;;
            *) echo -e "${RED}Pilihan tidak valid: $choice${NC}" ;;
        esac
    done
}
main() {
    check_root
    while true; do
        show_menu
        read -r choice
        case $choice in
            1)
                echo -e "\n${YELLOW}[START] Memulai Pembersihan Cepat...${NC}\n"
                analyze_only
                quick_clean
                show_summary
                ;;
            2)
                echo -e "\n${YELLOW}[START] Memulai Pembersihan Lengkap...${NC}\n"
                analyze_only
                full_clean
                show_summary
                ;;
            3)
                echo -e "\n${YELLOW}[START] Memulai Analisis...${NC}\n"
                analyze_only
                ;;
            4)
                echo -e "\n${YELLOW}[START] Custom Pembersihan...${NC}\n"
                custom_clean
                show_summary
                ;;
            5)
                echo -e "\n${GREEN}Terima kasih telah menggunakan tool ini!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Pilihan tidak valid!${NC}\n"
                ;;
        esac
        echo -n -e "\n${YELLOW}Tekan Enter untuk melanjutkan...${NC}"
        read -r
        clear
        echo -e "${BLUE}================================================${NC}"
        echo -e "${BLUE}   Fix 'No Space Left on Device' Error Tool    ${NC}"
        echo -e "${BLUE}            Kali Linux 2025.2                   ${NC}"
        echo -e "${BLUE}================================================${NC}\n"
    done
}
main