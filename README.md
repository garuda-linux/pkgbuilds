# Garuda Linux PKGBUILDs

[![pipeline status](https://gitlab.com/garuda-linux/pkgbuilds/badges/main/pipeline.svg)](https://gitlab.com/garuda-linux/pkgbuilds/-/commits/main) [![Commitizen friendly](https://img.shields.io/badge/commitizen-friendly-brightgreen.svg)](http://commitizen.github.io/cz-cli/)

This repository contains PKGBUILDs for all packages that currently reside in its `garuda` repository. It is operated on GitLab due to making extensive use of its CI and has a read-only GitHub mirror.

## Scope of this repo

All of our own PKGBUILDs are contained here. Historically, these were split into their own repositories.
To make finding the correct PKGBUILD easier, as well as to allow faster contributing, we recently consolidated them into this new repository.
Included are all packages' PKGBUILDs including their configuration files (this applies to smaller files like the `garuda-fish-config`).
For some of them, like the `garuda-*-settings` packages, the content may still be found in their respective repositories.

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
  - The [commitizen](https://github.com/commitizen-tools/commitizen) application helps with creating a fitting commit message.
    You can install it via [pip](https://pip.pypa.io/) as there is currently no package in Arch repos: `pip install --user -U Commitizen`.
    Then proceed by running `cz commit` in the cloned folder.
- [Create a new merge request at our main repository](https://gitlab.com/garuda-linux/pkgbuilds/-/merge_requests/new).
- Check if any of the pipeline runs fail and apply eventual suggestions.

We will then review the changes and eventually merge them.

## Handling certain packaging issues

### Deprecated and broken packages

There are cases of deprecated packages, which serve no purpose anymore and also cause systems to not be able to update.
These can be handled by adding the package to `conflicts()` of `garuda-common-settings` and [auto-pacman](https://gitlab.com/garuda-linux/pkgbuilds/-/blob/main/garuda-update/auto-pacman?ref_type=heads#L10)
of `garuda-update`. The result is that the offending package gets removed automatically due to the conflict.

## Deployments

### General

Deployments may automatically be triggered by appending `[deploy *]` to the commit message. Unlike the PKGBUILD checks, these are only available for commits on the `main` branch. Supported are:

- `[deploy all]`: Deploys a full `garuda` routine, meaning all PKGBUILDs in this repository.
- `[deploy pkgname]`: Deploys the package `pkgname`, which means that by replacing this with `garuda-bash-settings`, one would deploy `garuda-bash-settings`.

Once any of those combinations gets detected, the deployment starts after `shfmt` and `shellcheck` checks are completed successfully.
Logs of past deployments may be inspected via the [Pipelines](https://gitlab.com/garuda-linux/pkgbuilds/-/pipelines) section.

### Automated bumps

This repository provides a half-hourly pipeline that updates all PKGBUILDs to their latest versions if _their source resides in another repository_, based on the latest available tag.
It then proceeds to update the checksums and pushes the changes back to the main branch. A new deployment is automatically triggered by appending `[deploy *]` to the commit message.
That means it is sufficient to push a new tag in order to trigger the deployment of a new package version for these packages. Important notice:

- This does not apply to packages which have all their files in this repository
- Tags must not be prefixed with a _v_
- Needed information about a package's source are provided via the [SOURCES](./SOURCES) file. Each line follows the scheme `$url $pkgname $project_id`.
  The latter is used to retrieve the latest tag via GitLab API and can be found at the general settings page of the repository.

The latest runs of this job may be inspected by browsing the [pipelines](https://gitlab.com/garuda-linux/pkgbuilds/-/pipelines) section, every pipeline with the _scheduled_ badge was executed by the timer.
Additionally, the pipeline can be triggered manually by browsing the [pipeline schedules](https://gitlab.com/garuda-linux/pkgbuilds/-/pipeline_schedules) section and hitting _run pipeline schedule_.

## The VERSIONS file

In this file, all current packages and their corresponding versions are listed. The file is maintained by GitLab CI, so it will be automatically updated.
To-do: report proper versions for `-git` packages.

## Development setup

This repository features a NixOS flake, which may be used to set up the needed things like pre-commit hooks and checks, as well as needed utilities, automatically via [direnv](https://direnv.net/).
Needed are `nix` (the package manager) and [direnv](https://direnv.net/), after that, the environment may be entered by running `direnv allow`.
