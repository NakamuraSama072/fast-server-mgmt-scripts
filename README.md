# fast-server-mgmt-scripts

Lightweight server management scripts for common Linux initialization tasks within 1 click.

## Current Scope

This repository currently provides two distribution-specific server initialization scripts:

- Debian/Ubuntu script: [specific/fast-server-init-debian.sh](specific/fast-server-init-debian.sh)
- CentOS/RHEL script: [specific/fast-server-init-rhel.sh](specific/fast-server-init-rhel.sh)

## What These Scripts Do

Both scripts are designed for first-pass server bootstrap and include:

- System update at the beginning of execution
- OpenSSH server installation and service enablement
- Common baseline package installation
- Firewall setup for SSH (22), HTTP (80), and HTTPS (443)

Distribution-specific behavior:

- Debian/Ubuntu:
	- Uses UFW
	- Uses package manager fallback order: apt, then apt-get
	- Installs SELinux tools and attempts to enable SELinux (permissive) when disabled
- CentOS/RHEL family:
	- Uses firewalld (i.e. firewall-cmd)
	- Uses package manager fallback order: dnf, then yum
	- Installs and refreshes EPEL repository metadata

## Requirements

- Linux server (Debian/Ubuntu or CentOS/RHEL family)
- sudo/root privileges
- systemd-based environment
- Internet access for package installation and updates

## Usage

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

## Notes

- Run each script only on its matching distribution family.
- On Debian/Ubuntu, a reboot may be required after SELinux activation changes.
- These scripts intentionally do not modify software mirror/repository source lists.
