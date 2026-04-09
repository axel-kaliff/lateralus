#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Branding: Plymouth boot splash, GRUB theme, COSMIC wallpaper
###############################################################################

echo "::group:: Install Plymouth Boot Theme"

# Install the Lateralus plymouth theme (Evergreen-branded spinner)
# Theme files are shipped in build/files/usr/share/plymouth/themes/lateralus/
THEME_DIR="/usr/share/plymouth/themes/lateralus"
mkdir -p "${THEME_DIR}"
cp /ctx/build/files/usr/share/plymouth/themes/lateralus/* "${THEME_DIR}"/

# Set as default plymouth theme
plymouth-set-default-theme lateralus

# Regenerate initramfs so the plymouth theme is baked in
# On bootc, the initramfs must be built during container image build
QUALIFIED_KERNEL="$(rpm -qa | grep -P 'kernel-(\d+\.\d+\.\d+)' | sed -E 's/kernel-//' | tail -n 1)"
/usr/bin/dracut \
    --no-hostonly \
    --kver "${QUALIFIED_KERNEL}" \
    --reproducible \
    --zstd \
    --add ostree \
    -f "/lib/modules/${QUALIFIED_KERNEL}/initramfs.img"

echo "::endgroup::"

echo "::group:: Configure COSMIC Wallpaper"

# Set Evergreen gradient as default COSMIC wallpaper (dark green gradient)
# COSMIC reads system defaults from /usr/share/cosmic/
BG_DIR="/usr/share/cosmic/com.system76.CosmicBackground/v1"
mkdir -p "${BG_DIR}"

cat > "${BG_DIR}/all" << 'BGEOF'
(
    output: "all",
    source: Color(Gradient((colors: [[0.04, 0.06, 0.04], [0.14, 0.20, 0.14]], radius: 180.0))),
    filter_by_theme: false,
    rotation_frequency: 3600,
    filter_method: Lanczos,
    scaling_mode: Zoom,
    sampling_method: Alphanumeric,
)
BGEOF

echo 'true' > "${BG_DIR}/same-on-all"
echo '[]' > "${BG_DIR}/backgrounds"

echo "::endgroup::"

echo "::group:: Install GRUB Theme"

# Ship GRUB theme in the image — a first-boot service copies it to /boot
# because /boot is a separate partition not available during container build
GRUB_SRC="/usr/share/lateralus/grub-theme"
mkdir -p "${GRUB_SRC}"
cp /ctx/build/files/usr/share/lateralus/grub-theme/* "${GRUB_SRC}"/

# Install the GRUB setup service and script
install -Dm755 /ctx/build/files/usr/libexec/lateralus-grub-setup /usr/libexec/lateralus-grub-setup
install -Dm644 /ctx/build/files/usr/lib/systemd/system/lateralus-grub-setup.service /usr/lib/systemd/system/lateralus-grub-setup.service
systemctl enable lateralus-grub-setup.service

echo "::endgroup::"

echo "Branding complete!"
