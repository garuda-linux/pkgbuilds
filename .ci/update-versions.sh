#!/usr/bin/env bash
# shellcheck disable=SC1090

_PREV_VERSIONS=$(cat VERSIONS)
_NEW_VERSIONS=$(for i in */PKGBUILD; do
    source "$i"
    printf "%s %s\n" "$pkgname" "$pkgver"
done)

if [ "$_PREV_VERSIONS" != "$_NEW_VERSIONS" ]; then
    echo "$_NEW_VERSIONS" >VERSIONS
    echo "Updated versions file ✨"

    # Ensure we always have the latest version since the update job might
    # have pushed an updated version after the git repo state of this pipeline
    git switch main # we are in detached HEAD state by default
    git pull --rebase
    git add VERSIONS
    git commit -m "chore(versions): update with new PKGBUILD versions [skip ci]"
    git push "$REPO_URL" HEAD:main # provided via GitLab CI
else
    echo "No changes in versions 🎉"
    exit 0
fi
