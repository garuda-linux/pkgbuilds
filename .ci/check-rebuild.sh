#!/usr/bin/env bash

_AFFECTED=()
KNOWN_REBUILD_PACKAGES=(
    "protobuf"
    "icu"
)

pacman -Syu --noconfirm --needed "${KNOWN_REBUILD_PACKAGES[@]}"

determine-diffs() {
    LIB_VERSIONS=$(cat LIB_VERSIONS)
    rm LIB_VERSIONS

    for package in "${KNOWN_REBUILD_PACKAGES[@]}"; do
        _OLDVER=$(echo "$LIB_VERSIONS" | grep "$package")
        _NEWVER=$(pacman -Q "$package")
        if [[ "$_OLDVER" != "$_NEWVER" ]]; then
            echo "Library version mismatch detected for $package..."
            _BUMP_LIBS+=("$package")
        fi

        echo "$_NEWVER" >>LIB_VERSIONS
    done
}

determine-affected() {
    # Build a list of valid packages
    mapfile -t _PACKAGES < <(find . -mindepth 1 -type d -prune | sed -e '/.\./d' -e 's/.\///g')

    for package in "${_PACKAGES[@]}"; do
        mapfile -t _DEPENDS < <(grep -oP '\sdepends\s=\s\K.*' "$package/.SRCINFO")
        mapfile -t _MAKEDEPENDS < <(grep -oP '\smakedepends\s=\s\K.*' "$package/.SRCINFO")

        # Once we know a package is affected, we can exit the function with return 0
        for dep in "${_DEPENDS[@]}"; do
            if [[ "${KNOWN_REBUILD_PACKAGES[*]}" =~ [[:space:]]"$dep"[[:space:]] ]]; then
                _AFFECTED+=("$package")
                echo "Package $package is affected by library version bumps..."
            fi
        done
        for makedep in "${_MAKEDEPENDS[@]}"; do
            if [[ "${KNOWN_REBUILD_PACKAGES[*]}" =~ [[:space:]]"$makedep"[[:space:]] ]]; then
                _AFFECTED+=("$package")
                echo "Package $package is affected by library version bumps..."
            fi
        done
    done
}

bump-affected() {
    if [[ "${#_AFFECTED[@]}" -eq 0 ]]; then
        echo "No packages affected by library version bumps, skipping."
        return 0
    else
        for package in "${_AFFECTED[@]}"; do
            # We only want to bump each package once, even if multiple libraries got bumped
            if [[ "${_ALREADY_BUMPED[*]}" =~ [[:space:]]"$package"[[:space:]] ]]; then
                echo "Package $package already bumped, skipping..."
                continue
            fi

            # shellcheck source=/dev/null
            source "$package/.CI_CONFIG"

            if [[ "$CI_MANAGE_AUR" == 1 ]]; then
                # If we manage the AUR, bump regular pkgrel - changes will automatically be
                # pushed back to AUR by the CI pipeline
                echo "Package $package is managed by us, bumping pkgrel..."

                # shellcheck source=/dev/null
                _OLD_PKGVER=$(grep -oP '\spkgver\s=\s\K.*' "$package/.SRCINFO")
                _NEW_PKGREL=$((_OLD_PKGVER + 1))

                sed -i "s/pkgrel=.*/pkgrel=$_NEW_PKGREL/" "$package/PKGBUILD"
                _ALREADY_BUMPED+=("$package")
            else
                # If we don't manage the AUR, bump CI_PKGREL
                echo "Package $package is not managed by us, bumping CI_PKGREL..."

                if ! (grep -q "CI_PKGREL=" "$package/.CI_CONFIG" &>/dev/null); then
                    echo "CI_PKGREL is missing for $package, adding first bump..."
                    echo "# Bumps the pkgrel of $package by 0.1 for each +1" >>"$package/.CI_CONFIG"
                    echo "CI_PKGREL=1" >>"$package/.CI_CONFIG"
                    continue
                else
                    _NEW_PKGREL=$((CI_PKGREL + 1))

                    # Bump pkgrel
                    sed -i "s/CI_PKGREL=.*/CI_PKGREL=$_NEW_PKGREL/" "$package/.CI_CONFIG"
                    _ALREADY_BUMPED+=("$package")
                fi
            fi
        done

        if [[ "${#_ALREADY_BUMPED[@]}" -gt 0 ]]; then
            # Commit and push the changes to our new branch
            git add .
            git commit -m "chore(package-rebuild): rebuild packages against updated libraries" \
                -m "Affected packages: ${_AFFECTED[*]}" \
                -m "Bumped libraries: ${_BUMP_LIBS[*]}"

            git push "$REPO_URL" HEAD:main || git pull --rebase && git push "$REPO_URL" HEAD:main # Env provided via GitLab CI
        fi
    fi
}

determine-diffs
determine-affected
bump-affected
