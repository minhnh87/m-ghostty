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
    var onCommandClick: (String) -> Void
    var onCommandRemove: (String) -> Void

    // SSH profiles sidebar
    @ObservedObject var sshProfileStore: SSHProfileStore
    var onSSHConnect: (String) -> Void
    var onSSHConnectNewTab: (String) -> Void

    /// The most recently focused surface, equal to `focusedSurface` when it is non-nil.
    @State private var lastFocusedSurface: Weak<Ghostty.SurfaceView>?

    /// Whether the folder sidebar is visible.
    @State private var folderSidebarVisible: Bool = false

    /// Whether the command history sidebar is visible.
    @State private var commandHistoryVisible: Bool = false

    /// Whether the SSH profiles sidebar is visible.
    @State private var sshProfilesVisible: Bool = false

    /// Tracks which right sidebar was last toggled (to handle mutual exclusion).
    @State private var lastRightSidebar: RightSidebar = .commandHistory

    private enum RightSidebar {
        case commandHistory
        case sshProfiles
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

    var body: some View {
        switch ghostty.readiness {
        case .loading:
            Text("Loading")
        case .error:
            ErrorView()
        case .ready:
            GeometryReader { geometry in
            HStack(spacing: 0) {
                // Folder left sidebar
                if folderSidebarVisible {
                    FolderSidebarView(
                        store: folderSidebarStore,
                        onFolderClick: onFolderClick,
                        onFolderCmdClick: onFolderCmdClick
                    )
                    .transition(.move(edge: .leading))

                    Divider()
                }

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
                if commandHistoryVisible && lastRightSidebar == .commandHistory {
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
                if sshProfilesVisible && lastRightSidebar == .sshProfiles {
                    Divider()

                    SSHProfilesSidebarView(
                        store: sshProfileStore,
                        onSSHConnect: onSSHConnect,
                        onSSHConnectNewTab: onSSHConnectNewTab
                    )
                    .frame(width: geometry.size.width / 3)
                    .transition(.move(edge: .trailing))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: folderSidebarVisible)
            .animation(.easeInOut(duration: 0.2), value: commandHistoryVisible)
            .animation(.easeInOut(duration: 0.2), value: sshProfilesVisible)
            .animation(.easeInOut(duration: 0.2), value: lastRightSidebar)
            .background {
                Button("") { folderSidebarVisible.toggle() }
                    .keyboardShortcut("l", modifiers: .command)
                    .hidden()
                Button("") {
                    commandHistoryVisible.toggle()
                    if commandHistoryVisible {
                        lastRightSidebar = .commandHistory
                        sshProfilesVisible = false
                    }
                }
                    .keyboardShortcut("e", modifiers: .command)
                    .hidden()
                Button("") {
                    sshProfilesVisible.toggle()
                    if sshProfilesVisible {
                        lastRightSidebar = .sshProfiles
                        commandHistoryVisible = false
                        sshProfileStore.reload()
                    }
                }
                    .keyboardShortcut("s", modifiers: .command)
                    .hidden()
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
