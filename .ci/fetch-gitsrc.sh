#!/usr/bin/env bash

command -v git &>/dev/null || echo "Git is not installed!"

# Build a list of valid VCS packages
mapfile -t _PACKAGES < <(find . -mindepth 1 -type d -prune | sed -e '/.\./d' -e 's/.\///g')
mapfile -t _VCS_PKG < <(printf '%s\n' "${_PACKAGES[@]}" | sed '/-git/!d')

for package in "${_VCS_PKG[@]}"; do
    printf "\nChecking %s...\n" "$package"

    # Get current commit via .CI_CONFIG and the first occurrence of a git source
    _CURRENT_COMMIT=$(grep "CI_GIT_COMMIT=" "$package/.CI_CONFIG" | cut -f1)
    _SOURCE=$(grep -oP '\ssource\s=\s\Kgit.*$\n?' "$package/.SRCINFO")

    # Abort mission if source contains a fixed commit
    for fragment in branch commit tag revision; do
        if [[ "$_SOURCE" == *"#$fragment="* ]]; then
            echo "Can't update pkgver due to fixed $fragment, skipping."
            continue
        fi
    done

    # Strip git+ as ls-remote doesn't accept this kind of URL, then
    # retrieve latest commit based on current HEAD. This makes the operation
    # independant from any API and works with any git remote repository
    _SRC="${_SOURCE//git+/}"
    _NEWEST_COMMIT=$(git ls-remote "$_SRC" | grep HEAD | cut -f1)

    # Finally update CI_GIT_COMMIT
    if [[ "$_NEWEST_COMMIT" != "$_CURRENT_COMMIT" ]]; then
        if ! grep -q "CI_GIT_COMMIT=" "$package/.CI_CONFIG"; then
            printf "\nCI_GIT_COMMIT=%s" "$_NEWEST_COMMIT" >>"$package/.CI_CONFIG"
        else
            sed -i "s/CI_GIT_COMMIT=.*/CI_GIT_COMMIT=$_NEWEST_COMMIT/g" "$package/.CI_CONFIG"
        fi
    else
        echo "Package already up-to-date."
        continue
    fi
done

# Push back any changes in case of updates, triggering a rebuild for any package which had its
# .CI_CONFIG updated
if ! git diff --exit-code --quiet; then
    git add .
    git commit -m "chore(git-versions): update current git commits"
    git push "$REPO_URL" HEAD:main || git pull --rebase && git push "$REPO_URL" HEAD:main # Env provided via GitLab CI
else
    echo "No changes to commit."
fi
