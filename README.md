# Garuda Linux PKGBUILDs

[![pipeline status](https://gitlab.com/garuda-linux/pkgbuilds/badges/main/pipeline.svg)](https://gitlab.com/garuda-linux/pkgbuilds/-/commits/main) [![Commitizen friendly](https://img.shields.io/badge/commitizen-friendly-brightgreen.svg)](http://commitizen.github.io/cz-cli/)

This repository contains PKGBUILDs for all packages that currently reside in its `garuda` repository. It is operated on GitLab due to making extensive use of its CI and has a read-only GitHub mirror.

## Scope

All of our own PKGBUILDs are contained here. Historically, these were split into their own repositories. To make finding the correct PKGBUILD easier, as well as to allow faster contributing, we recently consolidated them into this new repository. Included are all packages' PKGBUILDs including their configuration files (this applies to smaller files like the `garuda-fish-config`). For some of them, like the `garuda-*-settings` packages, the content may still be found in their respective repositories.

## Found any issue?

If any packaging issues or similar things occur, don't hesitate to report them via our issues section. You can click [here](https://gitlab.com/garuda-linux/pkgbuilds/-/issues/new) to create a new one.

## How to contribute?

We highly appreciate contributions of any sort! 😊 To do so, please follow these steps:

- [Create a fork of this repository](https://gitlab.com/garuda-linux/pkgbuilds/-/forks/new).
- Clone your fork locally ([short git tutorial](https://rogerdudler.github.io/git-guide/)).
- Add the desired changes to PKGBUILDs or source code.
- Ensure [shellcheck](https://www.shellcheck.net) and [shfmt](https://github.com/patrickvane/shfmt) report no issues with the changed files
  - The needed dependencies need to be installed before, eg. via `sudo pacman -S shfmt shellcheck`
  - Run the `lint.sh` script via `bash ./.ci/lint.sh` check the code
  - Automatically apply certain suggestions via `bash ./ci/lint.sh apply`
- Commit using a [conventional commit message](https://www.conventionalcommits.org/en/v1.0.0/#summary) and push any changes back to your fork.
  - The [commitizen](https://github.com/commitizen-tools/commitizen) application helps with creating a fitting commit message, you can install it via [pip](https://pip.pypa.io/) as there is currently no package in Arch repos: `pip install --user -U Commitizen`. Then proceed by running `cz commit` in the cloned folder.
- [Create a new merge request at our main repository](https://gitlab.com/garuda-linux/pkgbuilds/-/merge_requests/new).
- Check if any of the pipeline runs fail and apply eventual suggestions.

We will then review the changes and eventually merge them.

## Deployments

Deployments may automatically be triggered by appending `[deploy *]` to the commit message. Unlike the PKGBUILD checks, these are only available for commits on the `main` branch. Supported are:

- `[deploy all]`: Deploys a full `garuda` routine, meaning all PKGBUILDs in this repository.
- `[deploy pkgname]`: Deploys the package `pkgname`, by replacing this with `garuda-bash-settings`, `garuda-bash-settings` would be the deployed package.

Once any of those combinations gets detected, the deployment starts after `shfmt` and `shellcheck` checks are completed successfully.

Logs of past deployments may be inspected via the [Pipelines](https://gitlab.com/garuda-linux/pkgbuilds/-/pipelines) section.

## Development setup

This repository features a NixOS flake, which may be used to set up the needed things like pre-commit hooks and checks, as well as needed utilities, automatically via [direnv](https://direnv.net/). Needed are `nix` (the package manager) and [direnv](https://direnv.net/), after that, the environment may be entered by running `direnv allow`.
