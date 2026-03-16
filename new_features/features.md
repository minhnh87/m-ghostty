# Các tính năng tuỳ chỉnh của m-ghostty

## 1. Command History Sidebar (Cmd+E)

Sidebar bên phải hiển thị lịch sử các lệnh đã thực thi trong terminal.

### Cách hoạt động

- Nhấn **Cmd+E** để bật/tắt sidebar. Sidebar ẩn theo mặc định.
- Sidebar xuất hiện bên phải cửa sổ terminal với hiệu ứng trượt (slide animation).
- Chiều rộng sidebar chiếm 1/3 chiều rộng cửa sổ.

### Tương tác

- **Click** vào một lệnh → gửi lệnh đó vào terminal để thực thi lại.
- **Cmd+Click** vào một lệnh → xóa lệnh khỏi danh sách lịch sử.
- Hover vào lệnh sẽ highlight lệnh đó và hiển thị con trỏ pointing hand.

### Lọc lệnh (Ignore Prefix)

Các lệnh bắt đầu bằng những prefix sau sẽ **không được lưu** vào lịch sử:

`gc`, `gt`, `po`, `gb`, `log`, `git`, `ls`, `ll`, `gs`

### Lưu trữ

- Tối đa **36 lệnh** được lưu.
- Lệnh mới nhất luôn nằm đầu danh sách.
- Nếu lệnh đã tồn tại, nó sẽ được di chuyển lên đầu (không trùng lặp).
- Dữ liệu được lưu trong **UserDefaults** với key `CommandHistoryCommands`.

### Files liên quan

| File | Mô tả |
| --- | --- |
| macos/Sources/Features/Terminal/CommandHistory/CommandHistoryStore.swift | Store quản lý danh sách lệnh, logic thêm/xóa/lọc prefix |
| macos/Sources/Features/Terminal/CommandHistory/CommandHistorySidebarView.swift | Giao diện sidebar và row hiển thị từng lệnh |
| macos/Sources/Features/Terminal/TerminalView.swift | Toggle sidebar bằng keyboard shortcut Cmd+E |

## 2. Folder Sidebar (Cmd+L)

Sidebar bên trái hiển thị danh sách các thư mục đã truy cập trong terminal.

### Cách hoạt động

- Nhấn **Cmd+L** để bật/tắt sidebar. Sidebar **ẩn theo mặc định**.
- Sidebar xuất hiện bên trái cửa sổ terminal với hiệu ứng trượt.
- Chiều rộng sidebar có thể kéo thay đổi (drag resize), từ 150px đến 400px, mặc định 250px.

### Tương tác

- **Click** vào thư mục → chuyển terminal đến thư mục đó.
- **Cmd+Click** vào thư mục → mở thư mục trong tab mới.
- **Right-click** vào thư mục → xóa thư mục khỏi danh sách.
- Hover vào thư mục sẽ highlight và hiển thị con trỏ pointing hand.

### Hiển thị

- Danh sách thư mục được sắp xếp theo tên (alphabetical, case-insensitive).
- Đường dẫn dài được rút gọn, chỉ hiển thị 2 thành phần cuối (ví dụ: `projects/my-app`).
- Tooltip hiển thị đường dẫn đầy đủ khi hover.

### Lưu trữ

- Không giới hạn số lượng thư mục.
- Nếu thư mục đã tồn tại, nó sẽ được di chuyển lên đầu (không trùng lặp).
- Dữ liệu được lưu trong **UserDefaults** với key `FolderSidebarFolders`.

### Files liên quan

| File | Mô tả |
| --- | --- |
| macos/Sources/Features/Terminal/FolderSidebar/FolderSidebarStore.swift | Store quản lý danh sách thư mục, logic thêm/xóa |
| macos/Sources/Features/Terminal/FolderSidebar/FolderSidebarView.swift | Giao diện sidebar, row, drag resize, right-click handler |
| macos/Sources/Features/Terminal/TerminalView.swift | Toggle sidebar bằng keyboard shortcut Cmd+L |