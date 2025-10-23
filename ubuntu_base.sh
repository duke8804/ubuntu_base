#!/bin/bash
set -e

UPDATES=/scripts/updates.sh
NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"

# Prompt for network and system info
read -rp "Enter new hostname: " HOSTNAME
read -rp "Enter IP address (e.g., 192.168.1.100): " IPADDR
read -rp "Enter subnet prefix (e.g., 24 for 255.255.255.0): " SUBNET
read -rp "Enter gateway: " GATEWAY
read -rp "Enter DNS server 1: " DNS1
read -rp "Enter DNS server 2: " DNS2
read -sp "Enter new password for user 'revel': " PASSWORD; echo

# Detect interface
NIC=$(ip route | awk '/default/ {print $5}' | head -n1)

# Hostname setup
hostnamectl set-hostname "$HOSTNAME"

# Disable cloud-init network config
touch /etc/cloud/cloud-init.disabled
rm -f /etc/netplan/50-cloud-init.yaml

# Create static netplan config
cat <<EOF > "$NETPLAN_FILE"
network:
  version: 2
  renderer: networkd
  ethernets:
    $NIC:
      dhcp4: no
      addresses: [$IPADDR/$SUBNET]
      nameservers:
        addresses: [$DNS1, $DNS2]
      routes:
        - to: default
          via: $GATEWAY
EOF

chmod 600 "$NETPLAN_FILE"
netplan apply

# Update /etc/hosts
if ! grep -q "$HOSTNAME" /etc/hosts; then
  echo "127.0.1.1 $HOSTNAME" >> /etc/hosts
fi

# Change password
echo -e "$PASSWORD\n$PASSWORD" | passwd revel

# Timezone
timedatectl set-timezone America/Chicago

# Package setup
apt update
apt install -y joe fail2ban qemu-guest-agent
apt upgrade -y

# Enable services
systemctl enable fail2ban
systemctl start fail2ban
cat <<EOF > /etc/fail2ban/jail.d/sshd.local
[sshd]
enabled = true
EOF
systemctl restart fail2ban
systemctl enable --now qemu-guest-agent || true

# Create scripts directory
mkdir -p /scripts/logs

# Create updates script
cat <<EOF > "$UPDATES"
#!/bin/bash
set -e
apt clean
apt update
apt upgrade -y
apt dist-upgrade -y
apt autoremove -y
apt autoclean -y
if [ -f /var/run/reboot-required ]; then
  shutdown -r now
fi
echo \$(date) "Updates Complete" >> /scripts/logs/updates.log
find /scripts/logs -type f -name 'updates.log' -size +1M -delete
EOF
chmod +x "$UPDATES"

# Schedule daily updates at 4 AM under root
( sudo crontab -l 2>/dev/null; echo "0 4 * * * $UPDATES" ) | sudo crontab -

# Run updates now
"$UPDATES"

echo "✅ Setup complete. Hostname: $HOSTNAME  IP: $IPADDR  NIC: $NIC"
