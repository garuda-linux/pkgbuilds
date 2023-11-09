#!/usr/bin/env bash

for dep in curl git jq updpkgsums; do
	command -v "$dep" &>/dev/null || echo "$dep is not installed!"
done

readarray -t _SOURCES < <(awk -F ' ' '{ print $1 }' ./SOURCES)
readarray -t _PKGNAME < <(awk -F ' ' '{ print $2 }' ./SOURCES)
readarray -t _API < <(awk -F ' ' '{ print $3 }' ./SOURCES)

# Allow makepkg to work in a non-root environment & unbreak git
chown -R nobody:root "$CI_BUILDS_DIR"
git config --global --add safe.directory "*"

i=0
for package in "${_SOURCES[@]}"; do
	# Get the latest tag from the GitLab API
	_LATEST=$(curl -s "https://gitlab.com/api/v4/projects/${_API[$i]}/repository/tags" | jq -r '.[0].name' | sed 's/v//g')

	cd "${_PKGNAME[$i]}" || echo "Failed to cd into ${_PKGNAME[$i]}!"

	# shellcheck disable=SC1091
	source PKGBUILD || echo "Failed to source PKGBUILD for ${_PKGNAME[$i]}!"

	if [[ "$pkgver" != "$_LATEST" ]]; then
		# Create a temporary directory to work with
		_TMPDIR=$(mktemp -d)

		# First update pkgver
		echo "Updating ${_PKGNAME[$i]} from $pkgver to $_LATEST"
		sed -i "s/pkgver=.*/pkgver=$_LATEST/g" PKGBUILD

		# Then update the source's checksum
		echo "Updating checksum for ${_PKGNAME[$i]}"
		sudo -Eu nobody updpkgsums

		# Generate a changelog between both versions to append to this commit
		echo "Generating changelog for ${_PKGNAME[$i]}"

		git clone --depth 1 "${_SOURCES[$i]}" "${_TMPDIR}"

		pushd "${_TMPDIR}" || echo "Failed to cd into ${_TMPDIR}!"
		_CHANGELOG=$(pipx run --spec commitizen cz changelog "$pkgver".."$_LATEST" --dry-run)
		popd || echo "Failed to return to the previous directory!"

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
