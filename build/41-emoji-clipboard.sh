#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Emoji picker clipboard fix
#
# The omarchy emoji picker (SUPER+CTRL+E) hands the selection to
# omarchy-menu-emoji-insert, which upstream implements as a transient
# `wl-copy --sensitive --foreground` plus a synthetic Shift+Insert, killing
# the wl-copy owner afterwards. Two problems here:
#
# - --sensitive needs wl-clipboard >= 2.3.0; Fedora 44 ships 2.2.1, so wl-copy
#   exits 1 and the emoji never reaches the clipboard (same Arch-assumption
#   class as the ttfx screensaver fix).
# - Even with a new enough wl-clipboard, the kill wipes the clipboard
#   ~0.35s after the paste, so a picked emoji can never be pasted manually.
#
# Overridden with a version that copies persistently and keeps the
# best-effort Shift+Insert. Runs after 36-omarchy-payload.sh so the RPM
# file exists to be replaced.
###############################################################################

echo "::group:: Override omarchy-menu-emoji-insert"

TARGET="/usr/share/omarchy/bin/omarchy-menu-emoji-insert"

# Assert the upstream file exists first: an upstream rename should fail the
# build loudly, not ship an orphaned override next to a broken picker.
[[ -f "${TARGET}" ]]

install -Dm755 /ctx/build/files/usr/share/omarchy/bin/omarchy-menu-emoji-insert "${TARGET}"

echo "::endgroup::"

echo "::group:: Smoke checks"

bash -n "${TARGET}"
[[ -x "${TARGET}" ]]

# The override took: no --sensitive left in the code, persistent wl-copy in
# place. Comments are stripped first — the override documents the upstream
# flag it replaces, and grepping the whole file trips over that prose.
# Plain `! grep` is exempt from errexit, so assert through an if.
if grep -v '^[[:space:]]*#' "${TARGET}" | grep -q -- '--sensitive'; then
    echo "override did not take: --sensitive still present in ${TARGET}" >&2
    exit 1
fi
grep -q 'wl-copy --type text/plain' "${TARGET}"

# Both tools the script leans on ship in the image.
[[ -x /usr/bin/wl-copy ]]
[[ -x /usr/bin/wtype ]]

echo "::endgroup::"

echo "Emoji clipboard fix complete!"
