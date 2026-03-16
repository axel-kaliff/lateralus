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

# Create the linuxbrew user and directory structure
useradd -m -d /home/linuxbrew linuxbrew 2>/dev/null || true
mkdir -p "${HOMEBREW_PREFIX}"
chown -R linuxbrew:linuxbrew /home/linuxbrew

# Install Homebrew as linuxbrew user (installer refuses root)
su - linuxbrew -c 'NONINTERACTIVE=1 /usr/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'

# Make brew accessible
eval "$("${HOMEBREW_PREFIX}/bin/brew" shellenv)"

echo "::endgroup::"

echo "::group:: Install Brew Packages"

# Install all packages from the dotfiles Brewfile
cat > /tmp/Brewfile << 'BREWEOF'
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
BREWEOF

chown linuxbrew:linuxbrew /tmp/Brewfile
su - linuxbrew -c "${HOMEBREW_PREFIX}/bin/brew bundle --file=/tmp/Brewfile --no-lock"
rm -f /tmp/Brewfile

echo "::endgroup::"

echo "::group:: Install Dotfiles to /etc/skel"

# Clone dotfiles into the image
git clone --depth 1 https://github.com/axel-kaliff/dotfiles.git /tmp/dotfiles

# Install dotfiles to /etc/skel/.config/ so all new users get them
mkdir -p /etc/skel/.config

# Copy all stow-managed config dirs
cd /tmp/dotfiles
for dir in fish ghostty nvim zellij starship.toml lazygit yazi ripgrep atuin tealdeer; do
    if [ -e "$dir" ]; then
        cp -r "$dir" /etc/skel/.config/
    fi
done

# Copy bash config to skel home
cp /tmp/dotfiles/bash/.bashrc /etc/skel/.bashrc

# Copy the Brewfile and justfile for user-level updates
mkdir -p /etc/skel/.config/dotfiles
cp /tmp/dotfiles/Brewfile /etc/skel/.config/dotfiles/
cp /tmp/dotfiles/justfile /etc/skel/.config/dotfiles/

# Clean up
rm -rf /tmp/dotfiles

echo "::endgroup::"

echo "::group:: Set Fish as Default Shell"

# Add fish to /etc/shells
grep -qxF "${HOMEBREW_PREFIX}/bin/fish" /etc/shells || echo "${HOMEBREW_PREFIX}/bin/fish" >> /etc/shells

echo "::endgroup::"

echo "Dotfiles and brew packages installed!"
