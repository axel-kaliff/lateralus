#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Install dotfiles and packages from github.com/axel-kaliff/dotfiles
###############################################################################

echo "::group:: Install System Packages"

# Packages available in Fedora repos (from dotfiles Brewfile)
dnf5 install -y \
    git \
    fish \
    bat \
    git-delta \
    fd-find \
    fzf \
    gcc \
    golang \
    lazygit \
    luarocks \
    neovim \
    nodejs \
    ripgrep \
    ruff \
    ShellCheck \
    stow \
    yazi \
    yq \
    zoxide \
    direnv \
    dust

echo "::endgroup::"

echo "::group:: Install Dotfiles to /etc/skel"

# Clone dotfiles into the image
git clone --depth 1 https://github.com/axel-kaliff/dotfiles.git /tmp/dotfiles

# Install dotfiles to /etc/skel/.config/ so all new users get them
# Stow target is ~/.config/, so we replicate that into /etc/skel/
mkdir -p /etc/skel/.config

# Copy all stow-managed config dirs (everything not in .stow-local-ignore)
cd /tmp/dotfiles
for dir in fish ghostty nvim zellij starship.toml lazygit yazi ripgrep atuin tealdeer; do
    if [ -e "$dir" ]; then
        cp -r "$dir" /etc/skel/.config/
    fi
done

# Copy bash config to skel home
cp /tmp/dotfiles/bash/.bashrc /etc/skel/.bashrc

# Copy the Brewfile and justfile for user-level setup
mkdir -p /etc/skel/.config/dotfiles
cp /tmp/dotfiles/Brewfile /etc/skel/.config/dotfiles/
cp /tmp/dotfiles/justfile /etc/skel/.config/dotfiles/

# Clean up
rm -rf /tmp/dotfiles

echo "::endgroup::"

echo "::group:: Set Fish as Default Shell"

# Add fish to /etc/shells if not present
grep -qxF '/home/linuxbrew/.linuxbrew/bin/fish' /etc/shells || echo '/home/linuxbrew/.linuxbrew/bin/fish' >> /etc/shells
grep -qxF '/usr/bin/fish' /etc/shells || echo '/usr/bin/fish' >> /etc/shells

echo "::endgroup::"

echo "Dotfiles and packages installed!"
