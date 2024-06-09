#!/bin/bash

# BASH Script to help speed up secure deployments for cloud environments, specifically VPS's.

# Define color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to check if a command succeeded
check_command() {
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: $1 failed. Exiting.${NC}"
    exit 1
  fi
}

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

sleep 3

# Update system packages
echo -e "${YELLOW}Updating system packages...${NC}"
apt update && apt upgrade -y
check_command "System update"

# Create a new user
echo -e "${YELLOW}Creating a new user...${NC}"
read -p "Enter the new username: " NEW_USER
adduser $NEW_USER
check_command "Add user"

# Add new user to sudo group
usermod -aG sudo $NEW_USER
check_command "Add user to sudo group"
echo -e "${YELLOW}[+] New User, $NEW_USER, has been created!${NC}"

# Set up UFW firewall
echo -e "${YELLOW}Setting up UFW firewall...${NC}"
ufw default deny incoming
ufw default allow outgoing
ufw allow 6969/tcp
ufw enable
ufw status
check_command "UFW setup"

# Disable root login and configure SSH
echo -e "${YELLOW}Configuring SSH...${NC}"
SSH_CONFIG="/etc/ssh/sshd_config"
cp $SSH_CONFIG $SSH_CONFIG.bak

sed -i 's/PermitRootLogin yes/PermitRootLogin no/' $SSH_CONFIG
sed -i "s/#Port 22/Port 13337/" $SSH_CONFIG
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' $SSH_CONFIG
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' $SSH_CONFIG

systemctl reload sshd
check_command "SSH configuration"

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
port = 13337
logpath = /var/log/auth.log
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

# Warning: SSH keys for the new user
echo -e "${RED}Be sure to set up SSH keys for the new user...${NC}"
echo -e "${RED}Via "touch authorized_keys" ...${NC}"
echo -e "${RED}Now, generate a new SSH key for the new user on your local machine and add the public key to authorized_keys on the VPS...${NC}"

# Display completion message
echo -e "${GREEN}[+] VPS security setup is complete. Password login is disabled.${NC}"
echo -e "${YELLOW} [!] Remember to log in using: ssh -p 13337 -i <id_rsa> $NEW_USER@<server_ip>${NC}"