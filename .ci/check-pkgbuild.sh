#!/usr/bin/env bash

mapfile -t _PACKAGES < <(find . -mindepth 1 -type d -prune | sed -e '/.\./d' -e 's/.\///g')

for package in "${_PACKAGES[@]}"; do
    printf "\nChecking %s...\n" "$package"
    namcap -i "$package/PKGBUILD" || true # be graceful for now
    aura -Pf "$package/PKGBUILD" || true
done
