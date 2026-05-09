# m-ghostty Project Overview

## Mục đích
Đây là **fork cá nhân của Ghostty** — terminal emulator nhanh, native, tính năng phong phú. Fork này (`m-ghostty`) thêm các tính năng tùy biến chủ yếu cho macOS app.

## Tech Stack
- **Core (cross-platform):** Zig (build system: `build.zig`)
- **macOS app:** Swift / SwiftUI / AppKit (`macos/`)
- **GTK app (Linux/FreeBSD):** Zig + GTK (`src/apprt/gtk`)
- **C API:** trong `include/`
- **Build cho macOS:** Zig build → `GhosttyKit.xcframework` → Xcode build app Swift

## Cấu trúc thư mục cấp cao
- `src/` — Zig core (terminal emulator, renderer, termio, font, input, config, ...)
- `include/` — C API headers
- `macos/` — macOS app (Xcode project)
  - `macos/Sources/App/` — App entry, AppDelegate
  - `macos/Sources/Features/` — Các tính năng UI (Terminal, Settings, QuickTerminal, ...)
  - `macos/Sources/Ghostty/` — Bridge sang GhosttyKit (C API)
  - `macos/Sources/Helpers/` — Tiện ích Swift
- `pkg/` — Zig package wrappers (apple-sdk, fontconfig, freetype, harfbuzz, ...)
- `po/` — Bản dịch (gettext)
- `nix/`, `flake.nix` — Nix build
- `flatpak/`, `snap/` — Linux packaging

## Ngôn ngữ
- Project được Serena nhận diện là `zig` (chính), kèm Swift (macOS UI)

## Files quan trọng để hiểu codebase
- `AGENTS.md` — Guide cho coding agents (commands, custom features)
- `HACKING.md` — Tài liệu phát triển
- `CLAUDE.md` — Hướng dẫn cho Claude (workflow rules)
- `AI_POLICY.md` — Policy về AI usage
