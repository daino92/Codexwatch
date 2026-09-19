# CodexWatch Agent Guidelines

## Project

CodexWatch is a native macOS menu-bar application for monitoring OpenAI Codex usage.

The application reads structured usage data locally from `codex app-server` using `account/rateLimits/read`.

CodexWatch must not send model prompts merely to determine usage.

## Technology

- Swift
- SwiftUI
- AppKit where necessary
- macOS 14+
- Xcode project
- Native macOS `MenuBarExtra`
- Codex CLI integration through `Process`
- `UserNotifications`
- `ServiceManagement`

## Project Structure

Application source code lives under `CodexWatch/`.

Main areas:

- `App/` — application entry point
- `Models/` — domain models
- `Services/` — Codex CLI, notifications, login services
- `Stores/` — observable application state
- `Views/` — SwiftUI views
- `Support/` — shared helpers

Tests live under:

- `CodexWatchTests/`
- `CodexWatchUITests/`

## Development Rules

Prefer native Apple APIs and SwiftUI.

Do not introduce third-party dependencies unless there is a strong technical reason.

Keep views small and composable.

Business logic should not live directly inside SwiftUI views when it can reasonably live in a Store, Service, or Model.

Use structured concurrency (`async` / `await`) for asynchronous operations where practical.

UI state that affects the whole application belongs in `UsageStore`.

Keep Codex CLI communication isolated inside `CodexCLIService`.

Do not parse human-readable Codex CLI output when structured app-server data is available.

Do not hardcode a single Codex installation path.

Codex may be installed through:

- NVM
- Homebrew
- Volta
- npm global
- local Codex installation

Remember that macOS GUI applications do not inherit the user's interactive shell environment.

## Swift Style

Use descriptive names.

Prefer early exits with `guard` over deeply nested conditionals.

Prefer one responsibility per type/function.

Avoid force unwraps unless correctness guarantees the value exists.

Use `private` by default for implementation details.

Use `@MainActor` for UI-facing observable state.

Prefer Swift concurrency over manually managed dispatch queues where possible.

Follow existing formatting and naming conventions in the project.

## SwiftUI

Prefer native SwiftUI components.

Maintain good macOS interaction behavior:

- sensible hover states
- adequate click targets
- keyboard accessibility where appropriate
- native system colors
- light/dark mode compatibility

Clickable rows should expose the full visible row as the hit target.

Do not sacrifice usability to make controls visually smaller.

Navigation inside the menu-bar popover should remain inside the popover unless there is a strong reason to open another window.

Keep animations subtle and native-looking.

## Menu Bar

The menu-bar label supports quota information for:

- 5-hour usage
- Weekly usage
- Luna Reserve

Warning thresholds:

- above 20% — normal system color
- 20% or below — orange
- 5% or below — red

When the regular Weekly quota is exhausted and Luna Reserve is available, Luna Reserve becomes the effective weekly quota shown in the menu bar.

Preserve this behavior.

## Notifications

Quota notifications exist for:

- 20% remaining
- 5% remaining

Notifications must be deduplicated.

Do not repeatedly notify the same threshold during refreshes.

A quota reset/recovery must allow notifications for the next quota cycle.

## Codex Health

The application distinguishes between:

- checking
- connected
- authentication required
- CLI unavailable
- connection error

Preserve meaningful error distinctions instead of collapsing every failure into a generic error.

## Testing Changes

Before considering a change complete:

1. Ensure the project compiles.
2. Check for Swift compiler warnings introduced by the change.
3. Preserve existing behavior unless the task explicitly changes it.
4. Consider both light and dark macOS appearances for UI changes.
5. Consider menu-bar behavior separately from popover behavior.

When possible, use `xcodebuild` for build verification.

## Git

Do not commit directly unless explicitly requested.

Do not push unless explicitly requested.

Do not modify unrelated files.

Keep changes scoped to the requested task.

Before large changes, inspect the current Git diff.

## Documentation

Update `README.md` when a change materially affects:

- features
- requirements
- setup
- architecture
- user-visible behavior

Do not document features that are only planned.

## Known Development Issues

There is currently an AppKit console warning involving `_NSDetectedLayoutRecursion`.

Do not assume unrelated UI changes fix this warning.

Investigate it independently before removing working UI behavior as a workaround.

The application may also log a macOS process/debugger message similar to:

`Unable to obtain a task name port right for pid ...`

Do not treat this message as an application failure unless it corresponds with actual broken behavior.
