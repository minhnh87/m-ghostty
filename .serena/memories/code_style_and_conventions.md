# Code Style & Conventions

## Zig
- Format: `zig fmt .` (4-space indent theo zig fmt mặc định).
- Naming: theo style chuẩn của Zig (`snake_case` cho biến/hàm, `PascalCase` cho type).
- File entry các build target: `src/main_*.zig` (mỗi target có một main).

## Swift (macOS)
- Lint/format: `swiftlint lint --fix` (config tại `.swiftlint.yml`).
- Tổ chức theo feature: `macos/Sources/Features/<FeatureName>/`.
- Bridge sang Zig core qua C API trong `macos/Sources/Ghostty/`.

## Khác
- Prettier cho file Web/Markdown/YAML: `prettier -w .` (config `.prettierignore`).
- `.editorconfig` quy định indent / line endings cơ bản.
- `.clang-format` cho C/C++ trong vendor / include nếu cần.
- Typos check: `typos.toml`.

## Commit / PR rules
- **AGENTS.md cấm tự tạo issue/PR.** Nếu user yêu cầu, tạo file đặc biệt (chi tiết trong AGENTS.md).
- Commit message style: xem `git log` của project (tiếng Anh, ngắn gọn).
- Branch hiện tại: `mmm`. Main branch: `main`.

## Workflow rules từ CLAUDE.md (project)
1. **Trước khi viết code, mô tả approach và chờ approval.**
2. **Nếu requirements mơ hồ, đặt câu hỏi clarify trước khi viết code.**
3. **Sau khi xong code, list edge cases & đề xuất test cases.**
4. **Nếu task cần thay đổi >3 files, dừng và chia nhỏ task.**
5. **Khi có bug, viết test reproduce trước, fix tới khi pass.**
6. **Mỗi lần bị correct, reflect và lập plan tránh sai lại.**

## Project-specific patterns (từ memory)
- **PTY command injection:** dùng `surface.writeText("cmd\r")`, KHÔNG dùng `sendText` (sendText wrap bracketed paste).
- **SwiftUI keyboardShortcut Esc không bắt được trong terminal view:** phím không-modifier bị NSView terminal nuốt trước SwiftUI → dùng `NSEvent` local monitor.
