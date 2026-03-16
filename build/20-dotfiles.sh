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

echo "::group:: Setup Flatpak"

# Ensure flatpak is installed and Flathub remote is configured
dnf5 install -y flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

echo "::endgroup::"

echo "::group:: Install Brew Packages and Flatpaks"

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

# Flatpaks (installed via brew at build time)
flatpak "app.zen_browser.zen"
flatpak "be.alexandervanhee.gradia"
flatpak "com.bitwarden.desktop"
flatpak "com.discordapp.Discord"
flatpak "com.github.PintaProject.Pinta"
flatpak "com.github.rafostar.Clapper"
flatpak "com.github.tchx84.Flatseal"
flatpak "com.github.unrud.VideoDownloader"
flatpak "com.mattjakeman.ExtensionManager"
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
flatpak "nl.hjdskes.gcolor3"
flatpak "org.audacityteam.Audacity"
flatpak "org.chromium.Chromium"
flatpak "org.ferdium.Ferdium"
flatpak "org.gnome.Calculator"
flatpak "org.gnome.Characters"
flatpak "org.gnome.clocks"
flatpak "org.gnome.Contacts"
flatpak "org.gnome.Decibels"
flatpak "org.gnome.FileRoller"
flatpak "org.gnome.Firmware"
flatpak "org.gnome.Loupe"
flatpak "org.gnome.Maps"
flatpak "org.gnome.NautilusPreviewer"
flatpak "org.gnome.NetworkDisplays"
flatpak "org.gnome.Papers"
flatpak "org.gnome.Snapshot"
flatpak "org.gnome.TextEditor"
flatpak "org.gnome.Weather"
flatpak "org.gustavoperedo.FontDownloader"
flatpak "org.inkscape.Inkscape"
flatpak "org.kde.dolphin"
flatpak "org.mozilla.Thunderbird"
flatpak "org.onlyoffice.desktopeditors"
flatpak "org.qbittorrent.qBittorrent"
flatpak "org.videolan.VLC"
flatpak "org.zotero.Zotero"
flatpak "page.tesk.Refine"
flatpak "re.sonny.Eloquent"
flatpak "us.zoom.Zoom"
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
