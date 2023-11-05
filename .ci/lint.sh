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

# Check the code style
_PATTERNS=(
    "PKGBUILD"
    "*.install"
)

for _PATTERN in "${_PATTERNS[@]}"; do
    find . -type f -name "$_PATTERN" -exec shfmt -d -w {} \;
    find . -type f -name "$_PATTERN" -exec shellcheck {} \;
done
