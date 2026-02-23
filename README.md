# fast-server-mgmt-scripts

Lightweight server management scripts for common Linux initialization tasks within 1 click.

## Current Scope

This repository currently provides two distribution-specific server initialization scripts:

- Debian/Ubuntu script: [specific/fast-server-init-debian.sh](specific/fast-server-init-debian.sh)
- CentOS/RHEL script: [specific/fast-server-init-rhel.sh](specific/fast-server-init-rhel.sh)

> [!TIP]
> Arch Linux and Arch-based distribution support is planned and will be released in a future update.
> Until then, use the existing scripts only on their matching distribution families.

## What These Scripts Do

Both scripts are designed for first-pass server bootstrap and include:

- System update at the beginning of execution
- OpenSSH server installation and service enablement (completed with the help of GPT-5.2)
- Common baseline package installation
- Firewall setup for SSH (22), HTTP (80), and HTTPS (443)

Distribution-specific behavior:

- Debian/Ubuntu:
	- Uses UFW
	- Uses package manager **fallback** order: **`apt`**, then **`apt-get`**
	- Installs SELinux tools and attempts to enable SELinux (permissive) when disabled
- CentOS/RHEL family:
	- Uses firewalld (i.e. firewall-cmd)
	- Uses package manager **fallback** order: **`dnf`**, then **`yum`**
	- Installs and refreshes EPEL repository metadata

## Requirements

- Linux server (Debian/Ubuntu or CentOS/RHEL family)
- sudo/root privileges
- systemd-based environment
- Internet access for package installation and updates

## Usage

> [!TIP]
> You might need to install `sudo` and configure Internet connections first on some distributions.

### Option A: Run from a local clone

First, clone the repository:

```bash
git clone --depth=1 https://www.github.com/nakamurasama072/fast-server-mgmt-scripts.git
```

Then change to the directory of the repository:

```bash
cd fast-server-mgmt-scripts
```

From the repository root:

```bash
chmod +x specific/fast-server-init-debian.sh specific/fast-server-init-rhel.sh
```

Run on Debian/Ubuntu:

```bash
sudo bash specific/fast-server-init-debian.sh
```

Run on CentOS/RHEL family:

```bash
sudo bash specific/fast-server-init-rhel.sh
```

### Option B: One-liner clean execution (no local clone)

This requires `curl` or `wget`, either of which is already included in most distributions.

Run on Debian/Ubuntu:

```bash
curl -fsSL https://raw.githubusercontent.com/nakamurasama072/fast-server-mgmt-scripts/main/specific/fast-server-init-debian.sh | sudo bash
wget -qO- https://raw.githubusercontent.com/nakamurasama072/fast-server-mgmt-scripts/main/specific/fast-server-init-debian.sh | sudo bash
```

Run on CentOS/RHEL family:

```bash
curl -fsSL https://raw.githubusercontent.com/nakamurasama072/fast-server-mgmt-scripts/main/specific/fast-server-init-rhel.sh | sudo bash
wget -qO- https://raw.githubusercontent.com/nakamurasama072/fast-server-mgmt-scripts/main/specific/fast-server-init-rhel.sh | sudo bash
```

## Notes

- Run each script only on its matching distribution family.
- On Debian/Ubuntu, a reboot may be required after SELinux activation changes.
- These scripts intentionally do not modify software mirror/repository source lists.
