#!/usr/bin/env bash

set -e

################################################################################
# Description
################################################################################
# This script is here to assist the maintenance of the upstream patches that are
# required to support this project.
#
# The script is divided in 2 stages:
#  - Stage 1 is to ensure that the current stored patches are exactly the same
#    to what is already commited in the repo.
#  - Stage 2 is to re-apply the patches over a merge-commit on the target branch
#    and ensure that they are still valid, update them if necessary and change
#    the stored patches accordingly.

################################################################################
# Functions
################################################################################
function _info() {
  >&2 echo "## ${@}"
}

function _error() {
  >&2 echo "error: ${@}"
}

function _git() {
  >&2 echo "+ git ${@}"
  git -C "${REPO_DIR}" "${@}"
}

function cleanup() {
  rm -r "${TMP_DIR}"
  _git switch "${STARTING_BRANCH}"
  _git branch -D "${TESTING_BRANCH}"
}

function format_patch_help() {
  echo "rm '${PATCHES_DIR}'/* && git format-patch --no-signature --keep-subject --zero-commit --output-directory '${PATCHES_DIR}' '${INITIAL_REF}'..HEAD"
}

################################################################################
# Globals
################################################################################
# The path to this script parent folder
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# The path to the root of the git repo
REPO_DIR="${SCRIPT_DIR}/.."
# The path to the dir with all the upstream patches
PATCHES_DIR="${REPO_DIR}/codee/patches"
# The starting branch in case we want to go back
STARTING_BRANCH="$(_git branch --show-current)"
# The branch that we will use to detect that the first stage was done correctly
TARGET_BRANCH="feature/UpgradeTreeSitterFortranAuto"
# Name of a temporary branch that we can delete later
TESTING_BRANCH="merge-upstream-testing-${RANDOM}"
# The name of the upstream git remote repo
MERGE_WITH="${MERGE_WITH:-tree-sitter-fortran/master}"
# List of git refspecs for the upstream code excluding downstream
DOWNSTREAM_PATHS=(:/ :^codee :^src/tree_sitter :^src/grammar.json :^src/node-types.json :^src/parser.c)

################################################################################
# Script
################################################################################
if [[ $# != 0 ]]; then
  >&2 echo "usage: ${0}

  Helper script to help merge (and verify our changes in) upstream code.

  This script parameters aren't supposed to be modified, so they are coded as
  variables inside the script."
  exit 1
fi

if [[ "${STARTING_BRANCH}" != "${TARGET_BRANCH}" ]]; then
  _info "Stage 1: Validate that the existing patches represent the current state
  - First, create a new '${TESTING_BRANCH}' branch to perform the validation
  - On that branch, reset the upstream folders to the upstream version
  - Apply all the stored patches and check if they match the original branch
    - If so, proceed to the second stage
    - If not, give instructions on how to fix the issue
"
  STAGE2=false
else
  _info "Stage 2: Finish the upstream update
  - It is assumed that the first stage finished successfully.
  - We will merge the '${MERGE_WITH}' branch discarding all our changes
  - To then apply all the stored patches one by one
  - After solving all conflicts, the merge should be ready to:
    - Pass tests, prepare for review and finally recreate the patches
"
  STAGE2=true
fi

_info "Do you want to proceed (Enter to continue, Ctrl+C to exit)?"
read

# Always ensure that the working tree and the stage are clean
if [ "$(_git status --porcelain)" != "" ]; then
  _error "Your working tree and stage must be clean"
  exit 1
fi

# In the first stage, sync up the remote branch
if ! _git describe "${MERGE_WITH}" &>/dev/null; then
  _error "there is no upstream to merge with ('${MERGE_WITH}'). You can add it
with:

  git remote add 'tree-sitter-fortran' git@github.com:stadelmanma/tree-sitter-fortran.git
  git fetch tree-sitter-fortran master"
  exit 1
fi

if [ "${STAGE2}" == false ]; then
  # The target branch shouldn't exist on the first stage
  if git show-ref --quiet --verify "refs/heads/${TARGET_BRANCH}"; then
    _error "target branch '${TARGET_BRANCH}' must not exist on stage1"
    exit 1
  fi

  UPSTREAM_TARGET=$(_git merge-base HEAD "${MERGE_WITH}")
  echo "# Stage 1: Verify that the patches are up to date (on current base)"
  _git switch --create "${TESTING_BRANCH}"
else
  UPSTREAM_TARGET="${MERGE_WITH}"

  echo "# Stage 2: Apply the already verified patches (on '${UPSTREAM_TARGET}')"
  _git merge --strategy=ours --no-commit "${UPSTREAM_TARGET}"
fi

# Copy the patches to a place outside git (in case you're changing them in the process)
TMP_DIR="$(mktemp -d)"
cp "${PATCHES_DIR}"/* "${TMP_DIR}"

# Discard all the upstream changes already committed
_git restore --source="${UPSTREAM_TARGET}" --worktree --staged -- "${DOWNSTREAM_PATHS[@]}"

# Create a commit to then, apply the patches stored
if [ "${STAGE2}" == false ]; then
  _git commit -m "[merge-upstream] Reverted upstream chances since '${UPSTREAM_TARGET}'"
else
  _git commit -m "Merge tree-sitter-fortran/master (to be finished)"
fi

# Store the reference to the start of the format-patch spec
INITIAL_REF="$(_git rev-parse HEAD)"

# Apply all the patches
if ! _git am --3way -k "${TMP_DIR}/"*; then
  _error "Patches are not up to date. You'll need to address the issues
and redo the patches before trying again.

    $(format_patch_help)
"
  exit 3
fi

if [ "${STAGE2}" == false ]; then
  # Check if there are any other changes that weren't in the patches
  if ! _git diff --quiet HEAD.."${STARTING_BRANCH}"; then
    >&2 echo "There are changes that are still not part of the patches:

    git diff HEAD..'${STARTING_BRANCH}'

  If the changes are new, just commit them as normal. If the changes are
  modifications of previous commits, you can try to ammend them automatically:

    git diff HEAD..'${STARTING_BRANCH}' | git apply --index
    git absorb --base '${INITIAL_REF}'

  Review carefully the changes you need to do, and then recreate the patches.

    $(format_patch_help)
"
    exit 2
  fi

  cleanup
  # Create the target branch for the second stage
  _git switch --create "${TARGET_BRANCH}"

  echo "
# Stage 1 completed succesfully. You are ready to jump to stage 2:
  $0"
else
  echo "
# Stage 2 completed succesfully. You're now on your own. Don't forget to:
  - Ensure that the patches compile successfully.
  - Fix the failing tests.
  - Update the final patches to the new version and open a PR to review them.
    $(format_patch_help)
  - Squash all the patches in the final merge commit!

  Good luck!"
fi
