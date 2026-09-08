#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Pomodoro — Quickshell bar plugin seeded into /etc/skel
###############################################################################
# `pneuma.pomodoro` is a third-party Omarchy shell plugin (service + bar-widget
# kinds) that puts a focus timer with a live countdown on the bar. Design
# decisions:
#   - It ships as a plugin under ~/.config/omarchy/plugins/ rather than being
#     patched into the omedora payload: user-space plugins survive an omedora
#     version bump untouched, and `omarchy plugin disable` turns it off without
#     touching the image.
#   - The timer engine is a `service` kind, so the shell instantiates exactly
#     one per session. A bar surface exists per monitor, so an engine living in
#     the bar widget would run one timer per screen and fire duplicate
#     completion notifications on any multi-monitor setup.
#   - Only /etc/skel's shell.json gains the bar entry. Existing users keep
#     whatever bar layout they already have (lateralus-omarchy-user-setup is
#     strictly no-clobber); they opt in with `omarchy plugin enable
#     pneuma.pomodoro`.
###############################################################################

PLUGIN_ID=pneuma.pomodoro
PLUGIN_DIR="/etc/skel/.config/omarchy/plugins/${PLUGIN_ID}"
SKEL_SHELL_JSON=/etc/skel/.config/omarchy/shell.json

echo "::group:: Install the pomodoro bar plugin into /etc/skel"

install -d "${PLUGIN_DIR}"
for asset in manifest.json Service.qml BarWidget.qml Model.js README.md; do
    install -Dm644 "/ctx/build/files/etc/skel/.config/omarchy/plugins/${PLUGIN_ID}/${asset}" \
        "${PLUGIN_DIR}/${asset}"
done

echo "::endgroup::"

echo "::group:: Enable the widget on the skel bar"

# A bar widget's enablement IS its layout entry — the top-level plugins[] array
# stays empty, which is expected and not a failed install. Prepending to the
# right section puts it left of the tray. Guarded so a re-run (or a future
# omedora-settings skel that ships it) does not duplicate the entry.
jq --arg id "${PLUGIN_ID}" '
    .bar.layout.right |= (
        if any(.[]; .id == $id) then . else [{"id": $id}] + . end
    )
' "${SKEL_SHELL_JSON}" >"${SKEL_SHELL_JSON}.new"
mv "${SKEL_SHELL_JSON}.new" "${SKEL_SHELL_JSON}"
chmod 644 "${SKEL_SHELL_JSON}"

echo "::endgroup::"

echo "::group:: Smoke checks"

# The manifest is what the shell's PluginRegistry validates; a malformed one
# means a silently missing widget rather than a build failure, so assert here.
jq -e --arg id "${PLUGIN_ID}" '
    .schemaVersion == 1 and .id == $id
    and (.kinds | index("service")) and (.kinds | index("bar-widget"))
' "${PLUGIN_DIR}/manifest.json" >/dev/null

# Every declared entry point must exist on disk, or the shell logs a load
# failure at runtime and shows nothing.
for entry in $(jq -r '.entryPoints[]' "${PLUGIN_DIR}/manifest.json"); do
    test -f "${PLUGIN_DIR}/${entry}"
done

# The bar entry landed exactly once and the file is still valid JSON.
[[ "$(jq --arg id "${PLUGIN_ID}" \
    '[.bar.layout.right[] | select(.id == $id)] | length' "${SKEL_SHELL_JSON}")" == "1" ]]

# The widget renders Nerd Font glyphs (hourglass, coffee, transport controls);
# a bar font without them shows tofu. 20-dotfiles.sh installs the font.
fc-list | grep -i 'JetBrainsMono Nerd Font' > /dev/null

# The phase-end chimes shell out to pw-play with absolute paths. Assert the
# player and both default sounds ship, rather than shipping a silent timer:
# the plugin deliberately swallows a failed chime, so nothing would report it.
#   pw-play              <- pipewire-utils
#   service-login.oga    <- sound-theme-freedesktop
#   string.ogg           <- gnome-control-center (asserted in 37)
test -x /usr/bin/pw-play
test -f /usr/share/sounds/freedesktop/stereo/service-login.oga
test -f /usr/share/sounds/gnome/default/alerts/string.ogg

echo "::endgroup::"

echo "Pomodoro bar plugin installed!"
