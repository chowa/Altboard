# Contributing to Altboard

## Contributor License Agreement

Altboard is distributed on the App Store, and its [license](LICENSE) lets others change and build it, and make new works based on it, only for their own personal use or to propose changes, so your contribution can ship there only with your permission. Before your first pull request is merged, sign the [Contributor License Agreement](CLA.md): you keep the copyright in your work and let the owner of Altboard use, change, sublicense and distribute it on any terms, including in the paid App Store builds. To sign, add the entry the CLA check shows you to [`.github/cla-signatures.json`](.github/cla-signatures.json) in your pull request. The check passes once the entry is there, and one signature covers all your future contributions. If others authored commits in your pull request, each of them signs too, in a pull request of their own. Commit with an email address linked to your GitHub account, so the check can tell who wrote each commit.

## Pull requests

Pull requests are squash-merged into `main`. The pull request title becomes the commit subject and GitHub appends the pull request number, so write the title the way [commit subjects](.agents/rules/commits.md) are written: a plain imperative title such as `Fix dictation stopping when the keyboard switches languages`.

Explain in the pull request description why the change is needed. To close an issue, add `Fixes #N` to the description, not to a commit message.
