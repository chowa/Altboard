# Swift

These rules cover Swift code and the two files that check it, `.swift-format` and `.swiftlint.yml`. Comments follow [comments.md](comments.md).

## Code

- Swift constants use lowerCamelCase, never UPPER_SNAKE_CASE: `defaultTimeout`, not `DEFAULT_TIMEOUT` or `DefaultTimeout`.
- Build views in code with SwiftUI or UIKit. The project has no storyboards or xibs.
- When code calls an API from Apple's [required reason list](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api), such as `UserDefaults`, file dates, free disk space or `UITextInputMode.activeInputModes`, add its category with a reason that matches the use to the `PrivacyInfo.xcprivacy` of each target the code is built into, in the same change: the build accepts a missing or wrong entry without a warning.

## Errors

- Use `try?` when `nil` is all a failure needs, such as a fallback value or an early exit: `guard let data = try? Data(contentsOf: cacheURL) else { return nil }`. Never save a fallback over data that failed to load: one failed read then overwrites what the user saved.
- Discard an error, with an unused `try?` or an empty `catch`, only where the failure loses nothing, such as removing a temporary file that may already be gone: a save or a write discarded this way loses the user's data without a trace.
- After `try? await Task.sleep`, add `guard !Task.isCancelled else { return }`, or write `try await` in a throwing function: `try?` discards the `CancellationError` that `Task.sleep` throws when its task is canceled, so the code after it runs anyway.
- Let any other error propagate with `try` to the code that can retry, fall back or tell the user, and log it there at the `error` level with a fixed message that names the operation: `logger.error("Could not save the dictionary: \(error)")`.
- Never log what the user types or dictates, and never mark an error `privacy: .public`: users expect a keyboard to send their words only to the text field.
- Use `try!` only where a failure is a programmer error that shows on every run, such as loading a resource from the app bundle, and give that reason in the `force_try` suppression. Write a constant regex as a `/…/` literal instead of `try! Regex(…)`: the compiler checks a literal. In a test, mark the function `throws` and write `try`: a thrown error fails only that test, while `try!` crashes the whole test run.

## Formatting and linting

Run both tools from the repository root:

```sh
swift format --in-place --recursive --parallel .
swift format lint --strict --recursive --parallel .
swift package --package-path BuildTools --force-resolved-versions plugin --allow-writing-to-package-directory swiftlint lint --strict --config "$PWD/.swiftlint.yml" "$PWD"
```

- Fix what SwiftLint reports by hand. Do not run `swiftlint --fix`: some of its corrections break code or silently change it, for example by removing `async` from a method that subclasses override, or the `self` that a `Logger` message needs.
- Run SwiftLint through `BuildTools` as above, not a SwiftLint installed with Homebrew: the package pins one version for everyone, CI included. To update SwiftLint, merge the pull request Dependabot opens, or change the version in `BuildTools/Package.swift` and run `swift package --package-path BuildTools update`. swift-format comes with the selected Xcode.
- Keep the repository path and `--config` in the SwiftLint command: the plugin runs SwiftLint from the `BuildTools` folder, so without the path it lints only that folder, and without `--config` it reads `.swiftlint.yml` as a nested configuration, which ignores `excluded` and lints hidden folders such as `BuildTools/.build`.
- CI runs the same commands in `.github/workflows/lint.yml`, with the Xcode that `DEVELOPER_DIR` names there: change a command in both places, and when the app moves to a new Xcode, point `DEVELOPER_DIR` at it.
- When you pass files by path instead of the repository folder, add `--force-exclude`, or SwiftLint ignores `excluded`.
- In Xcode, Editor > Structure > Format File (Control-Shift-I) formats the current file with the same `.swift-format`.

## Rules that flag correct code

Suppress such a finding with a reason, in the form [comments.md](comments.md) describes:

- Suppress `async_without_await` on an async stub that subclasses override, and on an async method that implements a requirement of an Objective-C protocol, such as `userNotificationCenter(_:willPresent:)`.
- Suppress `redundant_self` on the `self` that a value interpolated into a `Logger` or `OSSignposter` message needs inside a closure that captures `self` with `[weak self]` or `[self]`: SwiftLint cannot see that each interpolated value is an escaping autoclosure ([realm/SwiftLint#6389](https://github.com/realm/SwiftLint/issues/6389)).
- In a SwiftUI builder closure such as `VStack { }` or in a `@ViewBuilder` property, discard a result with an explicit type, such as `let _: Void = f()` or `let _: Bool = g()`, instead of suppressing `redundant_discardable_let`: its suggestion, `_ = f()`, does not compile there.

## When a size limit fails

`.swiftlint.yml` limits `file_length`, `type_body_length`, `function_body_length`, `cyclomatic_complexity`, `function_parameter_count`, `large_tuple` and `nesting`. When one of them fails:

- Split the code at a seam you could explain in a review, such as a subview, a step of the work, a protocol conformance, or a struct in place of a tuple of more than three members.
- Never move code only to get under a limit, as into a `bodyPart2()` helper or an extension that holds whatever did not fit: the code stays as large and as complex, and `type_body_length` does not count extensions.
- Split a SwiftUI view into `View` types that take only the data they read, not into `@ViewBuilder` properties or methods: SwiftUI can skip a subview whose inputs did not change, while a `@ViewBuilder` property runs with the parent's `body`.
- When the code has no such seam, as with a `switch` over every case of a large enum, keep it whole and suppress the rule on that declaration with a reason, in the form [comments.md](comments.md) describes: `superfluous_disable_command` fails the lint once the code fits the limit again.
- Suppress `file_length` with `// swiftlint:disable file_length - <reason>` at the top of the file and no `enable`: SwiftLint reports it on the last line, where a directive stops working once a line is added below it.

## Editing .swift-format

- Keep every rule in the `rules` block: swift-format turns off a rule that is missing from it, so deleting a line that holds a default value turns that rule off.
- After an Xcode update, compare the file with the output of `swift format dump-configuration`, for example with `diff <(swift format dump-configuration) .swift-format`, and add the new rules: they stay off until you list them.
- Keep the file strict JSON without comments: swift-format accepts comments, but VS Code and Zed mark them as errors.
- `TypeNamesShouldBeCapitalized` and `UseSynthesizedInitializer` stay off because SwiftLint checks the same things. `AlwaysUseLowerCamelCase` stays on: SwiftLint's `identifier_name` misses static names and names that start with an acronym, such as `URLSessionTimeout`. `NoPlaygroundLiterals` stays on: SwiftLint's `discouraged_object_literal` misses `#fileLiteral`.

## Editing .swiftlint.yml

- Keep `trailing_comma`, `opening_brace`, `closure_parameter_position` and `statement_position` disabled: swift-format's output trips them.
- Keep `trailing_whitespace`, `vertical_whitespace` and `vertical_parameter_alignment` disabled: `swift format lint` already reports the same code.
- Keep `redundant_string_enum_value` disabled: it rejects a raw value equal to its case name, which a stored enum needs so that renaming the case keeps the stored string.
- Keep `todo` disabled: it flags every TODO and FIXME, and `todo_without_gate` checks their form instead.
- Keep `line_length` disabled: swift-format keeps code within its `lineLength` of 120 and cannot break a string literal, and splitting a `Text` literal with `+` to fit takes the string out of the String Catalog.
- Keep `type_name` and `unneeded_synthesized_initializer` enabled: `.swift-format` leaves these checks to SwiftLint. Keep `identifier_name` enabled too: it is the only check on name length.
- Keep `file_name` off: it flags topic files such as `Errors.swift`, which [naming.md](naming.md) allows.
- Keep the size limits above SwiftLint's defaults: CI runs SwiftLint with `--strict`, so every warning fails the lint.
- `excluded` holds `**/.*` because hidden folders hold build output, dependency checkouts and worktrees, and swift-format skips them too.
- Set a size limit as a single number, the warning level: `--strict` fails the lint on any warning, and an `error` level would also stop the Xcode build, where SwiftLint runs as a build tool plugin.
- Change a size limit only in a pull request of its own that explains why the limit does not fit the codebase, never in the change that exceeds it: a limit covers every declaration, and nothing flags it once the code that needed it is gone.
- An `excluded` list inside a rule's settings, such as `identifier_name.excluded`, replaces the default list instead of adding to it.
- Settings for a rule that is not enabled have no effect, and SwiftLint only prints a message about them.
- `only_rules` cannot be combined with `disabled_rules` or `opt_in_rules`: SwiftLint crashes.
- After a SwiftLint update, recheck the comments in the file: they describe the pinned version.
