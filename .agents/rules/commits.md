# Commits

A commit subject is a plain imperative title, such as `Add haptic feedback to the mic button`. When GitHub squash-merges a pull request, it appends the pull request number: `Add haptic feedback to the mic button (#12)`.

A commit message is written in American English and mentions only what exists in this repository or at a public URL.

Messages git writes itself (`Merge …`, `Revert "…"`, `Reapply "…"`, `fixup! …`, `squash! …`, `amend! …`) keep git's wording. In a revert or reapply, add the reason to the body below the line git writes; in a pull request, give it in the pull request description instead. When the subject would nest quotes, as in `Revert "Reapply "…""`, replace it with a subject of your own by the rules below.

## Subject

- Write it as an imperative that completes "If applied, this commit will …".
- Start with a capital letter and end without a period. Capitalize the rest as in the project's documentation and code comments.
- Name the change specifically enough to understand without opening the diff, not `Fix warning`, `Fix CI`, `Improve performance`, `Update Formatting.swift` or `Address review feedback`:
  - For a fix, the symptom and when it happens: `Fix the mic button staying red after dictation ends`
  - For a deliberate change, the new behavior: `Change the default punctuation mode to automatic`
  - For restructured code, the operation rather than `Refactor`: `Extract audio session setup into AudioSessionController`
- Describe behavior as a user sees it. Name a type, function or file only when the change is about that code: `Fix dictation stopping when the keyboard switches languages`, not `Fix state reset in DictationSession`.
- Write identifiers as they are, without backticks.
- Keep it within 72 characters, not counting the ` (#N)` that GitHub appends on merge and you never type.
- One change per commit: if the subject needs "and" to join two changes, split the commit.
- Do not add a type prefix (`feat:`, `fix:`), a scope, a `[Tag]` or `Keyboard:` prefix, an issue number or emoji.
- Release commits use exactly `Bump version to X.Y.Z` or `Bump build to N`. A new version is one `Bump version to X.Y.Z` commit, even when the build number changes with it.

## Body

- Add one when the subject cannot carry why the change was made: what was wrong or missing, and why this approach. The diff already shows what changed. In a pull request, give this reason in the pull request description instead.
- Separate it from the subject with a blank line and wrap lines at 72 characters.
- Write full sentences. Leave code samples, logs and long details to the issue or pull request.
- For several separate points, use a list: one `- ` item per point, each a full sentence; indent wrapped lines by two spaces.
- Close an issue with `Fixes #N` on its own line; in a pull request, put it in the pull request description instead.
- When a commit made outside a pull request contains work by someone other than its git author, credit them with `Co-authored-by: Name <email>` in its own paragraph at the end of the message, after any `Fixes #N` line. Use their GitHub no-reply address, `ID+username@users.noreply.github.com` with the ID from `gh api users/username`, unless they asked you to use another email linked to their GitHub account.
