#!/bin/sh
# JioFi 4 AP+STA Wi-Fi Repeater Startup Script
# Created by Antigravity AI

echo "=== Starting JioFi Wi-Fi Repeater ==="

# 1. Redirect blocking /dev/random to non-blocking /dev/urandom (resolves hostapd entropy drops)
echo "[*] Redirecting /dev/random to /dev/urandom..."
rm -f /dev/random
ln -sf /dev/urandom /dev/random

# 2. Reload the custom offset-aligned concurrent driver (disabling power management)
echo "[*] Loading driver module..."
rmmod rtl8189es 2>/dev/null
insmod /data/rtl8189es-custom.ko rtw_power_mgnt=0 rtw_ips_mode=0

# 2. Wait for interfaces to register in sysfs
sleep 2

# 3. Bring wlan interfaces up
echo "[*] Bringing interfaces up..."
ifconfig wlan0 up
ifconfig wlan1 up

# 4. Connect to upstream Wi-Fi AP using wpa_supplicant
echo "[*] Starting wpa_supplicant..."
killall wpa_supplicant 2>/dev/null
wpa_supplicant -B -i wlan0 -c /data/wpa_supplicant.conf

# 5. Wait for wlan0 association
echo "[*] Waiting for association to complete..."
sleep 5

# 6. Configure wlan0 IP address and default gateway
echo "[*] Setting IP and routing rules..."
ifconfig wlan0 192.168.1.101 netmask 255.255.255.0
route add default gw 192.168.1.1 wlan0

# 7. Start hotspot Access Point on wlan1
echo "[*] Starting hostapd hotspot..."
killall hostapd 2>/dev/null
hostapd -B /data/hostapd.conf

# 8. Set up IP and secondary DHCP server on wlan1 (Routed AP mode)
echo "[*] Setting up IP and DHCP server on wlan1..."
brctl delif bridge0 wlan1 2>/dev/null || true
ifconfig wlan1 192.168.224.1 netmask 255.255.255.0
kill $(cat /var/run/dnsmasq_wlan1.pid 2>/dev/null) 2>/dev/null
dnsmasq --pid-file=/var/run/dnsmasq_wlan1.pid --dhcp-leasefile=/tmp/dnsmasq_wlan1.leases -u root -i wlan1 -z --dhcp-range=wlan1,192.168.224.20,192.168.224.60,255.255.255.0,12h --dhcp-option=6,8.8.8.8,1.1.1.1

# 9. Configure IP forwarding and NAT Firewall
echo "[*] Configuring IP forwarding & NAT (masquerade)..."
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -F FORWARD
iptables -P FORWARD ACCEPT
iptables -t nat -F
iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE

echo "=== JioFi Repeater is Active (wlan0: Client, wlan1: Routed Hotspot) ==="
