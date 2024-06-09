# 💻 VPS-Lock-Figuration ~ Designed to Configure your VPS with a Locked Tight Configuration 🔐
<img width="1266" alt="image" src="https://github.com/0xXyc/VPS-Lock-Figuration/assets/42036798/bdf4bd83-4ed1-4e40-bbe9-062fff3041f8">

## ✅ Deploy VPS Best Practices in the Click of a few Buttons!! 🤓
This is a neat little BASH script that should be ran immediately after your VPS boots up the first time. 
It will help deploy most known best security practices to date. 
Ultimately, helping you maintain and start off with a secure environment for your VPS!

## 🔥 Usage 🔥
Be sure to have a secure way to transfer keys to and from the system. In most cases, it is easiest to use your initial root login credentials to create SSH keys for a new user, and then use `ssh-copy-id` to transfer the keys to the new user.

The default port is `1337`, but be sure to change it in the `lock-figuration.sh` file if you want to use a different port.

## Connecting to the VPS
`ssh -p <port> -i <private_key_here> user@<server_address>`

