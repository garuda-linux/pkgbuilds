#!/usr/bin/env bash

for dep in curl git jq updpksums; do
    command -v "$dep" &>/dev/null || echo "$dep is not installed!"
done

readarray -t _SOURCES < <(awk -F ' ' '{ print $1 }' ./SOURCES)
readarray -t _PKGNAME < <(awk -F ' ' '{ print $2 }' ./SOURCES)
readarray -t _API < <(awk -F ' ' '{ print $3 }' ./SOURCES)

i=0
for package in "${_SOURCES[@]}"; do
    # Get the latest tag from the GitLab API
    _LATEST=$(curl -s "https://gitlab.com/api/v4/projects/${_API[$i]}/repository/tags" | jq -r '.[0].name' | sed 's/v//g')

    cd "${_PKGNAME[$i]}" || echo "Failed to cd into ${_PKGNAME[$i]}!"

    # shellcheck disable=SC1091
    source PKGBUILD || echo "Failed to source PKGBUILD for ${_PKGNAME[$i]}!"

    if [[ "$pkgver" != "$_LATEST" ]]; then
        # First update pkgver
        echo "Updating ${_PKGNAME[$i]} from $pkgver to $_LATEST"
        sed -i "s/pkgver=.*/pkgver=$_LATEST/g" PKGBUILD

        # Then update the source's checksum
        echo "Updating checksum for ${_PKGNAME[$i]}"
        updpkgsums &>/dev/null

        # Push changes back to main, triggering an instant deployment
        git add PKGBUILD
        git commit -m "bump: ${_PKGNAME[$i]} to $_LATEST [deploy ${_PKGNAME[$i]}]"
        git push "$REPO_URL" HEAD:main
    else
        echo "${_PKGNAME[$i]} is up to date"
    fi

    cd ..
    i=$((i+1))
done


