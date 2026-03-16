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

echo "::group:: Remove GNOME Desktop"

# Remove GNOME Shell and related packages
dnf5 remove -y \
    gnome-shell \
    gnome-shell-extension* \
    gnome-terminal \
    gnome-software \
    gnome-control-center \
    nautilus \
    gdm

echo "GNOME desktop removed"
echo "::endgroup::"

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
    cosmic-workspaces

echo "COSMIC desktop installed successfully"
echo "::endgroup::"

echo "::group:: Configure Display Manager"

# Enable cosmic-greeter (COSMIC's display manager)
systemctl enable cosmic-greeter

# Set COSMIC as default session
mkdir -p /etc/X11/sessions
cat > /etc/X11/sessions/cosmic.desktop << 'COSMICDESKTOP'
[Desktop Entry]
Name=COSMIC
Comment=COSMIC Desktop Environment
Exec=cosmic-session
Type=Application
DesktopNames=COSMIC
COSMICDESKTOP

echo "Display manager configured"
echo "::endgroup::"

echo "::group:: Install Additional Utilities"

# Install Ghostty terminal from COPR
copr_install_isolated "pgdev/ghostty" \
    ghostty

# Install additional utilities that work well with COSMIC
dnf5 install -y \
    flatpak \
    xdg-desktop-portal-cosmic

echo "Additional utilities installed"
echo "::endgroup::"

echo "::group:: Install COSMIC Community Applets"

# Install COSMIC community applets from COPR
copr_install_isolated "ryanabx/cosmic-epoch" \
    cosmic-ext-applet-clipboard-manager \
    cosmic-ext-calculator

echo "COSMIC applets installed"
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
# System-wide defaults in /usr/share/cosmic/ — users can override in ~/.config/cosmic/
mkdir -p /usr/share/cosmic/com.system76.CosmicTheme.Dark/v1

cat > /usr/share/cosmic/com.system76.CosmicTheme.Dark/v1/accent << 'THEMEEOF'
(
    base: (
        red: 0.36,
        green: 0.72,
        blue: 0.36,
        alpha: 1.0,
    ),
)
THEMEEOF

cat > /usr/share/cosmic/com.system76.CosmicTheme.Dark/v1/palette << 'PALETTEEOF'
(
    name: "Evergreen",
    bright_green: (
        red: 0.40,
        green: 0.80,
        blue: 0.40,
        alpha: 1.0,
    ),
    bright_red: (
        red: 0.90,
        green: 0.35,
        blue: 0.35,
        alpha: 1.0,
    ),
    bright_orange: (
        red: 0.90,
        green: 0.65,
        blue: 0.30,
        alpha: 1.0,
    ),
    ext_warm_grey: (
        red: 0.22,
        green: 0.24,
        blue: 0.22,
        alpha: 1.0,
    ),
    ext_cool_grey: (
        red: 0.18,
        green: 0.20,
        blue: 0.19,
        alpha: 1.0,
    ),
    neutral_0: (
        red: 0.0,
        green: 0.0,
        blue: 0.0,
        alpha: 1.0,
    ),
    neutral_1: (
        red: 0.07,
        green: 0.09,
        blue: 0.07,
        alpha: 1.0,
    ),
    neutral_2: (
        red: 0.10,
        green: 0.13,
        blue: 0.10,
        alpha: 1.0,
    ),
    neutral_3: (
        red: 0.14,
        green: 0.17,
        blue: 0.14,
        alpha: 1.0,
    ),
    neutral_4: (
        red: 0.18,
        green: 0.22,
        blue: 0.18,
        alpha: 1.0,
    ),
    neutral_5: (
        red: 0.25,
        green: 0.30,
        blue: 0.25,
        alpha: 1.0,
    ),
    neutral_6: (
        red: 0.35,
        green: 0.40,
        blue: 0.35,
        alpha: 1.0,
    ),
    neutral_7: (
        red: 0.55,
        green: 0.60,
        blue: 0.55,
        alpha: 1.0,
    ),
    neutral_8: (
        red: 0.75,
        green: 0.78,
        blue: 0.75,
        alpha: 1.0,
    ),
    neutral_9: (
        red: 0.88,
        green: 0.90,
        blue: 0.88,
        alpha: 1.0,
    ),
    neutral_10: (
        red: 1.0,
        green: 1.0,
        blue: 1.0,
        alpha: 1.0,
    ),
)
PALETTEEOF

# Evergreen background config
mkdir -p /usr/share/cosmic/com.system76.CosmicBackground/v1

echo "Evergreen theme configured"
echo "::endgroup::"

echo "COSMIC desktop installation complete!"
echo "After booting, select 'COSMIC' session at the login screen"
