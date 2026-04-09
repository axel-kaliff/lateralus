#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Swap GNOME Desktop with COSMIC Desktop + Ghostty Terminal
###############################################################################
# Replaces GNOME with System76's COSMIC desktop and installs Ghostty terminal.
#
# COSMIC: https://github.com/pop-os/cosmic-epoch
# Ghostty: https://ghostty.org
###############################################################################

# Source helper functions
# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

echo "::group:: Install COSMIC Desktop"

# Install COSMIC desktop from System76's COPR
# Using isolated pattern to prevent COPR from persisting
copr_install_isolated "ryanabx/cosmic-epoch" \
    cosmic-session \
    cosmic-greeter \
    cosmic-comp \
    cosmic-panel \
    cosmic-launcher \
    cosmic-applets \
    cosmic-settings \
    cosmic-files \
    cosmic-edit \
    cosmic-term \
    cosmic-workspaces \
    xdg-desktop-portal-cosmic

echo "COSMIC desktop installed successfully"
echo "::endgroup::"

echo "::group:: Configure Display Manager"

# Enable cosmic-greeter (COSMIC's display manager)
systemctl enable cosmic-greeter

# COSMIC is Wayland-native — the cosmic-session package registers its own
# session file. No X11 session file needed.

echo "Display manager configured"
echo "::endgroup::"

echo "::group:: Install Additional Utilities"

# Install Ghostty terminal from COPR
copr_install_isolated "pgdev/ghostty" \
    ghostty

# Install additional utilities that work well with COSMIC
dnf5 install -y \
    flatpak

echo "Additional utilities installed"
echo "::endgroup::"

echo "::group:: Install COSMIC Community Applets"

# Community applets — install from COPR if available, skip gracefully if not
# These COPRs may not exist yet; the applets can be installed later from source
for applet_copr in "ryanabx/cosmic-epoch cosmic-ext-applet-clipboard-manager" "ryanabx/cosmic-epoch cosmic-ext-calculator"; do
    copr_name="${applet_copr%% *}"
    pkg="${applet_copr#* }"
    echo "Attempting to install ${pkg} from ${copr_name}..."
    copr_install_isolated "${copr_name}" "${pkg}" || echo "WARN: ${pkg} not available, skipping"
done

echo "::endgroup::"

echo "::group:: Set Ghostty as Default Terminal"

# Set Ghostty as default terminal via xdg-terminals.list
cat > /usr/share/xdg-terminals.list << 'TERMEOF'
ghostty
cosmic-term
TERMEOF

# Set default MIME associations
mkdir -p /usr/share/applications
cat > /usr/share/applications/mimeapps.list << 'MIMEEOF'
[Default Applications]
x-scheme-handler/terminal=ghostty.desktop
MIMEEOF

echo "::endgroup::"

echo "::group:: Configure Evergreen Theme"

# Evergreen dark theme for COSMIC
# Uses the Builder config ID — COSMIC derives the final theme from this
# System-wide defaults in /usr/share/cosmic/ — users can override in ~/.config/cosmic/
THEME_DIR="/usr/share/cosmic/com.system76.CosmicTheme.Dark.Builder/v1"
mkdir -p "${THEME_DIR}"

# Green accent color
echo 'Some((red: 0.30, green: 0.69, blue: 0.31))' > "${THEME_DIR}/accent"

# Green success color
echo 'Some((red: 0.40, green: 0.80, blue: 0.40))' > "${THEME_DIR}/success"

# Warm orange warning
echo 'Some((red: 0.90, green: 0.65, blue: 0.30))' > "${THEME_DIR}/warning"

# Red destructive
echo 'Some((red: 0.90, green: 0.35, blue: 0.35))' > "${THEME_DIR}/destructive"

# Green window hint
echo 'Some((red: 0.30, green: 0.69, blue: 0.31))' > "${THEME_DIR}/window_hint"

# Subtle green neutral tint for dark surfaces
echo 'Some((red: 0.30, green: 0.40, blue: 0.30))' > "${THEME_DIR}/neutral_tint"

# Dark green-tinted background
echo 'Some((red: 0.08, green: 0.10, blue: 0.08, alpha: 1.0))' > "${THEME_DIR}/bg_color"

# Container backgrounds with green tint
echo 'Some((red: 0.12, green: 0.15, blue: 0.12, alpha: 1.0))' > "${THEME_DIR}/primary_container_bg"
echo 'Some((red: 0.16, green: 0.20, blue: 0.16, alpha: 1.0))' > "${THEME_DIR}/secondary_container_bg"

# No frosted glass
echo 'false' > "${THEME_DIR}/is_frosted"

# Window gaps and active hint
echo '(0, 8)' > "${THEME_DIR}/gaps"
echo '3' > "${THEME_DIR}/active_hint"

# Full palette with evergreen tones
cat > "${THEME_DIR}/palette" << 'PALETTEEOF'
Dark((name:"Evergreen",bright_red:(red:0.90,green:0.35,blue:0.35,alpha:1.0),bright_green:(red:0.40,green:0.80,blue:0.40,alpha:1.0),bright_orange:(red:0.90,green:0.65,blue:0.30,alpha:1.0),gray_1:(red:0.09,green:0.11,blue:0.09,alpha:1.0),gray_2:(red:0.13,green:0.16,blue:0.13,alpha:1.0),neutral_0:(red:0.0,green:0.0,blue:0.0,alpha:1.0),neutral_1:(red:0.05,green:0.06,blue:0.05,alpha:1.0),neutral_2:(red:0.08,green:0.10,blue:0.08,alpha:1.0),neutral_3:(red:0.14,green:0.17,blue:0.14,alpha:1.0),neutral_4:(red:0.22,green:0.26,blue:0.22,alpha:1.0),neutral_5:(red:0.30,green:0.35,blue:0.30,alpha:1.0),neutral_6:(red:0.40,green:0.45,blue:0.40,alpha:1.0),neutral_7:(red:0.55,green:0.60,blue:0.55,alpha:1.0),neutral_8:(red:0.70,green:0.75,blue:0.70,alpha:1.0),neutral_9:(red:0.85,green:0.88,blue:0.85,alpha:1.0),neutral_10:(red:1.0,green:1.0,blue:1.0,alpha:1.0),accent_blue:(red:0.30,green:0.69,blue:0.31,alpha:1.0),accent_indigo:(red:0.40,green:0.60,blue:0.50,alpha:1.0),accent_purple:(red:0.50,green:0.45,blue:0.65,alpha:1.0),accent_pink:(red:0.75,green:0.45,blue:0.55,alpha:1.0),accent_red:(red:0.85,green:0.40,blue:0.40,alpha:1.0),accent_orange:(red:0.90,green:0.60,blue:0.25,alpha:1.0),accent_yellow:(red:0.85,green:0.80,blue:0.35,alpha:1.0),accent_green:(red:0.30,green:0.69,blue:0.31,alpha:1.0),accent_warm_grey:(red:0.55,green:0.50,blue:0.45,alpha:1.0),ext_warm_grey:(red:0.45,green:0.42,blue:0.38,alpha:1.0),ext_orange:(red:0.90,green:0.60,blue:0.25,alpha:1.0),ext_yellow:(red:0.85,green:0.80,blue:0.35,alpha:1.0),ext_blue:(red:0.30,green:0.60,blue:0.55,alpha:1.0),ext_purple:(red:0.50,green:0.45,blue:0.65,alpha:1.0),ext_pink:(red:0.75,green:0.35,blue:0.50,alpha:1.0),ext_indigo:(red:0.35,green:0.55,blue:0.50,alpha:1.0)))
PALETTEEOF

echo "Evergreen theme configured"
echo "::endgroup::"

echo "COSMIC desktop installation complete!"
echo "After booting, select 'COSMIC' session at the login screen"
