#!/bin/bash

# BASH Script to help speed up secure deployments for cloud environments, specifically VPS's.

# Define color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Default SSH port — change this if you want a different port
SSH_PORT=13337

# Function to check if a command succeeded
check_command() {
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: $1 failed. Exiting.${NC}"
    exit 1
  fi
}

# Must be run as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: This script must be run as root.${NC}"
  exit 1
fi

# Detect SSH service name (Debian uses "ssh", older/RHEL uses "sshd")
if systemctl list-unit-files ssh.service &>/dev/null; then
  SSH_SERVICE="ssh"
elif systemctl list-unit-files sshd.service &>/dev/null; then
  SSH_SERVICE="sshd"
else
  echo -e "${RED}Error: Could not find SSH systemd service. Exiting.${NC}"
  exit 1
fi

# Display banner
echo -e "${GREEN}
   :::     :::       :::::::::       ::::::::        :::        ::::::::       ::::::::       :::    :::
  :+:     :+:       :+:    :+:     :+:    :+:       :+:       :+:    :+:     :+:    :+:      :+:   :+:
 +:+     +:+       +:+    +:+     +:+              +:+       +:+    +:+     +:+             +:+  +:+
+#+     +:+       +#++:++#+      +#++:++#++       +#+       +#+    +:+     +#+             +#++:++
+#+   +#+        +#+                   +#+       +#+       +#+    +#+     +#+             +#+  +#+
#+#+#+#         #+#            #+#    #+#       #+#       #+#    #+#     #+#    #+#      #+#   #+#
 ###           ###             ########        ########## ########       ########       ###    ###

   VPS Lock-Figuration ~ By Xyco
${NC}"

echo -e "${YELLOW}[*] Detected SSH service: $SSH_SERVICE${NC}"
echo -e "${YELLOW}[*] SSH port will be set to: $SSH_PORT${NC}"
sleep 2

# Update system packages
echo -e "${YELLOW}Updating system packages...${NC}"
apt update && apt upgrade -y
check_command "System update"

# Create a new user
echo -e "${YELLOW}Creating a new user...${NC}"
read -p "Enter the new username: " NEW_USER
adduser "$NEW_USER"
check_command "Add user"

# Add new user to sudo group
usermod -aG sudo "$NEW_USER"
check_command "Add user to sudo group"
echo -e "${YELLOW}[+] New User, $NEW_USER, has been created!${NC}"

# Set up SSH keys for the new user BEFORE disabling password auth
echo -e "${YELLOW}Setting up SSH keys for $NEW_USER...${NC}"
NEW_USER_HOME=$(eval echo "~$NEW_USER")
mkdir -p "$NEW_USER_HOME/.ssh"
chmod 700 "$NEW_USER_HOME/.ssh"
touch "$NEW_USER_HOME/.ssh/authorized_keys"
chmod 600 "$NEW_USER_HOME/.ssh/authorized_keys"
chown -R "$NEW_USER:$NEW_USER" "$NEW_USER_HOME/.ssh"

echo -e "${RED}[!] Paste the PUBLIC key for $NEW_USER now (one line, then press Enter):${NC}"
read -r PUB_KEY
if [ -n "$PUB_KEY" ]; then
  echo "$PUB_KEY" >> "$NEW_USER_HOME/.ssh/authorized_keys"
  echo -e "${GREEN}[+] Public key added for $NEW_USER.${NC}"
else
  echo -e "${RED}[!] WARNING: No key entered. You MUST add a key manually before rebooting${NC}"
  echo -e "${RED}    or you will be locked out of this server.${NC}"
  read -p "Continue anyway? (y/N): " CONTINUE
  if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Exiting. Add your SSH key and re-run the script.${NC}"
    exit 1
  fi
fi

# Configure SSH FIRST (before firewall) so sshd_config is valid when UFW enables
echo -e "${YELLOW}Configuring SSH...${NC}"
SSH_CONFIG="/etc/ssh/sshd_config"
cp "$SSH_CONFIG" "$SSH_CONFIG.bak"

# Handle all possible default states of these directives
sed -i -E "s/^#?PermitRootLogin .*/PermitRootLogin no/" "$SSH_CONFIG"
sed -i -E "s/^#?Port .*/Port $SSH_PORT/" "$SSH_CONFIG"
sed -i -E "s/^#?PasswordAuthentication .*/PasswordAuthentication no/" "$SSH_CONFIG"

# If the directives don't exist at all, append them
grep -q "^PermitRootLogin" "$SSH_CONFIG" || echo "PermitRootLogin no" >> "$SSH_CONFIG"
grep -q "^Port " "$SSH_CONFIG" || echo "Port $SSH_PORT" >> "$SSH_CONFIG"
grep -q "^PasswordAuthentication" "$SSH_CONFIG" || echo "PasswordAuthentication no" >> "$SSH_CONFIG"

# Validate the config BEFORE restarting — if sshd -t fails, don't touch the running service
echo -e "${YELLOW}Validating SSH config...${NC}"
if ! sshd -t; then
  echo -e "${RED}Error: sshd_config validation failed. Restoring backup.${NC}"
  cp "$SSH_CONFIG.bak" "$SSH_CONFIG"
  exit 1
fi
echo -e "${GREEN}[+] SSH config valid${NC}"

# Install and configure UFW (in case it's not already there)
echo -e "${YELLOW}Setting up UFW firewall...${NC}"
if ! command -v ufw >/dev/null 2>&1; then
  apt install -y ufw
  check_command "UFW installation"
fi

ufw default deny incoming
ufw default allow outgoing
ufw allow "$SSH_PORT/tcp"
ufw --force enable
ufw status
check_command "UFW setup"

# Now restart SSH — firewall already allows the new port
echo -e "${YELLOW}Restarting SSH on port $SSH_PORT...${NC}"
systemctl restart "$SSH_SERVICE"
check_command "SSH restart"

# Verify SSH is actually listening on the new port
sleep 2
if ss -tlnp | grep -q ":$SSH_PORT "; then
  echo -e "${GREEN}[+] SSH is listening on port $SSH_PORT${NC}"
else
  echo -e "${RED}[!] WARNING: SSH does not appear to be listening on port $SSH_PORT${NC}"
  echo -e "${RED}    DO NOT close this session until you verify you can log in with the new config.${NC}"
fi

# Install and configure Fail2Ban
echo -e "${YELLOW}Installing and configuring Fail2Ban...${NC}"
apt install -y fail2ban
check_command "Fail2Ban installation"

echo -e "${YELLOW}Configuring JAIL...${NC}"
cat <<EOF > /etc/fail2ban/jail.local
[DEFAULT]
bantime  = 600m
findtime  = 10m
maxretry = 5

[sshd]
enabled = true
port = $SSH_PORT
logpath = /var/log/auth.log
backend = systemd
EOF

echo -e "${YELLOW}Restarting fail2ban...${NC}"
systemctl restart fail2ban
check_command "Fail2Ban configuration"

# Enable automatic security updates
echo -e "${YELLOW}Enabling automatic security updates...${NC}"
apt install -y unattended-upgrades
check_command "Unattended upgrades installation"
echo -e "${YELLOW}[+] Updates complete!${NC}"

dpkg-reconfigure --priority=low unattended-upgrades
check_command "Unattended upgrades configuration"

# Configure auto-reboot when kernel/security updates land.
# Default unattended-upgrades does NOT reboot, leaving stale kernels running.
echo -e "${YELLOW}Configuring unattended-upgrades auto-reboot...${NC}"
cat > /etc/apt/apt.conf.d/52unattended-upgrades-reboot <<EOF
// Added by lock-figuration.sh
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "04:00";
Unattended-Upgrade::Automatic-Reboot-WithUsers "true";
EOF
echo -e "${GREEN}[+] Auto-reboot scheduled for 04:00 when needed${NC}"

# Display completion message
echo -e "${GREEN}[+] VPS security setup is complete. Password login is disabled.${NC}"
echo -e "${YELLOW} [!] Remember to log in using: ssh -p $SSH_PORT -i <id_rsa> $NEW_USER@<server_ip>${NC}"
echo ""
echo -e "${RED} [!] TEST YOUR LOGIN IN A NEW TERMINAL BEFORE CLOSING THIS SESSION${NC}"
