#!/usr/bin/env bash

for dep in curl git; do
    command -v "$dep" &>/dev/null || echo "$dep is not installed!"
done

# Parse our commit message for which packages to build based on folder names
mapfile -t _PACKAGES < <(find . -mindepth 1 -type d -prune | sed -e '/.\./d' -e 's/.\///g')

# This is required for makepkg
# shellcheck source=/dev/null
source /etc/makepkg.conf
chown -R ci-user:root "$CI_PROJECT_DIR"

# Get a list of all packages containing "-git"
mapfile -t _VCS_PKG < <(printf '%s\n' "${_PACKAGES[@]}" | sed '/-git/!d')

for package in "${_VCS_PKG[@]}"; do
    printf "\nChecking %s...\n" "$package"
    pushd "$package" || echo "Failed to change into $package!"

    # Parse PKGBUILD's variables
    _OLD_PKGVER=$(grep -oP '\spkgver\s=\s\K.*' .SRCINFO)
    mapfile -t _SOURCES < <(grep -oP '\ssource\s=\s\K.*' .SRCINFO)
    mapfile -t _MAKEDEPENDS <  <(grep -oP '\smakedepends\s=\s\K.*' .SRCINFO)

    # Abort mission if sources() contains a fixed commit
    for fragment in branch commit tag revision; do
        if [[ "${_SOURCES[*]}" == *"#$fragment="* ]]; then
            echo "Can't update pkgver due to fixed $fragment, skipping."
            continue
        fi
    done

    # Account for packages that use makedeps in prepare() or pkgver()
    if [[ "${#_MAKEDEPENDS[@]}" -gt 0 ]]; then
        pacman -Syu --noconfirm --needed --asdeps "${_MAKEDEPENDS[@]}"
    fi

    # Download and extract sources, skipping deps
    sudo -u ci-user -H makepkg -do

    # Run pkgver function of the sourced PKGBUILD
    sudo -u ci-user -H makepkg --printsrcinfo | tee .SRCINFO &>/dev/null

    _NEW_PKGVER=$(grep -oP '\spkgver\s=\s\K.*' .SRCINFO)

    if ! git diff --exit-code --quiet; then
        git add PKGBUILD .SRCINFO
        git commit -m "chore($package): git-version $_NEW_PKGVER [deploy $package]"
        git push "$REPO_URL" HEAD:main || git pull --rebase && git push "$REPO_URL" HEAD:main # Env provided via GitLab CI
    else
        echo "Package already up-to-date."
    fi

    # Cleanup stuff left behind, like sources or makedepends
    git reset --hard HEAD
    git clean -fd
    pacman -Qtdq | pacman -Rns --noconfirm - || echo "No orphans left behind."
done
