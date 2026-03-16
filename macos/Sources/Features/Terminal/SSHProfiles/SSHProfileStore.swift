import Foundation

struct SSHProfile: Identifiable, Codable, Equatable {
    var id: String { host }
    let host: String
    let hostname: String
    let user: String
    let port: Int
    let isManual: Bool

    var displaySubtitle: String {
        let userPart = user.isEmpty ? "" : "\(user)@"
        return "\(userPart)\(hostname):\(port)"
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

    private static let userDefaultsKey = "SSHProfiles"

    init() {
        reload()
    }

    func reload() {
        let configProfiles = parseSSHConfig()
        let manualProfiles = loadManualProfiles()
        // Merge: config profiles first, then manual profiles not already in config
        let configHosts = Set(configProfiles.map { $0.host })
        let uniqueManual = manualProfiles.filter { !configHosts.contains($0.host) }
        profiles = configProfiles + uniqueManual
    }

    func addManualProfile(host: String, hostname: String, user: String, port: Int) {
        let profile = SSHProfile(
            host: host,
            hostname: hostname,
            user: user,
            port: port,
            isManual: true
        )
        var manual = loadManualProfiles()
        manual.removeAll { $0.host == host }
        manual.insert(profile, at: 0)
        saveManualProfiles(manual)
        reload()
    }

    func removeManualProfile(_ profile: SSHProfile) {
        var manual = loadManualProfiles()
        manual.removeAll { $0.host == profile.host }
        saveManualProfiles(manual)
        reload()
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
                        port: currentPort ?? 22,
                        isManual: false
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
                port: currentPort ?? 22,
                isManual: false
            ))
        }

        return results
    }

    // MARK: - Manual Profiles Persistence

    private func loadManualProfiles() -> [SSHProfile] {
        guard let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey),
              let profiles = try? JSONDecoder().decode([SSHProfile].self, from: data) else {
            return []
        }
        return profiles
    }

    private func saveManualProfiles(_ profiles: [SSHProfile]) {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }
}

