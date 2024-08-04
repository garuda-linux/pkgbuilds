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

## CI / build tools

The following is partially taken from the build tools documentation, omitting information not relevant to this repo. In case you are looking for setup instructions, please it's [full README](https://gitlab.com/chaotic-aur/pkgbuilds/-/blob/main/README.md?ref_type=heads) instead.

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

### Adding packages

Adding packages is as easy as creating a new folder named after the `$pkgbase` of the package. Put the PKGBUILD and all
other required files in here.
Adding AUR packages is therefore as simple as cloning its repo and removing the `.git` folder.
CI relies on `.SRCINFO` files to parse most information, therefore, it is important to have them in place and up-to-date
in case of self-managed packages.
Finally, add a `.CI` folder containing the basic config (`CI_PKGBUILD_SOURCE` is required in case its external package,
self-managed PKBUILDs don't need it), commit any changes, and push the changes back to the main branch.
Please follow the [conventional commit convention](https://www.conventionalcommits.org/en/v1.0.0/) while doing
so ([cz-cli](https://github.com/commitizen/cz-cli) can help with that!). This means commits like:

- `feat($pkgname): init`
- `fix($pkgname): fix xyz`
- `chore($pkgname): update PKGBUILD`
- `ci(config): update`

This not only helps with having a uniform commit history, it also allows automatic changelog generation.

### Removing packages

This can be done by removing the folder containing a package's PKGBUILD. A cleanup job will then automatically remove
any obsolete package via the `on-commit` pipeline run. This will also consider any split packages that a package might
produce.
Renaming folders does also count as removing packages.

### On-commit pipeline

Whenever pushing a new commit, the CI pipeline will carry out the following actions:

- Checking when the last `scheduled` tag was created. This is used to determine which packages need to be scheduled.
- It parses each commit for a `[deploy $foldername]` string, only accepting valid values derived from the existing
  PKGBUILD folders. `[deploy all]` is a valid parameter as well. Misspelling `$pkgname` is a fatal error here. Any
  issues must be fixed and force-pushed.
- Then, the changed files are parsed. This also includes removed packages. Any changed relevant folder content will
  cause a package deployment of the corresponding package.
- The final action is to build the schedule parameters (handing it over to the scheduled job via artifacts) and remove
  all obsolete packages in case an earlier step is detected.
- In case all of these actions succeed, the `scheduled` tag gets updated, so we can refer to it on a later pipeline run.

### On-schedule pipeline

#### Half-hourly

Every half an hour, the on-schedule pipeline will carry out a few tasks:

- Updating the CI template from the template repository (in case this is enabled via `.ci/config`)
- Check if the scheduled tag does not exist or scheduled does not point to HEAD (in this case abort mission!)
- Check whether the .state worktree containing the state of the packages exists, if it does, it sets it up. Otherwise,
  it re-creates it from scratch (e.g., on force push)
- Check whether the last commit is automated (containing "chore(packages): update packages [skip ci]"), if yes, the
  commit resulting from the schedule will overwrite it to keep the commit history clean.
- Collect AUR timestamps of packages to determine whether a PKGBUILD changed
- Loop through each valid package and carry out the following actions:
  - Read the `.CI/config` file to gain information about the package configuration (e.g., whether to manage the AUR
    repository, the source of the PKGBUILD, etc.)
  - Update PKGBUILD in the following cases:
    - CI_PKGBUILD_SOURCE is set to `gitlab`: Updates the PKGBUILD from the GitLab repository tags
    - CI_PKGBUILD_SOURCE is set to `aur`: Updates the PKGBUILD from the AUR repository, pulling in the git repo and
      replacing the existing files with the new ones.
      If the AUR timestamp could not be collected earlier, the package update gets skipped.
    - CI_PKGBUILD_SOURCE is not set to `gitlab` or `aur`:
      tries to update the PKGBUILD by pulling the repository specified in CI_PKGBUILD_SOURCE.
      In case cloning was not successful after 2 tries, the update process gets skipped.
  - In case CI_GIT_COMMIT is set in the packages configuration variables, the latest commit of the git URL set in
    the `source` section of the PKGBUILD is
    updated. If it differs, schedule a build.
  - In case a custom hook exists (`.CI/update.sh` inside the package directory), it gets executed - this can be used for
    updating PKGBUILDs with a custom script.
  - Writing needed variables back to `.CI/config` (eg. Git hash)
- Either update the PKGBUILD silently in case of minor changes, create a PR for review in case of major updates (and
  only if `CI_HUMAN_REVIEW` is true)
  - Updates are only considered if diff actually reports changes between current PKGBUILD folder and AUR PKGBUILD repo
  - Any change made to the source files is detected, this however does _not_ detect malicious changes in the upstream
    project source that the package builds
- The state worktree gets updated with new information
- Schedule parameters are getting built and handed over to the scheduled job via artifact
- Obsolete branches (eg. merged review PRs) are getting pruned
- The scheduled tag gets updated again

#### Daily

A daily pipeline schedule has been added for specific packages which generate their `pkgver` dynamically.
To make use of it, set `CI_ON_TRIGGER=daily` inside the `.CI/config` file of the package.

### Manual scheduling

#### Scheduling packages without git commits

Packages can be added to the schedule manually by going to
the [pipeline runs](https://gitlab.com/chaotic-aur/pkgbuilds/-/pipelines) page, selecting "Run pipeline" and
adding `PACKAGES` as a variable with the package names as its value. The pipeline will then pick up the packages and
schedule them.
`PACKAGES` can also be set to `all` to schedule all packages. In case one or many packages are getting scheduled, it
needs to follow the format `pkgname1:pkgname2:pkgname3`.

#### Running scheduled pipelines on-demand

This can be done by going to the [pipeline runs](https://gitlab.com/chaotic-aur/pkgbuilds/-/pipeline_schedules) page,
selecting "Run pipeline" (the play symbol). A link to the pipeline page will be provided, where the pipeline logs can be
obtained.

### Adding interfere

Put the required interfere file in the `.CI` folder of a PKGBUILD folder:

- `prepare`: A script that is being executed after the building chroot has been set up. It can be used to source
  environment variables or modify other things before compilation starts.
  - If something needs to be set up before the actual compilation process, commands can be pushed by inserting
    eg. `$CAUR_PUSH 'source /etc/profile'`. Likewise, package conflicts can be solved, eg. as
    follows: `$CAUR_PUSH 'yes | pacman -S nftables'` (single quotes are important because we want the variables/pipes to
    evaluate in the guest's runtime and not while interfering)
- `interfere.patch`: a patch file that can be used to fix either multiple files or PKGBUILD if a lot of changes are
  required. All changes need to be added to this file.
- `PKGBUILD.prepend`: contents of this file are added to the beginning of PKGBUILD.
- `PKGBUILD.append`: contents of this file are added to the end of PKGBUILD. Fixing `build()` as is easy as adding the
  fixed `build()` into this file. This can be used for all kinds of fixes. If something needs to be added to an array,
  this is as easy as `makedepend+=(somepackage)`.
- `on-failure.sh`: A script that is being executed if the build fails.
- `on-success.sh`: A script that is being executed if the build succeeds.

### Bumping pkgrel

This is now carried out by adding the required variable `CI_PACKAGE_BUMP` to `.CI/config`. See below for more information.

### Dependency trees

The CI builds dependency trees automatically. They are passed to the Chaotic manager as a CI artifact and read whenever
a schedule command is being executed.
No manual intervention is needed.

### .CI/config

The `.CI/config` file inside each package directory contains additional flags to control the pipelines and build
processes with.

- `CI_MANAGE_AUR`: By setting this variable to `true`, the CI will update the corresponding AUR repository at the end of
  a
  pipeline run if changes occur (omitting CI-related files)
- `CI_PACKAGE_BUMP`: Controls package bumps for all packages which don't have `CI_MANAGE_AUR` set to `true`. It
  increases `pkgrel` by `0.1` for every `+1` increase of this variable.
- `CI_PKGBUILD_SOURCE`: Sets the source for all PKGBUILD-related files, used for pulling updated files from remote
  repositories.
  Valid values as of now are:
  - `gitlab`: Pulls the PKGBUILD from the GitLab repository tags. It needs to follow the format `gitlab:$PROJECT_ID`.
    The ID can be obtained by browsing the repository settings general section.
  - `aur`: Pulls the PKGBUILD from the AUR repository, pulling in the git repo and replacing the existing files with the
    new ones.
- `CI_ON_TRIGGER`: Can be provided in case a special schedule trigger should schedule the corresponding package. This
  can be used to schedule packages daily, by setting the value to `daily`.
  Since this checks whether "$TRIGGER == $CI_ON_TRIGGER", any custom schedule can be created using pipeline schedules
  and setting `TRIGGER` to `midnight`, adding a fitting schedule and setting `CI_ON_TRIGGER` for any affected package
  to `midnight`.
- `CI_REBUILD_TRIGGERS`: Add packages known to be causing rebuilds to this variable. A list of repositories to track package versions for is provided via the repositories' `CI_LIB_DB` parameter. Each package version is hashed and dumped to `.ci/lib.state`. Each scheduled pipeline run compares versions by checking hash mismatches and will bump each each affected package via `CI_PACKAGE_BUMP`.
- `BUILDER_CACHE_SOURCES`: Can be set to `true` in case the sources should be cached between builds. This can be useful
  in case of slow sources or sources that are not available all the time. Sources will be cleared automatically after 1
  month, which is important in case packages are getting removed or the source changes.

### Managing AUR packages

AUR packages can also be managed via this repository in an automated way using `.CI_CONFIG`.
This means that after each scheduled and on-commit pipeline, the AUR repository will be updated to reflect the changes
done to the PKGBUILD folder's files.
Files not relevant to AUR maintenance (e.g. `.CI` folders) will be omitted.
The commit message reflects the fact that the commit was created by a CI pipeline
and contains the link to the source repository's commit history and the pipeline run which triggered the update commit.

### Updating the CI's scripts

This is done automatically via the CI pipeline. Once changes have been detected on the template repository, all files
will be updated to the current version.

### Issues and pipeline failures

#### Last on-commit pipeline failed

This can happen in case of a few reasons, for example having provided an invalid package name. This causes
the `scheduled` tag to not be updated.
In this case, the on-schedule pipeline will not be able to run.
The last on-commit pipeline needs to be fixed before the on-schedule pipeline can run again.
Build failures however are not accounted as the `scheduled` tag would be updated already as soon as the scheduling
parameters were generated.
Force pushing a fixed up commit is actively encouraged in such a case, as pushing another commit will cause the CI to
evaluate the previous commits it missed, leading to noticing the same issue again and bailing out instead of silently
continuing.
This has been a design decision to prevent failures from being overlooked.

#### Resetting the build queue

There might be rare cases in which a reset of the build queue is needed. This can be done by shutting down the central
Redis instance, removing its dump, and restarting its service.

### Chaotic Manager

This tool is distributed as Docker containers and consists of a pair of manager and builder instances.

- Manager: `registry.gitlab.com/garuda-linux/tools/chaotic-manager/manager`
- Builder: `registry.gitlab.com/garuda-linux/tools/chaotic-manager/builder`
  - This one contains the actual logic behind package builds (seen [here](https://gitlab.com/garuda-linux/tools/chaotic-manager/-/tree/main/builder-container?ref_type=heads)) known from infra 3.0 like `interfere.sh`, `database.sh` etc.
  - Picks packages to build from the Redis instance managed by the manager instance

The manager is used by GitLab CI in the `schedule-package` job, scheduling packages by adding it to the build queue.
The builder can be used by any machine capable of running the container. It will pick available jobs from our central Redis instance.

## Development setup

This repository features a NixOS flake, which may be used to set up the needed things like pre-commit hooks and checks,
as well as needed utilities, automatically via [direnv](https://direnv.net/). This includes checking PKGBUILDs
via `shellcheck` and `shfmt`.
Needed are `nix` (the package manager) and [direnv](https://direnv.net/), after that, the environment may be entered by
running `direnv allow`.
