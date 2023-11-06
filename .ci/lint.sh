#!/usr/bin/env bash
# This script is used to check the code style of the project
set -e

# Check if the required tools are installed
! command -v shfmt &>/dev/null &&
    echo "shfmt not found. Please install shfmt!" &&
    exit 1
! command -v shellcheck &>/dev/null &&
    echo "shellcheck not found. Please install shellcheck!" &&
    exit 1

# Check the code style against the following patterns
_PATTERNS=("*/PKGBUILD" "*/*.install")

# Determine what to do
[[ $1 == "apply" ]] && _SHELLCHECK="shellcheck -f diff" || _SHELLCHECK="shellcheck"
[[ $1 == "apply" ]] && _SHFMT="shfmt -d -w" || _SHFMT="shfmt -d"

# Run the actions
for pattern in "${_PATTERNS[@]}"; do
    # shellcheck disable=SC2086
    $_SHELLCHECK $pattern
    # shellcheck disable=SC2086
    $_SHFMT $pattern
done
