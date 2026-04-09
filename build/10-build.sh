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

# Copy flatpak install list to /usr/share (immutable image layer)
# Read by lateralus-flatpak-setup.service on first boot and after rebases
mkdir -p /usr/share/lateralus
cp /ctx/custom/flatpaks/install.list /usr/share/lateralus/flatpaks.list

# Copy Quadlet container definitions
cp -r /ctx/build/files/usr/share/lateralus/quadlets /usr/share/lateralus/quadlets

echo "::endgroup::"

echo "::group:: Install Packages"

# System packages
dnf5 install -y \
    fwupd \
    power-profiles-daemon \
    bluez \
    firewalld \
    zram-generator \
    gtk4-layer-shell \
    rsync \
    wl-clipboard \
    gcc \
    plymouth-plugin-script

# Tailscale - official repo
dnf5 config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
dnf5 install -y tailscale
rm -f /etc/yum.repos.d/tailscale.repo

echo "::endgroup::"

echo "::group:: Install Lateralus Setup Scripts"

# Install rebase-safe setup scripts and services
install -Dm755 /ctx/build/files/usr/libexec/lateralus-brew-setup /usr/libexec/lateralus-brew-setup
install -Dm755 /ctx/build/files/usr/libexec/lateralus-user-setup /usr/libexec/lateralus-user-setup
install -Dm755 /ctx/build/files/usr/libexec/lateralus-flatpak-setup /usr/libexec/lateralus-flatpak-setup
install -Dm644 /ctx/build/files/usr/lib/systemd/system/lateralus-brew-setup.service /usr/lib/systemd/system/lateralus-brew-setup.service
install -Dm644 /ctx/build/files/usr/lib/systemd/system/lateralus-user-setup.service /usr/lib/systemd/system/lateralus-user-setup.service
install -Dm644 /ctx/build/files/usr/lib/systemd/system/lateralus-flatpak-setup.service /usr/lib/systemd/system/lateralus-flatpak-setup.service
install -Dm644 /ctx/build/files/usr/lib/tmpfiles.d/lateralus-homebrew.conf /usr/lib/tmpfiles.d/lateralus-homebrew.conf
install -Dm644 /ctx/build/files/usr/lib/sysusers.d/lateralus-homebrew.conf /usr/lib/sysusers.d/lateralus-homebrew.conf
install -Dm644 /ctx/build/files/usr/lib/systemd/system/lateralus-auto-upgrade.service /usr/lib/systemd/system/lateralus-auto-upgrade.service
install -Dm644 /ctx/build/files/usr/lib/systemd/system/lateralus-auto-upgrade.timer /usr/lib/systemd/system/lateralus-auto-upgrade.timer

echo "::endgroup::"

echo "::group:: System-wide Brew PATH"

# Ensure brew is in PATH for all users regardless of their shell config
# This is critical for existing users who rebase onto this image
# Pattern from ublue-os/brew: only interactive shells, append (not prepend) to PATH
# so system binaries always take priority over brew-installed ones
#
# Bash: /etc/profile sources /etc/profile.d/*.sh (Fedora default).
#       ostree 3-way-merges /etc on rebase, so build-time files persist fine.
# Fish: brew-installed fish reads /usr/share/fish/vendor_conf.d/ (XDG vendor path).
mkdir -p /etc/profile.d
cat > /etc/profile.d/lateralus-brew.sh << 'BREWPATHEOF'
# Add Homebrew to PATH for all users (interactive shells only)
# Appends to PATH so system binaries take priority — prevents issues like
# brew's p11-kit breaking Flatpak apps (ublue-os/bluefin#687)
if [[ -d /home/linuxbrew/.linuxbrew && $- == *i* ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv | grep -Ev '\bPATH=')"
    HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
    export PATH="${PATH}:${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin"
fi
BREWPATHEOF

mkdir -p /usr/share/fish/vendor_conf.d
cat > /usr/share/fish/vendor_conf.d/lateralus-brew.fish << 'FISHBREWEOF'
# Add Homebrew to PATH for all fish users (interactive shells only)
# Appends to PATH so system binaries take priority
if test -d /home/linuxbrew/.linuxbrew; and status is-interactive
    eval (/home/linuxbrew/.linuxbrew/bin/brew shellenv | string match -rv '\bPATH=')
    set -gx HOMEBREW_PREFIX /home/linuxbrew/.linuxbrew
    fish_add_path -aP $HOMEBREW_PREFIX/bin $HOMEBREW_PREFIX/sbin
end
FISHBREWEOF

echo "::endgroup::"

echo "::group:: System Configuration"

# Enable/disable systemd services
systemctl enable podman.socket
systemctl enable tailscaled
systemctl enable bluetooth
systemctl enable power-profiles-daemon
systemctl enable fwupd-refresh.timer
systemctl enable firewalld
systemctl enable lateralus-brew-setup.service
systemctl enable lateralus-user-setup.service
systemctl enable lateralus-flatpak-setup.service
systemctl enable lateralus-auto-upgrade.timer
systemctl enable podman-auto-update.timer

# Pre-enable user services for new users via /etc/skel
mkdir -p /etc/skel/.config/systemd/user/default.target.wants
ln -sf /usr/lib/systemd/user/tailscale-systray.service /etc/skel/.config/systemd/user/default.target.wants/tailscale-systray.service

echo "::endgroup::"

echo "::group:: ZRAM Configuration"

# Configure ZRAM with LZ4 compression (4GB)
# Use /usr/lib path (immutable layer) — /etc is user-owned state on ostree
mkdir -p /usr/lib/systemd
cat > /usr/lib/systemd/zram-generator.conf << 'ZRAMEOF'
[zram0]
zram-size = min(ram, 4096)
compression-algorithm = lz4
ZRAMEOF

echo "::endgroup::"

echo "::group:: Kernel Hardening"

# Sysctl hardening
# Use /usr/lib path (immutable layer) — /etc is user-owned state on ostree
mkdir -p /usr/lib/sysctl.d
cat > /usr/lib/sysctl.d/99-lateralus-hardening.conf << 'SYSCTLEOF'
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

echo "::group:: OS Release Branding"

# Customize /usr/lib/os-release so GRUB boot entries show "Lateralus"
# BLS entry titles in /boot/loader/entries/ are derived from PRETTY_NAME
# IMPORTANT: Do NOT copy to /etc/os-release — on Fedora it's a symlink to
# ../usr/lib/os-release. Breaking that symlink causes ostree 3-way merge
# failures during rebase, which can prevent the deployment from booting.
if [ -f /usr/lib/os-release ]; then
    sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Lateralus (Fedora Linux)"/' /usr/lib/os-release
    sed -i 's/^VARIANT=.*/VARIANT="Lateralus"/' /usr/lib/os-release
    grep -q '^VARIANT=' /usr/lib/os-release || echo 'VARIANT="Lateralus"' >> /usr/lib/os-release
    grep -q '^VARIANT_ID=' /usr/lib/os-release || echo 'VARIANT_ID=lateralus' >> /usr/lib/os-release
fi

echo "::endgroup::"

# Restore default glob behavior
shopt -u nullglob

echo "Custom build complete!"
