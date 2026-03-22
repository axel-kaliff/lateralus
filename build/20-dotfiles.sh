#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Install dotfiles and brew packages from github.com/axel-kaliff/dotfiles
###############################################################################

echo "::group:: Install Homebrew"

# Install Homebrew into /home/linuxbrew/.linuxbrew (standard ublue location)
# Need git and curl for the installer
dnf5 install -y git curl procps-ng

HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"

# Create the linuxbrew user via sysusers.d (rebase-safe, avoids /etc/passwd merge issues)
# The sysusers.d config at /usr/lib/sysusers.d/lateralus-homebrew.conf handles this
# at boot, but we need the user during build too
systemd-sysusers /usr/lib/sysusers.d/lateralus-homebrew.conf 2>/dev/null || useradd -r -d /home/linuxbrew linuxbrew 2>/dev/null || true
mkdir -p "${HOMEBREW_PREFIX}"
mkdir -p /home/linuxbrew
chown -R linuxbrew:linuxbrew /home/linuxbrew

# Install Homebrew as linuxbrew user (installer refuses root)
# Export NONINTERACTIVE before su to ensure it propagates
export NONINTERACTIVE=1
su - linuxbrew -c 'export NONINTERACTIVE=1; /usr/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'

# Make brew accessible
eval "$("${HOMEBREW_PREFIX}/bin/brew" shellenv)"

echo "::endgroup::"

echo "::group:: Install Brew Packages"

# Install all brew packages
cat > /tmp/Brewfile << 'BREWEOF'
# CLI tools (from dotfiles)
brew "gcc"
brew "fish"
brew "bat"
brew "delta"
brew "devcontainer"
brew "direnv"
brew "dust"
brew "dysk"
brew "eza"
brew "fd"
brew "fzf"
brew "gh"
brew "glab"
brew "go"
brew "just"
brew "lazygit"
brew "luarocks"
brew "neovim"
brew "node"
brew "ripgrep"
brew "ruff"
brew "shellcheck"
brew "starship"
brew "tealdeer"
brew "topgrade"
brew "trash-cli"
brew "ugrep"
brew "uv"
brew "yazi"
brew "yq"
brew "zellij"
brew "zoxide"
brew "atuin"
brew "stow"

# Dev tools (nvim LSP/lint/format dependencies)
brew "rust-analyzer"
brew "pyright"
brew "stylua"
brew "luacheck"
brew "markdownlint-cli"
brew "tree-sitter"

# System tools
brew "wl-clipboard"
brew "distrobox"

# AI/LLM
brew "ollama"

# Container tools
brew "dive"
brew "podman-compose"
brew "skopeo"

# Network tools
brew "nmap"
brew "bandwhich"
brew "trippy"

# Terminal productivity
brew "glow"
brew "slides"
brew "hyperfine"
brew "tokei"
brew "bottom"

# File sync/backup
brew "restic"
brew "rclone"

# Security
brew "age"
brew "sops"

# AI coding
brew "aider-chat"

# Modern CLI replacements
brew "sd"
brew "procs"
brew "xh"
brew "jq"
brew "jnv"
brew "doggo"
brew "watchexec"
brew "gum"
brew "vhs"

# Developer workflow
brew "mise"
brew "lazydocker"

# Nerd Fonts
cask "font-fira-code-nerd-font"
cask "font-jetbrains-mono-nerd-font"
cask "font-meslo-lg-nerd-font"
cask "font-hack-nerd-font"
BREWEOF

# Install brew packages as linuxbrew user
chown linuxbrew:linuxbrew /tmp/Brewfile
su - linuxbrew -c "${HOMEBREW_PREFIX}/bin/brew bundle --file=/tmp/Brewfile --no-lock"

rm -f /tmp/Brewfile

echo "::endgroup::"

echo "::group:: Package Homebrew for first-boot extraction"

# On ostree/bootc, /home is persistent /var/home — content placed there during
# build only appears on first-ever install, NOT on rebases. Ship the full brew
# installation as a tarball in /usr/share (immutable image layer) so it can be
# extracted reliably on any deployment via lateralus-brew-setup.service.
mkdir -p /usr/share/lateralus
tar --zstd -cf /usr/share/lateralus/homebrew.tar.zst -C / home/linuxbrew/.linuxbrew

# Clean up the build-time brew installation from /home (-> /var/home on ostree).
# On ostree, /var content from the image is only deployed on first install and ignored
# on rebases, so this copy is dead weight. The tarball in /usr/share is the reliable
# delivery mechanism. This also avoids bootc container lint warnings about /var content.
rm -rf /home/linuxbrew/.linuxbrew

echo "::endgroup::"

echo "::group:: Bundle Dotfiles for post-install stow"

# Clone dotfiles into the image for the user-setup service to deploy via stow
git clone --depth 1 https://github.com/axel-kaliff/dotfiles.git /usr/share/lateralus/dotfiles
rm -rf /usr/share/lateralus/dotfiles/.git

echo "::endgroup::"

echo "::group:: Configure Git"

# Set up git credential helper to use gh (GitHub CLI)
# After `gh auth login`, all git operations are automatically authenticated
# Uses command -v fallback so it works even if brew path changes
git config --system credential.helper '!command -v gh >/dev/null && gh auth git-credential || /home/linuxbrew/.linuxbrew/bin/gh auth git-credential'

# Pre-configure git identity and delta integration
git config --system user.name "Axel Kaliff"
git config --system user.email "axel.kaliff@protonmail.com"
git config --system core.pager delta
git config --system interactive.diffFilter "delta --color-only"
git config --system delta.navigate true
git config --system delta.side-by-side true
git config --system delta.line-numbers true

echo "::endgroup::"

echo "::group:: Set Fish as Default Shell"

# Add fish to /etc/shells
grep -qxF "${HOMEBREW_PREFIX}/bin/fish" /etc/shells || echo "${HOMEBREW_PREFIX}/bin/fish" >> /etc/shells

echo "::endgroup::"

echo "Dotfiles and brew packages installed!"
