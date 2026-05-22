import SwiftUI
import WebKit

/// Browser panel hiển thị bên cạnh terminal, hỗ trợ nhiều tab.
/// Mỗi tab giữ một WKWebView riêng nên scroll/state được preserve khi switch tab.
/// Khi panel được bật lên, luôn khởi tạo 2 tab default:
///   1) `http://localhost:3001/?f={pwd của terminal đang focus}`
///   2) `http://127.0.0.1:4444/?path={pwd của terminal đang focus}`
struct BrowserPanelView: View {
    @StateObject private var tabsModel: BrowserTabsModel

    /// Tổng width của khu terminal hiện tại — dùng để tính preset width.
    let totalWidth: CGFloat
    /// Width hiện hành của panel — dùng để quyết định minimal-state UI.
    let currentWidth: CGFloat
    /// Caller nhận target width và set/persist.
    let onSetWidth: (CGFloat) -> Void
    /// Cung cấp pwd của terminal đang focus tại thời điểm gọi. Dùng cho bookmark
    /// "1" — mỗi lần click sẽ build URL với pwd hiện hành.
    let pwdProvider: () -> String?

    init(
        totalWidth: CGFloat,
        currentWidth: CGFloat,
        onSetWidth: @escaping (CGFloat) -> Void,
        pwdProvider: @escaping () -> String?
    ) {
        self.totalWidth = totalWidth
        self.currentWidth = currentWidth
        self.onSetWidth = onSetWidth
        self.pwdProvider = pwdProvider
        // Snapshot pwd tại lúc init để dựng 2 tab default. @StateObject chỉ
        // dùng giá trị này lần đầu — re-render sau đó sẽ skip.
        _tabsModel = StateObject(wrappedValue: BrowserTabsModel(initialPWD: pwdProvider()))
    }

    var body: some View {
        VStack(spacing: 0) {
            BrowserTabBar(model: tabsModel)

            Divider()

            if let active = tabsModel.activeTab {
                BrowserActiveTabView(
                    tab: active,
                    totalWidth: totalWidth,
                    currentWidth: currentWidth,
                    onSetWidth: onSetWidth,
                    pwdProvider: pwdProvider
                )
                // Force re-init local URL state khi user switch tab.
                .id(active.id)
            }
        }
    }
}

/// URL bar + WebView của tab đang active. Tách ra subview để `@ObservedObject`
/// vào tab cụ thể và re-init local state qua `.id(...)`.
private struct BrowserActiveTabView: View {
    @ObservedObject var tab: BrowserTab
    let totalWidth: CGFloat
    let currentWidth: CGFloat
    let onSetWidth: (CGFloat) -> Void
    let pwdProvider: () -> String?

    @State private var urlString: String = ""

    /// Target width khi user click nút "minimal" — đủ thấy nút ½ để khôi phục.
    private static let minimalWidth: CGFloat = 44
    /// Width threshold dưới mức này panel chuyển sang minimal UI (ẩn mọi thứ
    /// trừ nút ½). Đặt 100 để không nhầm với preset ¼ trên màn hình nhỏ.
    private static let minimalThreshold: CGFloat = 100

    private var isMinimal: Bool { currentWidth < Self.minimalThreshold }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                HalfPresetButton(
                    isMinimal: isMinimal,
                    action: { onSetWidth(totalWidth * 0.5) }
                )

                if !isMinimal {
                    widthPresetButton(
                        fraction: 1.0,
                        target: totalWidth,
                        help: "Full width (100%)"
                    )
                    widthPresetButton(
                        fraction: 1.0 / 3.0,
                        target: totalWidth / 3,
                        help: "One-third width (33%)"
                    )
                    widthPresetButton(
                        fraction: 0.25,
                        target: totalWidth / 4,
                        help: "One-quarter width (25%)"
                    )
                    minimalPresetButton

                    bookmarkButton(label: "1", help: "Open localhost:3001 with current folder") {
                        tab.load(BrowserBookmarks.bookmark1(pwd: pwdProvider()))
                    }
                    bookmarkButton(label: "2", help: "Open localhost:4444 with current path") {
                        tab.load(BrowserBookmarks.bookmark2(pwd: pwdProvider()))
                    }

                    TextField("URL", text: $urlString, onCommit: { tab.load(urlString) })
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))

                    Button(action: { tab.reload() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(red: 0.85, green: 0.85, blue: 0.85))
                            .frame(width: 22, height: 22)
                            .background(Color(red: 0.16, green: 0.16, blue: 0.16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(red: 0.25, green: 0.25, blue: 0.25), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .help("Reload")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(red: 0.10, green: 0.10, blue: 0.10))
            .clipped()

            Divider()

            WebViewHost(webView: tab.webView)
        }
        .onAppear { urlString = tab.urlString }
        .onChange(of: tab.urlString) { newValue in
            urlString = newValue
        }
    }

    private var minimalPresetButton: some View {
        Button(action: { onSetWidth(Self.minimalWidth) }) {
            Image(systemName: "chevron.right.2")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(red: 0.85, green: 0.85, blue: 0.85))
                .frame(width: 22, height: 22)
                .background(Color(red: 0.16, green: 0.16, blue: 0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(red: 0.25, green: 0.25, blue: 0.25), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .help("Minimize (~44px)")
    }

    private func widthPresetButton(
        fraction: CGFloat,
        target: CGFloat,
        help: String
    ) -> some View {
        Button(action: { onSetWidth(target) }) {
            ZStack {
                Color(red: 0.16, green: 0.16, blue: 0.16)
                WidthIndicator(
                    fraction: fraction,
                    color: Color(red: 0.85, green: 0.85, blue: 0.85)
                )
            }
            .frame(width: 22, height: 22)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(red: 0.25, green: 0.25, blue: 0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func bookmarkButton(
        label: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(red: 0.85, green: 0.85, blue: 0.85))
                .frame(width: 22, height: 22)
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
}

/// Nút ½ riêng để gắn pulse animation khi panel đang ở minimal state — báo cho
/// user biết đây là nút khôi phục về ½ width.
private struct HalfPresetButton: View {
    let isMinimal: Bool
    let action: () -> Void

    @State private var pulseOn: Bool = false

    private static let normalBorder = Color(red: 0.25, green: 0.25, blue: 0.25)
    private static let normalIndicator = Color(red: 0.85, green: 0.85, blue: 0.85)

    var body: some View {
        Button(action: action) {
            ZStack {
                Color(red: 0.16, green: 0.16, blue: 0.16)
                WidthIndicator(fraction: 0.5, color: indicatorColor)
            }
            .frame(width: 22, height: 22)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(
                color: isMinimal
                    ? Color.accentColor.opacity(pulseOn ? 0.55 : 0.15)
                    : .clear,
                radius: isMinimal ? 6 : 0
            )
        }
        .buttonStyle(.plain)
        .help(isMinimal ? "Restore to half (50%)" : "Half width (50%)")
        .onAppear { if isMinimal { startPulse() } }
        .onChange(of: isMinimal) { newValue in
            if newValue { startPulse() } else { stopPulse() }
        }
    }

    private var borderColor: Color {
        if isMinimal {
            return Color.accentColor.opacity(pulseOn ? 0.9 : 0.45)
        }
        return Self.normalBorder
    }

    private var indicatorColor: Color {
        if isMinimal {
            return Color.accentColor.opacity(pulseOn ? 1.0 : 0.7)
        }
        return Self.normalIndicator
    }

    private func startPulse() {
        // Snap to base then start repeat to ensure clean entry, like
        // TerminalWindow's running pulse pattern.
        pulseOn = false
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            pulseOn = true
        }
    }

    private func stopPulse() {
        withAnimation(.easeInOut(duration: 0.2)) {
            pulseOn = false
        }
    }
}

/// Mini bar indicator: outlined rectangle với phần fill căn phải tỉ lệ theo
/// `fraction`. Dùng cho 4 nút ½ / full / ⅓ / ¼ để gợi proportion trực quan.
private struct WidthIndicator: View {
    let fraction: CGFloat
    let color: Color

    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 2)
                .stroke(color.opacity(0.55), lineWidth: 1)

            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: max(1.5, 10 * fraction), height: 5)
                .padding(.trailing, 1.5)
        }
        .frame(width: 13, height: 9)
    }
}

/// NSViewRepresentable wrapper. Nhận WKWebView (do BrowserTab own) và đặt vào
/// container view. WKWebView vẫn alive khi swap subview vì BrowserTab giữ ref strong.
private struct WebViewHost: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        install(webView, in: container)
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        if container.subviews.first !== webView {
            container.subviews.forEach { $0.removeFromSuperview() }
            install(webView, in: container)
        }
    }

    private func install(_ wv: WKWebView, in container: NSView) {
        wv.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(wv)
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: container.topAnchor),
            wv.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            wv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
    }
}
