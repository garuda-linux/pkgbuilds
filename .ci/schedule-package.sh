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
            _PKG="full_run"
            echo "Requested a full routine run."
        elif [[ "$CI_COMMIT_MESSAGE" == *"[deploy"*"]"* ]]; then
            for package in "${_PACKAGES[@]}"; do
                if [[ "$CI_COMMIT_MESSAGE" == *"[deploy $package]"* ]]; then
                    _PKG="$package"
                    echo "Requested package build for $package."
                    return 0
                fi
            done
            echo "No package to build found in commit message. Exiting." && exit 1
        else
            echo "No package to build found in commit message. Exiting." && exit 1
        fi
    else
        return 0
    fi
}

parse-gitdiff() {
    if [[ "$_FROM_COMMIT_MSG" == 0 ]]; then
        # Compare the last 2 commits
        _CURRENT_DIFF=$(git --no-pager diff --name-only HEAD~1..HEAD)

        # Check whether relevant folders got changed
        for package in "${_PACKAGES[@]}"; do
            if [[ "$_CURRENT_DIFF" =~ "$package"/ ]]; then
                _PKG+=("$package")
                echo "Detected changes in $package, scheduling build..."
            fi
        done

        if [[ "${#_PKG[@]}" == 0 ]]; then
            echo "No relevant package changes to build found, exiting gracefully." && exit 0
        fi
    else
        return 0
    fi
}

schedule-package() {
    # Schedule either a full run or a single package using chaotic-manager
    # the entry_point script also establishes a connection to our Redis server
    if [[ "$_PKG" == "full_run" ]]; then
        /entry_point.sh schedule --commit "${CI_COMMIT_SHA}:${CI_PIPELINE_ID}" --repo "$BUILD_REPO" "${_PACKAGES[@]}"
    elif [[ "${#_PKG[@]}" == 1 ]]; then
        /entry_point.sh schedule --commit "${CI_COMMIT_SHA}:${CI_PIPELINE_ID}" --repo "$BUILD_REPO" "$_PKG"
    else
        /entry_point.sh schedule --commit "${CI_COMMIT_SHA}:${CI_PIPELINE_ID}" --repo "$BUILD_REPO" "${_PKG[@]}"
    fi
}

prepare-env
parse-commit
parse-gitdiff
schedule-package
