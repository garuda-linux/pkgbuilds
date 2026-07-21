#!/bin/bash
# Update script for linux-garuda package
# Fetches the latest release from GitLab and updates PKGBUILD

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGBUILD_FILE="${SCRIPT_DIR}/../PKGBUILD"
RELEASE_API="https://gitlab.com/api/v4/projects/garuda-linux%2Fapplications%2Flinux-garuda/releases"

latest=$(curl -s "$RELEASE_API" | jq -r '.[0].tag_name')

current_pkgver=$(grep -E '^pkgver=' "$PKGBUILD_FILE" | sed 's/pkgver=//; s/"//g; s/'\''//g')
current_pkgrel=$(grep -E '^pkgrel=' "$PKGBUILD_FILE" | sed 's/pkgrel=//; s/"//g; s/'\''//g')
current="${current_pkgver}-${current_pkgrel}"

if [ "$current" != "$latest" ]; then
    pkgver=$(echo "$latest" | cut -d'-' -f1)
    pkgrel=$(echo "$latest" | cut -d'-' -f2)

    echo "update to $latest"
    sed -i "s/^pkgver=.*/pkgver=\"$pkgver\"/" "$PKGBUILD_FILE"
    sed -i "s/^pkgrel=.*/pkgrel=$pkgrel/" "$PKGBUILD_FILE"
    sed -i "s/^_fullver=.*/_fullver=\"\${pkgver}-\${pkgrel}\"/" "$PKGBUILD_FILE"
fi
