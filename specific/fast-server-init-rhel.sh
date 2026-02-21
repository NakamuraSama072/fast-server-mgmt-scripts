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
    fail "This script must be run with sudo (example: sudo bash fast-server-init-rhel.sh)."
  fi
}

detect_package_manager() {
  if command -v dnf >/dev/null 2>&1; then
    PKG_MGR="dnf"
  elif command -v yum >/dev/null 2>&1; then
    PKG_MGR="yum"
  else
    fail "Neither dnf nor yum was found on this system."
  fi
}

ensure_rhel_family() {
  if [[ ! -f /etc/os-release ]]; then
    fail "Cannot detect OS: /etc/os-release was not found."
  fi

  # shellcheck disable=SC1091
  source /etc/os-release
  local os_like="${ID_LIKE:-}"
  local os_id="${ID:-}"

  if [[ "${os_id}" != "rhel" && "${os_id}" != "centos" && "${os_id}" != "rocky" && "${os_id}" != "almalinux" && "${os_like}" != *"rhel"* && "${os_like}" != *"fedora"* ]]; then
    fail "This script only supports CentOS/RHEL family systems. Detected: ${PRETTY_NAME:-unknown}."
  fi
}

update_system() {
  log "Updating system packages..."
  ${PKG_MGR} -y update
}

install_epel() {
  log "Installing and enabling EPEL repository..."
  ${PKG_MGR} -y install epel-release
  ${PKG_MGR} -y makecache
}

install_base_packages() {
  log "Installing base packages..."
  ${PKG_MGR} -y install \
    openssh-server \
    firewalld \
    rsync \
    lrzsz \
    sysstat \
    elinks \
    wget \
    curl \
    net-tools \
    bash-completion \
    vim \
    ca-certificates \
    policycoreutils \
    policycoreutils-python-utils
}

configure_ssh() {
  log "Enabling and starting SSH service..."
  systemctl enable --now sshd
}

configure_firewalld() {
  log "Configuring firewalld rules..."
  systemctl enable --now firewalld
  firewall-cmd --permanent --add-service=ssh
  firewall-cmd --permanent --add-service=http
  firewall-cmd --permanent --add-service=https
  firewall-cmd --reload
}

check_selinux() {
  if command -v getenforce >/dev/null 2>&1; then
    local mode
    mode="$(getenforce)"
    log "Current SELinux mode: ${mode}"
    if [[ "${mode}" == "Permissive" ]]; then
      warn "SELinux is permissive. Consider setting enforcing mode after validating your services."
    elif [[ "${mode}" == "Disabled" ]]; then
      warn "SELinux is disabled. Enabling it requires policy configuration and a reboot."
    fi
  fi
}

main() {
  require_root
  ensure_rhel_family
  detect_package_manager

  update_system
  install_epel
  install_base_packages
  configure_ssh
  configure_firewalld
  check_selinux

  log "Initialization completed for CentOS/RHEL family."
}

main "$@"
