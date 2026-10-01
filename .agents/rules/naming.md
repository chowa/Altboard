# Naming

## All names

- Spell words out in file and folder names, as the Swift API Design Guidelines ask of API names: `Documentation/` and `AppConfiguration.swift`, not `Docs/` or `AppConfig.swift`.
- Keep only three abbreviations, which Apple's frameworks use as terms: `App`, `Info` and `ID`. Keep acronyms such as `URL` and `JSON` as well.
- Write acronyms in one case, as the Swift API Design Guidelines do: `URLSessionClient.swift` and `CLA.md`, not `UrlSessionClient.swift` or `Cla.md`.
- Keep a type's spelling in a file named after it: `Int+Clamping.swift`, not `Integer+Clamping.swift`.
- Never put spaces in file names.

## Swift files

- Name a Swift file after the main type it declares, in UpperCamelCase: `KeyboardViewController.swift`.
- Keep file names unique within a target, even across folders: the compiler rejects two files named `ViewModel.swift`. Name them after the feature instead: `SettingsViewModel.swift`.
- Only `main.swift` starts in lowercase, and only for top-level code. The app's `@main` entry point lives in `<AppName>App.swift`.
- Put an extension that adds a conformance in `Type+Protocol.swift` and other extensions in `Type+Feature.swift`: `KeyboardViewController+Dictation.swift`. Keep an extension in the type's own file when it uses the type's `private` or `fileprivate` members, or when the compiler rejects it in another file, as it does for `Sendable` and for any synthesized conformance, such as `Equatable`, `Codable` or `CaseIterable`.
- Keep a nested type in its outer type's file; when it moves to a file of its own, name the file like an extension file: `DictationSession+State.swift`.
- Name a file without one main type after its topic, in UpperCamelCase: `Formatting.swift`.
- Name a test file after the file it tests, with a `Tests` suffix, in the `<Target>Tests` folder: `DictationSessionTests.swift`, `KeyboardViewController+DictationTests.swift`, `FormattingTests.swift`. The file keeps this name whatever the test type inside it is called.

## Folders and targets

- Name targets in UpperCamelCase without spaces: `Altboard`, `AltboardTests`. Xcode builds the module name from the target name and turns each space into an underscore.
- Name folders that hold Swift code in UpperCamelCase: `Keyboard/`, `AltboardTests/`. A folder inside a target's folder may also separate capitalized words with spaces, as Xcode group names do: `Dictation Views/`.
- Name top-level folders for tooling and documentation in UpperCamelCase: `Documentation/`, `Scripts/`.

## Other files

- Keep the exact names that tools and GitHub look for, such as `README.md`, `CONTRIBUTING.md`, `LICENSE`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `SUPPORT.md`, `AGENTS.md`, `Package.swift`, `Info.plist`, `PrivacyInfo.xcprivacy`, `Localizable.xcstrings`, `InfoPlist.xcstrings`, and the folders `fastlane/`, `ci_scripts/`, `.github/` and `.agents/` with the files inside them.
- Keep GitHub's community health files, such as `CONTRIBUTING.md` and `SECURITY.md`, in the root or `.github/`: GitHub does not look for them in `Documentation/`.
- Name asset catalogs, entitlements, build configuration files and test plans in UpperCamelCase: `Assets.xcassets`, `Keyboard.entitlements`, `Release.xcconfig`, `AltboardTests.xctestplan`.
- Name Python files in snake_case: `update_translations.py`. PEP 8 asks for all-lowercase module names and allows underscores.
- Name shell scripts in kebab-case: `check-localizations.sh`.
- Name other Markdown files in UpperCamelCase: `Documentation/GettingStarted.md`.
