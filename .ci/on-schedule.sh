#!/usr/bin/env bash
set -euo pipefail
set -x

# This script is triggered by a scheduled pipeline

# Allow makepkg to work in a non-root environment & unbreak git
chown -R nobody:root "$CI_BUILDS_DIR"
git config --global --add safe.directory "*"

# Check if the scheduled tag does not exist or scheduled does not point to HEAD
if ! [ "$(git tag -l "scheduled")" ] || [ "$(git rev-parse HEAD)" != "$(git rev-parse scheduled)" ]; then
    echo "Previous on-commit pipeline did not seem to run successfully. Aborting." >&2
    exit 1
fi

# shellcheck source=/dev/null
source .ci/util.shlib

TMPDIR="${TMPDIR:-/tmp}"

PACKAGES=()
declare -A AUR_TIMESTAMPS
MODIFIED_PACKAGES=()
DELETE_BRANCHES=()
UTIL_GET_PACKAGES PACKAGES
COMMIT=false

git config --global user.name "$GIT_AUTHOR_NAME"
git config --global user.email "$GIT_AUTHOR_EMAIL"

# Loop through all packages to do optimized aur RPC calls
# $1 = Output associative array
function collect_aur_timestamps() {
    # shellcheck disable=SC2034
    local -n collect_aur_timestamps_output=$1
    local AUR_PACKAGES=()

    for package in "${PACKAGES[@]}"; do
        unset VARIABLES
        declare -gA VARIABLES
        if UTIL_READ_MANAGED_PACAKGE "$package" VARIABLES; then
            if [ -v "VARIABLES[CI_PKGBUILD_SOURCE]" ]; then
                local PKGBUILD_SOURCE="${VARIABLES[CI_PKGBUILD_SOURCE]}"
                if [[ "$PKGBUILD_SOURCE" == aur ]]; then
                    AUR_PACKAGES+=("$package")
                fi
            fi
        fi
    done

    # Get all timestamps from AUR
    UTIL_FETCH_AUR_TIMESTAMPS collect_aur_timestamps_output "${AUR_PACKAGES[*]}"
}

# $1: dir1
# $2: dir2
function package_changed() {
    # Check if the package has changed
    # NOTE: We don't care if anything but the PKGBUILD or .SRCINFO has changed.
    # Any properly built PKGBUILD will use hashes, which will change
    if diff -q "$1/PKGBUILD" "$2/PKGBUILD" >/dev/null; then
        if [ ! -f "$1/.SRCINFO" ] && [ ! -f "$2/.SRCINFO" ]; then
            return 1
        elif [ -f "$1/.SRCINFO" ] && [ -f "$2/.SRCINFO" ]; then
            if diff -q "$1/.SRCINFO" "$2/.SRCINFO" >/dev/null; then
                return 1
            fi
        fi
    fi
    return 0
}

# Check if the package has gotten major changes
# Any change that is not a pkgver or pkgrel bump is considered a major change
# $1: dir1
# $2: dir2
function package_major_change() {
    local sdiff_output
    if sdiff_output="$(sdiff -ds <(gawk -f .ci/awk/remove-checksum.awk "$1/PKGBUILD") <(gawk -f .ci/awk/remove-checksum.awk "$2/PKGBUILD"))"; then
        return 1
    fi

    if [ $? -eq 2 ]; then
        echo "Warning: sdiff failed" >&2
        return 2
    fi

    if gawk -f .ci/awk/check-diff.awk <<<"$sdiff_output"; then
        # Check the rest of the files in the folder for changes
        # Excluding PKGBUILD .SRCINFO, .gitignore, .git .CI
        # shellcheck disable=SC2046
        if diff -q $(UTIL_GET_EXCLUDE_LIST "-x" "PKGBUILD .SRCINFO") -r "$1" "$2" >/dev/null; then
            return 1
        fi
    fi
    return 0
}

# $1: VARIABLES
# $2: git URL
function update_via_git() {
    local -n VARIABLES_VIA_GIT=${1:-VARIABLES}
    local pkgbase="${VARIABLES_VIA_GIT[PKGBASE]}"

    git clone --depth=1 "$2" "$TMPDIR/aur-pulls/$pkgbase"

    # We always run shfmt on the PKGBUILD. Two runs of shfmt on the same file should not change anything
    shfmt -w "$TMPDIR/aur-pulls/$pkgbase/PKGBUILD"

    if package_changed "$TMPDIR/aur-pulls/$pkgbase" "$pkgbase"; then
        if [ -v CI_HUMAN_REVIEW ] && [ "$CI_HUMAN_REVIEW" == "true" ] && package_major_change "$TMPDIR/aur-pulls/$pkgbase" "$pkgbase"; then
            echo "Warning: Major change detected in $pkgbase."
            VARIABLES_VIA_GIT[CI_REQUIRES_REVIEW]=true
        fi
        # Rsync: delete files in the destination that are not in the source. Exclude deleting .CI, exclude copying .git
        # shellcheck disable=SC2046
        rsync -a --delete $(UTIL_GET_EXCLUDE_LIST "--exclude") "$TMPDIR/aur-pulls/$pkgbase/" "$pkgbase/"
    fi
}

# $1: VARIABLES
function update_via_gitlab_api() {
    local -n VARIABLES_VIA_GITLAB_API=${1:-VARIABLES}
    local pkgbase="${VARIABLES_VIA_GITLAB_API[PKGBASE]}"

    if ! [ -v "VARIABLES_UPDATE_PKGBUILD[CI_PKGBUILD_SOURCE]" ]; then
        return 0
    fi

    local _CI_PROJECT_PATH _CI_PROJECT_ID _LATEST _CURRENTVER
    _CI_PROJECT_PATH="$(echo "${VARIABLES_UPDATE_PKGBUILD[CI_PKGBUILD_SOURCE]}" | cut -d ':' -f2)"
    _CI_PROJECT_ID="$(echo "${VARIABLES_UPDATE_PKGBUILD[CI_PKGBUILD_SOURCE]}" | cut -d ':' -f3)"

    _LATEST=$(curl -s "https://gitlab.com/api/v4/projects/$_CI_PROJECT_ID/repository/tags" | jq -r '.[0].name' | sed 's/v//g')
    _CURRENTVER=$(grep -oP '\spkgver\s=\s\K.*' "$pkgbase/.SRCINFO")

    if [[ "$_CURRENTVER" != "$_LATEST" ]]; then
        # Create a temporary directory to work with
        cd "$pkgbase" || echo "Failed to cd into $pkgbase!"

        # First update pkgver, resetting pkgrel
        echo "Updating $$pkgbase from $_CURRENTVER to $_LATEST"
        sed -i -e "s/pkgver=.*/pkgver=$_LATEST/g" -e "s/pkgrel=.*/pkgrel=1/g" PKGBUILD

        # Then update the source's checksum
        echo "Updating checksum for $pkgbase..."
        sudo -u nobody updpkgsums
        echo "Generating .SRCINFO for $pkgbase..."
        sudo -u nobody makepkg --printsrcinfo | tee .SRCINFO &>/dev/null

        # Apply shfmt, which is needed because of updpkgsums changing intends
        # and potentially failing pipelines due this
        shfmt -d -w PKGBUILD

        # Clean any source archives and similar things
        git clean --force

        # Generate a changelog between both versions to append to this commit
        echo "Generating changelog for $pkgbase..."

        git clone --depth 1 "https://gitlab.com/$_CI_PROJECT_PATH" "${TMPDIR}/gitlab-pulls/$pkgbase"

        pushd "${TMPDIR}/gitlab-pulls/$pkgbase" || echo "Failed to cd into ${TMPDIR}!"
        local CHANGELOG
        _CHANGELOG=$(pipx run --spec commitizen cz changelog "$_CURRENTVER".."$_LATEST" --dry-run)
        popd || echo "Failed to return to the previous directory!"

        cd .. || echo "Failed to change back to the previous directory!"
    fi
}

function update_pkgbuild() {
    local -n VARIABLES_UPDATE_PKGBUILD=${1:-VARIABLES}
    local pkgbase="${VARIABLES_UPDATE_PKGBUILD[PKGBASE]}"
    if ! [ -v "VARIABLES_UPDATE_PKGBUILD[CI_PKGBUILD_SOURCE]" ]; then
        return 0
    fi

    local PKGBUILD_SOURCE="${VARIABLES_UPDATE_PKGBUILD[CI_PKGBUILD_SOURCE]}"

    # Check if the package is from the AUR
    if [[ "$PKGBUILD_SOURCE" =~ ^gitlab:.*$ ]]; then
        update_via_gitlab_api VARIABLES_UPDATE_PKGBUILD
    elif [[ "$PKGBUILD_SOURCE" != aur ]]; then
        update_via_git VARIABLES_UPDATE_PKGBUILD "$PKGBUILD_SOURCE"
    else
        local git_url="https://aur.archlinux.org/${pkgbase}.git"

        # Fetch from optimized AUR RPC call
        if ! [ -v "AUR_TIMESTAMPS[$pkgbase]" ]; then
            echo "Warning: Could not find $pkgbase in cached AUR timestamps." >&2
            return 0
        fi
        local NEW_TIMESTAMP="${AUR_TIMESTAMPS[$pkgbase]}"

        # Check if CI_PKGBUILD_TIMESTAMP is set
        if [ -v "VARIABLES_UPDATE_PKGBUILD[CI_PKGBUILD_TIMESTAMP]" ]; then
            local PKGBUILD_TIMESTAMP="${VARIABLES_UPDATE_PKGBUILD[CI_PKGBUILD_TIMESTAMP]}"
            if [ "$PKGBUILD_TIMESTAMP" != "$NEW_TIMESTAMP" ]; then
                update_via_git VARIABLES_UPDATE_PKGBUILD "$git_url"
                UTIL_UPDATE_AUR_TIMESTAMP VARIABLES_UPDATE_PKGBUILD "$NEW_TIMESTAMP"
            fi
        else
            update_via_git VARIABLES_UPDATE_PKGBUILD "$git_url"
            UTIL_UPDATE_AUR_TIMESTAMP VARIABLES_UPDATE_PKGBUILD "$NEW_TIMESTAMP"
        fi
    fi
}

function update_vcs() {
    local -n VARIABLES_UPDATE_VCS=${1:-VARIABLES}
    local pkgbase="${VARIABLES_UPDATE_VCS[PKGBASE]}"

    # Check if pkgbase ends with -git or if CI_GIT_COMMIT is set
    if [[ "$pkgbase" != *-git ]] && [ ! -v "VARIABLES_UPDATE_VCS[CI_GIT_COMMIT]" ]; then
        return 0
    fi

    local _NEWEST_COMMIT
    if ! _NEWEST_COMMIT="$(UTIL_FETCH_VCS_COMMIT VARIABLES_UPDATE_VCS)"; then
        echo "Warning: Could not fetch latest commit for $pkgbase via heuristic." >&2
        return 0
    fi

    if [ -z "$_NEWEST_COMMIT" ]; then
        unset "VARIABLES_UPDATE_VCS[CI_GIT_COMMIT]"
        return 0
    fi

    # Check if CI_GIT_COMMIT is set
    if [ -v "VARIABLES_UPDATE_VCS[CI_GIT_COMMIT]" ]; then
        local CI_GIT_COMMIT="${VARIABLES_UPDATE_VCS[CI_GIT_COMMIT]}"
        if [ "$CI_GIT_COMMIT" != "$_NEWEST_COMMIT" ]; then
            UTIL_UPDATE_VCS_COMMIT VARIABLES_UPDATE_VCS "$_NEWEST_COMMIT"
        fi
    else
        UTIL_UPDATE_VCS_COMMIT VARIABLES_UPDATE_VCS "$_NEWEST_COMMIT"
    fi
}

# Collect last modified timestamps from AUR in an efficient way
collect_aur_timestamps AUR_TIMESTAMPS

mkdir "$TMPDIR/aur-pulls"

# Loop through all packages to check if they need to be updated
for package in "${PACKAGES[@]}"; do
    unset VARIABLES
    declare -A VARIABLES
    if UTIL_READ_MANAGED_PACAKGE "$package" VARIABLES; then
        update_pkgbuild VARIABLES
        update_vcs VARIABLES
        UTIL_WRITE_KNOWN_VARIABLES_TO_FILE "./${package}/.CI/config" VARIABLES

        if ! git diff --exit-code --quiet; then
            if [[ -v VARIABLES[CI_REQUIRES_REVIEW] ]] && [ "${VARIABLES[CI_REQUIRES_REVIEW]}" == "true" ]; then
                "$(dirname "$(realpath "$0")")"/create-pr.sh "$package"
            else
                git add .
                if [ "$COMMIT" == "false" ]; then
                    COMMIT=true
                    git commit -m "chore(packages): update packages [skip ci]"
                else
                    git commit --amend --no-edit
                fi
                MODIFIED_PACKAGES+=("$package")
                if [ -v CI_HUMAN_REVIEW ] && [ "$CI_HUMAN_REVIEW" == "true" ] && git show-ref --quiet "origin/update-$package"; then
                    DELETE_BRANCHES+=("update-$package")
                fi
            fi
        fi
    fi
done

if [ ${#MODIFIED_PACKAGES[@]} -ne 0 ]; then
    "$(dirname "$(realpath "$0")")"/schedule-packages.sh "${MODIFIED_PACKAGES[*]}"
fi

if [ "$COMMIT" = true ]; then
    git tag -f scheduled
    git_push_args=()
    for branch in "${DELETE_BRANCHES[@]}"; do
        git_push_args+=(":$branch")
    done
    git push --atomic "$REPO_URL" HEAD:main +refs/tags/scheduled "${git_push_args[@]}"
fi
