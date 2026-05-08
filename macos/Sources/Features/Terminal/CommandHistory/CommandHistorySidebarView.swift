import SwiftUI

struct CommandHistorySidebarView: View {
    @ObservedObject var store: CommandHistoryStore

    /// Called when a command is clicked. `execute` is true when Cmd or Shift is held
    /// (run immediately); false for a plain click (print only, no newline).
    var onCommandClick: (String, Bool) -> Void

    /// Called when a command is removed via right-click.
    var onCommandRemove: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if store.commands.isEmpty {
                emptyState
            } else {
                commandList
            }
        }
        .background(Color(red: 0.11, green: 0.11, blue: 0.11))
    }

    // MARK: - Subviews

    @ViewBuilder
    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No commands yet")
                .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.55))
                .font(.system(size: 12))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var commandList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.commands, id: \.self) { command in
                    CommandHistoryRow(
                        command: command,
                        onCommandClick: onCommandClick,
                        onRemove: { onCommandRemove(command) }
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
            }
        }
    }
}

// MARK: - Right Click Helper

private struct RightClickHandler: NSViewRepresentable {
    var onRightClick: () -> Void

    func makeNSView(context: Context) -> RightClickNSView {
        let view = RightClickNSView()
        view.onRightClick = onRightClick
        return view
    }

    func updateNSView(_ nsView: RightClickNSView, context: Context) {
        nsView.onRightClick = onRightClick
    }
}

private class RightClickNSView: NSView {
    var onRightClick: (() -> Void)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil && monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
                guard let self = self, let window = self.window else { return event }
                let locationInView = self.convert(event.locationInWindow, from: nil)
                if self.bounds.contains(locationInView) {
                    self.onRightClick?()
                    return nil // consume the right-click
                }
                return event
            }
        }
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        if superview == nil, let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // Pass through all hit testing so left clicks reach SwiftUI
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}

// MARK: - Row

private struct CommandHistoryRow: View {
    let command: String
    var onCommandClick: (String, Bool) -> Void
    var onRemove: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Text(command)
            .foregroundColor(isHovered ? Color(red: 0.85, green: 0.85, blue: 0.85) : Color(red: 0.55, green: 0.55, blue: 0.55))
            .lineLimit(1)
            .truncationMode(.tail)
            .font(.system(size: 13, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                let mods = NSEvent.modifierFlags
                let execute = mods.contains(.command) || mods.contains(.shift)
                onCommandClick(command, execute)
            }
            .overlay(
                RightClickHandler(onRightClick: { onRemove() })
            )
            .help(command)
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

