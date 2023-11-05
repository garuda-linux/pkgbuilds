# Garuda Linux PKGBUILDs

[![pipeline status](https://gitlab.com/garuda-linux/pkgbuilds/badges/main/pipeline.svg)](https://gitlab.com/garuda-linux/pkgbuilds/-/commits/main)

This repository contains PKGBUILDs for all packages that currently reside in its `garuda` repository.

## Scope

All of our own PKGBUILDs are contained here. Historically, these were split into their own repositories. To make finding the correct PKGBUILD easier, as well as to allow faster contributing, we recently consolidated them into this new repository. Included are all packages' PKGBUILDs including their configuration files (this applies to smaller files like the `garuda-fish-config`). For some of them, like the `garuda-*-settings` packages, the content may still be found in their respective repositories.

## Found any issue?

If any packaging issues or similar things occur, don't hesitate reporting them via our issues section. You can click [here](https://gitlab.com/garuda-linux/pkgbuilds/-/issues/new) to create a new one.

## How to contribute?

We highly appreciate contributions of any sort! 😊 In order to do so, please follow these steps:

- [Create a fork of this repository](https://gitlab.com/garuda-linux/pkgbuilds/-/forks/new)
- Clone your fork locally ([short git tutorial](https://rogerdudler.github.io/git-guide/))
- Add the desired changes to PKGBUILDs or code
- Ensure [shellcheck](https://www.shellcheck.net) and [shfmt](https://github.com/patrickvane/shfmt) report no issues with the changed files (run the `lint.sh` script)
- Commit and push any changes back to your fork
- [Create a new merge request at our main repository](https://gitlab.com/garuda-linux/pkgbuilds/-/merge_requests/new)

We will then review the changes and eventually merge them.

## Deployments

Deployments may automatically be triggered by appending `[deploy *]` to the commit message. Supported are:

- `[deploy all]`: Deploys a full `garuda` routine, meaning all PKGBUILDs in this repository
- `[deploy pkgname]`: Deploys the package `pkgname`, by replacing this with `garuda-bash-settings`, `garuda-bash-settings` would be the deployed package

Once any of those combinations gets detected, the deployment starts after `shfmt` and `shellcheck` checks completed successfully.

Logs of past deployments may be inspected via the [Pipelines](https://gitlab.com/garuda-linux/pkgbuilds/-/pipelines) section.
