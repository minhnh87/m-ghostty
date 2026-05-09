import SwiftUI

struct FolderSidebarView: View {
    @ObservedObject var store: FolderSidebarStore

    /// Called when a folder is clicked (left click).
    var onFolderClick: (String) -> Void

    /// Called when a folder is Cmd+clicked (opens new tab).
    var onFolderCmdClick: (String) -> Void

    private var sortedFolders: [String] {
        store.folders.sorted { lhs, rhs in
            let lhsParent = (lhs as NSString).deletingLastPathComponent
            let rhsParent = (rhs as NSString).deletingLastPathComponent
            let parentOrder = lhsParent.localizedCaseInsensitiveCompare(rhsParent)
            if parentOrder != .orderedSame {
                return parentOrder == .orderedAscending
            }
            let lhsName = (lhs as NSString).lastPathComponent
            let rhsName = (rhs as NSString).lastPathComponent
            return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if store.folders.isEmpty {
                emptyState
            } else {
                folderList
            }
        }
        .background(Color(red: 0.11, green: 0.11, blue: 0.11))
    }

    // MARK: - Subviews

    @ViewBuilder
    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No folders pinned")
                .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.55))
                .font(.system(size: 12))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var folderList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sortedFolders, id: \.self) { path in
                    FolderSidebarRow(
                        path: path,
                        onFolderClick: onFolderClick,
                        onFolderCmdClick: onFolderCmdClick,
                        onRemove: { store.removeFolder(path) }
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
            }
        }
    }
}

// MARK: - Row

private struct FolderSidebarRow: View {
    let path: String
    var onFolderClick: (String) -> Void
    var onFolderCmdClick: (String) -> Void
    var onRemove: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Text(shortPath)
            .foregroundColor(isHovered ? Color(red: 0.85, green: 0.85, blue: 0.85) : Color(red: 0.55, green: 0.55, blue: 0.55))
            .lineLimit(1)
            .truncationMode(.middle)
            .font(.system(size: 13, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                handleClick()
            }
            .overlay(
                RightClickHandler { onRemove() }
            )
            .help(path)
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

    private func handleClick() {
        if NSEvent.modifierFlags.contains(.command) {
            onFolderCmdClick(path)
        } else {
            onFolderClick(path)
        }
    }

    private var shortPath: String {
        let components = (path as NSString).pathComponents
        if components.count <= 2 {
            return (path as NSString).lastPathComponent
        }
        let last2 = components.suffix(2)
        return last2.joined(separator: "/")
    }
}

// MARK: - Right Click Handler

private struct RightClickHandler: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> RightClickView {
        RightClickView(action: action)
    }

    func updateNSView(_ nsView: RightClickView, context: Context) {
        nsView.action = action
    }

    class RightClickView: NSView {
        var action: () -> Void
        private var monitor: Any?

        init(action: @escaping () -> Void) {
            self.action = action
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            fatalError()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil && monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
                    guard let self, let window = self.window else { return event }
                    let locationInWindow = event.locationInWindow
                    let locationInView = self.convert(locationInWindow, from: nil)
                    if self.bounds.contains(locationInView) {
                        self.action()
                        return nil // consume the event
                    }
                    return event // pass through
                }
            }
        }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            if superview == nil, let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        // CRITICAL: Return nil so this view doesn't intercept any hit testing
        override func hitTest(_ point: NSPoint) -> NSView? {
            return nil
        }
    }
}