import Foundation

/// Giữ prompt cache của session Claude Code trong một tab luôn ấm.
///
/// Khi bật, mỗi 60s kiểm tra session mới nhất của cwd (file `.jsonl` sửa gần
/// nhất trong `~/.claude/projects/<cwd mã hoá>/`). Nếu session idle quá ngưỡng
/// (55 phút với cache TTL 1h, 4 phút với TTL 5m) thì gửi một request headless
/// `--resume --fork-session`, rồi xoá session fork sinh ra.
///
/// Không dùng `--disallowedTools`: đổi danh sách tool làm đổi prefix → trượt
/// cache hoàn toàn. Dùng `--max-turns 1` + prompt cấm tool thay thế.
final class ClaudeCacheKeepAlive: ObservableObject {
    @Published private(set) var isActive = false

    private var cwd: String?
    private var timer: Timer?
    private var isPinging = false
    private var lastPingAt: Date?

    private static let checkInterval: TimeInterval = 60
    private static let threshold1h: TimeInterval = 55 * 60
    private static let threshold5m: TimeInterval = 4 * 60
    private static let pingPrompt = "Reply with just: ok. Do not use any tools."

    private static let claudeHome = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude")

    deinit {
        timer?.invalidate()
    }

    /// Bật/tắt keep-alive. `cwd` là thư mục của surface đang focus lúc bật.
    func toggle(cwd: String?) {
        if isActive {
            timer?.invalidate()
            timer = nil
            isActive = false
            return
        }
        guard let cwd, !cwd.isEmpty else { return }
        self.cwd = cwd
        lastPingAt = nil
        isActive = true
        let timer = Timer(timeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    private func tick() {
        guard isActive, !isPinging, let cwd else { return }
        guard let session = Self.latestSession(cwd: cwd) else {
            NSLog("ClaudeKeepAlive: no session found for \(cwd)")
            return
        }

        let lastActivity = max(session.modified, lastPingAt ?? .distantPast)
        let threshold = Self.uses5mCache(session.url) ? Self.threshold5m : Self.threshold1h
        guard Date().timeIntervalSince(lastActivity) >= threshold else { return }

        ping(originalID: session.id, cwd: cwd)
    }

    private func ping(originalID: String, cwd: String) {
        guard let claude = Self.claudeExecutable() else {
            NSLog("ClaudeKeepAlive: claude executable not found")
            return
        }
        let forkID = UUID().uuidString.lowercased()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: claude)
        process.arguments = [
            "-p", Self.pingPrompt,
            "--resume", originalID,
            "--fork-session",
            "--session-id", forkID,
            "--max-turns", "1",
        ]
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        var env = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        env["PATH"] = "\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin:" + (env["PATH"] ?? "/usr/bin:/bin")
        process.environment = env
        process.terminationHandler = { [weak self] proc in
            Self.deleteSession(id: forkID, originalID: originalID, cwd: cwd)
            DispatchQueue.main.async {
                self?.isPinging = false
            }
            NSLog("ClaudeKeepAlive: ping \(originalID) exit=\(proc.terminationStatus)")
        }

        isPinging = true
        lastPingAt = Date()
        do {
            try process.run()
        } catch {
            isPinging = false
            NSLog("ClaudeKeepAlive: failed to launch claude: \(error)")
        }
    }

    // MARK: - Session files

    /// Claude Code mã hoá cwd thành tên thư mục: mọi ký tự không phải chữ/số → "-".
    private static func projectDir(cwd: String) -> URL {
        let encoded = cwd.replacingOccurrences(of: "[^A-Za-z0-9]", with: "-", options: .regularExpression)
        return claudeHome.appendingPathComponent("projects").appendingPathComponent(encoded)
    }

    private static func latestSession(cwd: String) -> (id: String, url: URL, modified: Date)? {
        let dir = projectDir(cwd: cwd)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return nil }

        return files
            .filter { $0.pathExtension == "jsonl" }
            .compactMap { url -> (id: String, url: URL, modified: Date)? in
                let id = url.deletingPathExtension().lastPathComponent
                guard isUUID(id),
                      let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                else { return nil }
                return (id, url, modified)
            }
            .max { $0.modified < $1.modified }
    }

    /// Đọc ngược phần cuối file session, lấy request gần nhất có ghi cache để
    /// biết TTL đang dùng. Không xác định được → coi như 5m (ping dày hơn, an toàn hơn).
    private static func uses5mCache(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return true }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let chunk: UInt64 = 256 * 1024
        try? handle.seek(toOffset: size > chunk ? size - chunk : 0)
        guard let data = try? handle.readToEnd(),
              let text = String(data: data, encoding: .utf8) else { return true }

        for line in text.split(separator: "\n").reversed() {
            guard line.contains("\"cache_creation\""),
                  let json = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let message = json["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any],
                  let creation = usage["cache_creation"] as? [String: Any]
            else { continue }
            let tokens5m = creation["ephemeral_5m_input_tokens"] as? Int ?? 0
            let tokens1h = creation["ephemeral_1h_input_tokens"] as? Int ?? 0
            if tokens5m > 0 { return true }
            if tokens1h > 0 { return false }
        }
        return true
    }

    /// Xoá các file của session fork. Chỉ xoá khi id là UUID hợp lệ và khác session gốc.
    private static func deleteSession(id: String, originalID: String, cwd: String) {
        guard isUUID(id), id != originalID else { return }
        let dir = projectDir(cwd: cwd)
        let paths = [
            dir.appendingPathComponent("\(id).jsonl"),
            dir.appendingPathComponent(id),
            claudeHome.appendingPathComponent("session-env").appendingPathComponent(id),
            claudeHome.appendingPathComponent("file-history").appendingPathComponent(id),
        ]
        for path in paths where FileManager.default.fileExists(atPath: path.path) {
            try? FileManager.default.removeItem(at: path)
        }
    }

    private static func isUUID(_ s: String) -> Bool {
        UUID(uuidString: s) != nil
    }

    private static func claudeExecutable() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = ["\(home)/.local/bin/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
