#!/usr/bin/env bash

set -euo pipefail
set -x

# This script parses the parameters passed to this script and outputs a list of package names to a file

declare -a PACKAGES
PACKAGES=("$@")

source .ci/util.shlib

if [ -v "PACKAGES[0]" ] && [ "${PACKAGES[0]}" == "all" ]; then
    echo "Rebuild of all packages requested."
    UTIL_GET_PACKAGES PACKAGES
fi

# Check if the array of packages is empty
if [ ${#PACKAGES[@]} -eq 0 ]; then
    echo "No packages to build."
    exit 0
fi

declare -a PARAMS
PARAMS+=("schedule" "--repo=$REPO_NAME")

# Check if running on gitlab
if [ -v GITLAB_CI ]; then
    PARAMS+=("--commit")
    PARAMS+=("${CI_COMMIT_SHA}:${CI_PIPELINE_ID}")
elif [ -v GITHUB_ACTIONS ]; then
    echo "Warning: Pipeline updates are not supported on GitHub Actions yet."
fi

# Prepend the source repo name to each package name and push to PARAMS
for i in "${!PACKAGES[@]}"; do
    PARAMS+=("${BUILD_REPO}:${PACKAGES[$i]}")
done

# Write the parameters to a file .ci/schedule-params.txt
declare -p PARAMS >.ci/schedule-params.txt

# Write necessary redis variables to file .ci/schedule-redis.txt
for key in "REDIS_SSH_HOST" "REDIS_SSH_PORT" "REDIS_SSH_USER" "REDIS_PORT"; do
    declare -p "$key" >>.ci/schedule-params.txt
done
