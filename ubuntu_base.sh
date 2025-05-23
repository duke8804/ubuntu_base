#!/bin/bash

# Prompt for network details
read -rp "Enter new hostname: " HOSTNAME
read -rp "Enter IP address (e.g., 192.168.1.100): " IPADDR
read -rp "Enter subnet prefix (e.g., 24 for 255.255.255.0): " SUBNET
read -rp "Enter gateway: " GATEWAY
read -rp "Enter DNS server: " DNS

# Set hostname
hostnamectl set-hostname "$HOSTNAME"

# Create netplan config (do not apply yet)
cat <<EOF > /etc/netplan/01-netcfg.yaml
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: no
      addresses: [$IPADDR/$SUBNET]
      nameservers:
        addresses: [$DNS]
      routes:
        - to: default
          via: $GATEWAY
EOF

# Set secure permissions
chmod 600 /etc/netplan/01-netcfg.yaml

# Update and install packages
apt update
apt install -y joe fail2ban qemu-guest-agent
apt upgrade -y

# Enable and configure fail2ban
systemctl enable fail2ban
systemctl start fail2ban
cat <<EOF > /etc/fail2ban/jail.d/sshd.local
[sshd]
enabled = true
EOF
systemctl restart fail2ban

# Apply static IP config last
netplan apply

echo "Setup complete. IP address may have changed."
