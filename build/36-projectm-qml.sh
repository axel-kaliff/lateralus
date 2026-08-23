#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# projectM QML plugin (Lateralus.ProjectM)
###############################################################################
# Builds the Milkdrop visualizer QML module used by the Quickshell media
# widget popup (akaliff.media dotfiles plugin). Source: build/src/projectm-qml.
#
# projectM: https://github.com/projectM-visualizer/projectm
###############################################################################

echo "::group:: Install projectM runtime"

# Installed separately from the build deps so the runtime library — and the
# 4188 classic Milkdrop presets the rpm ships under /usr/share/projectM — are
# marked user-installed and survive the dnf5 remove below (same trick as
# gettext in build/30-cosmic-desktop.sh).
dnf5 install -y libprojectM

echo "::endgroup::"

echo "::group:: Build projectM QML plugin"

BUILD_DEPS=(
    cmake
    ninja-build
    gcc-c++
    pkg-config
    qt6-qtbase-devel
    qt6-qtdeclarative-devel
    libprojectM-devel
    pipewire-devel
    mesa-libGL-devel
)
dnf5 install -y "${BUILD_DEPS[@]}"

# Build under /var/tmp: /tmp is a tmpfs during image builds (see build/30).
# -j4 caps parallelism for 16 GB runners. No -march flags: gcc defaults to
# generic x86-64, which is what a shipped image needs.
cmake -S /ctx/build/src/projectm-qml -B /var/tmp/projectm-qml -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr
cmake --build /var/tmp/projectm-qml -j4
cmake --install /var/tmp/projectm-qml
rm -rf /var/tmp/projectm-qml

# Smoke checks — fail the image build, not the first popup open in a VM
QML_MODULE_DIR=/usr/lib64/qt6/qml/Lateralus/ProjectM
test -f "${QML_MODULE_DIR}/qmldir"
test -f "${QML_MODULE_DIR}/libprojectm-qml.so"
ldd "${QML_MODULE_DIR}/libprojectm-qml.so" | (! grep 'not found')
test -d /usr/share/projectM/presets
[[ "$(find /usr/share/projectM/presets -name '*.milk' | wc -l)" -gt 1000 ]]

dnf5 remove -y "${BUILD_DEPS[@]}"

echo "projectM QML plugin built and installed"
echo "::endgroup::"
