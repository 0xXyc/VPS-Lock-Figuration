# VPS-Lock-Figuration ~ Designed to Configure your VPS with a Locked Tight Configuration
<img width="1266" alt="image" src="https://github.com/0xXyc/VPS-Lock-Figuration/assets/42036798/bdf4bd83-4ed1-4e40-bbe9-062fff3041f8">

## Deploy VPS Best Practices in the Click of a few Buttons!!
This is a neat little BASH script that should be ran immediately after your VPS boots up the first time.
It will help deploy most known best security practices to date.
Ultimately, helping you maintain and start off with a secure environment for your VPS!

## Best Practices Deployed
  1. Update system packages
  2. Create a new user with sudo privileges
  3. Set up SSH keys for the new user (prompted during setup)
  4. Set up a firewall using UFW to allow only inbound SSH on your configured port (default: `13337`)
  5. Disable root login and password authentication via SSH
  6. Install and configure Fail2Ban
  7. Enable automatic security updates

## Configuration
The SSH port is defined as a variable at the top of `lock-figuration.sh`:
```bash
SSH_PORT=13337
```
Change this before running if you want a different port. It's used everywhere — UFW, sshd_config, and Fail2Ban — so you only need to change it in one place.

## Usage
```bash
# Must be run as root on a fresh VPS
chmod +x lock-figuration.sh
./lock-figuration.sh
```

The script will:
1. Update and upgrade all packages
2. Create a new user and add them to sudo
3. **Prompt you to paste your SSH public key** — do this before continuing or you'll be locked out
4. Configure UFW to only allow your SSH port
5. Harden sshd_config (disable root login, disable password auth, set custom port)
6. Install and configure Fail2Ban with a jail on your SSH port
7. Enable unattended security upgrades

> **IMPORTANT:** Test your login in a **new terminal** before closing your current session!

## Connecting to the VPS
```
ssh -p <port> -i <private_key> user@<server_address>
```

## Future
Let me know if I should add anything else!
