---
name: apple-development
description: Build, modify, debug, and review native Swift, SwiftUI, macOS, and iOS applications using the Apple/Xcode toolchain.
---

# Apple Development Skill

Use this skill when working on Swift, SwiftUI, macOS, iOS, Xcode projects, or Apple platform APIs.

## Specialized Skill Handoff

When available in the active skills registry, also load and follow the specialized `Build macOS Apps` and `Build iOS Apps` skills. Use `Build macOS Apps` for macOS work, `Build iOS Apps` for iOS work, and both when a task spans platforms. Their platform-specific guidance takes precedence when instructions overlap; continue using this skill for the shared Apple/Xcode guidance.

Do not block waiting for a skill activation or permission prompt. If either specialized skill is unavailable, requires approval that does not complete, or appears to freeze, continue with this skill and apply the relevant platform guidance here.

## Toolchain

Use the installed Xcode toolchain.

Prefer Apple-native tools:

- `xcodebuild`
- `xcrun`
- `swift`
- Swift Package Manager when applicable

Do not replace an Xcode project with another build system unless explicitly requested.

## Before Editing

Inspect:

1. `AGENTS.md`
2. relevant Swift files
3. project structure
4. existing implementation patterns
5. current Git diff

Do not assume web-development patterns map directly to SwiftUI.

## Building

For CodexWatch, determine available schemes with:

`xcodebuild -project CodexWatch.xcodeproj -list`

Prefer verifying macOS builds with the existing CodexWatch scheme.

Do not change signing settings simply to make a local build pass.

When a build fails, identify the first meaningful compiler error rather than treating cascading errors as separate root causes.

## Swift

Prefer modern Swift.

Use:

- structured concurrency
- `async` / `await`
- actors where isolation is useful
- `@MainActor` for UI state
- value types where appropriate

Avoid:

- unnecessary force unwraps
- unnecessary singletons
- blocking the main thread
- unnecessary `DispatchQueue` usage when Swift concurrency provides a cleaner solution

## SwiftUI

Prefer SwiftUI before falling back to AppKit/UIKit.

Use AppKit/UIKit when SwiftUI cannot provide the required platform behavior cleanly.

Respect:

- environment appearance
- accessibility
- hit targets
- native control behavior
- platform conventions

For macOS menu-bar applications, be particularly careful with:

- `MenuBarExtra`
- popover/window sizing
- layout recursion
- hover behavior
- menu-bar rendering
- AppKit/SwiftUI bridging

## Xcode Project Safety

Be conservative when editing:

- `.pbxproj`
- entitlements
- build settings
- signing configuration
- capabilities

Never regenerate the Xcode project merely to add a source-code change.

When adding a new source file, verify that Xcode target membership/build phases are correct.

## Debugging

Do not suppress warnings without understanding their source.

For AppKit layout recursion, use the symbolic breakpoint `_NSDetectedLayoutRecursion` and inspect the call stack.

Differentiate application failures from harmless system/debugger console noise.

## Verification

After meaningful code changes:

1. Compile the project.
2. Report compiler errors.
3. Inspect the changed files.
4. Review the Git diff.
5. Avoid claiming success if the build was not actually verified.

For UI changes that cannot be visually verified from the available environment, state that limitation.
