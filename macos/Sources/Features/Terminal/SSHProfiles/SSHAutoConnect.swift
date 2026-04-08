import Foundation
import GhosttyKit

/// Helper for auto-connecting to SSH with password auto-fill using expect
class SSHAutoConnect {
    private let keychainManager = SSHKeychainManager()

    /// Connect to SSH profile with optional password auto-fill
    /// - Parameters:
    ///   - profile: The SSH profile to connect to
    ///   - password: Optional password for auto-fill (if nil, will try to get from Keychain)
    ///   - surface: The terminal surface model to send the command to
    @MainActor
    func connect(profile: SSHProfile, password: String? = nil, to surface: Ghostty.Surface) {
        // Try to get password from Keychain if not provided
        let finalPassword = password ?? keychainManager.getPassword(profileId: profile.host)

        // If we have a password and expect is available, use auto-connect
        if let pwd = finalPassword, isExpectAvailable() {
            let expectCommand = buildExpectCommand(profile: profile, password: pwd)
            surface.sendText(expectCommand)
        } else {
            // Fallback to normal SSH command
            surface.sendText(profile.sshCommand())
        }
    }
    
    /// Check if expect is available on the system
    private func isExpectAvailable() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["expect"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    /// Build expect command for auto-filling SSH password
    private func buildExpectCommand(profile: SSHProfile, password: String) -> String {
        // Escape special characters in password for expect
        let escapedPassword = password
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")
        
        // Build SSH command parts
        var sshCmd = "ssh "
        if !profile.user.isEmpty {
            sshCmd += "\(profile.user)@"
        }
        sshCmd += profile.hostname
        if profile.port != 22 {
            sshCmd += " -p \(profile.port)"
        }
        
        // Build expect script
        let expectScript = """
        expect -c "
          spawn \(sshCmd)
          expect {
            \\"*password:\\" { send \\"\(escapedPassword)\\r\\"; exp_continue }
            \\"*Password:\\" { send \\"\(escapedPassword)\\r\\"; exp_continue }
            eof
          }
          interact
        "
        """
        
        return expectScript + "\n"
    }
}

