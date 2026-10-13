import SwiftUI

struct FolderSidebarView: View {
    @ObservedObject var store: FolderSidebarStore

    /// Called when a folder is clicked (left click).
    var onFolderClick: (String) -> Void

    /// Called when a folder is Cmd+clicked (opens new tab).
    var onFolderCmdClick: (String) -> Void

    @State private var filterText: String = ""
    @FocusState private var isFilterFocused: Bool

    /// Row highlighted for keyboard navigation (Up/Down + Enter in the filter).
    @State private var selectedIndex: Int = 0

    /// The focus state is owned by TerminalView so the Esc handler there can
    /// tell whether the filter field held focus when the sidebar closes.
    init(
        store: FolderSidebarStore,
        onFolderClick: @escaping (String) -> Void,
        onFolderCmdClick: @escaping (String) -> Void,
        filterFocused: FocusState<Bool>
    ) {
        self.store = store
        self.onFolderClick = onFolderClick
        self.onFolderCmdClick = onFolderCmdClick
        _isFilterFocused = filterFocused
    }

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

    private var filteredFolders: [String] {
        let query = filterText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return sortedFolders }
        return sortedFolders.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if store.folders.isEmpty {
                emptyState
            } else {
                filterBar
                if filteredFolders.isEmpty {
                    noMatchState
                } else {
                    folderList
                }
            }
        }
        .background(Color(red: 0.11, green: 0.11, blue: 0.11))
        .onChange(of: filterText) { _ in selectedIndex = 0 }
    }

    private func moveSelection(by delta: Int) {
        let count = filteredFolders.count
        guard count > 0 else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), count - 1)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var filterBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.55))

            TextField("Filter folders", text: $filterText)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Color(red: 0.85, green: 0.85, blue: 0.85))
                .focused($isFilterFocused)
                .backport.onKeyPress(.upArrow) { _ in
                    moveSelection(by: -1)
                    return .handled
                }
                .backport.onKeyPress(.downArrow) { _ in
                    moveSelection(by: 1)
                    return .handled
                }
                .onSubmit {
                    let folders = filteredFolders
                    guard folders.indices.contains(selectedIndex) else { return }
                    onFolderClick(folders[selectedIndex])
                }

            if !filterText.isEmpty {
                Button {
                    filterText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.55))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.16, green: 0.16, blue: 0.16))
        )
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

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
    private var noMatchState: some View {
        VStack {
            Spacer()
            Text("No matching folders")
                .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.55))
                .font(.system(size: 12))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var folderList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredFolders.enumerated()), id: \.element) { index, path in
                        FolderSidebarRow(
                            path: path,
                            isSelected: isFilterFocused && index == selectedIndex,
                            onFolderClick: onFolderClick,
                            onFolderCmdClick: onFolderCmdClick,
                            onRemove: { store.removeFolder(path) }
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            isFilterFocused && index == selectedIndex
                                ? Color(red: 0.2, green: 0.2, blue: 0.2)
                                : Color.clear
                        )
                    }
                }
            }
            .onChange(of: selectedIndex) { index in
                let folders = filteredFolders
                guard folders.indices.contains(index) else { return }
                proxy.scrollTo(folders[index])
            }
        }
    }
}

// MARK: - Row

private struct FolderSidebarRow: View {
    let path: String
    var isSelected: Bool
    var onFolderClick: (String) -> Void
    var onFolderCmdClick: (String) -> Void
    var onRemove: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Text(shortPath)
            .foregroundColor(isHovered || isSelected ? Color(red: 0.85, green: 0.85, blue: 0.85) : Color(red: 0.55, green: 0.55, blue: 0.55))
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