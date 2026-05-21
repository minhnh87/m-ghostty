import SwiftUI
import WebKit

/// Browser panel hiển thị bên cạnh terminal, hỗ trợ nhiều tab.
/// Mỗi tab giữ một WKWebView riêng nên scroll/state được preserve khi switch tab.
/// Khi panel được bật lên, luôn khởi tạo 2 tab default:
///   1) `http://localhost:3001/?f={pwd của terminal đang focus}`
///   2) `http://127.0.0.1:4444/?path={pwd của terminal đang focus}`
struct BrowserPanelView: View {
    @StateObject private var tabsModel: BrowserTabsModel

    /// True khi panel đang ở chế độ expanded (≥80% chiều rộng app).
    let isExpanded: Bool
    /// Caller chuyển đổi giữa 90% (expanded) và 50% (collapsed) và persist.
    let onToggleExpand: () -> Void
    /// Cung cấp pwd của terminal đang focus tại thời điểm gọi. Dùng cho bookmark
    /// "1" — mỗi lần click sẽ build URL với pwd hiện hành.
    let pwdProvider: () -> String?

    init(
        isExpanded: Bool,
        onToggleExpand: @escaping () -> Void,
        pwdProvider: @escaping () -> String?
    ) {
        self.isExpanded = isExpanded
        self.onToggleExpand = onToggleExpand
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
                    isExpanded: isExpanded,
                    onToggleExpand: onToggleExpand,
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
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let pwdProvider: () -> String?

    @State private var urlString: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.right.2" : "chevron.left.2")
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
                .help(isExpanded ? "Collapse (50%)" : "Expand (100%)")
                
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
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(red: 0.10, green: 0.10, blue: 0.10))

            Divider()

            WebViewHost(webView: tab.webView)
        }
        .onAppear { urlString = tab.urlString }
        .onChange(of: tab.urlString) { newValue in
            urlString = newValue
        }
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
