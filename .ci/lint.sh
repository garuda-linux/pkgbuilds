#!/usr/bin/env bash
# This script is used to check the code style of the project
# shellcheck disable=SC2086 # breaks for loops
set -e

# Check if the required tools are installed
for dep in markdownlint shfmt shellcheck yamllint; do
	command -v "$dep" &>/dev/null || echo "$dep is not installed!"
done

# Check the code style against the following patterns
_PATTERNS_SH=("*/PKGBUILD" "*/*.install" "*/*.sh"
	"./garuda-update/garuda-update"
	"./garuda-update/main-update"
	"./garuda-update/update-helper-scripts")
_PATTERNS_MD=("*.md")
_PATTERNS_YML=(".*.yml" ".*.yaml")

# Determine what to do
[[ $1 == "apply" ]] && _MDLINT="markdownlint -f" || _MDLINT="markdownlint"
[[ $1 == "apply" ]] && _SHELLCHECK="shellcheck -f diff" || _SHELLCHECK="shellcheck"
[[ $1 == "apply" ]] && _SHFMT="shfmt -d -w" || _SHFMT="shfmt -d"
[[ $1 == "apply" ]] && _YAMLLINT="yamlfix" || _YAMLLINT="yamllint"

# Run the actions
for pattern in "${_PATTERNS_SH[@]}"; do
	[[ "$_SHELLCHECK" == "shellcheck" ]] && $_SHELLCHECK $pattern || _FAILURE=1
	([[ "$_SHELLCHECK" != "shellcheck" ]] && $_SHELLCHECK $pattern | git apply &>/dev/null || true) || _FAILURE=1
	$_SHFMT $pattern || _FAILURE=1
done
for pattern in "${_PATTERNS_MD[@]}"; do
	$_MDLINT $pattern || _FAILURE=1
done
for pattern in "${_PATTERNS_YML[@]}"; do
	$_YAMLLINT $pattern || _FAILURE=1
done

if [[ $_FAILURE -eq 1 ]]; then
	echo "Code style check failed! 🙁"
	exit 1
else echo "Code style check passed! 🎉"
fi