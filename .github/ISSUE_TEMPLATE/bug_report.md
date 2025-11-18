---
name: Bug Report
about: Create a report to help us improve
title: '[BUG] '
labels: bug
assignees: ''

---

## 🐛 Bug Description
A clear and concise description of what the bug is.

## 📋 Steps to Reproduce
1. Go to '...'
2. Run command '...'
3. See error

## ✅ Expected Behavior
A clear description of what you expected to happen.

## ❌ Actual Behavior
A clear description of what actually happened.

## 🖥️ Environment
- **OS**: [e.g., Ubuntu 22.04]
- **systemd version**: [output of `systemctl --version`]
- **Affected service(s)**: [e.g., nginx, mysql]
- **Script version**: [e.g., v2.0.0]

## 📝 Logs
Please include relevant logs:

```bash
# Setup log
sudo cat /var/log/autorestart_setup.log

# Service logs
sudo journalctl -u <service> -n 100 --no-pager

# Validation output
sudo ./validate_autorestart.sh
```

<details>
<summary>Paste logs here</summary>

```
[Paste your logs here]
```

</details>

## 🔍 Additional Context
Add any other context about the problem here. Screenshots can be helpful.

## 🔧 Attempted Solutions
What have you tried to fix this?

## 📎 Related Issues
Link to any related issues here.
