#!/usr/bin/env bash
# shellcheck disable=SC1090

_PREV_VERSIONS=$(cat VERSIONS)
_NEW_VERSIONS=$(for i in */PKGBUILD; do
    source "$i"
    printf "%s %s\n" "$pkgname" "$pkgver"
done)

[ "$_PREV_VERSIONS" != "$_NEW_VERSIONS" ] &&
    echo "$_NEW_VERSIONS" >VERSIONS &&
    echo "Updated versions file ✨" ||
    echo "No changes in versions 🎉"
    