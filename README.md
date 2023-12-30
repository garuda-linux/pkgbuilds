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

## GitLab CI

### General

Deployments may automatically be triggered by either changing content inside a PKGBUILD directory or appending `[deploy *]` to the commit message.
Unlike the PKGBUILD checks, these are only available for commits on the `main` branch. Supported are:

- `[deploy all]`: Deploys a full `garuda` routine, meaning all PKGBUILDs in this repository.
- `[deploy $pkgname]`: Deploys the package `pkgname`, which means that by replacing this with `garuda-bash-settings`, one would deploy `garuda-bash-settings`.

Once any of those combinations gets detected, the deployment starts after a few checks are completed successfully.
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

### Manually updating versions

For some PKGBUILDs, like `garuda-fish-config`, all files reside in this repository.
**When updating PKGBUILDs, please ensure to also update the corresponding `.SRCINFO` file as this one is used to parse all package related information!**

### .CI_CONFIG

The `.CI_CONFIG` file inside each package directory contains additional flags to control the pipelines and build processes with.

- `CI_GIT_COMMIT`: Used by CI to determine whether the latest commit changed. Used by `fetch-gitsrc` to schedule new builds.
- `CI_IS_GIT_SOURCE`: By setting this to `1`, the `fetch-gitsrc` job will check out the latest git commit of the source and compare it with the value recorded in `CI_GIT_COMMIT`.
  If it differs, schedules a build.
  This is useful for packages which use `pkgver()` to set their version without being having `-git` or another VCS package suffix.
- `CI_MANAGE_AUR`: By setting this variable to `1`, the CI will update the corresponding AUR repository at the end of a pipeline run if changes occurred (omitting CI-related files)
- `CI_PKGREL`: Controls package bumps for all packages which don't have `CI_MANAGE_AUR` set to `1`. It increases `pkgrel` by `0.1` for every `+1` increase of this variable.
- `CI_PKGBUILD_SOURCE`: Sets the source for all PKGBUILD related files, used for pulling updated files from remote repositories

### Managing AUR packages

AUR packages can also be managed via this repository in an automated way using `.CI_CONFIG`. See the above section for details.

### Jobs

These generally execute scripts found in the `.ci` folder.

- Check PKGBUILD:
  - Checks PKGBUILD for superficial issues via `namcap` and `aura`
- Check rebuild:
  - Checks whether packages known to be causing rebuilds have been updated
  - Updates `pkgrel` for affected packages and pushes changes back to this repo
  - This triggers another pipeline run which schedules the corresponding builds
- Fetch Git sources:
  - Checks whether the latest git commit differs from the one found in `.CI_CONFIG`, updating it in case it changed.
    Changes are then pushed back to this repo
  - This also triggers another pipeline run
- Lint:
  - Lints scripts, configs and PKGBUILDs via a set of linters
- Manage AUR:
  - Checks `.CI_CONFIG` in each PKGBUILDs folder for whether a package is meant to be managed on the AUR side
  - Clones the AUR repo and updates files with current versions of this repo
  - Pushes changes back
- Schedule package:
  - Checks for a list of changes between the last two commits
  - Checks whether a `[deploy]` string exists in the commit message or PKGBUILD directories changed
  - In either case a list of packages to be scheduled for a build gets created
  - Schedules all changed packages for a build via Chaotic Manager

### Chaotic Manager

This tool is distributed as Docker containers and consists of a pair of manager and builder instances.

- Manager: `registry.gitlab.com/garuda-linux/tools/chaotic-manager/manager`
- Builder: `registry.gitlab.com/garuda-linux/tools/chaotic-manager/builder`
  - This one contains the actual logic behind package builds (seen [here](https://gitlab.com/garuda-linux/tools/chaotic-manager/-/tree/main/builder-container?ref_type=heads)) known from infra 3.0 like `interfere.sh`, `database.sh` etc.
  - Picks packages to build from the Redis instance managed by the manager instance

The manager is used by GitLab CI in the `schedule-package` job, scheduling packages by adding it to the build queue.
The builder can be used by any machine capable of running the container. It will pick available jobs from our central Redis instance.

## Development setup

This repository features a NixOS flake, which may be used to set up the needed things like pre-commit hooks and checks, as well as needed utilities, automatically via [direnv](https://direnv.net/).
Needed are `nix` (the package manager) and [direnv](https://direnv.net/), after that, the environment may be entered by running `direnv allow`.
