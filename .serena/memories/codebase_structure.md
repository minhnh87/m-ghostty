# Codebase Structure

## Top-level
```
m-ghostty/
├── src/                  # Zig core
├── include/              # C API headers (libghostty)
├── macos/                # macOS app (Swift + Xcode project)
├── pkg/                  # Zig package wrappers (deps)
├── po/                   # Translations (gettext)
├── nix/, flake.nix       # Nix build
├── flatpak/, snap/       # Linux packaging
├── dist/                 # Distribution metadata
├── example/              # Example configs
├── test/                 # Integration tests
├── vendor/               # Vendored deps
├── build.zig             # Main build file
├── build.zig.zon         # Zig deps
├── AGENTS.md             # Agent guide
├── CLAUDE.md             # Claude workflow rules
├── HACKING.md            # Dev guide
└── CONTRIBUTING.md
```

## src/ (Zig core)
- `main.zig`, `main_ghostty.zig`, `main_c.zig`, `main_wasm.zig`, `main_bench.zig`, `main_gen.zig`, `main_build_data.zig` — entry points cho từng target.
- `App.zig` — App layer
- `Surface.zig` — Surface (terminal view) layer
- `Command.zig`, `pty.zig` — PTY / command exec
- `apprt/` — Application runtime abstraction (gtk, embedded, ...)
- `terminal/` — Terminal emulator core (parser, state machine, screen)
- `termio/` — Terminal I/O backend
- `renderer/` — GPU renderer (Metal, OpenGL)
- `font/` — Font loading & shaping (freetype, harfbuzz)
- `input/` — Input handling (key, mouse)
- `config/`, `config.zig` — Config parsing
- `cli/`, `cli.zig` — CLI commands
- `crash/` — Crash reporting
- `inspector/` — Terminal state inspector
- `unicode/` — Unicode tables
- `simd/` — SIMD optimizations
- `datastruct/` — Custom data structures
- `os/` — OS-specific
- `synthetic/` — Synthetic input gen (test)
- `benchmark/` — Benchmarks
- `shell-integration/` — Shell hooks (bash, zsh, fish, elvish)
- `terminfo/` — Terminfo entry
- `lib/`, `lib_vt.zig` — Library API
- `extra/` — Extra utilities
- `helpgen.zig` — Help text generator

## macos/Sources/
- `App/` — AppDelegate, App entry
- `Features/` — Mỗi tính năng UI một thư mục:
  - `Terminal/` — Terminal view chính + sidebars
    - `CommandHistory/` — Command history panel (custom)
    - `SSHProfiles/` — SSH profiles panel (custom)
    - `FolderSidebar/` — Folders panel (custom)
    - `TerminalView.swift` — Main terminal view, includes Cmd+E unified sidebar và Cmd+P quick password
  - `Custom App Icon/` — Custom green "M" icon (custom)
  - `Settings/`, `About/`, `QuickTerminal/`, `Splits/`, `Update/`, `Services/`, `Command Palette/`, `Secure Input/`, `Global Keybinds/`, `App Intents/`, `ClipboardConfirmation/`
- `Ghostty/` — Bridge sang GhosttyKit C API
- `Helpers/` — Swift utilities

## macos/ files
- `Ghostty.xcodeproj` — Xcode project
- `GhosttyKit.xcframework` — Pre-built xcframework từ Zig
- `Ghostty-Info.plist`, `*.entitlements` — App metadata
- `Tests/`, `GhosttyUITests/` — Tests

## include/
- `include/ghostty.h` — C API header chính

## pkg/
- Wrappers cho: `apple-sdk`, `fontconfig`, `freetype`, `harfbuzz`, `libxev`, `oniguruma`, `simdutf`, ...
