# Comments

These rules cover comments in Swift code, scripts, workflows and configuration files; comments on GitHub follow [writing.md](writing.md). A comment tells the reader what the code cannot: what would break, with no check failing, if the code changed.

## License header

- Start every Swift file and script written for this repository with the license header. Copy it from `BuildTools/Package.swift` for Swift or from `Scripts/check-cla.sh` for a script, put the file's own name on the second line and the year you create the file on the copyright line, and never update that year.
- Put the header first, below only the shebang of a script or the `swift-tools-version` line of a `Package.swift`.
- The header is a license notice, so the rules below do not apply to it: keep its wording, capitals and layout as they are.
- Code copied from elsewhere keeps the header its own license requires, and its path goes into `excluded` in `.swiftlint.yml`.
- To change the header text, change `required_pattern` under `file_header` in `.swiftlint.yml` and the header in every file in the same commit: SwiftLint checks only Swift files, so nothing catches a script left with the old text.

## When to comment

- Most code needs no comment. Write one only when a change that looks reasonable would break something without a build, lint or test failing: a workaround, a value found by measurement, an order that must not change, a check that looks redundant but is not, something left out on purpose. Say what breaks: `// Save the transcript before closing the session: closing it discards the buffer.`
- When a precondition, an `#available` check or a test can make that failure loud, write it instead of the comment.
- A choice that a build, lint or test defends needs no comment: its reason goes in the commit message or the pull request description.
- After an action pinned to a commit SHA, write the version tag of that commit, and change both together: `uses: actions/checkout@3d3c42e… # v7.0.1`.
- Do not restate the code. When a comment would explain what a line does, try a clearer name, a named constant or a smaller function instead.
- Leave history to git: no author names, creation dates, descriptions of earlier versions or commented-out code.
- When a change makes a comment false, fix the comment in the same commit. Leave comments your change does not affect as they are.

## Sources

- Link only what anyone can open: files in this repository and public URLs, such as Apple documentation, a Swift Forums thread or a public issue.
- Describe a platform or tool bug in the comment itself. Name the iOS or tool version unless this repository pins the tool, and add a date only as AGENTS.md allows: `(verified 2026-09-29, iOS 26.0)`. A Feedback Assistant number opens only for the person who filed it, so add it after the description, never instead of it: `(verified 2026-09-29, iOS 26.0, FB12345678)`.
- Give a workaround the condition for removing it: an `#available` check, or a TODO gated on the release that fixes the bug.
- Link the source of code adapted from elsewhere, and adapt it only if its license allows.

## Form

- Write a `//` comment in full sentences in American English, starting with a capital letter and ending with a period. A short end-of-line comment may be a fragment without a period.
- Keep a comment to one to three lines. A workaround or an invariant that must be read at that spot may take more, as long as each extra line says what else breaks. The reasoning behind a choice, the alternatives you rejected and the story of a bug belong in the commit message or the pull request description; a longer explanation goes to a document in `Documentation/`, and the comment keeps one line that points to it.
- Divide a long file into sections with `// MARK: - Topic`, not with banners such as `// ====`: Xcode lists MARK comments in the jump bar and the minimap.

## Documentation comments

- Write a documentation comment only when a caller could misuse the declaration in a way the compiler does not catch: the unit or range of a value, when the result is `nil`, which errors are thrown and when, or what it changes besides its result.
- Begin with a summary, as the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) ask: for a function, what it does and returns; for an initializer, what it creates; for a subscript, what it accesses; for anything else, what it is. Write a sentence fragment that ends with a period. If the summary is hard to write, reconsider the API.
- Follow the summary with `- Parameter name:` for one parameter or `- Parameters:` for several, then `- Returns:` and `- Throws:`. Leave out a tag that only repeats the summary.
- Document the complexity of a computed property that is not O(1): `- Complexity: O(n), where n is the length of the text.`
- End the text of each tag with a period, even when it is a fragment: the list rules in [writing.md](writing.md) cover Markdown files, not documentation comments.
- Place a documentation comment above the declaration's attributes and modifiers.
- Use `//` for a comment about a group of declarations: `///` documents only the declaration that follows it.

## TODO and FIXME

- Write `TODO: <gate> - <action>` where you want to do future work and `FIXME: <gate> - <action>` where code needs a fix, as Xcode's documentation uses them; the jump bar highlights both. The gate is something you can see happen: a release (`TODO: iOS 27 - …`), a dependency version (`TODO: Swift 6.3 - …`), an issue (`FIXME: #42 - …`) or an event. Never a person. SwiftLint checks the form of both with `todo_without_gate`.
- `todo_without_gate` also flags these words in plain prose, such as `// See the TODO list`: reword such a comment.
- A limitation with no foreseeable end is not a TODO or a FIXME: describe it in an ordinary comment.

## Suppressions

Give the reason for every suppression, in the form each tool accepts:

- SwiftLint takes the reason after ` - ` on the directive line: `// swiftlint:disable:next force_unwrapping - the caller checked for nil`. After `--`, SwiftLint reads every word of the reason as a rule name and fails the lint.
- `:next` and `:this` cover a single line: the line where SwiftLint reports the violation. When swift-format wraps a declaration or a call, that line can be the first one, the one with the `async` keyword, or an argument line. Put `:next` directly above that line. Use `:this` only when the line stays within 120 characters, because the directive counts toward `line_length`, and swift-format moves a trailing comment to the last line when it wraps the code.
- On a declaration with a documentation comment, put `// swiftlint:disable <rule> - <reason>` above the documentation comment and `// swiftlint:enable <rule>` on the line after the one SwiftLint reports. A `:next` line between the documentation comment and the declaration detaches the comment, and `orphaned_doc_comment` fails the lint.
- swift-format takes the reason only on its own line above `// swift-format-ignore: RuleName`. Text after the rule name silently turns the directive off, and a directive without a rule name turns off every rule for the code below it.
- ShellCheck takes the reason after `#` on the directive line: `# shellcheck disable=SC2016 # the $ names are jq variables`. After `--`, ShellCheck cannot parse the directive and stops checking the file (verified 2026-09-29, ShellCheck 0.11.0).
