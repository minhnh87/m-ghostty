# Task Completion Checklist

Khi hoàn thành một task code, **luôn** thực hiện các bước sau trước khi báo done:

## 1. Format
- Zig: `zig fmt .`
- Swift: `swiftlint lint --fix`
- Khác: `prettier -w .`

## 2. Build (BẮT BUỘC — feedback từ user)
- **Nếu chỉ sửa Zig core:** `zig build` hoặc `zig build -Demit-macos-app=false`
- **Nếu sửa macOS Swift:**
  - Debug: `xcodebuild -project macos/Ghostty.xcodeproj -scheme Ghostty -arch arm64 build`
  - ReleaseLocal: cần build Zig lib với `-Doptimize=ReleaseFast` trước
- Nếu lỗi codesign liên quan xattr: `xattr -cr <path>/Ghostty.app` rồi build lại.

## 3. Test
- Zig: `zig build test`
- Test cụ thể: `zig build test -Dtest-filter=<test name>`
- Nếu fix bug → đảm bảo có test reproduce bug đó (theo CLAUDE.md rule #5).

## 4. List edge cases & test cases (CLAUDE.md rule #3)
- Sau khi xong code, liệt kê edge cases và đề xuất test cases để cover.

## 5. Verify ở UI (cho thay đổi macOS UI)
- Mở app build ra để test thật:
  `open ~/Library/Developer/Xcode/DerivedData/Ghostty-*/Build/Products/Debug/Ghostty.app`
- Type checking và test suite chỉ verify code correctness, **không** verify feature correctness.
- Nếu không test được UI, nói rõ với user, không claim success.

## 6. Git
- **KHÔNG tự commit trừ khi user yêu cầu.**
- **KHÔNG tự tạo PR/issue** (AGENTS.md cấm).
- Khi commit (nếu được yêu cầu): tạo commit MỚI, không amend trừ khi user yêu cầu.

## Lưu ý phạm vi đổi
- Nếu task đụng >3 files → dừng, chia nhỏ task trước (CLAUDE.md rule #4).
