#!/usr/bin/env bash
# This script is used to check the code style of the project
# shellcheck disable=SC2086 # breaks for loops
set -e

# Check if the required tools are installed
! command -v markdownlint &>/dev/null &&
    echo "markdownlint not found. Please install markdownlint!" &&
    exit 1
! command -v shfmt &>/dev/null &&
    echo "shfmt not found. Please install shfmt!" &&
    exit 1
! command -v shellcheck &>/dev/null &&
    echo "shellcheck not found. Please install shellcheck!" &&
    exit 1
! command -v yamllint &>/dev/null &&
    echo "yamllint not found. Please install yamllint!" &&
    exit 1

# Check the code style against the following patterns
_PATTERNS_SH=("*/PKGBUILD" "*/*.install" "*/*.sh")
_PATTERNS_MD=("*.md")
_PATTERNS_YML=(".*.yml" ".*.yaml")

# Determine what to do
[[ $1 == "apply" ]] && _MDLINT="markdownlint -f" || _MDLINT="markdownlint"
[[ $1 == "apply" ]] && _SHELLCHECK="shellcheck -f diff" || _SHELLCHECK="shellcheck"
[[ $1 == "apply" ]] && _SHFMT="shfmt -d -w" || _SHFMT="shfmt -d"
[[ $1 == "apply" ]] && _YAMLLINT="yamlfix" || _YAMLLINT="yamllint"

# Run the actions
for pattern in "${_PATTERNS_SH[@]}"; do
    [[ "$_SHELLCHECK" != "shellcheck" ]] && $_SHELLCHECK $pattern | git apply
    [[ "$_SHELLCHECK" == "shellcheck" ]] && $_SHELLCHECK $pattern
    $_SHFMT $pattern
done
for pattern in "${_PATTERNS_MD[@]}"; do
    $_MDLINT $pattern
done
for pattern in "${_PATTERNS_YML[@]}"; do
    $_YAMLLINT $pattern
done