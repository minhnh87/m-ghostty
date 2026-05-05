import AppKit
import Foundation

@MainActor
class CustomBackgroundStore: ObservableObject {
    static let shared = CustomBackgroundStore()

    /// The currently-active session override hex (`#RRGGBB`/etc), or nil if no override is active.
    /// Mutated only via `setBackground(_:)` / `clear()`.
    @Published var customBackground: String?

    private static let hexRegex = try! NSRegularExpression(
        pattern: #"^#([0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$"#,
        options: []
    )

    private init() {}

    /// Validates a hex color string; on success records it as the active session override and
    /// returns `true`. Does not touch any file. Returns `false` on invalid input without mutating.
    @discardableResult
    func setBackground(_ hex: String) -> Bool {
        let range = NSRange(hex.startIndex..<hex.endIndex, in: hex)
        guard Self.hexRegex.firstMatch(in: hex, options: [], range: range) != nil else {
            return false
        }
        customBackground = hex
        return true
    }

    /// Clears the active session override. Does not touch any file.
    func clear() {
        customBackground = nil
    }

    // MARK: - Helpers

    /// Normalize an accepted hex string (3/4/6/8 digit, with leading `#`) to lowercase `#RRGGBB`.
    /// Assumes the input has already passed `hexRegex` validation.
    static func normalizeHexToRRGGBB(_ hex: String) -> String {
        let stripped = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let lower = stripped.lowercased()
        let rrggbb: String
        switch lower.count {
        case 3:
            // #RGB → #RRGGBB
            rrggbb = lower.map { "\($0)\($0)" }.joined()
        case 4:
            // #RGBA → take first 3 then double each
            rrggbb = lower.prefix(3).map { "\($0)\($0)" }.joined()
        case 6:
            rrggbb = lower
        case 8:
            // #RRGGBBAA → take first 6
            rrggbb = String(lower.prefix(6))
        default:
            // Should not happen if input was validated; fall back to whatever we have.
            rrggbb = lower
        }
        return "#" + rrggbb
    }

    /// Apply an OSC 11 background color override to a single surface. Single source of truth for
    /// the per-surface call so broadcast and per-new-surface replay stay in sync.
    static func applyTo(_ surfaceView: Ghostty.SurfaceView, hexRRGGBB: String) {
        surfaceView.surfaceModel?.setBackgroundColor(hexRRGGBB)
    }

    /// Broadcasts an OSC 11 background color override to every surface in every BaseTerminalController
    /// window currently open (regular terminals + Quick Terminal).
    static func applyToAllSurfaces(hexRRGGBB: String) {
        for window in NSApp.windows {
            guard let controller = window.windowController as? BaseTerminalController else { continue }
            for surfaceView in controller.surfaceTree {
                applyTo(surfaceView, hexRRGGBB: hexRRGGBB)
            }
        }
    }
}
