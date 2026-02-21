#!/bin/bash

set -euo pipefail

log() {
  echo "[INFO] $1"
}

warn() {
  echo "[WARN] $1"
}

fail() {
  echo "[ERROR] $1" >&2
  exit 1
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    fail "This script must be run with sudo (example: sudo bash fast-server-init-debian.sh)."
  fi
}

detect_package_manager() {
  if command -v apt >/dev/null 2>&1; then
    PKG_MGR="apt"
  elif command -v apt-get >/dev/null 2>&1; then
    PKG_MGR="apt-get"
  else
    fail "Neither apt nor apt-get was found on this system."
  fi
}

ensure_debian_family() {
  if [[ ! -f /etc/os-release ]]; then
    fail "Cannot detect OS: /etc/os-release was not found."
  fi

  # shellcheck disable=SC1091
  source /etc/os-release
  local os_like="${ID_LIKE:-}"
  local os_id="${ID:-}"

  if [[ "${os_id}" != "debian" && "${os_id}" != "ubuntu" && "${os_like}" != *"debian"* ]]; then
    fail "This script only supports Debian/Ubuntu systems. Detected: ${PRETTY_NAME:-unknown}."
  fi
}

update_system() {
  log "Updating package index..."
  ${PKG_MGR} update

  log "Upgrading installed packages..."
  DEBIAN_FRONTEND=noninteractive ${PKG_MGR} -y upgrade
}

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

configure_ssh() {
  log "Enabling and starting SSH service..."
  if systemctl list-unit-files | grep -q '^ssh\.service'; then
    systemctl enable --now ssh
  else
    systemctl enable --now sshd
  fi
}

configure_ufw() {
  log "Configuring UFW firewall rules..."
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow 22/tcp
  ufw allow 80/tcp
  ufw allow 443/tcp
  ufw --force enable
}

install_selinux_tools() {
  log "Installing SELinux tools (Debian/Ubuntu optional hardening)..."
  if ! DEBIAN_FRONTEND=noninteractive ${PKG_MGR} -y install selinux-utils selinux-basics selinux-policy-default; then
    warn "SELinux packages could not be fully installed. Continuing without stopping."
  fi
}

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
