#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Nerd Fonts, dotfiles bundle, and system-wide git/shell configuration
###############################################################################
# Homebrew and brew packages are NOT installed here — they are handled
# entirely at first boot by lateralus-brew-setup.service. This keeps the
# OCI image small and decouples brew package updates from image rebuilds.
###############################################################################

echo "::group:: Install Build Dependencies"

# git: clone dotfiles repo, curl: download Nerd Font releases
dnf5 install -y git curl

echo "::endgroup::"

echo "::group:: Install Nerd Fonts"

# Homebrew casks are macOS-only — install nerd fonts directly from GitHub releases
NERD_FONTS_VERSION="v3.4.0"
FONT_DIR="/usr/share/fonts/nerd-fonts"
mkdir -p "${FONT_DIR}"

for font in FiraCode JetBrainsMono Meslo Hack; do
    echo "Installing ${font} Nerd Font..."
    curl -fsSL --connect-timeout 30 --max-time 120 \
        "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}/${font}.tar.xz" \
        -o "/tmp/${font}.tar.xz"
    mkdir -p "${FONT_DIR}/${font}"
    tar -xf "/tmp/${font}.tar.xz" -C "${FONT_DIR}/${font}"
    rm -f "/tmp/${font}.tar.xz"
done

# Rebuild font cache
fc-cache -f "${FONT_DIR}"

echo "::endgroup::"

echo "::group:: Bundle Dotfiles for post-install stow"

# Clone dotfiles into the image for the user-setup service to deploy via stow
git clone --depth 1 https://github.com/axel-kaliff/dotfiles.git /usr/share/lateralus/dotfiles
rm -rf /usr/share/lateralus/dotfiles/.git

echo "::endgroup::"

echo "::group:: Configure Git"

HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"

# Set up git credential helper to use gh (GitHub CLI)
# After `gh auth login`, all git operations are automatically authenticated
# Uses command -v fallback so it works even if brew path changes
git config --system credential.helper '!command -v gh >/dev/null && gh auth git-credential || /home/linuxbrew/.linuxbrew/bin/gh auth git-credential'

# Configure delta as system-wide pager (tools, not identity)
# Identity (user.name, user.email) belongs in per-user dotfiles, not system config
git config --system core.pager delta
git config --system interactive.diffFilter "delta --color-only"
git config --system delta.navigate true
git config --system delta.side-by-side true
git config --system delta.line-numbers true

echo "::endgroup::"

echo "::group:: Set Fish as Default Shell"

# Add fish to /etc/shells — the binary is installed post-boot by brew,
# but the path must be registered at build time so chsh works immediately
grep -qxF "${HOMEBREW_PREFIX}/bin/fish" /etc/shells || echo "${HOMEBREW_PREFIX}/bin/fish" >> /etc/shells

echo "::endgroup::"

echo "Dotfiles and fonts installed!"
