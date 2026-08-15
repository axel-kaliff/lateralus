#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Omarchy v4 "Quattro" desktop (Hyprland + Quickshell) alongside COSMIC
###############################################################################
# Installs the Omarchy v4 experience via the omedora RPMs (MIT-licensed Fedora
# adaptation of basecamp/omarchy, tracking upstream v4) from COPR
# agaspar/omedora-4, plus the Hyprland stack the official Fedora repos no
# longer carry.
#
# Design decisions (see README "Omarchy" section):
#   - Runs AFTER 30-cosmic-desktop.sh (COSMIC stays installed, sessions
#     coexist) and BEFORE 40-branding.sh (Plymouth/dracut runs last, so the
#     lateralus boot splash always wins — the omarchy Plymouth theme ships in
#     the payload but is never set as default).
#   - SDDM becomes the default display manager (Omarchy v4's own login flow);
#     cosmic-greeter stays installed and switchable via ujust omarchy-greeter.
#   - Ghostty (built in script 30) stays the default terminal.
#   - Update subsystem is remapped to bootc/brew/flatpak via the overrides
#     overlay in /usr/share/lateralus/omarchy-overrides (installed below).
#   - Deliberately NOT installed:
#       omedora-nerd-fonts        (326 MB; 20-dotfiles.sh already ships
#                                  JetBrainsMono Nerd Font, the family omarchy
#                                  configs reference)
#       hyprland-uwsm,
#       hyprland-omedora          (duplicate/conflicting wayland-session files;
#                                  omedora-settings ships omedora.desktop)
#       starship via brew         (installed as RPM below so the shell prompt
#                                  works before first-boot brew finishes)
#       lazygit/lazydocker/mise   (brew — CLI channel)
#       satty                     (replaced by tensaku in v4)
#       snapper/limine            (bootc image rollback replaces snapshots;
#                                  omarchy-snapshot exits 127 without snapper,
#                                  which omarchy-update treats as "deliberately
#                                  absent")
#       localsend                 (flatpak; firewalld service def shipped below)
#       XR/experimental packages  (monado*, hypxr*, voxtype accel variants)
#       omarchy-nvim              (needs network Lazy-sync at build; LazyVim is
#                                  user-space — deferred)
#
# Omarchy: https://omarchy.org  ·  omedora: https://github.com/AndrewGaspar/omedora
###############################################################################

# Source helper functions
# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

echo "::group:: Install Official-Repo Packages for Omarchy"

# Everything Omarchy needs that official Fedora 44 carries. install_weak_deps
# is globally 0, so runtime companions must be listed explicitly even when
# they are "usually there" (e.g. mesa-dri-drivers is only a Recommends of
# hyprland — without it Hyprland falls back to software rendering).
# chromium is a deliberate RPM exception to the "GUI apps are flatpaks" rule:
# Flatpak Chromium groups all --app windows under one window class, which
# breaks Omarchy's per-webapp window matching (flathub/org.chromium.Chromium#216).
dnf5 install -y \
    sddm \
    sddm-wayland-generic \
    xdg-desktop-portal-gtk \
    xdg-terminal-exec \
    xdg-user-dirs \
    xdg-utils \
    mesa-dri-drivers \
    foot \
    tmux \
    grim \
    slurp \
    wtype \
    brightnessctl \
    ddcutil \
    pamixer \
    libnotify \
    inotify-tools \
    socat \
    plocate \
    tesseract \
    tesseract-langpack-eng \
    zbar \
    qrencode \
    ImageMagick \
    yt-dlp \
    mpv \
    mpv-mpris \
    imv \
    nautilus \
    nautilus-python \
    sushi \
    ffmpegthumbnailer \
    gvfs-mtp \
    gvfs-smb \
    gvfs-nfs \
    udiskie \
    fcitx5 \
    fcitx5-gtk \
    fcitx5-qt \
    gnome-keyring \
    bluez-tools \
    bolt \
    fprintd \
    alsa-utils \
    pipewire-utils \
    btop \
    fastfetch \
    yaru-icon-theme \
    liberation-fonts \
    google-noto-color-emoji-fonts \
    google-noto-naskh-arabic-fonts \
    google-noto-nastaliq-urdu-fonts \
    chromium

echo "::endgroup::"

echo "::group:: Install Omarchy/Hyprland Stack from COPR (isolated)"

# agaspar/omedora-4 — adapted Omarchy v4 payload + the Hyprland 0.56 stack.
# Hard deps of omedora auto-pull: omedora-settings, quickshell (at Omarchy's
# exact commit pin), uwsm, hyprland-no-session, aquamarine/hypr* libs, gum,
# jq, fzf, foot. Those CLI tools must be RPM (not brew): omarchy scripts and
# the Quickshell shell exec them in contexts where brew isn't on PATH yet.
copr_install_isolated "agaspar/omedora-4" \
    omedora \
    hyprland \
    xdg-desktop-portal-hyprland \
    hyprland-guiutils \
    hyprland-preview-share-picker \
    hyprpicker \
    hyprsunset \
    gpu-screen-recorder \
    starship \
    herdr \
    tensaku \
    ttfx \
    omacalc \
    omacut \
    omawrite \
    voxtype

echo "::endgroup::"

echo "::group:: Configure SDDM (Omarchy greeter)"

# Vendor config in /usr/lib (repo convention — /etc is user-owned on ostree;
# SDDM reads /usr/lib/sddm/sddm.conf.d before /etc/sddm.conf.d).
install -Dm644 /ctx/build/files/usr/lib/sddm/sddm.conf.d/10-lateralus-wayland.conf \
    /usr/lib/sddm/sddm.conf.d/10-lateralus-wayland.conf
install -Dm644 /ctx/build/files/usr/lib/sddm/sddm.conf.d/20-lateralus-theme.conf \
    /usr/lib/sddm/sddm.conf.d/20-lateralus-theme.conf

# Surface the Omarchy SDDM theme + greeter compositor config where the
# sddm.conf.d files expect them (payload lives under /usr/share/omarchy).
mkdir -p /usr/share/sddm/themes
ln -sfn /usr/share/omarchy/default/sddm/omarchy /usr/share/sddm/themes/omarchy
ln -sfn /usr/share/omarchy/default/sddm/hyprland.lua /usr/share/sddm/hyprland.lua

# Fedora's sddm RPM ships a sysusers.d entry for the sddm user. Assert, and
# self-heal if a future package change drops it (never useradd at build on
# ostree — sysusers materialize the user at first boot).
if ! grep -rqsE '^u[[:space:]]+sddm([[:space:]]|$)' /usr/lib/sysusers.d/; then
    cat > /usr/lib/sysusers.d/lateralus-sddm.conf << 'EOF'
u sddm - "SDDM display manager" /var/lib/sddm
EOF
fi

echo "::endgroup::"

echo "::group:: Switch Display Manager to SDDM"

# Both cosmic-greeter.service and sddm.service alias display-manager.service;
# release the alias held by script 30 first or the enable fails.
# Switch back at runtime with: ujust omarchy-greeter cosmic
systemctl disable cosmic-greeter.service
systemctl enable sddm.service

# lateralus-greeter-groups (enabled in script 30) now also covers the sddm
# user — see build/files/usr/libexec/lateralus-greeter-groups.

echo "::endgroup::"

echo "::group:: Keep Ghostty the Default Terminal"

# All Omarchy terminal launches route through xdg-terminal-exec (Super+Return,
# TUI menu entries). Inside a Hyprland session the desktop-specific list wins,
# and omedora-settings ships it with only foot — overwrite both lists with
# Ghostty first. Ghostty's desktop ID is asserted in the smoke checks below.
cat > /usr/share/xdg-terminal-exec/hyprland-xdg-terminals.list << 'EOF'
# Terminal preference order for xdg-terminal-exec in Hyprland sessions.
# Users override via ~/.config/xdg-terminals.list (omarchy default terminal <x>).
com.mitchellh.ghostty.desktop
foot.desktop
EOF

cat > /usr/share/xdg-terminals.list << 'EOF'
com.mitchellh.ghostty.desktop
foot.desktop
com.system76.CosmicTerm.desktop
EOF

# Seed the per-user preference for new users too (settings skel doesn't ship one)
install -Dm644 /usr/share/xdg-terminal-exec/hyprland-xdg-terminals.list \
    /etc/skel/.config/xdg-terminals.list

echo "::endgroup::"

echo "::group:: Chromium Compat Shims"

# Omarchy scripts hardcode Arch's names (chromium binary, chromium.desktop);
# Fedora ships chromium-browser. Shim rather than patch a dozen scripts.
test -x /usr/bin/chromium-browser
if [ ! -e /usr/bin/chromium ]; then
    ln -s /usr/bin/chromium-browser /usr/bin/chromium
fi
if [ ! -e /usr/share/applications/chromium.desktop ] &&
    [ -f /usr/share/applications/chromium-browser.desktop ]; then
    ln -s chromium-browser.desktop /usr/share/applications/chromium.desktop
fi

echo "::endgroup::"

echo "::group:: Scope Omarchy User Units to Hyprland Sessions"

# omedora-settings ships user units WantedBy=graphical-session.target with no
# desktop condition — they would also start under COSMIC. uwsm sets
# XDG_CURRENT_DESKTOP=Hyprland (omedora.desktop: uwsm start ... -D Hyprland)
# and imports it into the user manager before graphical-session.target, so
# this condition scopes them cleanly. Under COSMIC the variable is COSMIC (or
# unset) and the units are skipped.
shopt -s nullglob
for unit in /usr/lib/systemd/user/omarchy-*.service /usr/lib/systemd/user/bt-agent.service; do
    dropin_dir="${unit}.d"
    mkdir -p "${dropin_dir}"
    cat > "${dropin_dir}/50-lateralus-hyprland-only.conf" << 'EOF'
# Installed by lateralus (build/35-omarchy-desktop.sh):
# don't start Omarchy session services under COSMIC.
[Unit]
ConditionEnvironment=XDG_CURRENT_DESKTOP=Hyprland
EOF
done

# limine/snapper don't exist on bootc — drop the notifier so it can't error
# at login (bootc deployments are the rollback mechanism).
rm -f /etc/skel/.config/autostart/limine-snapper-notify.desktop

# Same scoping for XDG autostart entries seeded from /etc/skel (fcitx5 etc.):
# systemd's xdg-autostart-generator honors OnlyShowIn.
for desktop in /etc/skel/.config/autostart/*.desktop; do
    grep -q '^OnlyShowIn=' "${desktop}" || echo 'OnlyShowIn=Hyprland;' >> "${desktop}"
done
shopt -u nullglob

echo "::endgroup::"

echo "::group:: Install Lateralus Omarchy Integration"

# First-boot per-user config seeding + conditional SDDM autologin
install -Dm755 /ctx/build/files/usr/libexec/lateralus-omarchy-user-setup /usr/libexec/lateralus-omarchy-user-setup
install -Dm755 /ctx/build/files/usr/libexec/lateralus-omarchy-autologin /usr/libexec/lateralus-omarchy-autologin
install -Dm755 /ctx/build/files/usr/libexec/lateralus-sddm-autologin /usr/libexec/lateralus-sddm-autologin
install -Dm755 /ctx/build/files/usr/libexec/lateralus-update-flag /usr/libexec/lateralus-update-flag
install -Dm644 /ctx/build/files/usr/lib/systemd/system/lateralus-omarchy-setup.service /usr/lib/systemd/system/lateralus-omarchy-setup.service
install -Dm644 /ctx/build/files/usr/lib/systemd/system/lateralus-omarchy-autologin.service /usr/lib/systemd/system/lateralus-omarchy-autologin.service
systemctl enable lateralus-omarchy-setup.service
systemctl enable lateralus-omarchy-autologin.service

# firewalld service definition for LocalSend (Omarchy expects ufw; lateralus
# keeps firewalld). Enable with: firewall-cmd --permanent --add-service=localsend
install -Dm644 /ctx/build/files/usr/lib/firewalld/services/localsend.xml \
    /usr/lib/firewalld/services/localsend.xml

# Overrides overlay: remap the pacman/snapper update subsystem to
# bootc/brew/flatpak. The omarchy dispatcher execs subcommands by absolute
# path from its own directory, so PATH shadowing can't intercept them — the
# binaries must be replaced. On bootc RPMs never change at runtime, so
# install-over-RPM at build time is deterministic on every rebuild.
# Sources stay visible in /usr/share/lateralus/omarchy-overrides for docs.
mkdir -p /usr/share/lateralus
cp -r /ctx/build/files/usr/share/lateralus/omarchy-overrides /usr/share/lateralus/omarchy-overrides
for override in /usr/share/lateralus/omarchy-overrides/bin/*; do
    install -m755 "${override}" "/usr/bin/$(basename "${override}")"
done

# Note: omedora-settings ships /etc drop-ins (sysctl, logind, resolved, oomd,
# sudoers) reviewed and accepted as-is. Judgment call kept Omarchy-authentic:
# logind HandlePowerKey=ignore applies system-wide (also COSMIC) — drop with
# `rm -f /etc/systemd/logind.conf.d/10-ignore-power-button.conf` if unwanted.

echo "::endgroup::"

echo "::group:: Record Manifest + Smoke Checks"

# Manifest for supportability — the COPR is unpinned (it is itself a curated
# pin of omarchy v4), so record exactly what each build shipped.
rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' \
    'omedora*' 'hypr*' 'quickshell*' 'uwsm*' 'sddm*' chromium foot | sort \
    > /usr/share/lateralus/omarchy-build-manifest.txt
cat /usr/share/lateralus/omarchy-build-manifest.txt

# Cheap in-container assertions — fail the build here, not in a VM.
rpm -q omedora omedora-settings hyprland hyprland-no-session quickshell uwsm \
    sddm sddm-wayland-generic xdg-desktop-portal-hyprland chromium foot starship
test -x /usr/bin/Hyprland
test -x /usr/bin/start-hyprland
test -x /usr/bin/omarchy-menu
test -x /usr/bin/uwsm
test -f /usr/share/wayland-sessions/omedora.desktop
test -f /usr/share/wayland-sessions/hyprland.desktop # omedora.desktop Exec needs it
test -f /usr/share/wayland-sessions/cosmic.desktop   # COSMIC must survive
test -e /usr/share/sddm/themes/omarchy
test -e /usr/share/sddm/hyprland.lua
test -f /usr/share/applications/com.mitchellh.ghostty.desktop # terminal-list ID
[[ "$(readlink /etc/systemd/system/display-manager.service)" == *sddm.service ]]
[[ "$(grep -v '^#' /usr/share/xdg-terminal-exec/hyprland-xdg-terminals.list | head -n1)" == "com.mitchellh.ghostty.desktop" ]]
grep -rqs 'sddm' /usr/lib/sysusers.d/
# No grep -q here: -q exits at first match and fc-list's remaining writes
# then die with SIGPIPE (exit 141), which pipefail turns into a build failure.
fc-list | grep -i 'JetBrainsMono Nerd Font' > /dev/null
# Minimum-version guard: the Quickshell shell + Lua configs need Hyprland 0.56+
rpm -q --qf '%{VERSION}' hyprland-no-session | grep -qE '^(0\.(5[6-9]|[6-9][0-9])|[1-9])'

echo "::endgroup::"

echo "Omarchy desktop installation complete!"
