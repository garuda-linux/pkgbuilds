#!/usr/bin/env bash

for dep in curl git jq updpkgsums; do
	command -v "$dep" &>/dev/null || echo "$dep is not installed!"
done

readarray -t _SOURCES < <(awk -F ' ' '{ print $1 }' ./SOURCES)
readarray -t _PKGNAME < <(awk -F ' ' '{ print $2 }' ./SOURCES)
readarray -t _API < <(awk -F ' ' '{ print $3 }' ./SOURCES)

i=0
for package in "${_SOURCES[@]}"; do
	# Get the latest tag from the GitLab API
	_LATEST=$(curl -s "https://gitlab.com/api/v4/projects/${_API[$i]}/repository/tags" | jq -r '.[0].name' | sed 's/v//g')

	cd "${_PKGNAME[$i]}" || echo "Failed to cd into ${_PKGNAME[$i]}!"

	# shellcheck disable=SC1091
	source PKGBUILD || echo "Failed to source PKGBUILD for ${_PKGNAME[$i]}!"

	if [[ "$pkgver" != "$_LATEST" ]]; then
		# First update pkgver
		echo "Updating ${_PKGNAME[$i]} from $pkgver to $_LATEST"
		sed -i "s/pkgver=.*/pkgver=$_LATEST/g" PKGBUILD

		# Then update the source's checksum
		echo "Updating checksum for ${_PKGNAME[$i]}"
		updpkgsums &>/dev/null

		# Generate a changelog between both versions to append to this commit
		echo "Generating changelog for ${_PKGNAME[$i]}"
		_TMPDIR=$(mktemp -d)
		_CURDIR=$(pwd)
		git clone --depth 1 "${_SOURCES[$i]}" "${_TMPDIR}" &>/dev/null

		cd "${_TMPDIR}" || echo "Failed to cd into ${_TMPDIR}!"
		_CHANGELOG=$(pipx run --spec commitizen cz changelog "$pkgver".."$_LATEST" --dry-run)
		cd "$_CURDIR" || echo "Failed to change back to the previous directory!"

		# Push changes back to main, triggering an instant deployment
		git add PKGBUILD
		git commit -m "bump: ${_PKGNAME[$i]} to $_LATEST [deploy ${_PKGNAME[$i]}]" -m "$_CHANGELOG"
		git push "$REPO_URL" HEAD:main # Env provided via GitLab CI
	else
		echo "${_PKGNAME[$i]} is up to date"
	fi

	cd .. || echo "Failed to change back to the previous directory!"
	i=$((i + 1))
done
