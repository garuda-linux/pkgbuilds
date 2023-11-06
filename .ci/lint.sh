#!/usr/bin/env bash
# This script is used to check the code style of the project
# shellcheck disable=SC2086 # breaks for loops
set -e

# Check if the required tools are installed
for dep in markdownlint shfmt shellcheck yamllint; do
    command -v "$dep" &>/dev/null || echo "$dep is not installed!"
done

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