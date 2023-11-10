#!/usr/bin/env bash

for dep in fakeroot sudo; do
    command -v "$dep" &>/dev/null || echo "$dep is not installed!"
done

TO_DEPLOY=$(cat /tmp/TO_DEPLOY)

# This is required because makepkg does not like to be run as root and installation of
# packages is required for the build to succeed
install_deps() {
    # shellcheck disable=1091
    source PKGBUILD

    if [[ -n "$depends" ]]; then
        for j in "${depends[@]}"; do
            pacman -Qi "$j" &>/dev/null && continue
            echo "Installing $j from deps.."
            pacman -S --noconfirm --needed "$j" &>/dev/null || echo "Failed to install $j!"
        done
    fi
    if [[ -n "$makedepends" ]]; then
        for j in "${makedepends[@]}"; do
            pacman -Qi "$j" &>/dev/null && continue
            echo "Installing $j from makedeps.."
            pacman -S --noconfirm --needed "$j" &>/dev/null || echo "Failed to install $j, the build will probably fail!"
        done
    fi
}

# Allow makepkg to work
chown -R nobody:root "$CI_BUILDS_DIR"

if [[ "$TO_DEPLOY" == "routine" ]]; then
    echo "Testing a full routine run."

    # Build a list of valid paths
    mapfile -t _PACKAGES < <(find . -mindepth 1 -not -path '*/.*' -type d -prune | sed 's|^./||')

    # Proceed by running makepkg on each of them, logging the output to *.log
    # since there are too many lines for GitLab to handle
    for i in "${_PACKAGES[@]}"; do
        printf "\nBuilding %s.." "$i"
        cd "$i" || echo "Failed to cd into $i!"
        install_deps

        sudo -Eu nobody sh -c 'makepkg -s --noconfirm &> makepkg.log' || _FAILURES+=("$i")
        cd .. || echo "Failed to change back to the root directory!"
    done

    # If there were failures, print them and exit with an error
    if [[ ${#_FAILURES[@]} -gt 0 ]]; then
        printf "\nThe following packages failed to build:"
        for i in "${_FAILURES[@]}"; do
            printf "%s\n" "$i"
        done
        exit 1
    else
        echo "All packages built successfully!"
        exit 0
    fi
else
    echo "Testing a build of $TO_DEPLOY."

    # Proceed by running makepkg on $TO_DEPLOY
    cd "$TO_DEPLOY" || echo "Failed to cd into $TO_DEPLOY!"
    install_deps
    sudo -Eu nobody makepkg -s --noconfirm --needed && exit 0 ||
        echo "Failed to build $TO_DEPLOY, please have a look at why!" &&
        exit 1
fi
