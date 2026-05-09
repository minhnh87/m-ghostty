# Suggested Commands

## Zig (core)
- **Build:** `zig build`
- **Build chỉ thư viện (không build macOS app):** `zig build -Demit-macos-app=false`
- **Build Release thư viện cho macOS:** `zig build -Demit-macos-app=false -Doptimize=ReleaseFast`
- **Test toàn bộ:** `zig build test`
- **Test theo filter:** `zig build test -Dtest-filter=<test name>`
- **Format Zig:** `zig fmt .`

## macOS (Swift/Xcode)
- **Build Debug (arm64):**
  `xcodebuild -project macos/Ghostty.xcodeproj -scheme Ghostty -arch arm64 build`
- **Build ReleaseLocal (arm64):**
  `xcodebuild -project macos/Ghostty.xcodeproj -scheme Ghostty -configuration ReleaseLocal -arch arm64 build`
- **KHÔNG dùng `-configuration Release`** (cần Apple Developer code signing). Dùng `ReleaseLocal`.
- **Build output Debug:** `~/Library/Developer/Xcode/DerivedData/Ghostty-ayxvyoywtcakflfnktjcqshqirod/Build/Products/Debug/Ghostty.app`
- **Build output ReleaseLocal:** `~/Library/Developer/Xcode/DerivedData/Ghostty-ayxvyoywtcakflfnktjcqshqirod/Build/Products/ReleaseLocal/Ghostty.app`
- **Mở app:** `open <path>/Ghostty.app`
- **Format Swift:** `swiftlint lint --fix`

## Workflow ReleaseLocal đầy đủ
1. `zig build -Demit-macos-app=false -Doptimize=ReleaseFast`
2. `xcodebuild -project macos/Ghostty.xcodeproj -scheme Ghostty -configuration ReleaseLocal -arch arm64 build`
3. `open ~/Library/Developer/Xcode/DerivedData/Ghostty-ayxvyoywtcakflfnktjcqshqirod/Build/Products/ReleaseLocal/Ghostty.app`

Lưu ý: nếu thiếu `-Doptimize=ReleaseFast`, Zig lib mặc định Debug → app hiện cảnh báo "debug build" dù Xcode đã build ReleaseLocal.

## Khắc phục codesign
- Lỗi codesign liên quan extended attributes: `xattr -cr <path>/Ghostty.app`

## Format khác
- **Prettier:** `prettier -w .`

## Git / CLI hệ thống (Darwin)
- macOS dùng BSD coreutils (khác GNU): chú ý khi dùng `find`, `sed`, `xargs` (dùng `find -E` cho regex extended, `sed -i ''` cần arg rỗng).
- Git status hiện tại nằm trên branch `mmm`, branch chính là `main`.

## Config Ghostty
- File config: `~/.config/ghostty/config`
- Custom keys của fork: `prefer-background` (override `background` khi set)
