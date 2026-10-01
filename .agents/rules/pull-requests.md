# Pull requests

Pull requests are squash-merged: the pull request title becomes the commit subject on `main`, and GitHub appends ` (#N)`. Write the title by the subject rules in [commits.md](commits.md).

Explain in the pull request description why the change is needed: what was wrong or missing, and why this approach. For a revert, explain why the change is reverted. The ` (#N)` in the commit subject on `main` links to the pull request.

To close an issue, put `Fixes #N` in the pull request description, not in a commit message.

If the title breaks the subject rules, correct it with `gh pr edit --title` before merging. Merge with `gh pr merge --squash`, without `--subject` or `--body`, so GitHub writes the commit message itself: `--subject` replaces the whole subject, ` (#N)` included, and `--body` replaces the body GitHub writes, with its `Co-authored-by` lines.

Before merging, check that everyone named in a `Co-authored-by` line of the branch's commits has an entry in `.github/cla-signatures.json`. The CLA check covers the pull request author and the author of every commit, but not those lines, which GitHub copies into the squash commit.
