# m-ghostty Custom Features (Fork-specific)

Đây là các tính năng đã được thêm so với upstream Ghostty.

## Unified Sidebar (Cmd+E)
- Một shortcut `Cmd+E` cycle qua 3 panel bên phải: **Command History → SSH Profiles → Folders → đóng**
- Tất cả panel đều ở phía bên phải terminal.

### Command History panel
- Hiển thị lệnh đã chạy.
- Bỏ qua các prefix sau (không lưu): `gc`, `gt`, `po`, `gb`, `log`, `git`, `ls`, `ll`, `gs`.
- Click trái → gửi command vào terminal; click phải → xóa khỏi list.
- Files: `macos/Sources/Features/Terminal/CommandHistory/`

### SSH Profiles panel
- Đọc từ `~/.ssh/config`.
- Click → gửi lệnh ssh vào terminal hiện tại; `Cmd+Click` → mở tab mới.
- Nút "+" để thêm profile (ghi vào `~/.ssh/config`).
- Click phải → xóa profile (xóa khỏi `~/.ssh/config`).
- Auto-fill password qua `expect`; password lưu trong Keychain.
- Files: `macos/Sources/Features/Terminal/SSHProfiles/`

### Folders panel
- Hiển thị các thư mục đã thăm.
- Click → cd tới thư mục.
- Files: `macos/Sources/Features/Terminal/FolderSidebar/`, `macos/Sources/Features/Terminal/TerminalView.swift`

## Quick Password Fill (Cmd+P)
- Trong session SSH, `Cmd+P` gửi password đã lưu.
- Detect SSH session từ focused surface, match profile theo hostname+user.
- Lấy password từ Keychain qua `SSHKeychainManager` bằng profile ID.
- Silent fail nếu không phải SSH / không khớp profile / không có password.
- Files: `macos/Sources/Features/Terminal/TerminalView.swift`

## Custom Green "M" App Icon
- Icon gradient xanh tự sinh runtime, có chữ "M" trắng.
- Đặt làm default icon (thay icon Ghostty official).
- Files:
  - `macos/Sources/Features/Custom App Icon/MGreenAppIcon.swift`
  - `macos/Sources/Features/Custom App Icon/AppIcon.swift`
  - `macos/Sources/Features/Custom App Icon/AppDelegate.swift`

## Session-only background override (OSC 11)
- Commit `30fafc083`. Cho phép override background runtime, không ảnh hưởng config.
- Liên quan custom config key `prefer-background`.

## Bottom panel & utility (gần đây nhất, branch `mmm`)
- Commit gần nhất: `70da3d472 update bottom panel and some utility`.
