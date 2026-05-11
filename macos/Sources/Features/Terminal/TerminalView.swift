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

    /// Which sidebar panel is currently visible (nil = all closed).
    @State private var activeSidebar: SidebarPanel? = nil

    /// Browser panel width (nil = use 50% default). Session-only, not persisted.
    @State private var browserWidth: CGFloat? = nil

    private enum SidebarPanel: CaseIterable {
        case commandHistory
        case sshProfiles
        case folders
        case browser

        /// Panels included in the Cmd+E cycle. Browser is excluded — it has its
        /// own dedicated Cmd+B toggle to avoid pulling the heavier WKWebView
        /// into the cycle.
        static var cycleCases: [SidebarPanel] {
            [.commandHistory, .sshProfiles, .folders]
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

    /// Effective browser width with clamping. Default = 50% of total.
    /// Clamp range keeps both terminal and browser at least `browserMinWidth` wide.
    private func clampedBrowserWidth(total: CGFloat) -> CGFloat {
        let raw = browserWidth ?? (total / 2)
        let minW = browserMinWidth
        let maxW = max(minW, total - minW)
        return min(max(raw, minW), maxW)
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
                            action: { delegate?.performSplitAction($0) })
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
                        onFolderCmdClick: onFolderCmdClick
                    )
                    .frame(width: geometry.size.width / 3)
                    .transition(.move(edge: .trailing))
                }

                // Browser panel (right side, 50/50 default, resizable)
                if activeSidebar == .browser {
                    BrowserResizeHandle(
                        totalWidth: geometry.size.width,
                        browserWidth: $browserWidth
                    )

                    BrowserPanelView()
                        .frame(width: clampedBrowserWidth(total: geometry.size.width))
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
                onPaste: {
                    guard let surfaceView = lastFocusedSurface?.value else { return }
                    surfaceView.paste(nil)
                },
                onToggleBrowser: {
                    activeSidebar = (activeSidebar == .browser) ? nil : .browser
                }
            )
            } // VStack
            .animation(.easeInOut(duration: 0.2), value: activeSidebar)
            .background {
                Button("") {
                    // Cycle: nil → commandHistory → sshProfiles → folders → nil
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
                }
                .keyboardShortcut("e", modifiers: .command)
                .hidden()

                // Cmd+B toggles browser panel directly (not part of Cmd+E cycle)
                Button("") {
                    activeSidebar = (activeSidebar == .browser) ? nil : .browser
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

                if activeSidebar != nil {
                    EscapeKeyHandler {
                        activeSidebar = nil
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

// MARK: - Browser Resize Handle

/// Min width cho cả terminal và browser panel khi resize.
fileprivate let browserMinWidth: CGFloat = 300

/// Drag handle giữa terminal và browser panel. Width 4px, hiển thị divider 1px
/// ở giữa, đổi cursor thành resizeLeftRight khi hover. Cập nhật `browserWidth`
/// dạng "delta-from-current" để cảm giác kéo tự nhiên ở bất kỳ vị trí nào.
private struct BrowserResizeHandle: View {
    let totalWidth: CGFloat
    @Binding var browserWidth: CGFloat?

    @State private var dragStartWidth: CGFloat? = nil

    private static let handleWidth: CGFloat = 4

    var body: some View {
        ZStack {
            Color.clear
            Divider()
        }
        .frame(width: Self.handleWidth)
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let start = dragStartWidth ?? (browserWidth ?? (totalWidth / 2))
                    if dragStartWidth == nil { dragStartWidth = start }
                    let proposed = start - value.translation.width
                    let minW = browserMinWidth
                    let maxW = max(minW, totalWidth - minW)
                    browserWidth = min(max(proposed, minW), maxW)
                }
                .onEnded { _ in
                    dragStartWidth = nil
                }
        )
    }
}
