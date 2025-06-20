# How to merge `tree-sitter-fortran`

This document explains the process for updating our downstream copy of
`tree-sitter-fortran` repository with the latest changes from the upstream
repository, ensuring Codee remains up-to-date with new features, fixes, and
improvements.

## 0. Prerequisites

Before merging upstream changes, ensure that the official `tree-sitter-fortran`
repository is added as a Git remote and updated. If it is not already
configured, you can set it up with the following commands:

```bash
$ git remote add tree-sitter-fortran git@github.com:stadelmanma/tree-sitter-fortran.git
$ git fetch tree-sitter-fortran master
```

Additionally, confirm that your local working directory is clean, with no
uncommitted changes, to avoid conflicts during the merge process.

## 1. Run the update script

Run the [`codee/merge-upstream.sh`](/codee/merge-upstream.bash) script to check
whether our [`codee/patches`](/codee/patches) are synchronized with our
downstream repository. If the patches are outdated, you must update and merge
them to ensure compatibility before proceeding with the main merge process.

Once the patches are verified and up-to-date, the script transitions to a second
stage. In this stage, the script applies the patches to our downstream project,
incorporating the latest upstream changes. This process involves using `git am`
to apply each patch from the `codee/patches` directory. During this step,
conflicts may arise that you will need to resolve manually.

To identify the source of conflicts, use `git am --show-current-patch=diff`.
This command highlights the specific patch causing the issue, helping you assess
and resolve the conflict efficiently. After addressing the conflict, continue
applying the remaining patches until all patches have been successfully applied.

After all patches are applied, your current branch should resemble the
following:

```bash
$ git log --oneline
92081e66c3b5 Baz
4b5ccc6f50e4 Bar
6858ad4b7960 Foo
# ...
dbdb4564d47c Merge tree-sitter-fortran/master
# ...
```

The commits following `Merge tree-sitter-fortran/master` represent the updated
versions of the patches with conflicts resolved and context synchronized with
the latest upstream changes.

At this point, regenerate the patches to reflect the latest changes by running
the appropriate script. Once regenerated, commit these changes as a fixup commit
to keep the process organized. After updating the patches, you can squash all
the commits created by `git am`, as the relevant changes are now captured within
the patches themselves. There is no need to revisit all the upstream changes;
instead, focus the review on the updates made to the patches in the fixup
commit, ensuring that only the necessary adjustments are highlighted.

## 2. Prepare the changes for review

At this stage, it is time to prepare your branch for review. Take into
consideration that a clean and well-organized commit history will significantly
improve the review process and make it easier to identify meaningful changes.

For example, the commit that updates the conflicting patches can be separated.
This commit often contains updates to the context of the patches, but we are
only interested in those where conflicts actually occurred. You can either
squash these updates into the merge commit or leave them as a separate fixup
commit. If you choose the latter, make sure to clearly label these commits with
a message like "Do not review" so reviewers can easily skip them.

Additionally, ensure that each commit has a clear and concise message, ideally
with references to relevant upstream changes. Once you have organized and
squashed any unnecessary commits, your branch should be ready for review.
Reviewers can then focus solely on the key changes that align with the upstream
updates, without being bogged down by irrelevant or redundant commits.

Furthermore, during the process, you may identify commits that can be merged
into the downstream project prior to the actual upstream merge. These commits
could include improvements that help streamline the review process, such as
migrating away from deprecated APIs that will be removed in the merge. In such
cases, it is best to separate these changes and submit them as a distinct
pull request, to be merged before the main upstream merge. This approach keeps
the integration process clean, ensures clarity, and avoids potential
complications by addressing non-merge-related improvements ahead of time.

To further ease the review process, consider submitting a branch with just the
merge commit. Then, create a separate branch that targets this merge branch,
containing only the fixup commits. This will allow reviewers to focus
exclusively on the necessary adjustments, without having to look through the
upstream commit history.

## 3. Cleanup and pushing the final changes

Once the pull request has been fully reviewed and you have addressed all the
review comments, it is time to finalize the changes and prepare them for
merging. The goal here is to ensure that all necessary changes are
well-organized and that the commit history is clean and concise.

First, take a look at any post-merge commits and decide how to handle them. You
may place them before the merge commit if applicable, or squash them into the
merge commit, making sure to retain the squashed commit's message in the merge
commit's message.

Assuming the merge is already passing tests in the
`feature/UpgradeTreeSitterFortranAuto` branch, the workflow for this step should
look something like this:

```bash
# Branch off feature/UpgradeTreeSitterFortranAuto to update it
$ git switch -c feature/UpdatedUpgradeTreeSitterFortranAuto feature/UpgradeTreeSitterFortranAuto
# Merge changes from origin/codee and solve any potential conflicts with newer
# codee changes
$ git merge origin/codee
# Create a final branch to clean things up
$ git switch -c feature/FinalUpgradeTreeSitterFortranAuto origin/codee
# Cherry-pick commits to place before the merge commit
$ git cherry-pick <commit to place before merge>
# Re-run the intended merge
$ git merge --no-commit <merge commit>
# If merging unrelated histories, you may need to remove deleted files
$ for f in $(git status --porcelain | grep "UD" | cut -d " " -f 2); do git rm $f; done
# Don't worry about conflicts; simply restore the original branch
$ git restore --source feature/UpgradeTreeSitterFortranAuto .
# Stage everything
$ git add .
# Commit to finish the merge, including messages for the remaining post-merge
# commits that were not moved
$ git commit
# Optionally add commits that need to be placed after the merge
$ git cherry-pick <commit to place after merge>
# Optionally check that the new branch matches the updated branch
$ git diff feature/FinalUpgradeTreeSitterFortranAuto feature/UpdatedUpgradeTreeSitterFortranAuto
# Push the final branch
$ git push feature/FinalUpgradeTreeSitterFortranAuto origin/feature/FinalUpgradeTreeSitterFortranAuto
```

Once you have pushed your final branch, open a pull request targeting `codee`
with `feature/FinalUpgradeTreeSitterFortranAuto` and request any necessary
approvals. This step should be a formality as everything has already been
reviewed in the previous pull request.

After the pull request is approved and tests pass, push it to `codee`:

```bash
$ git push origin feature/FinalUpgradeTreeSitterFortranAuto:codee
```
