#!/usr/bin/env bash
mapfile -t _PACKAGES < <(find . -mindepth 1 -type d -prune | sed 's|^./||')

[[ "$CI_COMMIT_MESSAGE" == *"[deploy all]" ]] &&
    echo "routine" >> /tmp/TO_DEPLOY && 
    echo "Requested a full routine run." &&
    exit 0

for i in "${_PACKAGES[@]}"; do
    # shellcheck disable=SC2076
    [[ "$CI_COMMIT_MESSAGE" == *"[deploy $i]"* ]] &&
        echo "$i" >> /tmp/TO_DEPLOY && 
        echo "Requested package build for $TO_DEPLOY." &&
        exit 0
done

echo "No package to deploy found in commit message, aborting." && exit 1
