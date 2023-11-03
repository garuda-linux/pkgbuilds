#!/usr/bin/env bash
# This script's purpose is deploying packages when
# certain commit messages are used
set -e

initialize() {
    # Check if we have a deploy key
    [[ -z $DEPLOY_KEY ]] &&
        echo "No deploy key available, backing off!" &&
        exit 2

    # Check if this commit is supposed to deploy something
    # (GitLab CI should handle this nevertheless)
    grep -q "deploy" <<<"$CI_COMMIT_MESSAGE" &&
        echo "We are not supposed to deploy this commit!" &&
        exit 2

    # Set up ssh authentication
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    echo "$DEPLOY_KEY" >>~/.ssh/id_ed25519
    chmod 400 ~/.ssh/id_ed25519
}

parse() {
    # Build a list of current packages
    _PACKAGES=(find ./* -prune -type d)

    # [deploy all] would deploy all current packages
    [[ "deploy all" =~ $CI_COMMIT_MESSAGE ]] && TO_DEPLOY="routine"

    # [deploy pkgname] would deploy only a single package
    for i in "${_PACKAGES[@]}"; do
        [[ "deploy $i" =~ $CI_COMMIT_MESSAGE ]] && TO_DEPLOY="$i"
    done
}

deploy() {
    # This connects to a dedicated unprivileged builder account
    # which can only execute either a full routine or garuda packages
    ssh -i gitlab@builds.garudalinux.org "chaotictrigger \"$TO_DEPLOY\""
}

initialize
parse
deploy
