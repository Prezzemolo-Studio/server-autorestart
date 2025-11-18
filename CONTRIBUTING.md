# Contributing to Server Auto-Restart System

First off, thank you for considering contributing to the Server Auto-Restart System! It's people like you that make this tool better for everyone.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Pull Request Process](#pull-request-process)
- [Style Guidelines](#style-guidelines)
- [Testing](#testing)

## 📜 Code of Conduct

This project and everyone participating in it is governed by respect and professionalism. Please be kind and courteous to others.

## 🤝 How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates.

When creating a bug report, include:
- **Clear title and description**
- **Steps to reproduce** the behavior
- **Expected behavior**
- **Actual behavior**
- **Environment details**:
  - OS and version (e.g., Ubuntu 22.04)
  - systemd version: `systemctl --version`
  - Services affected (nginx, mysql, etc.)
- **Logs** if applicable:
  ```bash
  sudo journalctl -u <service> -n 100 --no-pager
  sudo cat /var/log/autorestart_setup.log
  ```

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, include:
- **Clear title and description**
- **Use case**: Why is this enhancement needed?
- **Proposed solution**: How would it work?
- **Alternatives considered**: Other ways to achieve the same goal

### Pull Requests

We actively welcome your pull requests!

## 🛠️ Development Setup

### Prerequisites

- Linux system with systemd
- Bash 4.0+
- Git
- Root access for testing

### Setup

1. **Fork and clone the repository**:
   ```bash
   git clone git@github.com:YOUR_USERNAME/server-autorestart.git
   cd server-autorestart
   ```

2. **Create a test environment** (recommended):
   ```bash
   # Using Docker
   docker run -d --name test-server --privileged ubuntu:22.04
   docker exec -it test-server bash
   
   # Or using a VM
   # Recommended: Vagrant, VirtualBox, or cloud instance
   ```

3. **Make your changes**:
   ```bash
   # Create a feature branch
   git checkout -b feature/my-new-feature
   
   # Or a bugfix branch
   git checkout -b fix/bug-description
   ```

4. **Test your changes**:
   ```bash
   chmod +x *.sh
   sudo ./setup_autorestart_all.sh
   sudo ./validate_autorestart.sh
   ```

## 🔄 Pull Request Process

1. **Update documentation** if needed:
   - Update README.md for new features
   - Add entry to CHANGELOG.md
   - Update QUICK_REFERENCE.md if adding commands

2. **Ensure all tests pass**:
   ```bash
   sudo ./validate_autorestart.sh --skip-crash-test
   ```

3. **Follow commit message conventions**:
   ```
   type(scope): subject
   
   body (optional)
   
   footer (optional)
   ```
   
   Types:
   - `feat`: New feature
   - `fix`: Bug fix
   - `docs`: Documentation changes
   - `style`: Code style changes (formatting)
   - `refactor`: Code refactoring
   - `test`: Adding or updating tests
   - `chore`: Maintenance tasks
   
   Examples:
   ```
   feat(detection): Add Redis support
   fix(timer): Correct timer interval calculation
   docs(readme): Update installation instructions
   ```

4. **Create the Pull Request**:
   - Use a clear title and description
   - Reference any related issues
   - Include screenshots for UI changes
   - List any breaking changes

5. **Respond to feedback**:
   - Address review comments
   - Update your branch if needed
   - Be patient and respectful

## 📝 Style Guidelines

### Bash Script Style

Follow these conventions in bash scripts:

```bash
# Use descriptive function names
function my_descriptive_function() {
    local param1=$1
    local param2=$2
    
    # Add comments for complex logic
    if [ -z "$param1" ]; then
        echo "Error: param1 is required"
        return 1
    fi
    
    # Use consistent indentation (4 spaces)
    echo "Processing..."
}

# Use meaningful variable names (uppercase for globals, lowercase for locals)
GLOBAL_CONFIG="value"
local_variable="value"

# Always quote variables
echo "${local_variable}"

# Use [[ ]] instead of [ ] for conditionals
if [[ -f "$file" ]]; then
    echo "File exists"
fi
```

### Documentation Style

- Use clear, concise language
- Include code examples
- Add links to related documentation
- Use proper markdown formatting
- Check spelling and grammar

### Commit Message Style

```bash
# Good commit messages
feat(mysql): Add MariaDB 11 support
fix(timer): Resolve race condition in service check
docs(advanced): Add Prometheus integration example

# Bad commit messages
update stuff
fix bug
changes
```

## 🧪 Testing

### Manual Testing Checklist

Before submitting a PR, test:

- [ ] Script runs without errors
- [ ] All supported services are detected correctly
- [ ] Configuration files are created properly
- [ ] Timers start and work correctly
- [ ] Validation script passes
- [ ] Uninstall script removes everything cleanly
- [ ] No permission errors
- [ ] Works on multiple distributions:
  - [ ] Ubuntu 20.04+
  - [ ] Debian 10+
  - [ ] CentOS 8+ / Rocky Linux

### Test Script

```bash
#!/bin/bash
# test.sh - Basic test script

set -e

echo "=== Running Tests ==="

# Test 1: Script syntax
echo "Test 1: Checking bash syntax..."
bash -n setup_autorestart_all.sh
bash -n validate_autorestart.sh
bash -n uninstall_autorestart.sh
echo "✓ Syntax check passed"

# Test 2: Installation
echo "Test 2: Installing..."
sudo ./setup_autorestart_all.sh
echo "✓ Installation passed"

# Test 3: Validation
echo "Test 3: Validating..."
sudo ./validate_autorestart.sh --skip-crash-test
echo "✓ Validation passed"

# Test 4: Uninstall
echo "Test 4: Uninstalling..."
sudo ./uninstall_autorestart.sh --dry-run
echo "✓ Uninstall passed"

echo "=== All Tests Passed ==="
```

## 🎯 Areas Where We Need Help

- **Testing on different distributions**
- **Support for additional services** (Redis, MongoDB, etc.)
- **Internationalization** (i18n)
- **Performance optimization**
- **Documentation improvements**
- **Integration examples** (monitoring, logging platforms)

## 💡 Feature Requests

Have an idea for a new feature? Great! Please:

1. Check if it's already requested in Issues
2. Create a new issue with the `enhancement` label
3. Describe the use case and benefits
4. Be open to discussion and feedback

## 🐛 Bug Reports

Found a bug? We want to hear about it!

1. Check if it's already reported
2. Create a new issue with the `bug` label
3. Include all relevant information (see "Reporting Bugs" above)
4. Be responsive to questions

## 📖 Documentation Contributions

Documentation improvements are always welcome:

- Fix typos or grammatical errors
- Clarify confusing sections
- Add examples
- Translate to other languages
- Create video tutorials

## ⚖️ License

By contributing, you agree that your contributions will be licensed under the MIT License.

## 🙏 Recognition

Contributors will be:
- Listed in the CHANGELOG.md
- Mentioned in release notes
- Added to a CONTRIBUTORS.md file (planned)

## 📧 Questions?

Don't hesitate to ask questions:
- Open an issue with the `question` label
- Be specific and provide context
- Check existing Q&A in issues

## 🎉 Thank You!

Your contributions make this project better for everyone. We appreciate your time and effort!

---

**Happy Contributing! 🚀**

Repository: https://github.com/Prezzemolo-Studio/server-autorestart
