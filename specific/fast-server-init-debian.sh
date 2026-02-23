#!/bin/bash

set -euo pipefail

# Basic log helpers.
log() {
  echo "[INFO] $1"
}

note() {
  echo "[NOTE] $1"
}

warn() {
  echo "[WARN] $1"
}

fail() {
  echo "[ERROR] $1" >&2
  exit 1
}

# Require sudo/root execution.
require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    fail "This script must be run with sudo (example: sudo bash fast-server-init-debian.sh)."
  fi
}

# Prefer newer package manager first: apt -> apt-get.
detect_package_manager() {
  if command -v apt >/dev/null 2>&1; then
    log "'apt' detected. It will be used as the package manager."
    PKG_MGR="apt"
  elif command -v apt-get >/dev/null 2>&1; then
    log "'apt-get' detected instead. Note that 'apt-get' is older and may have different behavior compared to 'apt'."
    PKG_MGR="apt-get"
  else
    fail "Neither apt nor apt-get was found on this system."
    fail "Initialization terminated with errors."
    exit 1
  fi
}

# Validate OS family before running Debian/Ubuntu-specific operations.
ensure_debian_family() {
  if [[ ! -f /etc/os-release ]]; then
    fail "Cannot detect OS: /etc/os-release was not found."
    fail "Initialization terminated with errors."
    exit 1
  fi

  # shellcheck disable=SC1091
  source /etc/os-release
  local os_like="${ID_LIKE:-}"
  local os_id="${ID:-}"

  if [[ "${os_id}" != "debian" && "${os_id}" != "ubuntu" && "${os_like}" != *"debian"* ]]; then
    fail "This script only supports Debian/Ubuntu systems. Detected: ${PRETTY_NAME:-unknown}."
    note "If you are using CentOS/RHEL, please run the CentOS/RHEL-specific initialization script instead:"
    note "curl -fsSL https://raw.githubusercontent.com/nakamurasama072/fast-server-mgmt-scripts/main/specific/fast-server-init-rhel.sh | sudo bash"
    fail "Initialization terminated with errors."
    exit 1
  fi
}

# Always update system before initialization tasks.
update_system() {
  log "Updating package index (This will not upgrade packages!)..."
  ${PKG_MGR} update

  log "Upgrading installed packages..."
  DEBIAN_FRONTEND=noninteractive ${PKG_MGR} -y dist-upgrade

  log "Removing unnecessary packages and cleaning up..."
  DEBIAN_FRONTEND=noninteractive ${PKG_MGR} -y autoremove
  DEBIAN_FRONTEND=noninteractive ${PKG_MGR} -y clean
}

# Install baseline tools used in RHCSA-related setup workflows.
install_base_packages() {
  log "Installing base packages..."
  DEBIAN_FRONTEND=noninteractive ${PKG_MGR} -y install \
    openssh-server \
    ufw \
    rsync \
    lrzsz \
    sysstat \
    elinks \
    wget \
    curl \
    net-tools \
    bash-completion \
    vim \
    ca-certificates
}

# Ensure SSH service is enabled and started.
configure_ssh() {
  log "Enabling and starting SSH service..."
  if systemctl list-unit-files | grep -q '^ssh\.service'; then
    systemctl enable --now ssh
  else
    systemctl enable --now sshd
  fi
}

# Configure UFW with secure defaults and common web ports.
configure_ufw() {
  log "Configuring UFW firewall rules..."
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow 22/tcp
  ufw allow 80/tcp
  ufw allow 443/tcp
  ufw --force enable
}

# Install SELinux userspace tools on Debian/Ubuntu.
install_selinux_tools() {
  log "Installing SELinux tools (Debian/Ubuntu optional hardening)..."
  if ! DEBIAN_FRONTEND=noninteractive ${PKG_MGR} -y install selinux-utils selinux-basics selinux-policy-default; then
    warn "SELinux packages could not be fully installed. Continuing without stopping."
  fi
}

# Check SELinux status and attempt activation when currently disabled.
check_and_enable_selinux() {
  if ! command -v getenforce >/dev/null 2>&1; then
    warn "SELinux tools are not available. Skipping SELinux status check."
    return
  fi

  local mode
  mode="$(getenforce)"
  log "Current SELinux mode: ${mode}"

  if [[ "${mode}" == "Disabled" ]]; then
    log "SELinux is disabled. Trying to enable SELinux in permissive mode..."

    if [[ -f /etc/selinux/config ]]; then
      sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config
    else
      warn "/etc/selinux/config was not found. Creating a minimal config file."
      cat > /etc/selinux/config <<'EOF'
SELINUX=permissive
SELINUXTYPE=default
EOF
    fi

    if command -v selinux-activate >/dev/null 2>&1; then
      selinux-activate || warn "selinux-activate returned a non-zero status. Please verify SELinux setup manually."
    else
      warn "selinux-activate command was not found. Please activate SELinux manually."
    fi

    log "SELinux enablement steps were applied. A reboot is required for changes to take effect."
  elif [[ "${mode}" == "Permissive" ]]; then
    log "SELinux is already enabled in permissive mode."
  elif [[ "${mode}" == "Enforcing" ]]; then
    log "SELinux is already enabled in enforcing mode."
  else
    warn "Unexpected SELinux mode value: ${mode}"
  fi
}

# Main execution flow.
main() {
  require_root
  ensure_debian_family
  detect_package_manager

  update_system
  install_base_packages
  configure_ssh
  configure_ufw
  install_selinux_tools
  check_and_enable_selinux

  log "Initialization completed for Debian/Ubuntu."
  log "If SELinux was just enabled, reboot the system to apply the new mode."
}

main "$@"
