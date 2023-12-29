#!/usr/bin/env bash

function prepare-env() {
    if [[ "$CI_COMMIT_MESSAGE" == *"[deploy"*"]"* ]]; then
        _FROM_COMMIT_MSG=1
    else
        _FROM_COMMIT_MSG=0
    fi

    # Parse our commit message for which packages to build based on folder names
    mapfile -t _PACKAGES < <(find . -mindepth 1 -type d -prune | sed -e '/.\./d' -e 's/.\///g')
}

function parse-commit() {
    if [[ "$_FROM_COMMIT_MSG" == 1 ]]; then
        if [[ "$CI_COMMIT_MESSAGE" == *"[deploy all]"* ]]; then
            for package in "${_PACKAGES[@]}"; do
                _PKG+=("garuda:$package")
            done
            echo "Requested a full routine run."
        elif [[ "$CI_COMMIT_MESSAGE" == *"[deploy"*"]"* ]]; then
            for package in "${_PACKAGES[@]}"; do
                if [[ "$CI_COMMIT_MESSAGE" == *"[deploy $package]"* ]]; then
                    _PKG=("garuda:$package")
                    echo "Requested package build for $package."
                    return 0
                fi
            done
            echo "No package to build found in commit message. Exiting." && exit 1
        else
            echo "No package to build found in commit message. Exiting." && exit 1
        fi
    fi
}

parse-gitdiff() {
    if [[ "$_FROM_COMMIT_MSG" == 0 ]]; then
        # Compare the last 2 commits
        local _CURRENT_DIFF
        _CURRENT_DIFF=$(git --no-pager diff --name-only HEAD~1..HEAD)

        # Check whether relevant folders got changed
        for package in "${_PACKAGES[@]}"; do
            if [[ "$_CURRENT_DIFF" =~ "$package"/ ]]; then
                _PKG+=("garuda:$package")
                echo "Detected changes in $package, scheduling build..."
            fi
        done

        if [[ "${#_PKG[@]}" == 0 ]]; then
            echo "No relevant package changes to build found, exiting gracefully." && exit 0
        fi
    fi
}

schedule-package() {
    if [[ "${#_PKG[@]}" == 0 ]]; then
        echo "No relevant package changes to build found, exiting gracefully." && exit 0
    fi

    # To only schedule each package once, strip all duplicates
    mapfile -t _FINAL_PKG < <(for pkg in "${_PKG[@]}"; do echo "$pkg"; done | sort -u)

    # Schedule either a full run or a single package using chaotic-manager
    # the entry_point script also establishes a connection to our Redis server
    /entry_point.sh schedule --commit "${CI_COMMIT_SHA}:${CI_PIPELINE_ID}" --repo "$BUILD_REPO" "${_FINAL_PKG[@]}"
}

prepare-env
parse-commit
parse-gitdiff
schedule-package