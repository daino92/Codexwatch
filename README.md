# CodexWatch

Native macOS menu-bar monitor for Codex usage. CodexWatch reads structured rate-limit data locally from `codex app-server` using `account/rateLimits/read`, including Luna Reserve support, and does not send model prompts.

## Features

- Native macOS menu-bar app
- 5-hour, Weekly, and Luna Reserve quota monitoring
- Smart menu-bar quota display
  - shows 5-hour and Weekly usage by default
  - automatically shows Luna Reserve instead of an exhausted Weekly quota when Reserve is available
  - configurable display modes: 5-hour + Weekly, 5-hour only, Weekly only, or icon only
- Quota warning colors
  - normal: system primary color
  - 20% or less: orange
  - 5% or less: red
- Clickable quota cards with dedicated detail views
  - used percentage
  - remaining percentage
  - reset date and time
  - live time-remaining countdown
- Reset timestamps and live relative countdowns in the main usage view
- Codex CLI connection status
  - Connected
  - Checking
  - Authentication required
  - Codex CLI unavailable
  - Connection error
- Manual refresh with animated refresh indicator
- Configurable automatic refresh interval
- Optional refresh when opening the menu-bar popover
- Optional quota notifications at 20% and 5%
  - persistent deduplication prevents repeated alerts for the same threshold
  - notification state resets when a quota recovers/resets
- Optional rapid-usage alerts
  - detects a materially faster burn rate than recent usage
  - estimates when the active quota may be exhausted
  - limits rapid-usage alerts to one per quota every 30 minutes
- Launch at Login
- In-popover navigation for quota details and Settings
- Larger native-style back-button hit areas
- Hover states and navigation chevrons for clickable quota rows

## Quota Notifications

When enabled, CodexWatch can notify you when a quota reaches the following remaining-usage thresholds:

- **20% remaining** — low quota warning
- **5% remaining** — critical quota warning

CodexWatch stores the last notification band locally so restarting the app does not repeatedly trigger the same alert. Once a quota resets or recovers, notifications can trigger again during the next usage cycle.

Rapid-usage alerts require several refresh samples before evaluating usage speed. They trigger only when the recent burn rate is at least twice the preceding average and reaches a minimum rate, then remain suppressed for 30 minutes.

## Codex CLI Integration

CodexWatch communicates with the local Codex CLI through:

```text
codex app-server --stdio
```

It initializes the app-server and requests structured usage information using:

```text
account/rateLimits/read
```

with Luna Reserve support enabled.

CodexWatch searches common Codex CLI locations, including Homebrew, Volta, npm-global, local installs, and NVM.

When Codex is installed through NVM, its bin directory is prepended to the child-process `PATH` so `/usr/bin/env node` also works when CodexWatch is launched from Finder or as a Login Item.

## Development

Requirements:

- macOS 14 or later
- Xcode
- Codex CLI installed and authenticated

Open `CodexWatch.xcodeproj` in Xcode, select the **CodexWatch** scheme and **My Mac**, then press **⌘R**.

## Current Development Notes

The app currently works with the local Codex CLI and structured rate-limit API. There are two console warnings still under investigation:

- AppKit may report `_NSDetectedLayoutRecursion` while laying out the menu-bar popover.
- macOS may log `Unable to obtain a task name port right` when launching/interacting with the Codex subprocess.

These are currently tracked as development issues and are not considered resolved.
