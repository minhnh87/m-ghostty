import SwiftUI
import WebKit

/// Browser panel hiển thị bên cạnh terminal. Per-tab state, nhưng "last URL"
/// được persist qua `@AppStorage` — mỗi tab mới hoặc lần restart sẽ mở ở URL
/// gần nhất bất kỳ tab nào load.
/// URL bar + nút reload, không có back/forward (v1).
struct BrowserPanelView: View {
    @AppStorage("browserPanelLastURL") private var lastURL: String = "https://www.google.com"

    /// True khi panel đang ở chế độ expanded (≥80% chiều rộng app). Quyết định
    /// icon của nút Expand/Collapse.
    let isExpanded: Bool
    /// Caller chuyển đổi giữa 90% (expanded) và 50% (collapsed) và persist.
    let onToggleExpand: () -> Void

    @State private var urlString: String = ""
    @State private var loadURL: URL? = nil
    @State private var reloadTrigger: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                TextField("URL", text: $urlString, onCommit: loadCurrentURL)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))

                Button(action: { reloadTrigger += 1 }) {
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
                .help(isExpanded ? "Collapse (50%)" : "Expand (90%)")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(red: 0.10, green: 0.10, blue: 0.10))

            Divider()

            WebView(url: loadURL, reloadTrigger: reloadTrigger)
        }
        .onAppear {
            // Khởi tạo từ lastURL (đã persist). Tách khỏi @State default để
            // mọi tab mới đều thấy URL gần nhất được load ở bất kỳ tab nào.
            if loadURL == nil {
                urlString = lastURL
                loadURL = URL(string: lastURL)
            }
        }
    }

    private func loadCurrentURL() {
        var s = urlString.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return }
        if !s.contains("://") { s = "https://" + s }
        if let url = URL(string: s) {
            loadURL = url
            urlString = s
            lastURL = s
        }
    }
}

private struct WebView: NSViewRepresentable {
    let url: URL?
    let reloadTrigger: Int

    func makeNSView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if let url = url, context.coordinator.lastLoadedURL != url {
            context.coordinator.lastLoadedURL = url
            nsView.load(URLRequest(url: url))
        }
        if context.coordinator.lastReloadTrigger != reloadTrigger {
            context.coordinator.lastReloadTrigger = reloadTrigger
            nsView.reload()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastLoadedURL: URL?
        var lastReloadTrigger: Int = 0
    }
}
