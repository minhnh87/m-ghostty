import Foundation

/// Tracks keyboard input as a fallback for capturing commands when shell
/// integration (OSC 133) is not available, e.g. during SSH sessions.
///
/// Each terminal surface owns one InputTracker. When shell integration is
/// detected (via OSC 133;C), the tracker disables itself so that commands
/// are not duplicated.
class InputTracker {
    /// The accumulated text the user has typed since the last Enter/reset.
    private(set) var currentInput: String = ""

    /// Set to `true` once we receive an OSC 133 semantic prompt, meaning
    /// the shell has Ghostty integration and we should not capture commands.
    private(set) var hasShellIntegration: Bool = false

    /// Append typed text to the buffer.
    func appendText(_ text: String) {
        currentInput += text
    }

    /// Handle a backspace: remove the last character if any.
    func handleBackspace() {
        guard !currentInput.isEmpty else { return }
        currentInput.removeLast()
    }

    /// Handle Enter: return the trimmed input and reset the buffer.
    /// Returns `nil` if the buffer is empty or whitespace-only.
    func handleEnter() -> String? {
        let trimmed = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        currentInput = ""
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Reset the buffer (e.g. on Ctrl+C).
    func reset() {
        currentInput = ""
    }

    /// Mark that shell integration is active for this surface.
    func markShellIntegrationActive() {
        hasShellIntegration = true
    }
}

