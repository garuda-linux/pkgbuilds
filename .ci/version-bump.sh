#!/usr/bin/env bash

for dep in curl git jq shfmt updpkgsums; do
	command -v "$dep" &>/dev/null || echo "$dep is not installed!"
done

readarray -t _SOURCES < <(awk -F ' ' '{ print $1 }' ./SOURCES)
readarray -t _PKGNAME < <(awk -F ' ' '{ print $2 }' ./SOURCES)
readarray -t _API < <(awk -F ' ' '{ print $3 }' ./SOURCES)

# Allow makepkg to work in a non-root environment & unbreak git
chown -R nobody:root "$CI_BUILDS_DIR"
git config --global --add safe.directory "*"

_COUNTER=0
for package in "${_SOURCES[@]}"; do
	# Get the latest tag from the GitLab API
	_LATEST=$(curl -s "https://gitlab.com/api/v4/projects/${_API[$_COUNTER]}/repository/tags" | jq -r '.[0].name' | sed 's/v//g')
	_CURRENTVER=$(grep -oP '\spkgver\s=\s\K.*' "${_PKGNAME[$_COUNTER]}/.SRCINFO")

	if [[ "$_CURRENTVER" != "$_LATEST" ]]; then
		# Create a temporary directory to work with
		_TMPDIR=$(mktemp -d)
		cd "${_PKGNAME[$_COUNTER]}" || echo "Failed to cd into ${_PKGNAME[$_COUNTER]}!"

		# First update pkgver, resetting pkgrel
		echo "Updating ${_PKGNAME[$_COUNTER]} from $_CURRENTVER to $_LATEST"
		sed -i "s/pkgver=.*/pkgver=$_LATEST/g" PKGBUILD
		sed -i "s/pkgrel=.*/pkgrel=1/g" PKGBUILD

		# Then update the source's checksum
		echo "Updating checksum for ${_PKGNAME[$_COUNTER]}..."
		sudo -u nobody updpkgsums
		echo "Generating .SRCINFO for ${_PKGNAME[$_COUNTER]}..."
		sudo -u nobody makepkg --printsrcinfo | tee .SRCINFO &>/dev/null

		# Apply shfmt, which is needed because of updpkgsums changing intends
		# and potentially failing pipelines due this
		shfmt -d -w PKGBUILD

		# Generate a changelog between both versions to append to this commit
		echo "Generating changelog for ${_PKGNAME[$_COUNTER]}..."

		git clone --depth 1 "${_SOURCES[$_COUNTER]}" "${_TMPDIR}"

		pushd "${_TMPDIR}" || echo "Failed to cd into ${_TMPDIR}!"
		_CHANGELOG=$(pipx run --spec commitizen cz changelog "$_CURRENTVER".."$_LATEST" --dry-run)
		popd || echo "Failed to return to the previous directory!"

		# Push changes back to main, triggering an instant deployment
		git add PKGBUILD
		git commit -m "bump: ${_PKGNAME[$_COUNTER]} to $_LATEST [deploy ${_PKGNAME[$_COUNTER]}]" -m "$_CHANGELOG"
		git push "$REPO_URL" HEAD:main # Env provided via GitLab CI

		cd .. || echo "Failed to change back to the previous directory!"
	else
		echo "${_PKGNAME[$_COUNTER]} is up to date."
	fi

	((_COUNTER++))
done
