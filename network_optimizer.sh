#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[!] This script must be run as root${NC}"
        exit 1
    fi
}
show_banner() {
    clear
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║         KALI LINUX NETWORK OPTIMIZER                  ║"
    echo "║         Optimized for VMware Environment              ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}
backup_settings() {
    echo -e "${YELLOW}[*] Creating backup of current settings...${NC}"
    BACKUP_DIR="/root/network_optimizer_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    cp /etc/sysctl.conf "$BACKUP_DIR/sysctl.conf.bak" 2>/dev/null
    cp /etc/network/interfaces "$BACKUP_DIR/interfaces.bak" 2>/dev/null
    sysctl -a | grep -E "net\.|vm\." > "$BACKUP_DIR/current_sysctl_network.txt" 2>/dev/null
    echo -e "${GREEN}[✓] Backup created at: $BACKUP_DIR${NC}"
}
optimize_tcp_stack() {
    echo -e "${YELLOW}[*] Optimizing TCP/IP Stack...${NC}"
    cat >> /etc/sysctl.conf << EOF

# Network Optimizer for Kali Linux - TCP/IP Stack Optimization
# Added on $(date)

# Core network settings
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.rmem_default = 256960
net.core.wmem_default = 256960
net.core.optmem_max = 40960
net.core.netdev_max_backlog = 5000

# TCP settings
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = 2
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15

# Enable TCP Fast Open
net.ipv4.tcp_fastopen = 3

# Increase the maximum number of connections
net.core.somaxconn = 1024
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15

# UDP optimizations
net.core.netdev_budget = 600
net.core.netdev_budget_usecs = 20000

EOF
    sysctl -p > /dev/null 2>&1
    echo -e "${GREEN}[✓] TCP/IP Stack optimized${NC}"
}
optimize_vmware() {
    echo -e "${YELLOW}[*] Optimizing for VMware environment...${NC}"
    cat >> /etc/sysctl.conf << EOF

# VMware Specific Optimizations
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5

# Disable IPv6 if not needed (improves performance)
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1

EOF
    if command -v vmware-toolbox-cmd &> /dev/null; then
        echo -e "${GREEN}[✓] VMware Tools detected, enabling optimizations${NC}"
        vmware-toolbox-cmd timesync enable > /dev/null 2>&1
    fi
    echo -e "${GREEN}[✓] VMware optimizations applied${NC}"
}
optimize_network_interface() {
    echo -e "${YELLOW}[*] Optimizing network interfaces...${NC}"
    PRIMARY_IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [ -z "$PRIMARY_IFACE" ]; then
        echo -e "${RED}[!] No primary network interface found${NC}"
        return
    fi
    echo -e "${BLUE}[i] Primary interface detected: $PRIMARY_IFACE${NC}"
    ethtool -K "$PRIMARY_IFACE" rx on tx on sg on tso on gso on gro on lro on 2>/dev/null
    ethtool -G "$PRIMARY_IFACE" rx 4096 tx 4096 2>/dev/null
    ip link set dev "$PRIMARY_IFACE" mtu 1500 2>/dev/null
    echo -e "${GREEN}[✓] Network interface optimized${NC}"
}
optimize_dns() {
    echo -e "${YELLOW}[*] Optimizing DNS settings...${NC}"
    cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null
    cat > /etc/resolv.conf << EOF
# Optimized DNS Configuration
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 1.0.0.1
nameserver 8.8.4.4
options timeout:2 attempts:3 rotate
EOF
    chattr +i /etc/resolv.conf 2>/dev/null
    echo -e "${GREEN}[✓] DNS settings optimized${NC}"
}
install_performance_tools() {
    echo -e "${YELLOW}[*] Installing performance monitoring tools...${NC}"
    apt-get update -qq
    TOOLS="iftop nethogs bmon nload speedtest-cli mtr-tiny tcpdump"
    for tool in $TOOLS; do
        if ! command -v $tool &> /dev/null; then
            echo -e "${BLUE}[i] Installing $tool...${NC}"
            apt-get install -y -qq $tool
        fi
    done
    echo -e "${GREEN}[✓] Performance tools installed${NC}"
}
create_monitor_script() {
    echo -e "${YELLOW}[*] Creating network monitoring script...${NC}"
    cat > /usr/local/bin/netmon << 'EOF'
#!/bin/bash
# Network Monitor for Kali Linux

clear
echo "=== NETWORK MONITOR ==="
echo "1. Real-time bandwidth (iftop)"
echo "2. Process network usage (nethogs)"
echo "3. Network statistics (bmon)"
echo "4. Speed test"
echo "5. Network diagnostics (mtr)"
echo "6. Exit"

read -p "Select option: " choice

case $choice in
    1) sudo iftop ;;
    2) sudo nethogs ;;
    3) bmon ;;
    4) speedtest-cli ;;
    5) read -p "Enter target host: " host && mtr "$host" ;;
    6) exit ;;
    *) echo "Invalid option" ;;
esac
EOF
    chmod +x /usr/local/bin/netmon
    echo -e "${GREEN}[✓] Network monitor script created (run: netmon)${NC}"
}
optimize_firewall() {
    echo -e "${YELLOW}[*] Optimizing firewall settings...${NC}"
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F
    iptables -X
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables-save > /etc/iptables/rules.v4 2>/dev/null
    echo -e "${GREEN}[✓] Firewall optimized${NC}"
}
run_performance_test() {
    echo -e "${YELLOW}[*] Running network performance test...${NC}"
    echo -e "${BLUE}[i] Testing connectivity...${NC}"
    if ping -c 3 google.com > /dev/null 2>&1; then
        echo -e "${GREEN}[✓] Internet connectivity: OK${NC}"
    else
        echo -e "${RED}[!] Internet connectivity: FAILED${NC}"
    fi
    echo -e "${BLUE}[i] Current network configuration:${NC}"
    ip addr show | grep -E "inet |link/ether" | grep -v "127.0.0.1"
    echo -e "${BLUE}[i] Testing DNS resolution...${NC}"
    if nslookup google.com > /dev/null 2>&1; then
        echo -e "${GREEN}[✓] DNS resolution: OK${NC}"
    else
        echo -e "${RED}[!] DNS resolution: FAILED${NC}"
    fi
}
main_menu() {
    while true; do
        show_banner
        echo -e "${YELLOW}Select optimization options:${NC}"
        echo "1. Full optimization (Recommended)"
        echo "2. TCP/IP Stack optimization only"
        echo "3. VMware specific optimization only"
        echo "4. Network interface optimization only"
        echo "5. DNS optimization only"
        echo "6. Install performance tools"
        echo "7. Run performance test"
        echo "8. Restore default settings"
        echo "9. Exit"
        echo
        read -p "Enter your choice [1-9]: " choice
        case $choice in
            1)
                backup_settings
                optimize_tcp_stack
                optimize_vmware
                optimize_network_interface
                optimize_dns
                optimize_firewall
                install_performance_tools
                create_monitor_script
                run_performance_test
                echo -e "${GREEN}[✓] Full optimization completed!${NC}"
                echo -e "${YELLOW}[!] Please reboot for all changes to take effect${NC}"
                read -p "Press Enter to continue..."
                ;;
            2)
                backup_settings
                optimize_tcp_stack
                read -p "Press Enter to continue..."
                ;;
            3)
                backup_settings
                optimize_vmware
                read -p "Press Enter to continue..."
                ;;
            4)
                optimize_network_interface
                read -p "Press Enter to continue..."
                ;;
            5)
                optimize_dns
                read -p "Press Enter to continue..."
                ;;
            6)
                install_performance_tools
                create_monitor_script
                read -p "Press Enter to continue..."
                ;;
            7)
                run_performance_test
                read -p "Press Enter to continue..."
                ;;
            8)
                echo -e "${YELLOW}[*] This will restore default settings${NC}"
                read -p "Are you sure? (y/n): " confirm
                if [[ $confirm == "y" ]]; then
                    sed -i '/# Network Optimizer for Kali Linux/,/^$/d' /etc/sysctl.conf
                    sed -i '/# VMware Specific Optimizations/,/^$/d' /etc/sysctl.conf
                    sysctl -p > /dev/null 2>&1
                    chattr -i /etc/resolv.conf 2>/dev/null
                    if [ -f /etc/resolv.conf.bak ]; then
                        cp /etc/resolv.conf.bak /etc/resolv.conf
                    fi
                    echo -e "${GREEN}[✓] Default settings restored${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            9)
                echo -e "${GREEN}[✓] Exiting...${NC}"
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