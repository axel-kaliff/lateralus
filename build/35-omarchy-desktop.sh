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
# perl-JSON-PP: omarchy-menu-select/-input build their Quickshell IPC payload
# with `perl -MJSON::PP`; Arch bundles JSON::PP in core perl, Fedora splits it.
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
    perl-JSON-PP \
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

# Pre-seed migration markers: a fresh install has nothing to migrate, so every
# shipped migration is marked done (upstream's installer does this via
# omarchy-provision-user --first-install, which nothing calls on lateralus).
# Without markers every login toasts "N pending migrations" and omarchy-migrate
# would replay years of Arch-era migrations against a pristine home.
install -d /etc/skel/.local/state/omarchy/migrations
for migration in /usr/share/omarchy/migrations/*.sh; do
    touch "/etc/skel/.local/state/omarchy/migrations/$(basename "${migration}")"
done

echo "::endgroup::"

echo "::group:: Default Keyboard Layouts (US + Swedish)"

# omedora-settings ships the skel input.lua fully commented; append an active
# override so every user seeded from skel gets both layouts. Existing users
# keep their own copy (lateralus-omarchy-user-setup never clobbers).
#
# No grp:* option here on purpose. Every Alt-based group toggle -- including
# grp:alts_toggle, which this used to set -- rebinds <RALT> to plain Alt_R,
# which destroys AltGr (ISO_Level3_Shift). US never notices, but on "se" every
# level-3 symbol lives behind AltGr: @ $ { [ ] } \ | ~ all stop working.
# The layout toggle is a keybinding instead, see the SUPER + SHIFT + SPACE
# bind appended to bindings.lua below.
cat >> /etc/skel/.config/hypr/input.lua << 'EOF'

-- Lateralus default: US + Swedish layouts, toggle with SUPER + SHIFT + SPACE.
hl.config({
  input = {
    kb_layout = "us,se",
    kb_options = "compose:caps,shift:both_capslock_cancel",
  },
})
EOF

echo "::endgroup::"

echo "::group:: Vim-Style Window Navigation"

# Same skel-append pattern as the layouts above: omedora-settings ships
# bindings.lua fully commented. SUPER + hjkl focuses, + SHIFT swaps. The three
# defaults that owned those keys move to the same key with ALT added, except
# SUPER + ALT + K (already the tmux cheatsheet), so the Omarchy keybindings
# menu takes SHIFT + ALT. Unbinds must precede the rebinds.
cat >> /etc/skel/.config/hypr/bindings.lua << 'EOF'

-- Lateralus default: vim-style window navigation.
hl.unbind("SUPER + J") -- was: Toggle window split
hl.unbind("SUPER + K") -- was: Keybindings
hl.unbind("SUPER + L") -- was: Toggle workspace layout

o.bind("SUPER + ALT + J", "Toggle window split", hl.dsp.layout("togglesplit"))
o.bind("SUPER + SHIFT + ALT + K", "Keybindings", "omarchy-menu-keybindings")
o.bind("SUPER + ALT + L", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")

o.bind("SUPER + H", "Focus on left window", hl.dsp.focus({ direction = "l" }))
o.bind("SUPER + J", "Focus on below window", hl.dsp.focus({ direction = "d" }))
o.bind("SUPER + K", "Focus on above window", hl.dsp.focus({ direction = "u" }))
o.bind("SUPER + L", "Focus on right window", hl.dsp.focus({ direction = "r" }))

o.bind("SUPER + SHIFT + H", "Swap window to the left", hl.dsp.window.swap({ direction = "l" }))
o.bind("SUPER + SHIFT + J", "Swap window down", hl.dsp.window.swap({ direction = "d" }))
o.bind("SUPER + SHIFT + K", "Swap window up", hl.dsp.window.swap({ direction = "u" }))
o.bind("SUPER + SHIFT + L", "Swap window to the right", hl.dsp.window.swap({ direction = "r" }))

-- Input language switching, replacing the Alt+Alt toggle that input.lua no
-- longer sets (it broke AltGr). The top-bar toggle it displaces moves to
-- SUPER + SHIFT + T.
hl.unbind("SUPER + SHIFT + SPACE") -- was: Toggle top bar
o.bind_toggle("SUPER + SHIFT + T", "Toggle top bar", "bar")
o.bind("SUPER + SHIFT + SPACE", "Next keyboard layout", "hyprctl switchxkblayout all next")
EOF

echo "::endgroup::"

echo "::group:: Laptop Panel Below External Monitors"

# Same skel-append pattern again. Hyprland resolves eDP-1 first (monitor ID 0),
# so putting auto-center-down on it leaves nothing to center against and the
# monitors land side by side. Inverting it works: pin eDP-1 as the anchor and
# let everything else auto-center above. Both rules reuse the file's own
# omarchy_monitor_scale local, so omarchy-hyprland-monitor-scaling (which only
# rewrites that one line) keeps working. Machines with no eDP-1 fall through
# the second rule; a desktop with several externals stacks them upward.
cat >> /etc/skel/.config/hypr/monitors.lua << 'EOF'

-- Lateralus default: the laptop panel sits centered below any external monitor.
hl.monitor({ output = "", mode = "preferred", position = "auto-center-up", scale = omarchy_monitor_scale })
hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = omarchy_monitor_scale })
EOF

echo "::endgroup::"

echo "::group:: Brew PATH for uwsm Sessions"

# uwsm recomposes the session environment at login (prepare-env.sh sources
# uwsm/env.d/* fragments) and exports its PATH into the systemd user manager,
# overriding the base's profile.d plumbing for GUI-launched apps. Without this
# fragment, omarchy menu -> ghostty -e nvim/lazygit can't find brew binaries.
# Users can override via ~/.config/uwsm/env.d/. (POSIX sh)
mkdir -p /usr/share/uwsm/env.d
cat > /usr/share/uwsm/env.d/50-lateralus-brew << 'UWSMBREWEOF'
# Append Homebrew to the uwsm session PATH (system binaries keep priority).
if [ -d /home/linuxbrew/.linuxbrew ]; then
  HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-/home/linuxbrew/.linuxbrew}"
  export HOMEBREW_PREFIX
  case ":${PATH}:" in
  *":${HOMEBREW_PREFIX}/bin:"*) ;;
  *) export PATH="${PATH}:${HOMEBREW_PREFIX}/bin:${HOMEBREW_PREFIX}/sbin" ;;
  esac
fi
UWSMBREWEOF

echo "::endgroup::"

echo "::group:: SSH Agent for uwsm Sessions"

# The base image's only SSH agent is GNOME's XDG autostart entry
# (/etc/xdg/autostart/gnome-keyring-ssh.desktop), which is
# OnlyShowIn=GNOME;Unity;MATE — so a Hyprland session gets no agent at all and
# SSH_AUTH_SOCK stays unset: passphrases re-prompt on every connection,
# AddKeysToAgent is a silent no-op, and hosts whose key is only ever offered by
# the agent fall through to password auth.
#
# gcr-ssh-agent.socket (from gcr, pulled in by gnome-keyring above) is
# the systemd-native replacement: its ExecStartPost exports SSH_AUTH_SOCK into
# the user manager environment, which uwsm sessions inherit because
# sockets.target is reached long before graphical-session.target. No desktop
# condition here — a sockets.target unit starts before uwsm imports
# XDG_CURRENT_DESKTOP, so ConditionEnvironment (used for the omarchy-* units
# above) would never match. Harmless under GNOME: gnome-keyring's autostart
# sets SSH_AUTH_SOCK later in session startup and keeps winning there.
systemctl --global enable gcr-ssh-agent.socket

# Belt-and-braces against preset re-application on ostree deploys: the base's
# 99-default-disable.preset is "disable *", which would drop the symlink above.
cat > /usr/lib/systemd/user-preset/45-lateralus-ssh-agent.preset << 'EOF'
enable gcr-ssh-agent.socket
EOF

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
# Hyprland sessions have no SSH agent without this (COSMIC/GNOME keyring
# autostarts are OnlyShowIn=<their own desktop>) — assert binary + enablement.
test -x /usr/libexec/gcr-ssh-agent
test -L /etc/systemd/user/sockets.target.wants/gcr-ssh-agent.socket
# The skel appends above land in files the omedora-settings RPM ships; a payload
# layout change would otherwise create a stray file and fail silently at login.
grep -q 'kb_layout = "us,se"' /etc/skel/.config/hypr/input.lua
# Active (non-comment) grp:* line only -- the skel ships a commented example
# that mentions grp:alts_toggle. Any Alt group toggle rebinds <RALT> and kills AltGr.
# Asserted through an if: a plain `! grep` is exempt from errexit, so it would
# report the problem by doing nothing at all.
if grep -qE '^[[:space:]]*[^-[:space:]].*grp:' /etc/skel/.config/hypr/input.lua; then
    echo "ERROR: active grp:* option in skel input.lua — it rebinds RALT and kills AltGr" >&2
    exit 1
fi
grep -q 'switchxkblayout all next' /etc/skel/.config/hypr/bindings.lua
grep -q 'o.bind("SUPER + H", "Focus on left window"' /etc/skel/.config/hypr/bindings.lua
grep -q 'position = "auto-center-up"' /etc/skel/.config/hypr/monitors.lua
# monitors.lua's fragment reuses the file's own omarchy_monitor_scale local
grep -q 'local omarchy_monitor_scale' /etc/skel/.config/hypr/monitors.lua
test -f /usr/share/uwsm/env.d/50-lateralus-brew
# No grep -q here: -q exits at first match and fc-list's remaining writes
# then die with SIGPIPE (exit 141), which pipefail turns into a build failure.
fc-list | grep -i 'JetBrainsMono Nerd Font' > /dev/null
# Minimum-version guard: the Quickshell shell + Lua configs need Hyprland 0.56+
rpm -q --qf '%{VERSION}' hyprland-no-session | grep -qE '^(0\.(5[6-9]|[6-9][0-9])|[1-9])'
# Every shipped migration must have a pre-seeded skel marker (fresh installs
# have nothing to migrate); count equality catches payload layout changes too.
[[ "$(find /usr/share/omarchy/migrations -maxdepth 1 -name '*.sh' | wc -l)" -gt 0 ]]
[[ "$(find /usr/share/omarchy/migrations -maxdepth 1 -name '*.sh' | wc -l)" == \
    "$(find /etc/skel/.local/state/omarchy/migrations -maxdepth 1 -name '*.sh' | wc -l)" ]]

echo "::endgroup::"

echo "Omarchy desktop installation complete!"
