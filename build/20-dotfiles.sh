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
# Export NONINTERACTIVE before su to ensure it propagates
export NONINTERACTIVE=1
su - linuxbrew -c 'export NONINTERACTIVE=1; /usr/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'

# Make brew accessible
eval "$("${HOMEBREW_PREFIX}/bin/brew" shellenv)"

echo "::endgroup::"

echo "::group:: Setup Flatpak"

# Ensure flatpak is installed and Flathub remote is configured
dnf5 install -y flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

echo "::endgroup::"

echo "::group:: Install Brew Packages and Flatpaks"

# Install all packages from the dotfiles Brewfile
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

# Flatpaks
flatpak "app.zen_browser.zen"
flatpak "be.alexandervanhee.gradia"
flatpak "com.bitwarden.desktop"
flatpak "com.discordapp.Discord"
flatpak "com.github.PintaProject.Pinta"
flatpak "com.github.rafostar.Clapper"
flatpak "com.github.tchx84.Flatseal"
flatpak "com.github.unrud.VideoDownloader"
flatpak "com.obsproject.Studio"
flatpak "com.ranfdev.DistroShelf"
flatpak "com.slack.Slack"
flatpak "com.spotify.Client"
flatpak "de.schmidhuberj.DieBahn"
flatpak "dev.bragefuglseth.Keypunch"
flatpak "io.github.flattool.Ignition"
flatpak "io.github.flattool.Warehouse"
flatpak "io.github.nozwock.Packet"
flatpak "io.github.slgobinath.SafeEyes"
flatpak "io.gitlab.adhami3310.Impression"
flatpak "io.missioncenter.MissionCenter"
flatpak "io.podman_desktop.PodmanDesktop"
flatpak "it.mijorus.smile"
flatpak "md.obsidian.Obsidian"
flatpak "net.ankiweb.Anki"
flatpak "net.mullvad.MullvadBrowser"
flatpak "org.audacityteam.Audacity"
flatpak "org.chromium.Chromium"
flatpak "org.ferdium.Ferdium"
flatpak "org.gnome.FileRoller"
flatpak "org.gnome.Firmware"
flatpak "org.gnome.Loupe"
flatpak "org.gnome.Papers"
flatpak "org.inkscape.Inkscape"
flatpak "org.mozilla.Thunderbird"
flatpak "org.onlyoffice.desktopeditors"
flatpak "org.qbittorrent.qBittorrent"
flatpak "org.videolan.VLC"
flatpak "org.zotero.Zotero"
flatpak "page.tesk.Refine"
flatpak "re.sonny.Eloquent"
flatpak "us.zoom.Zoom"
flatpak "com.github.finefindus.eyedropper"
flatpak "com.usebottles.bottles"
flatpak "com.valvesoftware.Steam"
flatpak "org.gimp.GIMP"
BREWEOF

# Split Brewfile: brew packages run as linuxbrew, flatpaks run as root
grep -v '^flatpak ' /tmp/Brewfile > /tmp/Brewfile.brew
grep '^flatpak ' /tmp/Brewfile > /tmp/Brewfile.flatpak || true

# Install brew packages as linuxbrew user
chown linuxbrew:linuxbrew /tmp/Brewfile.brew
su - linuxbrew -c "${HOMEBREW_PREFIX}/bin/brew bundle --file=/tmp/Brewfile.brew --no-lock"

# Install flatpaks as root (requires system-level access)
while IFS= read -r line; do
    # Extract app ID from: flatpak "org.example.App"
    app_id=$(echo "$line" | sed 's/flatpak "\(.*\)"/\1/')
    echo "Installing flatpak: ${app_id}"
    flatpak install -y --noninteractive flathub "${app_id}" || echo "WARN: Failed to install ${app_id}, skipping"
done < /tmp/Brewfile.flatpak

rm -f /tmp/Brewfile /tmp/Brewfile.brew /tmp/Brewfile.flatpak

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
