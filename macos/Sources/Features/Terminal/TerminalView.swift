import SwiftUI
import GhosttyKit
import os

/// This delegate is notified of actions and property changes regarding the terminal view. This
/// delegate is optional and can be used by a TerminalView caller to react to changes such as
/// titles being set, cell sizes being changed, etc.
protocol TerminalViewDelegate: AnyObject {
    /// Called when the currently focused surface changed. This can be nil.
    func focusedSurfaceDidChange(to: Ghostty.SurfaceView?)

    /// The URL of the pwd should change.
    func pwdDidChange(to: URL?)

    /// The cell size changed.
    func cellSizeDidChange(to: NSSize)

    /// Perform an action. At the time of writing this is only triggered by the command palette.
    func performAction(_ action: String, on: Ghostty.SurfaceView)

    /// A split tree operation
    func performSplitAction(_ action: TerminalSplitOperation)
}

/// The view model is a required implementation for TerminalView callers. This contains
/// the main state between the TerminalView caller and SwiftUI. This abstraction is what
/// allows AppKit to own most of the data in SwiftUI.
protocol TerminalViewModel: ObservableObject {
    /// The tree of terminal surfaces (splits) within the view. This is mutated by TerminalView
    /// and children. This should be @Published.
    var surfaceTree: SplitTree<Ghostty.SurfaceView> { get set }

    /// The command palette state.
    var commandPaletteIsShowing: Bool { get set }

    /// The update overlay should be visible.
    var updateOverlayIsVisible: Bool { get }
}

/// The main terminal view. This terminal view supports splits.
struct TerminalView<ViewModel: TerminalViewModel>: View {
    @ObservedObject var ghostty: Ghostty.App

    // The required view model
    @ObservedObject var viewModel: ViewModel

    // An optional delegate to receive information about terminal changes.
    weak var delegate: (any TerminalViewDelegate)?

    // Folder sidebar
    @ObservedObject var folderSidebarStore: FolderSidebarStore
    var onFolderClick: (String) -> Void
    var onFolderCmdClick: (String) -> Void

    // Command history sidebar
    @ObservedObject var commandHistoryStore: CommandHistoryStore
    var onCommandClick: (String, Bool) -> Void
    var onCommandRemove: (String) -> Void

    // SSH profiles sidebar
    @ObservedObject var sshProfileStore: SSHProfileStore
    var onSSHConnect: (SSHProfile) -> Void
    var onSSHConnectNewTab: (SSHProfile) -> Void

    // Custom background (rendered inside SSH profiles panel)
    @ObservedObject var customBackgroundStore: CustomBackgroundStore
    var initialBackgroundHex: String
    var onCustomBackgroundApply: (String?) -> Void


    /// The most recently focused surface, equal to `focusedSurface` when it is non-nil.
    @State private var lastFocusedSurface: Weak<Ghostty.SurfaceView>?

    // Owned here (not in FolderSidebarView) so the Esc handler below can
    // restore terminal focus only when the folder filter field had it.
    @FocusState private var folderFilterFocused: Bool

    /// Which sidebar panel is currently visible (nil = all closed).
    @State private var activeSidebar: SidebarPanel? = nil

    /// Khi non-nil, leaf có id này sẽ render BrowserPanelView thay vì terminal.
    /// Anchor cố định vào leaf đang focus tại thời điểm bật Cmd+B; user switch
    /// focus sang pane khác KHÔNG di chuyển browser. Cleared khi toggle off
    /// hoặc khi anchored leaf bị remove khỏi tree.
    @State private var browserAnchoredSurfaceID: Ghostty.SurfaceView.ID? = nil

    private enum SidebarPanel: CaseIterable {
        case commandHistory
        case sshProfiles
        case folders

        /// All cases are part of the Cmd+E cycle. Browser is no longer a sidebar
        /// — nó anchor vào focused split leaf và toggle qua Cmd+B.
        static var cycleCases: [SidebarPanel] {
            [.folders, .commandHistory, .sshProfiles]
        }
    }

    // This seems like a crutch after switching from SwiftUI to AppKit lifecycle.
    @FocusState private var focused: Bool

    // Various state values sent back up from the currently focused terminals.
    @FocusedValue(\.ghosttySurfaceView) private var focusedSurface
    @FocusedValue(\.ghosttySurfacePwd) private var surfacePwd
    @FocusedValue(\.ghosttySurfaceCellSize) private var cellSize

    // The pwd of the focused surface as a URL
    private var pwdURL: URL? {
        guard let surfacePwd, surfacePwd != "" else { return nil }
        return URL(fileURLWithPath: surfacePwd)
    }

    /// Toggle browser anchor. Nếu anchor đang trỏ vào leaf hợp lệ → clear (off).
    /// Ngược lại (chưa set hoặc anchor stale do leaf bị remove) → set vào
    /// focused surface (fallback last-focused). No-op nếu không có surface nào
    /// để anchor vào.
    private func toggleBrowserAnchor() {
        if let id = browserAnchoredSurfaceID, viewModel.surfaceTree.find(id: id) != nil {
            browserAnchoredSurfaceID = nil
        } else if let id = (focusedSurface ?? lastFocusedSurface?.value)?.id {
            browserAnchoredSurfaceID = id
        }
    }

    /// Anchor đã được validate đối với surfaceTree hiện tại. Nếu leaf gốc đã
    /// bị remove thì trả nil để view không cố render browser vào id stale.
    private var effectiveBrowserAnchor: Ghostty.SurfaceView.ID? {
        guard let id = browserAnchoredSurfaceID else { return nil }
        return viewModel.surfaceTree.find(id: id) != nil ? id : nil
    }

    /// Inject `cd "<pwd>"` của tab liền kề bên trái vào surface đang focus.
    /// Im lặng nếu: không có surface focus, không có tabGroup, đang ở leftmost,
    /// hoặc tab trái không có pwd.
    private func cdToLeftTabPath() {
        guard let currentSurface = lastFocusedSurface?.value,
              let currentWindow = currentSurface.window,
              let tabGroup = currentWindow.tabGroup else { return }
        let windows = tabGroup.windows
        guard let currentIndex = windows.firstIndex(of: currentWindow),
              currentIndex > 0 else { return }
        let leftWindow = windows[currentIndex - 1]
        guard let leftController = leftWindow.windowController as? TerminalController,
              let leftPwd = leftController.focusedSurface?.pwd,
              !leftPwd.isEmpty else { return }
        let escaped = leftPwd.replacingOccurrences(of: "\"", with: "\\\"")
        currentSurface.surfaceModel?.writeText("cd \"\(escaped)\"\r")
    }

    var body: some View {
        switch ghostty.readiness {
        case .loading:
            Text("Loading")
        case .error:
            ErrorView()
        case .ready:
            GeometryReader { geometry in
            VStack(spacing: 0) {
            HStack(spacing: 0) {
                ZStack {
                    VStack(spacing: 0) {
                        // If we're running in debug mode we show a warning so that users
                        // know that performance will be degraded.
                        if Ghostty.info.mode == GHOSTTY_BUILD_MODE_DEBUG || Ghostty.info.mode == GHOSTTY_BUILD_MODE_RELEASE_SAFE {
                            DebugBuildWarningView()
                        }

                        TerminalSplitTreeView(
                            tree: viewModel.surfaceTree,
                            action: { delegate?.performSplitAction($0) },
                            browserAnchoredSurfaceID: effectiveBrowserAnchor,
                            pwdProvider: { surfacePwd })
                            .environmentObject(ghostty)
                            .ghosttyLastFocusedSurface(lastFocusedSurface)
                            .focused($focused)
                            .onAppear { self.focused = true }
                            .onChange(of: focusedSurface) { newValue in
                                // We want to keep track of our last focused surface so even if
                                // we lose focus we keep this set to the last non-nil value.
                                if newValue != nil {
                                    lastFocusedSurface = .init(newValue)
                                    self.delegate?.focusedSurfaceDidChange(to: newValue)
                                }
                            }
                            .onChange(of: pwdURL) { newValue in
                                self.delegate?.pwdDidChange(to: newValue)
                            }
                            .onChange(of: cellSize) { newValue in
                                guard let size = newValue else { return }
                                self.delegate?.cellSizeDidChange(to: size)
                            }
                            .frame(idealWidth: lastFocusedSurface?.value?.initialSize?.width,
                                   idealHeight: lastFocusedSurface?.value?.initialSize?.height)
                    }
                    // Ignore safe area to extend up in to the titlebar region if we have the "hidden" titlebar style
                    .ignoresSafeArea(.container, edges: ghostty.config.macosTitlebarStyle == "hidden" ? .top : [])

                    if let surfaceView = lastFocusedSurface?.value {
                        TerminalCommandPaletteView(
                            surfaceView: surfaceView,
                            isPresented: $viewModel.commandPaletteIsShowing,
                            ghosttyConfig: ghostty.config,
                            updateViewModel: (NSApp.delegate as? AppDelegate)?.updateViewModel) { action in
                            self.delegate?.performAction(action, on: surfaceView)
                        }
                    }

                    // Show update information above all else.
                    if viewModel.updateOverlayIsVisible {
                        UpdateOverlay()
                    }
                }
                .frame(maxWidth: .greatestFiniteMagnitude, maxHeight: .greatestFiniteMagnitude)

                // Command history right sidebar
                if activeSidebar == .commandHistory {
                    Divider()

                    CommandHistorySidebarView(
                        store: commandHistoryStore,
                        onCommandClick: onCommandClick,
                        onCommandRemove: onCommandRemove
                    )
                    .frame(width: geometry.size.width / 3)
                    .transition(.move(edge: .trailing))
                }

                // SSH profiles right sidebar
                if activeSidebar == .sshProfiles {
                    Divider()

                    SSHProfilesSidebarView(
                        store: sshProfileStore,
                        onSSHConnect: onSSHConnect,
                        onSSHConnectNewTab: onSSHConnectNewTab,
                        onPasswordFill: { password in
                            if let surfaceModel = lastFocusedSurface?.value?.surfaceModel {
                                surfaceModel.sendText(password + "\n")
                            }
                        },
                        customBackgroundStore: customBackgroundStore,
                        initialBackgroundHex: initialBackgroundHex,
                        onCustomBackgroundApply: onCustomBackgroundApply
                    )
                    .frame(width: geometry.size.width / 3)
                    .transition(.move(edge: .trailing))
                }

                // Folder sidebar (right side)
                if activeSidebar == .folders {
                    Divider()

                    FolderSidebarView(
                        store: folderSidebarStore,
                        onFolderClick: onFolderClick,
                        onFolderCmdClick: onFolderCmdClick,
                        filterFocused: _folderFilterFocused
                    )
                    .frame(width: geometry.size.width / 3)
                    .transition(.move(edge: .trailing))
                }

            }

            BottomToolbarView(
                customBackgroundStore: customBackgroundStore,
                onCustomBackgroundApply: onCustomBackgroundApply,
                onSendCtrlC: {
                    guard let surface = lastFocusedSurface?.value?.surfaceModel else { return }
                    surface.writeText("\u{0003}")
                },
                onSplitHorizontal: {
                    guard let surface = lastFocusedSurface?.value?.surface else { return }
                    ghostty.split(surface: surface, direction: GHOSTTY_SPLIT_DIRECTION_DOWN)
                },
                onSplitVertical: {
                    guard let surface = lastFocusedSurface?.value?.surface else { return }
                    ghostty.split(surface: surface, direction: GHOSTTY_SPLIT_DIRECTION_RIGHT)
                },
                onCloseTab: {
                    guard let controller = lastFocusedSurface?.value?.window?.windowController as? TerminalController else { return }
                    controller.closeTab(nil)
                },
                onCopyCwd: {
                    guard let pwd = lastFocusedSurface?.value?.pwd, !pwd.isEmpty else { return }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(pwd, forType: .string)
                },
                onOpenInFinder: {
                    guard let pwd = lastFocusedSurface?.value?.pwd, !pwd.isEmpty else { return }
                    NSWorkspace.shared.open(URL(fileURLWithPath: pwd, isDirectory: true))
                },
                onToggleBrowser: {
                    toggleBrowserAnchor()
                },
                onOpenGitGui: {
                    let rawPwd = lastFocusedSurface?.value?.pwd
                    NSLog("Git Gui: clicked, pwd=\(rawPwd ?? "<nil>")")
                    guard let pwd = rawPwd, !pwd.isEmpty else {
                        NSLog("Git Gui: pwd empty, aborting")
                        return
                    }
                    let candidates = ["/opt/homebrew/bin/git", "/usr/local/bin/git", "/usr/bin/git"]
                    guard let gitPath = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
                        NSLog("Git Gui: git not found in \(candidates)")
                        return
                    }
                    NSLog("Git Gui: launching \(gitPath) gui in \(pwd)")
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: gitPath)
                    process.arguments = ["gui"]
                    process.currentDirectoryURL = URL(fileURLWithPath: pwd)
                    // GUI apps inherit a minimal PATH; git resolves the `gui`
                    // subcommand (and its `wish` interpreter) via PATH.
                    var env = ProcessInfo.processInfo.environment
                    env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (env["PATH"] ?? "/usr/bin:/bin")
                    process.environment = env
                    do {
                        try process.run()
                        NSLog("Git Gui: spawned pid=\(process.processIdentifier)")
                    } catch {
                        NSLog("Git Gui: failed to launch \(gitPath) gui in \(pwd): \(error)")
                    }
                },
                onOpenInVSCode: {
                    guard let pwd = lastFocusedSurface?.value?.pwd, !pwd.isEmpty else { return }
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    process.arguments = ["-a", "Visual Studio Code", pwd]
                    try? process.run()
                }
            )
            } // VStack
            .animation(.easeInOut(duration: 0.2), value: activeSidebar)
            .background {
                Button("") {
                    // Cycling away destroys the folder filter field; if it held
                    // focus, restore the terminal (same as the Esc handler).
                    let filterWasFocused = folderFilterFocused
                    // Cycle: nil → folders → commandHistory → sshProfiles → nil
                    // Browser is intentionally excluded (toggled via Cmd+B).
                    let panels = SidebarPanel.cycleCases
                    if let current = activeSidebar, let idx = panels.firstIndex(of: current) {
                        let nextIdx = panels.index(after: idx)
                        if nextIdx < panels.endIndex {
                            activeSidebar = panels[nextIdx]
                        } else {
                            activeSidebar = nil
                        }
                    } else {
                        activeSidebar = panels.first
                    }
                    // Reload SSH profiles when switching to that panel
                    if activeSidebar == .sshProfiles {
                        sshProfileStore.reload()
                    }
                    if filterWasFocused, let surface = lastFocusedSurface?.value {
                        Ghostty.moveFocus(to: surface)
                    }
                }
                .keyboardShortcut("e", modifiers: .command)
                .hidden()

                // Cmd+B anchors browser vào focused split leaf (toggle).
                Button("") {
                    toggleBrowserAnchor()
                }
                .keyboardShortcut("b", modifiers: .command)
                .hidden()

                // Cmd+L: cd vào pwd của tab liền kề bên trái. Im lặng nếu là
                // tab leftmost hoặc tab trái không có pwd.
                Button("") {
                    cdToLeftTabPath()
                }
                .keyboardShortcut("l", modifiers: .command)
                .hidden()

                // Esc đóng sidebar đang mở. Browser không phải sidebar nên không
                // bị ảnh hưởng — browser chỉ đóng qua Cmd+B.
                if activeSidebar != nil {
                    EscapeKeyHandler {
                        // Read before closing: closing destroys the filter field.
                        let filterWasFocused = folderFilterFocused
                        activeSidebar = nil
                        // Closing the sidebar removes the filter field; if it
                        // held focus, first responder is stranded on the window.
                        // Restore the terminal. Guarded so focus is never yanked
                        // from other inputs (command palette, browser URL, ...).
                        if filterWasFocused, let surface = lastFocusedSurface?.value {
                            Ghostty.moveFocus(to: surface)
                        }
                    }
                }
            }
            } // GeometryReader
        }
    }
}

private struct UpdateOverlay: View {
    var body: some View {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            VStack {
                Spacer()

                HStack {
                    Spacer()
                    UpdatePill(model: appDelegate.updateViewModel)
                        .padding(.bottom, 9)
                        .padding(.trailing, 9)
                }
            }
        }
    }
}

struct DebugBuildWarningView: View {
    @State private var isPopover = false

    var body: some View {
        HStack {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)

            Text("You're running a debug build of Ghostty! Performance will be degraded.")
                .padding(.all, 8)
                .popover(isPresented: $isPopover, arrowEdge: .bottom) {
                    Text("""
                    Debug builds of Ghostty are very slow and you may experience
                    performance problems. Debug builds are only recommended during
                    development.
                    """)
                    .padding(.all)
                }

            Spacer()
        }
        .background(Color(.windowBackgroundColor))
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Debug build warning")
        .accessibilityValue("Debug builds of Ghostty are very slow and you may experience performance problems. Debug builds are only recommended during development.")
        .accessibilityAddTraits(.isStaticText)
        .onTapGesture {
            isPopover = true
        }
    }
}

// MARK: - Escape Key Handler

private struct EscapeKeyHandler: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> EscapeKeyView {
        EscapeKeyView(action: action)
    }

    func updateNSView(_ nsView: EscapeKeyView, context: Context) {
        nsView.action = action
    }

    final class EscapeKeyView: NSView {
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
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    guard let self else { return event }
                    guard event.keyCode == 53 else { return event } // 53 = Escape
                    guard self.window?.isKeyWindow == true else { return event }
                    DispatchQueue.main.async { self.action() }
                    return nil
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

        override func hitTest(_ point: NSPoint) -> NSView? {
            return nil
        }
    }
}

