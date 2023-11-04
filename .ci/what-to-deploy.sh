#!/usr/bin/env bash
mapfile -t _PACKAGES < <(find . -type d | sed 's|^./||')

[[ "$CI_COMMIT_MESSAGE" =~ "deploy all" ]] && TO_DEPLOY="routine" && exit 0

for i in "${_PACKAGES[@]}"; do
    [[ "$CI_COMMIT_MESSAGE" =~ "deploy $i" ]] && TO_DEPLOY="$i" && exit 0
done

echo "No package to deploy found in commit message, aborting." && exit 1
