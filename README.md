# 🔄 Auto-Restart System for Linux Services

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-4.0%2B-green.svg)](https://www.gnu.org/software/bash/)
[![systemd](https://img.shields.io/badge/systemd-229%2B-orange.svg)](https://systemd.io/)

Production-ready script system to automatically restart web servers and databases on Linux when they crash or become unresponsive.

## 🎯 What It Does

Protects your critical services (Nginx, Apache, MySQL, MariaDB, PostgreSQL) by implementing a dual safety system:
1. **Immediate restart** when a service crashes (via systemd)
2. **Periodic monitoring** to detect and fix anomalies (via timer)

**Result**: Your website/API comes back online in 10-15 seconds instead of waiting for manual intervention.

## ⚡ Quick Start

```bash
# 1. Clone this repository
git clone https://github.com/Prezzemolo-Studio/server-autorestart.git
cd server-autorestart

# 2. Make scripts executable and run
chmod +x *.sh && sudo ./setup_autorestart_all.sh

# 3. Verify it works
sudo systemctl list-timers | grep restart
```

✅ Done! Your services are now protected.

## 📦 What's Included

### 🔧 Executable Scripts

| Script | Description | Size |
|--------|-------------|------|
| **setup_autorestart_all.sh** | Main installation script (auto-detects services) | 16 KB |
| **validate_autorestart.sh** | Validation and testing script | 14 KB |
| **uninstall_autorestart.sh** | Clean removal script | 11 KB |

### 📚 Documentation

| File | Description | Size |
|------|-------------|------|
| **INDEX.md** | Start here - Navigation guide | 9 KB |
| **README.md** | Complete documentation | 9 KB |
| **DEPLOYMENT_CHECKLIST.md** | Step-by-step deployment guide | 11 KB |
| **QUICK_REFERENCE.md** | Quick commands and troubleshooting | 8 KB |
| **ADVANCED_CONFIGS.md** | Advanced configurations and scenarios | 14 KB |

**Total**: 8 files, ~92 KB of comprehensive documentation

## 🎓 Supported Services

- ✅ **Web Servers**: Apache (apache2), Nginx
- ✅ **Databases**: MySQL, MariaDB, PostgreSQL

Auto-detection: The script automatically detects which services are running and configures only those.

## 🚀 Features

### Automatic Detection
Script automatically detects active services and configures them accordingly.

### Dual Protection Layer
1. **Method 1**: Systemd override → Immediate restart on crash
2. **Method 2**: Periodic timer → Check every minute

### Production-Ready
- ✅ Idempotent (can be run multiple times)
- ✅ Structured logging
- ✅ Complete validation
- ✅ Clean uninstall
- ✅ Zero downtime during install
- ✅ Configurable for every scenario

### Comprehensive Documentation
- ✅ 8 documentation files
- ✅ 92 KB of detailed guides
- ✅ Practical examples
- ✅ Troubleshooting for every problem
- ✅ Advanced configurations

## 📖 Documentation

### For Beginners (15 min)
1. Read [INDEX.md](INDEX.md)
2. Follow [README.md](README.md) Quick Start
3. Run the script
4. Bookmark [QUICK_REFERENCE.md](QUICK_REFERENCE.md)

### For Professional Deployment (1 hour)
1. Read [README.md](README.md) (complete)
2. Follow [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) step-by-step
3. Test in non-production environment
4. Deploy to production with checklist
5. Set up monitoring with [ADVANCED_CONFIGS.md](ADVANCED_CONFIGS.md)

### For DevOps Experts (2 hours)
1. Quick review of [README.md](README.md)
2. Customize `setup_autorestart_all.sh`
3. Configure advanced profile from [ADVANCED_CONFIGS.md](ADVANCED_CONFIGS.md)
4. Integrate with existing monitoring system
5. Set up custom notifications

## 🔧 Installation Methods

### Method 1: Direct Clone on Server (Recommended)

```bash
# On your server
git clone https://github.com/Prezzemolo-Studio/server-autorestart.git
cd server-autorestart
chmod +x *.sh
sudo ./setup_autorestart_all.sh
```

### Method 2: Local Clone + SCP Upload

```bash
# On your local machine
git clone https://github.com/Prezzemolo-Studio/server-autorestart.git
cd server-autorestart

# Upload to server
scp *.sh *.md user@your-server:/tmp/

# On server
ssh user@your-server
cd /tmp
chmod +x *.sh
sudo ./setup_autorestart_all.sh
```

## 🔍 Quick Verification

After installation, verify everything works:

```bash
# Check that timers are active
sudo systemctl list-timers | grep restart

# Check service status
sudo systemctl status nginx mysql

# View logs
sudo journalctl -u nginx -n 50
sudo tail -f /var/log/restart-nginx.log

# Validate installation (comprehensive test)
sudo ./validate_autorestart.sh --skip-crash-test
```

## ⚙️ Customization

The script uses sensible defaults, but you can customize:

```bash
# Edit setup_autorestart_all.sh before running
nano setup_autorestart_all.sh

# Modify these variables (around line 40-45):
RESTART_SEC="10s"           # Time before restart
START_LIMIT_BURST="5"       # Max restarts in time window
TIMER_INTERVAL="1min"       # Check frequency
```

See [ADVANCED_CONFIGS.md](ADVANCED_CONFIGS.md) for pre-configured profiles:
- **Aggressive**: Fast restart, many attempts (for critical services)
- **Conservative**: Slow restart, few attempts (for heavy services)
- **Balanced**: Default recommended settings

## 📊 What Gets Created

For each configured service (e.g., nginx):

```
/etc/systemd/system/
├── nginx.service.d/
│   └── 99-auto-restart.conf          # Systemd override
├── restart-nginx.service              # Monitoring service
└── restart-nginx.timer                # Periodic timer

/usr/local/bin/
└── restart-nginx.sh                   # Monitoring script

/var/log/
├── restart-nginx.log                  # Monitoring log
└── autorestart_setup.log              # Setup log
```

## 🛡️ Safety Features

- Requires root privileges (security check)
- Rate limiting (max 5 restarts in 5 minutes by default)
- Comprehensive logging
- Validation script included
- Clean uninstall available
- No credentials or sensitive data exposed

## ⚠️ Important Notes

### This is NOT a Fix, It's a Protection

This system is a **safety net**, not a **solution**. 

If your services crash frequently, you have an underlying problem that must be fixed:
- **OOM Kill**: Optimize memory configuration, add swap, increase RAM
- **Frequent crashes**: Analyze logs, fix bugs, update software
- **Configuration issues**: Review and correct service configurations

**Example**: If MySQL crashes due to OOM:
- ❌ **Wrong**: "Configured auto-restart, problem solved"
- ✅ **Correct**: "Configured auto-restart + optimized innodb_buffer_pool_size + added swap"

## 📈 Success Metrics

After 1 week of deployment, check:

- ✅ Improved uptime
- ✅ < 2 automatic restarts per week (ideally 0)
- ✅ No StartLimitBurst reached
- ✅ Logs show no anomalies

If these metrics aren't met, there's an underlying problem to fix!

## 🆘 Troubleshooting

### Script doesn't detect services
```bash
# Verify services are active
sudo systemctl status nginx mysql

# If not active, start them
sudo systemctl start nginx mysql
```

### Permission denied
```bash
# Always use sudo
sudo ./setup_autorestart_all.sh
```

### Timer not working
```bash
# Reload systemd
sudo systemctl daemon-reload
sudo systemctl restart restart-nginx.timer
```

### Service restarts continuously
```bash
# 🚨 CRITICAL - Stop timer and fix root cause
sudo systemctl stop restart-nginx.timer
sudo journalctl -u nginx -n 200
# Fix the problem (e.g., OOM, configuration)
sudo systemctl start restart-nginx.timer
```

**For detailed troubleshooting**: See [QUICK_REFERENCE.md](QUICK_REFERENCE.md)

## 📋 Requirements

- **OS**: Ubuntu 16.04+ / Debian 9+ / CentOS 7+ / RHEL 7+ or any distro with systemd 229+
- **Shell**: Bash 4.0+
- **Init system**: systemd
- **Privileges**: root (sudo)
- **Services**: At least one of: Apache, Nginx, MySQL, MariaDB, PostgreSQL

## 🤝 Contributing

Found a bug or have a suggestion? Please:
1. Check existing issues in the repository
2. Open a new issue with detailed description
3. Or submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👨‍💻 Author

**Prezzemolo Studio**
- GitHub: https://github.com/Prezzemolo-Studio
- Website: [Prezzemolo Studio](https://prezzemolostudio.it)

## 🙏 Acknowledgments

- Inspired by common DevOps practices
- Built with production experience from multiple deployments
- Tested on various Linux distributions and configurations

## 📞 Support

1. **Documentation**: Read the markdown files in this directory
2. **Validation**: Run `./validate_autorestart.sh`
3. **Logs**: Check `/var/log/autorestart_setup.log`
4. **Troubleshooting**: See [QUICK_REFERENCE.md](QUICK_REFERENCE.md)

## ⭐ Star This Repository

If this script helped you, please consider starring the repository!

---

**Made with ❤️ by Prezzemolo Studio**
