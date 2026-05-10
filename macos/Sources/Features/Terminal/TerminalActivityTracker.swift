import AppKit
import Combine
import GhosttyKit

/// Drives the per-window tab color dot animations: a slow breathing pulse while a
/// shell command is running, and a one-shot scale burst when a surface emits an
/// OSC 9 / 777 desktop notification (e.g. claude task finished).
///
/// Two independent signals so the visual layers don't fight:
/// - `isRunning`: at least one surface in the window has a shell command that has
///   been running for >= `runningPulseDelay` (skips short commands like `ls`).
/// - `attentionTick`: increments each time an OSC 9 fires for a surface in the
///   window. View observes the change and plays a one-shot burst, no sustained
///   state.
///
/// Also mirrors `tabColor` from the window so the SwiftUI `TabColorIndicatorView`
/// can be a single observed object — re-assigning the hosting view's `rootView`
/// resets `@State` (animation phase) and was the root cause of the prior hacky
/// workarounds.
final class TerminalActivityTracker: ObservableObject {
    /// Delay before a running command starts pulsing. Picked to match the
    /// "feels long enough to care about" threshold — `ls`, `cd`, `git status`
    /// shouldn't trigger a pulse.
    static let runningPulseDelay: TimeInterval = 1.5

    @Published var tabColor: TerminalTabColor = .none
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var attentionTick: Int = 0

    /// Window this tracker watches. Activity from surfaces hosted in this window
    /// counts; activity from other windows is ignored.
    private weak var window: NSWindow?

    /// Surfaces currently running a shell command, mapped to start time.
    private var runningSince: [UUID: Date] = [:]
    /// Pending promotion timers per surface (fires runningPulseDelay after start).
    private var promotionWork: [UUID: DispatchWorkItem] = [:]

    private var observers: [NSObjectProtocol] = []

    init() {}

    /// Attach to a window. Must be called once after the window is fully wired
    /// up (e.g. inside `awakeFromNib`). Surfaces hosted in this window will be
    /// tracked; other windows are ignored.
    func attach(window: NSWindow) {
        self.window = window

        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: Ghostty.Notification.ghosttyCommandStarted,
            object: nil, queue: .main
        ) { [weak self] n in
            self?.handleCommandStarted(n)
        })
        observers.append(center.addObserver(
            forName: Ghostty.Notification.ghosttyCommandFinishedAny,
            object: nil, queue: .main
        ) { [weak self] n in
            self?.handleCommandFinished(n)
        })
        observers.append(center.addObserver(
            forName: Ghostty.Notification.ghosttyDesktopNotificationDidFire,
            object: nil, queue: .main
        ) { [weak self] n in
            self?.handleDesktopNotification(n)
        })
    }

    deinit {
        let center = NotificationCenter.default
        for o in observers { center.removeObserver(o) }
        for work in promotionWork.values { work.cancel() }
    }

    // MARK: - Notification handlers

    private func handleCommandStarted(_ notification: Notification) {
        guard let surface = notification.object as? Ghostty.SurfaceView,
              belongsToWindow(surface) else { return }
        let id = surface.id
        runningSince[id] = Date()

        promotionWork[id]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            // Only promote if still running — commandFinished may have arrived
            // between schedule and fire.
            if self.runningSince[id] != nil {
                self.recomputeRunning()
            }
        }
        promotionWork[id] = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.runningPulseDelay,
            execute: work)
    }

    private func handleCommandFinished(_ notification: Notification) {
        // Don't gate on belongsToWindow here: a surface may have moved to
        // another window between started and finished, but we still need to
        // clear the tracking entry to avoid a stuck pulse.
        guard let surface = notification.object as? Ghostty.SurfaceView else { return }
        let id = surface.id
        guard runningSince[id] != nil else { return }
        runningSince.removeValue(forKey: id)
        promotionWork[id]?.cancel()
        promotionWork.removeValue(forKey: id)
        recomputeRunning()
    }

    private func handleDesktopNotification(_ notification: Notification) {
        guard let surface = notification.object as? Ghostty.SurfaceView,
              belongsToWindow(surface) else { return }
        attentionTick &+= 1
    }

    // MARK: - State

    private func recomputeRunning() {
        let now = Date()
        let active = runningSince.contains { _, started in
            now.timeIntervalSince(started) >= Self.runningPulseDelay
        }
        if isRunning != active {
            isRunning = active
        }
    }

    /// Whether the surface is hosted inside the tracked window right now.
    private func belongsToWindow(_ surface: Ghostty.SurfaceView) -> Bool {
        guard let trackedWindow = window else { return false }
        return surface.window === trackedWindow
    }
}
