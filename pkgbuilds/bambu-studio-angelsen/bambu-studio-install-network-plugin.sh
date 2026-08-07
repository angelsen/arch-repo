#!/bin/bash
# Fetch and install Bambu Lab's proprietary network plugin.
#
# Bambu Studio downloads this blob at runtime on first login and it is not
# redistributable, so it cannot ship inside this package. Run this helper when
# the app reports "Please install the network plugin before logging in" and its
# own in-app download has failed.
#
# Mirrors the vendor-documented manual procedure:
# https://wiki.bambulab.com/en/software/bambu-studio/failed-to-get-network-plugin

set -euo pipefail

readonly API='https://api.bambulab.com/v1/iot-service/api/slicer/resource'
readonly DEST="${XDG_CONFIG_HOME:-${HOME}/.config}/BambuStudio/plugins"

die() {
    echo "error: $*" >&2
    exit 1
}

if [[ ${1:-} == -h || ${1:-} == --help ]]; then
    cat <<EOF
Usage: ${0##*/} [app-version]

Installs the Bambu network plugin matching an installed Bambu Studio into
${DEST}. Defaults to the version of the installed
bambu-studio-angelsen package.
EOF
    exit 0
fi

version="${1:-}"
if [[ -z ${version} ]]; then
    version=$(pacman -Q bambu-studio-angelsen 2>/dev/null | cut -d' ' -f2 | cut -d- -f1) \
        || die "bambu-studio-angelsen is not installed; pass a version explicitly"
fi

# The API is keyed on the first three version components only. The plugin
# carries its own patch level (app 02.07.01.62 is served plugin 02.07.01.51);
# Bambu Studio accepts any plugin whose version agrees on those three.
query="${version%.*}.00"
echo "==> Looking up plugin for Bambu Studio ${version} (query ${query})"

# X-BBL-OS-Type is required. Without it the API hands back the Windows zip,
# which is why the vendor's browser-based instructions only work on Windows.
url=$(curl -fsS -H 'X-BBL-OS-Type: linux' "${API}?slicer/plugins/cloud=${query}" \
    | jq -r '.resources[] | select(.type == "slicer/plugins/cloud") | .url')
[[ -n ${url} ]] || die "no Linux plugin published for ${query}"

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT

echo "==> Downloading ${url##*/}"
curl -fsSL -o "${tmp}/plugin.zip" "${url}"

echo "==> Installing into ${DEST}"
mkdir -p "${DEST}"
bsdtar -xf "${tmp}/plugin.zip" -C "${DEST}"
# Matches the permissions Bambu Studio applies to its own downloads.
chmod 644 "${DEST}"/*.so

echo "==> Done. Restart Bambu Studio and log in."
