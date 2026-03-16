import Foundation

/// Information about an active SSH session detected from the terminal title.
struct SSHSessionInfo: Equatable {
    let user: String
    let hostname: String
    let connectedAt: Date
}

