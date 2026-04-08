import Foundation

struct QuickPassword: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }

    /// Keychain account key uses "qp-{id}" prefix to avoid conflicts with SSH profile passwords
    var keychainId: String { "qp-\(id.uuidString)" }
}

struct SSHProfile: Identifiable, Codable, Equatable {
    var id: String { host }
    let host: String
    let hostname: String
    let user: String
    let port: Int

    var displaySubtitle: String {
        let userPart = user.isEmpty ? "" : "\(user)@"
        return "\(userPart)\(hostname):\(port)"
    }

    var hasPassword: Bool {
        let keychainManager = SSHKeychainManager()
        return keychainManager.hasPassword(profileId: host)
    }

    func sshCommand() -> String {
        var cmd = "ssh "
        if !user.isEmpty {
            cmd += "\(user)@"
        }
        cmd += hostname
        if port != 22 {
            cmd += " -p \(port)"
        }
        cmd += "\n"
        return cmd
    }
}

class SSHProfileStore: ObservableObject {
    @Published var profiles: [SSHProfile] = []
    @Published var quickPasswords: [QuickPassword] = []

    private static let quickPasswordsKey = "QuickPasswords"
    private let keychainManager = SSHKeychainManager()

    init() {
        reload()
        loadQuickPasswords()
    }

    func reload() {
        profiles = parseSSHConfig()
    }

    func addProfile(host: String, hostname: String, user: String, port: Int) {
        let sshDir = NSString("~/.ssh").expandingTildeInPath
        let configPath = NSString("~/.ssh/config").expandingTildeInPath
        let fm = FileManager.default

        // Create ~/.ssh/ directory if needed (0700 permissions)
        if !fm.fileExists(atPath: sshDir) {
            try? fm.createDirectory(atPath: sshDir, withIntermediateDirectories: true, attributes: [
                .posixPermissions: 0o700
            ])
        }

        // Build the Host block to append
        var block = "\nHost \(host)\n"
        block += "    Hostname \(hostname)\n"
        if !user.isEmpty {
            block += "    User \(user)\n"
        }
        if port != 22 {
            block += "    Port \(port)\n"
        }

        // Create file if it doesn't exist (0600 permissions), or append
        if !fm.fileExists(atPath: configPath) {
            fm.createFile(atPath: configPath, contents: block.data(using: .utf8), attributes: [
                .posixPermissions: 0o600
            ])
        } else {
            if let handle = FileHandle(forWritingAtPath: configPath) {
                handle.seekToEndOfFile()
                if let data = block.data(using: .utf8) {
                    handle.write(data)
                }
                handle.closeFile()
            }
        }

        reload()
    }

    func removeProfile(_ profile: SSHProfile) {
        let configPath = NSString("~/.ssh/config").expandingTildeInPath
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else { return }

        let lines = content.components(separatedBy: "\n")
        var result: [String] = []
        var skipping = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let normalized = trimmed
                .replacingOccurrences(of: "\t", with: " ")
                .replacingOccurrences(of: "=", with: " ")
            let parts = normalized.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)

            if parts.count == 2, String(parts[0]).lowercased() == "host" {
                let hostValue = String(parts[1]).trimmingCharacters(in: .whitespaces)
                if hostValue == profile.host {
                    skipping = true
                    // Also remove a preceding blank line if the last result line is empty
                    if let last = result.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
                        result.removeLast()
                    }
                    continue
                } else {
                    skipping = false
                }
            }

            if !skipping {
                result.append(line)
            }
        }

        // Remove trailing blank lines
        while let last = result.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            result.removeLast()
        }

        let newContent = result.joined(separator: "\n") + "\n"
        try? newContent.write(toFile: configPath, atomically: true, encoding: .utf8)

        // Delete password from Keychain when removing profile
        try? keychainManager.deletePassword(profileId: profile.host)
        reload()
    }

    func savePassword(for profileId: String, password: String) throws {
        try keychainManager.savePassword(profileId: profileId, password: password)
    }

    func deletePassword(for profileId: String) throws {
        try keychainManager.deletePassword(profileId: profileId)
    }

    // MARK: - Quick Passwords

    func addQuickPassword(name: String, password: String) {
        let entry = QuickPassword(name: name)
        var list = loadQuickPasswordList()
        list.insert(entry, at: 0)
        saveQuickPasswordList(list)
        try? keychainManager.savePassword(profileId: entry.keychainId, password: password)
        loadQuickPasswords()
    }

    func removeQuickPassword(_ entry: QuickPassword) {
        var list = loadQuickPasswordList()
        list.removeAll { $0.id == entry.id }
        saveQuickPasswordList(list)
        try? keychainManager.deletePassword(profileId: entry.keychainId)
        loadQuickPasswords()
    }

    func changeQuickPassword(_ entry: QuickPassword, newPassword: String) {
        try? keychainManager.savePassword(profileId: entry.keychainId, password: newPassword)
    }

    func getQuickPassword(_ entry: QuickPassword) -> String? {
        keychainManager.getPassword(profileId: entry.keychainId)
    }

    private func loadQuickPasswords() {
        quickPasswords = loadQuickPasswordList()
    }

    private func loadQuickPasswordList() -> [QuickPassword] {
        guard let data = UserDefaults.standard.data(forKey: Self.quickPasswordsKey),
              let list = try? JSONDecoder().decode([QuickPassword].self, from: data) else {
            return []
        }
        return list
    }

    private func saveQuickPasswordList(_ list: [QuickPassword]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: Self.quickPasswordsKey)
        }
    }

    // MARK: - SSH Config Parsing

    private func parseSSHConfig() -> [SSHProfile] {
        let configPath = NSString("~/.ssh/config").expandingTildeInPath
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return []
        }

        var results: [SSHProfile] = []
        var currentHost: String?
        var currentHostname: String?
        var currentUser: String?
        var currentPort: Int?

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            // Normalize: replace tabs and = with spaces to handle all SSH config formats
            // (Key Value, Key\tValue, Key=Value, Key = Value, Key\t=\tValue)
            let normalized = trimmed
                .replacingOccurrences(of: "\t", with: " ")
                .replacingOccurrences(of: "=", with: " ")
            let parts = normalized.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).lowercased()
            let value = String(parts[1]).trimmingCharacters(in: .whitespaces)

            if key == "host" {
                // Save previous host entry
                if let host = currentHost, !host.contains("*") {
                    results.append(SSHProfile(
                        host: host,
                        hostname: currentHostname ?? host,
                        user: currentUser ?? "",
                        port: currentPort ?? 22
                    ))
                }
                currentHost = value
                currentHostname = nil
                currentUser = nil
                currentPort = nil
            } else if key == "hostname" {
                currentHostname = value
            } else if key == "user" {
                currentUser = value
            } else if key == "port" {
                currentPort = Int(value)
            }
        }

        // Don't forget the last entry
        if let host = currentHost, !host.contains("*") {
            results.append(SSHProfile(
                host: host,
                hostname: currentHostname ?? host,
                user: currentUser ?? "",
                port: currentPort ?? 22
            ))
        }

        return results
    }

}

