#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Main Build Script
###############################################################################
# This script follows the @ublue-os/bluefin pattern for build scripts.
# It uses set -eoux pipefail for strict error handling and debugging.
###############################################################################

# Source helper functions
# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

# Enable nullglob for all glob operations to prevent failures on empty matches
shopt -s nullglob

echo "::group:: Copy Bluefin Config from Common"

# Copy just files from @projectbluefin/common (includes 00-entry.just which imports 60-custom.just)
mkdir -p /usr/share/ublue-os/just/
shopt -s nullglob
cp -r /ctx/oci/common/bluefin/usr/share/ublue-os/just/* /usr/share/ublue-os/just/
shopt -u nullglob

echo "::endgroup::"

echo "::group:: Copy Custom Files"

# Copy Brewfiles to standard location
mkdir -p /usr/share/ublue-os/homebrew/
cp /ctx/custom/brew/*.Brewfile /usr/share/ublue-os/homebrew/

# Consolidate Just Files
find /ctx/custom/ujust -iname '*.just' -exec printf "\n\n" \; -exec cat {} \; >> /usr/share/ublue-os/just/60-custom.just

# Copy Flatpak preinstall files
mkdir -p /etc/flatpak/preinstall.d/
cp /ctx/custom/flatpaks/*.preinstall /etc/flatpak/preinstall.d/

echo "::endgroup::"

echo "::group:: Install Packages"

# System packages
dnf5 install -y \
    fwupd \
    power-profiles-daemon \
    bluez \
    firewalld \
    pipewire-codec-aptx \
    zram-generator

# Tailscale - official repo
dnf5 config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
dnf5 install -y tailscale
rm -f /etc/yum.repos.d/tailscale.repo

echo "::endgroup::"

echo "::group:: System Configuration"

# Enable/disable systemd services
systemctl enable podman.socket
systemctl enable tailscaled
systemctl enable bluetooth
systemctl enable power-profiles-daemon
systemctl enable fwupd-refresh.timer
systemctl enable firewalld

# Pre-enable Tailscale systray for all users (systemd user service)
mkdir -p /etc/skel/.config/systemd/user/default.target.wants
ln -sf /usr/lib/systemd/user/tailscale-systray.service /etc/skel/.config/systemd/user/default.target.wants/tailscale-systray.service

echo "::endgroup::"

echo "::group:: ZRAM Configuration"

# Configure ZRAM with LZ4 compression (4GB)
mkdir -p /etc/systemd
cat > /etc/systemd/zram-generator.conf << 'ZRAMEOF'
[zram0]
zram-size = min(ram, 4096)
compression-algorithm = lz4
ZRAMEOF

echo "::endgroup::"

echo "::group:: Kernel Hardening"

# Sysctl hardening
cat > /etc/sysctl.d/99-lateralus-hardening.conf << 'SYSCTLEOF'
# Restrict dmesg access to root
kernel.dmesg_restrict = 1

# Hide kernel pointers
kernel.kptr_restrict = 2

# Restrict ptrace
kernel.yama.ptrace_scope = 2

# Disable core dumps
fs.suid_dumpable = 0

# Network hardening
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
SYSCTLEOF

echo "::endgroup::"

# Restore default glob behavior
shopt -u nullglob

echo "Custom build complete!"
