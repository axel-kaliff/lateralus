#!/usr/bin/bash

set -euo pipefail

###############################################################################
# Image Info Generation
###############################################################################
# Generates /usr/share/ublue-os/image-info.json and customizes /usr/lib/os-release.
# This script is bluefin-pattern: each consumer provides its own branding.
#
# Required env vars (set as ARGs in Containerfile):
#   IMAGE_NAME          - Image name (e.g. finpilot, my-custom-os)
#   IMAGE_VENDOR        - Image vendor/owner (e.g. github username or org)
#   UBLUE_IMAGE_TAG     - Image tag/stream (e.g. stable, testing, latest)
#   BASE_IMAGE_NAME     - Base image name (e.g. silverblue)
#   FEDORA_MAJOR_VERSION - Fedora version (e.g. 42)
#   VERSION             - Full version string (e.g. stable-42.20250531)
#   SHA_HEAD_SHORT      - Short git SHA (optional, for dev builds)
###############################################################################

# Branding — customize these for your image
IMAGE_PRETTY_NAME="${IMAGE_PRETTY_NAME:-My Custom OS}"
IMAGE_LIKE="${IMAGE_LIKE:-fedora}"
HOME_URL="${HOME_URL:-https://github.com/${IMAGE_VENDOR}/${IMAGE_NAME}}"
DOCUMENTATION_URL="${DOCUMENTATION_URL:-https://github.com/${IMAGE_VENDOR}/${IMAGE_NAME}/blob/main/README.md}"
SUPPORT_URL="${SUPPORT_URL:-https://github.com/${IMAGE_VENDOR}/${IMAGE_NAME}/issues}"
BUG_REPORT_URL="${BUG_REPORT_URL:-https://github.com/${IMAGE_VENDOR}/${IMAGE_NAME}/issues/new}"

# Paths
IMAGE_INFO="/usr/share/ublue-os/image-info.json"
OS_RELEASE="/usr/lib/os-release"

# Derive image flavor from name
if [[ "${IMAGE_NAME}" =~ nvidia ]]; then
	IMAGE_FLAVOR="nvidia"
else
	IMAGE_FLAVOR="main"
fi

# Image ref (used by bootc for upgrade source)
IMAGE_REF="ostree-image-signed:docker://ghcr.io/${IMAGE_VENDOR}/${IMAGE_NAME}"

###############################################################################
# Write image-info.json
###############################################################################
mkdir -p /usr/share/ublue-os
cat >"${IMAGE_INFO}" <<EOF
{
  "image-name": "${IMAGE_NAME}",
  "image-flavor": "${IMAGE_FLAVOR}",
  "image-vendor": "${IMAGE_VENDOR}",
  "image-ref": "${IMAGE_REF}",
  "image-tag": "${UBLUE_IMAGE_TAG}",
  "base-image-name": "${BASE_IMAGE_NAME}",
  "fedora-version": "${FEDORA_MAJOR_VERSION}"
}
EOF

echo "Wrote ${IMAGE_INFO}"
echo "  image-name: ${IMAGE_NAME}"
echo "  image-flavor: ${IMAGE_FLAVOR}"
echo "  image-vendor: ${IMAGE_VENDOR}"

###############################################################################
# Customize /usr/lib/os-release
###############################################################################
# Update keys IN PLACE (replace if present, append if missing) instead of
# appending a block. The template's append produced a comment line, a blank
# line, and duplicate keys — bootc-image-builder's os-release parser rejects
# lines that aren't KEY=VALUE ("readOSRelease: invalid input"), which broke
# every qcow2/ISO build. In-place updates keep the file strictly parseable
# and idempotent while producing the same effective values (os-release
# semantics: last duplicate wins, so these were the winners anyway).
set_os_release_key() {
	local key="$1" value="$2"
	if grep -q "^${key}=" "${OS_RELEASE}"; then
		sed -i "s|^${key}=.*|${key}=\"${value}\"|" "${OS_RELEASE}"
	else
		echo "${key}=\"${value}\"" >>"${OS_RELEASE}"
	fi
}

if [[ -f "${OS_RELEASE}" ]]; then
	if [[ -n "${VERSION:-}" ]]; then
		OS_VERSION="${VERSION}"
	else
		OS_VERSION="${UBLUE_IMAGE_TAG}"
	fi

	set_os_release_key VARIANT_ID "${IMAGE_FLAVOR}"
	set_os_release_key PRETTY_NAME "${IMAGE_PRETTY_NAME}"
	set_os_release_key NAME "${IMAGE_NAME}"
	set_os_release_key IMAGE_ID "${IMAGE_NAME}"
	set_os_release_key IMAGE_VERSION "${OS_VERSION}"
	set_os_release_key ID_LIKE "${IMAGE_LIKE}"
	set_os_release_key HOME_URL "${HOME_URL}"
	set_os_release_key DOCUMENTATION_URL "${DOCUMENTATION_URL}"
	set_os_release_key SUPPORT_URL "${SUPPORT_URL}"
	set_os_release_key BUG_REPORT_URL "${BUG_REPORT_URL}"

	echo "Customized ${OS_RELEASE}"
fi
