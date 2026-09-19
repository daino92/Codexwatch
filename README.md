# CodexWatch

Native macOS menu-bar monitor for Codex usage. It reads structured rate-limit data locally from `codex app-server` using `account/rateLimits/read` and does not send model prompts.

## Current UI

- 5-hour, weekly and Luna Reserve quotas
- Reset timestamps and relative countdowns
- Menu-bar quota display with the same warning colors as the popover
  - normal: system primary color
  - 20% or less: orange
  - 5% or less: red
- Settings navigate inside the same menu-bar popover; use the back button to return to usage
- Configurable refresh interval and refresh-on-open
- Optional 20% / 5% notifications
- Launch at Login

## Development

Open `CodexWatch.xcodeproj` in Xcode, select the CodexWatch scheme and **My Mac**, then press **⌘R**.

CodexWatch searches common Codex CLI locations, including Homebrew, Volta, npm-global and NVM. When Codex is installed through NVM, its bin directory is prepended to the child process PATH so `/usr/bin/env node` also works when CodexWatch is launched as a GUI/Login Item.
