import SwiftUI

/// Bottom toolbar luôn hiển thị ở dưới cùng của TerminalView.
/// Chứa các quick action: color swatches custom background + nút Ctrl+C.
/// Thiết kế mở rộng được — thêm quick action mới chỉ cần append vào HStack.
struct BottomToolbarView: View {
    @ObservedObject var customBackgroundStore: CustomBackgroundStore
    var onCustomBackgroundApply: (String?) -> Void
    var onSendCtrlC: () -> Void
    var onSplitHorizontal: () -> Void
    var onSplitVertical: () -> Void
    var onCloseTab: () -> Void
    var onToggleBrowser: () -> Void
    var onOpenInVSCode: () -> Void

    @State private var hoveredSwatch: String? = nil

    private static let swatchHexes: [String] = [
        "#202940",
        "#4B4038",
        "#093C5D",
        "#2C3947",
        "#574964",
        "#355872",
    ]

    var body: some View {
        HStack(spacing: 8) {
            // Color swatches — mirror với CustomBackgroundSection
            HStack(spacing: 4) {
                ForEach(Self.swatchHexes, id: \.self) { hex in
                    Button(action: { applySwatch(hex) }) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Self.color(fromHex: hex))
                            .frame(width: 20, height: 20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(
                                        hoveredSwatch == hex
                                            ? Color(red: 0.55, green: 0.55, blue: 0.55)
                                            : Color(red: 0.20, green: 0.20, blue: 0.20),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .help(hex)
                    .onHover { isHovering in
                        hoveredSwatch = isHovering ? hex : nil
                    }
                }
            }

            Divider()
                .frame(height: 18)

            quickActionButton(
                label: "Chia ngang",
                systemImage: "rectangle.split.1x2",
                help: "Chia màn hình ngang (panel mới ở dưới)",
                action: onSplitHorizontal
            )

            quickActionButton(
                label: "Chia dọc",
                systemImage: "rectangle.split.2x1",
                help: "Chia màn hình dọc (panel mới ở phải)",
                action: onSplitVertical
            )

            quickActionButton(
                label: "Close",
                systemImage: "xmark",
                help: "Đóng tab hiện tại",
                action: onCloseTab
            )

            quickActionButton(
                label: "Browser",
                systemImage: "globe",
                help: "Bật/tắt browser panel (Cmd+B)",
                action: onToggleBrowser
            )

            quickActionButton(
                label: "Code",
                systemImage: "chevron.left.forwardslash.chevron.right",
                help: "Mở thư mục hiện tại trong VS Code",
                action: onOpenInVSCode
            )

            quickActionButton(label: "Ctrl+C", systemImage: nil, help: "Send Ctrl+C (interrupt running process)", action: onSendCtrlC)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.10, green: 0.10, blue: 0.10))
        .overlay(Divider(), alignment: .top)
    }

    @ViewBuilder
    private func quickActionButton(
        label: String,
        systemImage: String?,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .medium))
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
            .foregroundColor(Color(red: 0.85, green: 0.85, blue: 0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(red: 0.16, green: 0.16, blue: 0.16))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(red: 0.25, green: 0.25, blue: 0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Actions

    private func applySwatch(_ hex: String) {
        if customBackgroundStore.setBackground(hex) {
            onCustomBackgroundApply(hex)
        }
    }

    /// Parse a 6-digit hex string (with leading `#`) into a SwiftUI Color.
    private static func color(fromHex hex: String) -> Color {
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        let value = UInt32(s, radix: 16) ?? 0
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}

#if DEBUG
#Preview {
    BottomToolbarView(
        customBackgroundStore: CustomBackgroundStore.shared,
        onCustomBackgroundApply: { _ in },
        onSendCtrlC: {},
        onSplitHorizontal: {},
        onSplitVertical: {},
        onCloseTab: {},
        onToggleBrowser: {},
        onOpenInVSCode: {}
    )
    .frame(width: 800)
    .background(Color.black)
}
#endif
