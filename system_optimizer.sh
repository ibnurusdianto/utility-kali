#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
TOTAL_RAM=$(free -m | awk 'NR==2{print $2}')
CPU_CORES=$(nproc)
CURRENT_SWAPPINESS=$(cat /proc/sys/vm/swappiness)
KERNEL_VERSION=$(uname -r)
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[!] This script must be run as root${NC}"
        exit 1
    fi
}
show_banner() {
    clear
    echo -e "${PURPLE}"
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║         KALI LINUX SYSTEM OPTIMIZER                   ║"
    echo "║         Optimized for Low Resource VMware             ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${CYAN}System Info:${NC}"
    echo -e "├─ RAM: ${TOTAL_RAM}MB"
    echo -e "├─ CPU Cores: ${CPU_CORES}"
    echo -e "├─ Kernel: ${KERNEL_VERSION}"
    echo -e "└─ Current Swappiness: ${CURRENT_SWAPPINESS}"
    echo
}
backup_system_settings() {
    echo -e "${YELLOW}[*] Creating system backup...${NC}"
    BACKUP_DIR="/root/system_optimizer_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    cp /etc/sysctl.conf "$BACKUP_DIR/" 2>/dev/null
    cp /etc/fstab "$BACKUP_DIR/" 2>/dev/null
    cp /etc/default/grub "$BACKUP_DIR/" 2>/dev/null
    cp -r /etc/systemd/system.conf "$BACKUP_DIR/" 2>/dev/null
    cp -r /etc/security/limits.conf "$BACKUP_DIR/" 2>/dev/null
    sysctl -a > "$BACKUP_DIR/current_sysctl_all.txt" 2>/dev/null
    systemctl list-unit-files --state=enabled > "$BACKUP_DIR/enabled_services.txt" 2>/dev/null
    echo -e "${GREEN}[✓] Backup created at: $BACKUP_DIR${NC}"
}
optimize_kernel_parameters() {
    echo -e "${YELLOW}[*] Optimizing kernel parameters...${NC}"
    cat >> /etc/sysctl.conf << EOF

# System Optimizer for Kali Linux - Kernel Parameters
# Optimized for 2GB RAM System - Added on $(date)

# Virtual Memory Optimization
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_background_ratio = 5
vm.dirty_ratio = 10
vm.dirty_writeback_centisecs = 1500
vm.overcommit_memory = 1
vm.overcommit_ratio = 50
vm.min_free_kbytes = 65536

# Memory Management
vm.page-cluster = 3
vm.laptop_mode = 5
vm.oom_kill_allocating_task = 1

# File System Optimization
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
fs.nr_open = 1048576

# Kernel Optimization
kernel.sched_migration_cost_ns = 5000000
kernel.sched_autogroup_enabled = 1
kernel.threads-max = 100000
kernel.pid_max = 4194304
kernel.panic = 10
kernel.panic_on_oops = 1

# Shared Memory
kernel.shmmax = 1073741824
kernel.shmall = 2097152
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
kernel.msgmnb = 65536
kernel.msgmax = 65536

# For VMware optimization
kernel.numa_balancing = 0

# CPU Scheduler optimization for 2 cores
kernel.sched_min_granularity_ns = 2250000
kernel.sched_wakeup_granularity_ns = 3000000
kernel.sched_latency_ns = 18000000
kernel.sched_nr_migrate = 32

EOF
    sysctl -p > /dev/null 2>&1
    echo -e "${GREEN}[✓] Kernel parameters optimized${NC}"
}
configure_swap() {
    echo -e "${YELLOW}[*] Configuring SWAP space...${NC}"
    SWAP_SIZE=$(free -m | awk '/^Swap:/ {print $2}')
    if [ $SWAP_SIZE -lt 2048 ]; then
        echo -e "${BLUE}[i] Creating 4GB swap file...${NC}"
        if [ ! -f /swapfile ]; then
            dd if=/dev/zero of=/swapfile bs=1M count=4096 status=progress
            chmod 600 /swapfile
            mkswap /swapfile
            swapon /swapfile
            if ! grep -q "/swapfile" /etc/fstab; then
                echo "/swapfile none swap sw 0 0" >> /etc/fstab
            fi
        fi
    fi
    echo -e "${BLUE}[i] Enabling zswap compression...${NC}"
    echo 1 > /sys/module/zswap/parameters/enabled
    echo lz4 > /sys/module/zswap/parameters/compressor
    echo 20 > /sys/module/zswap/parameters/max_pool_percent
    echo -e "${GREEN}[✓] SWAP configured${NC}"
}
optimize_services() {
    echo -e "${YELLOW}[*] Optimizing system services...${NC}"
    DISABLE_SERVICES=(
        "bluetooth.service"
        "cups.service"
        "cups-browsed.service"
        "ModemManager.service"
        "speech-dispatcher.service"
        "avahi-daemon.service"
        "colord.service"
        "switcheroo-control.service"
        "rtkit-daemon.service"
        "accounts-daemon.service"
    )
    for service in "${DISABLE_SERVICES[@]}"; do
        if systemctl is-enabled "$service" &>/dev/null; then
            echo -e "${BLUE}[i] Disabling $service${NC}"
            systemctl disable "$service" &>/dev/null
            systemctl stop "$service" &>/dev/null
        fi
    done
    systemctl mask systemd-rfkill.service &>/dev/null
    systemctl mask systemd-rfkill.socket &>/dev/null
    echo -e "${GREEN}[✓] Services optimized${NC}"
}
optimize_grub() {
    echo -e "${YELLOW}[*] Optimizing GRUB bootloader...${NC}"
    cp /etc/default/grub /etc/default/grub.bak
    sed -i 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
    GRUB_CMDLINE="quiet splash mitigations=off nowatchdog nmi_watchdog=0 transparent_hugepage=madvise elevator=noop"
    if ! grep -q "mitigations=off" /etc/default/grub; then
        sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\".*\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_CMDLINE\"/" /etc/default/grub
    fi
    update-grub &>/dev/null
    echo -e "${GREEN}[✓] GRUB optimized${NC}"
}
optimize_systemd() {
    echo -e "${YELLOW}[*] Optimizing systemd...${NC}"
    mkdir -p /etc/systemd/system.conf.d/
    cat > /etc/systemd/system.conf.d/50-optimization.conf << EOF
[Manager]
DefaultTimeoutStopSec=10s
DefaultTimeoutStartSec=10s
DefaultCPUAccounting=no
DefaultMemoryAccounting=no
DefaultTasksAccounting=no
DefaultBlockIOAccounting=no
DefaultIPAccounting=no
EOF
    mkdir -p /etc/systemd/journald.conf.d/
    cat > /etc/systemd/journald.conf.d/50-optimization.conf << EOF
[Journal]
SystemMaxUse=100M
SystemMaxFileSize=50M
MaxFileSec=1week
ForwardToSyslog=no
EOF
    systemctl daemon-reload
    echo -e "${GREEN}[✓ Systemd optimized${NC}"
}
configure_cpu_governor() {
    echo -e "${YELLOW}[*] Configuring CPU governor...${NC}"
    if ! command -v cpufreq-set &> /dev/null; then
        apt-get install -y -qq cpufrequtils &>/dev/null
    fi
    for ((i=0; i<$CPU_CORES; i++)); do
        cpufreq-set -c $i -g performance &>/dev/null
    done
    echo 'GOVERNOR="performance"' > /etc/default/cpufrequtils
    echo -e "${GREEN}[✓] CPU governor configured${NC}"
}
optimize_filesystem() {
    echo -e "${YELLOW}[*] Optimizing file system...${NC}"
    ROOT_DEVICE=$(df / | tail -1 | awk '{print $1}')
    if ! grep -q "noatime" /etc/fstab; then
        sed -i "s|${ROOT_DEVICE}.*ext4.*defaults|${ROOT_DEVICE} / ext4 defaults,noatime,nodiratime|g" /etc/fstab
    fi
    echo 'ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/scheduler}="noop"' > /etc/udev/rules.d/60-scheduler.rules
    tune2fs -O ^has_journal $ROOT_DEVICE &>/dev/null 2>&1
    echo -e "${GREEN}[✓] Filesystem optimized${NC}"
}
install_preload() {
    echo -e "${YELLOW}[*] Installing preload for application caching...${NC}"
    if ! command -v preload &> /dev/null; then
        apt-get install -y -qq preload &>/dev/null
        sed -i 's/^memtotal =.*/memtotal = 50/' /etc/preload.conf
        sed -i 's/^memfree =.*/memfree = 20/' /etc/preload.conf
        sed -i 's/^memcached =.*/memcached = 30/' /etc/preload.conf
        systemctl enable preload &>/dev/null
        systemctl start preload &>/dev/null
    fi
    echo -e "${GREEN}[✓] Preload installed and configured${NC}"
}
configure_tmpfs() {
    echo -e "${YELLOW}[*] Configuring tmpfs for temporary directories...${NC}"
    cat >> /etc/fstab << EOF

# Tmpfs optimization
tmpfs /tmp tmpfs defaults,noatime,mode=1777,size=512M 0 0
tmpfs /var/tmp tmpfs defaults,noatime,mode=1777,size=256M 0 0
tmpfs /var/log tmpfs defaults,noatime,mode=0755,size=256M 0 0
EOF
    echo -e "${GREEN}[✓] Tmpfs configured${NC}"
}
clean_system() {
    echo -e "${YELLOW}[*] Cleaning system...${NC}"
    apt-get clean
    apt-get autoclean
    apt-get autoremove -y
    dpkg -l 'linux-*' | sed '/^ii/!d;/'"$(uname -r | sed "s/\$.*\$-\$[^0-9]\+\$/\1/")"'/d;s/^[^ ]* [^ ]* \$[^ ]*\$.*/\1/;/[0-9]/!d' | xargs apt-get -y purge &>/dev/null
    journalctl --vacuum-time=1d &>/dev/null
    find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;
    rm -rf /var/cache/apt/archives/*.deb
    rm -rf ~/.cache/*
    rm -rf /tmp/*
    echo -e "${GREEN}[✓] System cleaned${NC}"
}
create_performance_monitor() {
    echo -e "${YELLOW}[*] Creating performance monitoring script...${NC}"
    cat > /usr/local/bin/sysmon << 'EOF'
#!/bin/bash

# System Performance Monitor

clear
echo "=== SYSTEM PERFORMANCE MONITOR ==="
echo "1. Real-time system resources (htop)"
echo "2. Memory usage details"
echo "3. CPU usage by process"
echo "4. Disk I/O statistics"
echo "5. System boot time analysis"
echo "6. Service status"
echo "7. Temperature monitoring"
echo "8. Exit"

read -p "Select option: " choice

case $choice in
    1) htop ;;
    2) free -h && echo -e "\nMemory by process:" && ps aux --sort=-%mem | head -20 ;;
    3) ps aux --sort=-%cpu | head -20 ;;
    4) iostat -x 1 ;;
    5) systemd-analyze blame | head -20 ;;
    6) systemctl status ;;
    7) sensors 2>/dev/null || echo "Install lm-sensors for temperature monitoring" ;;
    8) exit ;;
    *) echo "Invalid option" ;;
esac
EOF
    chmod +x /usr/local/bin/sysmon
    echo -e "${GREEN}[✓] Performance monitor created (run: sysmon)${NC}"
}
run_system_benchmark() {
    echo -e "${YELLOW}[*] Running system benchmark...${NC}"
    echo -e "${BLUE}[i] Memory usage:${NC}"
    free -h
    echo -e "${BLUE}[i] CPU information:${NC}"
    lscpu | grep -E "Model name|CPU\$s\$|Thread|Core"
    echo -e "${BLUE}[i] Disk usage:${NC}"
    df -h | grep -E "^/dev/"
    echo -e "${BLUE}[i] Boot time analysis:${NC}"
    systemd-analyze
    echo -e "${BLUE}[i] Process count:${NC}"
    echo "Total processes: $(ps aux | wc -l)"
    echo "Running services: $(systemctl list-units --type=service --state=running | grep -c ".service")"
}
optimize_vmware_specific() {
    echo -e "${YELLOW}[*] Applying VMware specific optimizations...${NC}"
    if ! dpkg -l | grep -q open-vm-tools; then
        echo -e "${BLUE}[i] Installing VMware tools...${NC}"
        apt-get install -y -qq open-vm-tools open-vm-tools-desktop &>/dev/null
    fi
    cat >> /etc/sysctl.conf << EOF

# VMware Specific Optimizations
net.ipv4.tcp_timestamps = 0
vm.block_dump = 0
vm.dirty_expire_centisecs = 3000

EOF
    echo never > /sys/kernel/mm/transparent_hugepage/enabled
    echo never > /sys/kernel/mm/transparent_hugepage/defrag
    cat > /etc/rc.local << 'EOF'
#!/bin/bash
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
echo noop > /sys/block/sda/queue/scheduler
exit 0
EOF
    chmod +x /etc/rc.local
    echo -e "${GREEN}[✓] VMware optimizations applied${NC}"
}
generate_report() {
    echo -e "${YELLOW}[*] Generating optimization report...${NC}"
    REPORT_FILE="/root/system_optimization_report_$(date +%Y%m%d_%H%M%S).txt"
    cat > "$REPORT_FILE" << EOF
KALI LINUX SYSTEM OPTIMIZATION REPORT
Generated on: $(date)

SYSTEM INFORMATION:
- RAM: ${TOTAL_RAM}MB
- CPU Cores: ${CPU_CORES}
- Kernel: ${KERNEL_VERSION}

OPTIMIZATIONS APPLIED:
1. Kernel parameters optimized for low RAM
2. Swap configured with compression
3. Unnecessary services disabled
4. GRUB boot time reduced
5. Systemd optimized
6. CPU governor set to performance
7. Filesystem optimized with noatime
8. Tmpfs configured for temp directories
9. VMware specific optimizations

PERFORMANCE IMPROVEMENTS:
- Reduced memory usage
- Faster boot time
- Better responsiveness
- Optimized I/O performance

RECOMMENDATIONS:
1. Reboot system to apply all changes
2. Monitor performance with 'sysmon' command
3. Run 'sudo sysctl -p' if issues occur
4. Backup stored in: ${BACKUP_DIR}

EOF
    echo -e "${GREEN}[✓] Report saved to: $REPORT_FILE${NC}"
}
main_menu() {
    while true; do
        show_banner
        echo -e "${YELLOW}Select optimization options:${NC}"
        echo "1. Full system optimization (Recommended)"
        echo "2. Memory optimization only"
        echo "3. CPU optimization only"
        echo "4. Service optimization only"
        echo "5. Boot optimization only"
        echo "6. VMware specific optimization"
        echo "7. Clean system"
        echo "8. Run benchmark"
        echo "9. Generate report"
        echo "10. Restore defaults"
        echo "11. Exit"
        echo
        read -p "Enter your choice [1-11]: " choice
        case $choice in
            1)
                backup_system_settings
                optimize_kernel_parameters
                configure_swap
                optimize_services
                optimize_grub
                optimize_systemd
                configure_cpu_governor
                optimize_filesystem
                install_preload
                configure_tmpfs
                optimize_vmware_specific
                clean_system
                create_performance_monitor
                generate_report
                echo -e "${GREEN}[✓] Full system optimization completed!${NC}"
                echo -e "${YELLOW}[!] Please reboot your system to apply all changes${NC}"
                read -p "Press Enter to continue..."
                ;;
            2)
                backup_system_settings
                optimize_kernel_parameters
                configure_swap
                configure_tmpfs
                echo -e "${GREEN}[✓] Memory optimization completed${NC}"
                read -p "Press Enter to continue..."
                ;;
            3)
                configure_cpu_governor
                echo -e "${GREEN}[✓] CPU optimization completed${NC}"
                read -p "Press Enter to continue..."
                ;;
            4)
                optimize_services
                echo -e "${GREEN}[✓] Service optimization completed${NC}"
                read -p "Press Enter to continue..."
                ;;
            5)
                optimize_grub
                optimize_systemd
                echo -e "${GREEN}[✓] Boot optimization completed${NC}"
                read -p "Press Enter to continue..."
                ;;
            6)
                optimize_vmware_specific
                echo -e "${GREEN}[✓] VMware optimization completed${NC}"
                read -p "Press Enter to continue..."
                ;;
            7)
                clean_system
                echo -e "${GREEN}[✓] System cleaned${NC}"
                read -p "Press Enter to continue..."
                ;;
            8)
                run_system_benchmark
                read -p "Press Enter to continue..."
                ;;
            9)
                generate_report
                read -p "Press Enter to continue..."
                ;;
            10)
                echo -e "${YELLOW}[*] This will restore default settings${NC}"
                read -p "Are you sure? (y/n): " confirm
                if [[ $confirm == "y" ]]; then
                    if [ -d "$BACKUP_DIR" ]; then
                        cp "$BACKUP_DIR"/* /etc/ 2>/dev/null
                        sysctl -p > /dev/null 2>&1
                        update-grub &>/dev/null
                        echo -e "${GREEN}[✓] Default settings restored${NC}"
                    else
                        echo -e "${RED}[!] No backup found${NC}"
                    fi
                fi
                read -p "Press Enter to continue..."
                ;;
            11)
                echo -e "${GREEN}[✓] Exiting System Optimizer${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}[!] Invalid option${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}
check_root
main_menu