import SwiftUI
import WebKit

/// 2 bookmarks cứng sẵn cho Browser panel.
/// Bookmark "1" cần `pwd` (working directory của terminal đang focus) để gắn
/// vào query `?path=...`. Bookmark "2" là URL tĩnh.
enum BrowserBookmarks {
    static let bookmark2: String = "http://localhost:3001/"

    /// Build URL bookmark "1" với pwd hiện tại. Path được percent-encode an toàn
    /// qua `.urlQueryAllowed` (giữ '/' không encode vì hợp lệ trong query).
    /// Nếu `pwd` nil hoặc rỗng, fallback về home directory.
    static func bookmark1(pwd: String?) -> String {
        let raw = (pwd?.isEmpty == false ? pwd! : NSHomeDirectory())
        let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw
        return "http://127.0.0.1:4444/?path=\(encoded)"
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
        let wv = WKWebView()
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
            wv.load(URLRequest(url: url))
        }
    }

    func load(_ raw: String) {
        var s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return }
        if !s.contains("://") { s = "https://" + s }
        guard let url = URL(string: s) else { return }
        urlString = s
        webView.load(URLRequest(url: url))
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
        let tab2 = BrowserTab(urlString: BrowserBookmarks.bookmark2)
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
