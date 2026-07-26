import SwiftUI
import WebKit

/// Browser panel thay thế surface đang focus khi user bật Cmd+B. Panel chiếm
/// 100% width của leaf nó được anchor vào (nếu tab có split thì chỉ chiếm
/// pane đó, không ảnh hưởng các pane khác). Mỗi tab giữ một WKWebView riêng
/// nên scroll/state được preserve khi switch giữa các browser tab.
/// Khi panel được bật lên, luôn khởi tạo 2 tab default (base URL lấy từ
/// config `browser-panel-base-url`):
///   1) `{base}index.html?f={pwd của terminal đang focus}`
///   2) `{base}claude.html`
struct BrowserPanelView: View {
    @StateObject private var tabsModel: BrowserTabsModel

    /// Cung cấp pwd của terminal đang focus tại thời điểm gọi. Dùng cho bookmark
    /// "1" — mỗi lần click sẽ build URL với pwd hiện hành.
    let pwdProvider: () -> String?

    init(pwdProvider: @escaping () -> String?) {
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
    let pwdProvider: () -> String?

    @State private var urlString: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                bookmarkButton(label: "1", help: "Open index.html with current folder") {
                    tab.load(BrowserBookmarks.bookmark1(pwd: pwdProvider()))
                }
                bookmarkButton(label: "2", help: "Open claude.html") {
                    tab.load(BrowserBookmarks.bookmark2())
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
            .clipped()

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
        let container = BrowserContainerView()
        container.webView = webView
        install(webView, in: container)
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        if let container = container as? BrowserContainerView {
            container.webView = webView
        }
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

/// Container view cho WKWebView trong Browser Panel. Lý do tồn tại: Cmd+C / Cmd+V
/// trong WKWebView không work khi đặt trong cây view của terminal — nhiều khả năng
/// do menu Edit > Copy bị Ghostty inject keyEquivalent Cmd+C (xem
/// `AppDelegate.syncMenuShortcut` cho action `copy_to_clipboard`) làm hỏng dispatch
/// `copy:` xuống first responder là WKWebView. Ta override `performKeyEquivalent`
/// ở ngay tầng container để bắt sớm và forward thẳng vào webView khi focus đang
/// nằm bên trong webView.
private final class BrowserContainerView: NSView {
    weak var webView: WKWebView?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let webView,
              let window,
              let fr = window.firstResponder as? NSView,
              fr.isDescendant(of: webView),
              event.modifierFlags.intersection([.command, .option, .control, .shift]) == .command
        else { return super.performKeyEquivalent(with: event) }

        switch event.charactersIgnoringModifiers {
        case "c":
            NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
            return true
        case "v":
            NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}
