#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Build hyprglass against the image's exact Hyprland build
###############################################################################
# Plugins share Hyprland's C++ ABI, so headers must match the installed RPM.
# v0.11.0 targets Hyprland 0.56.2; use system gcc-c++ like agaspar/omedora-4.
# The user's dotfiles hypr/looknfeel.lua loads /usr/lib64/hyprland/hyprglass.so
# with hl.plugin.load. Nothing loads the plugin automatically.
###############################################################################

# shellcheck source=/dev/null
source /ctx/build/copr-helpers.sh

echo "::group:: Install hyprglass Build Dependencies"

# /tmp is a tmpfs during image builds; keep sources and objects on disk.
BUILD_DIR=$(mktemp -d /var/tmp/hyprglass.XXXXXX)
# Snapshot names instead of removing a fixed deps array: pre-existing packages
# (notably gettext/COSMIC) must survive to avoid the login loop noted in script 30.
rpm -qa --qf '%{NAME}\n' | sort -u > "${BUILD_DIR}/packages-before"
HYPRLAND_PACKAGE=$(rpm -qf --qf '%{NAME}' /usr/bin/Hyprland)
HYPRLAND_EVR=$(rpm -q --qf '%{VERSION}-%{RELEASE}' "${HYPRLAND_PACKAGE}")
rpm -qa --qf '%{NAME}\n' "${HYPRLAND_PACKAGE}" \
    aquamarine hyprutils hyprlang hyprgraphics hyprcursor hyprwire \
    | sort -u > "${BUILD_DIR}/runtime-packages"
mapfile -t HYPR_RUNTIME < "${BUILD_DIR}/runtime-packages"
rpm -q "${HYPR_RUNTIME[@]}" > "${BUILD_DIR}/runtime-before"

copr_install_isolated "agaspar/omedora-4" "hyprland-devel-${HYPRLAND_EVR}"
dnf5 install -y gcc-c++ make git pkgconf-pkg-config \
    glslang-devel pixman-devel libdrm-devel wayland-devel

# hyprland.pc's hypr* requirements also come from this COPR.
pkg-config --print-requires hyprland \
    | awk '{print "pkgconfig(" $1 ")"}' > "${BUILD_DIR}/pkgconfig-deps"
mapfile -t HYPR_BUILD_DEPS < "${BUILD_DIR}/pkgconfig-deps"
copr_install_isolated "agaspar/omedora-4" "${HYPR_BUILD_DEPS[@]}"
pkg-config --cflags hyprland pixman-1 libdrm wayland-server

echo "::endgroup::"

echo "::group:: Build and Install hyprglass"

# Hyprland links Lua 5.5.0 statically and its -devel omits Lua headers.
# Fedora's lua-devel is 5.4, a different ABI; use only these upstream headers.
curl --fail --show-error --location --max-time 60 \
    --output "${BUILD_DIR}/lua.tar.gz" https://www.lua.org/ftp/lua-5.5.0.tar.gz
printf '57ccc32bbbd005cab75bcc52444052535af691789dba2b9016d5c50640d68b3d  %s\n' \
    "${BUILD_DIR}/lua.tar.gz" | sha256sum -c -
tar -xzf "${BUILD_DIR}/lua.tar.gz" -C "${BUILD_DIR}"

# renovate: datasource=github-tags depName=hyprnux/hyprglass
HYPRGLASS_VERSION="v0.11.0"
HYPRGLASS_COMMIT="7fc328064c63d9fbaaac8d8204eadf85dcdeae19"
timeout 300 git clone https://github.com/hyprnux/hyprglass "${BUILD_DIR}/hyprglass"
cd "${BUILD_DIR}/hyprglass"
git checkout --detach "${HYPRGLASS_COMMIT}"
[[ "$(git rev-parse "refs/tags/${HYPRGLASS_VERSION}^{commit}")" == "${HYPRGLASS_COMMIT}" ]]
# Keep .git: the Makefile uses git describe for the plugin version.
CPLUS_INCLUDE_PATH="${BUILD_DIR}/lua-5.5.0/src" timeout 1800 make -j"$(nproc)"
install -Dm755 hyprglass.so /usr/lib64/hyprland/hyprglass.so
install -Dm644 LICENSE /usr/share/licenses/hyprglass/LICENSE
cd /

echo "::endgroup::"

echo "::group:: Remove hyprglass Build Dependencies and Verify Runtime"

rpm -qa --qf '%{NAME}\n' | sort -u > "${BUILD_DIR}/packages-after"
comm -13 "${BUILD_DIR}/packages-before" "${BUILD_DIR}/packages-after" \
    > "${BUILD_DIR}/packages-added"
mapfile -t BUILD_ADDED < "${BUILD_DIR}/packages-added"
if [[ ${#BUILD_ADDED[@]} -gt 0 ]]; then
    # Disable autoremove and protect every original package against cascading
    # removal; fail the transaction if any existing runtime package would go.
    dnf5 remove -y --no-autoremove \
        --setopt="protected_packages=glob:${BUILD_DIR}/packages-before" \
        "${BUILD_ADDED[@]}"
fi

rpm -q "${HYPR_RUNTIME[@]}" > "${BUILD_DIR}/runtime-after"
cmp "${BUILD_DIR}/runtime-before" "${BUILD_DIR}/runtime-after"
rpm -qa --qf '%{NAME}\n' | sort -u > "${BUILD_DIR}/packages-after"
cmp "${BUILD_DIR}/packages-before" "${BUILD_DIR}/packages-after"
ldd /usr/lib64/hyprland/hyprglass.so > "${BUILD_DIR}/ldd"
if grep -q 'not found' "${BUILD_DIR}/ldd"; then
    exit 1
fi
find "${BUILD_DIR}" -depth -delete

echo "::endgroup::"
