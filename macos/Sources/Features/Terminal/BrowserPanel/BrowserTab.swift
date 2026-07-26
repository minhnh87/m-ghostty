import SwiftUI
import WebKit

/// 2 bookmarks default cho Browser panel, build từ base URL lấy trong config
/// (`browser-panel-base-url`, fallback về research/public). Bookmark 1 nhận
/// `pwd` (working directory của terminal đang focus) gắn vào query `f=`.
enum BrowserBookmarks {
    /// Base URL đọc từ config mỗi lần gọi để user đổi config là ăn ngay
    /// (sau reload config) mà không cần đổi code. Luôn có trailing slash.
    private static var baseURL: String {
        guard let appDelegate = NSApp.delegate as? AppDelegate else {
            return "file:///Users/minh/www/git/personal/research/public/"
        }
        return appDelegate.ghostty.config.browserPanelBaseURL
    }

    /// Bookmark "1": `{base}index.html` với param `f={pwd}` (current folder),
    /// kèm `path=last_talk.md`, `theme=dark` và `zoom=90` cố định.
    static func bookmark1(pwd: String?) -> String {
        return "\(baseURL)index.html?path=last_talk.md&f=\(encodedPWD(pwd))&theme=dark&zoom=90"
    }

    /// Bookmark "2": `{base}claude.html`, không param.
    static func bookmark2() -> String {
        return "\(baseURL)claude.html"
    }

    /// Percent-encode qua `.urlQueryAllowed` (giữ '/' không encode vì hợp lệ
    /// trong query). Fallback về home directory nếu `pwd` nil hoặc rỗng.
    private static func encodedPWD(_ pwd: String?) -> String {
        let raw = (pwd?.isEmpty == false ? pwd! : NSHomeDirectory())
        return raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw
    }
}

/// Một tab trong Browser panel. Giữ WKWebView riêng để preserve scroll/state
/// khi switch tab. Observe `webView.title` và `webView.url` qua KVO.
final class BrowserTab: ObservableObject, Identifiable {
    let id = UUID()
    let webView: WKWebView

    @Published var title: String = ""
    @Published var urlString: String = ""

    private var titleObservation: NSKeyValueObservation?
    private var urlObservation: NSKeyValueObservation?

    init(urlString: String) {
        self.urlString = urlString
        // Cho phép trang file:// fetch/XHR file khác (vd đọc file trong pwd
        // của terminal). Hai key này là KVC private nhưng là cách chuẩn de-facto
        // với WKWebView.
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        let wv = WKWebView(frame: .zero, configuration: config)
        self.webView = wv

        titleObservation = wv.observe(\.title, options: [.new]) { [weak self] wv, _ in
            let t = wv.title ?? ""
            DispatchQueue.main.async { self?.title = t }
        }
        urlObservation = wv.observe(\.url, options: [.new]) { [weak self] wv, _ in
            guard let s = wv.url?.absoluteString else { return }
            DispatchQueue.main.async {
                self?.urlString = s
            }
        }

        if let url = URL(string: urlString) {
            load(url)
        }
    }

    func load(_ raw: String) {
        var s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return }
        if !s.contains("://") { s = "https://" + s }
        guard let url = URL(string: s) else { return }
        urlString = s
        load(url)
    }

    /// WebContent process của WKWebView luôn sandboxed nên file URL phải load
    /// qua `loadFileURL(_:allowingReadAccessTo:)` để cấp quyền đọc; grant tới
    /// home directory để trang đọc được file ở pwd bất kỳ.
    private func load(_ url: URL) {
        if url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true))
        } else {
            webView.load(URLRequest(url: url))
        }
    }

    func reload() { webView.reload() }

    /// Label hiển thị trên tab: title nếu đã load, fallback về host, cuối cùng "New Tab".
    var displayTitle: String {
        if !title.isEmpty { return title }
        if let host = URL(string: urlString)?.host { return host }
        return "New Tab"
    }

    deinit {
        titleObservation?.invalidate()
        urlObservation?.invalidate()
    }
}

/// Quản lý list tabs + tab đang active. Mỗi lần khởi tạo (mỗi lần panel được
/// bật lên) sẽ tạo lại 2 tab default (bookmark1 + bookmark2). Tabs không persist
/// qua các session hoặc qua toggle panel — theo yêu cầu.
final class BrowserTabsModel: ObservableObject {
    @Published var tabs: [BrowserTab] = []
    @Published var activeTabID: UUID?

    init(initialPWD: String?) {
        let tab1 = BrowserTab(urlString: BrowserBookmarks.bookmark1(pwd: initialPWD))
        let tab2 = BrowserTab(urlString: BrowserBookmarks.bookmark2())
        tabs = [tab1, tab2]
        activeTabID = tab1.id
    }

    var activeTab: BrowserTab? {
        guard let id = activeTabID else { return nil }
        return tabs.first { $0.id == id }
    }

    func addTab(urlString: String? = nil) {
        let tab = BrowserTab(urlString: urlString ?? "https://www.google.com")
        tabs.append(tab)
        activeTabID = tab.id
    }

    func closeTab(_ id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: idx)
        if tabs.isEmpty {
            // Không bao giờ để 0 tab — tạo tab mới với URL default.
            addTab()
            return
        }
        if activeTabID == id {
            let newIdx = min(idx, tabs.count - 1)
            activeTabID = tabs[newIdx].id
        }
    }

    func setActive(_ id: UUID) {
        guard activeTabID != id else { return }
        activeTabID = id
    }
}
