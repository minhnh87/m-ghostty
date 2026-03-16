import SwiftUI

struct SSHProfilesSidebarView: View {
    @ObservedObject var store: SSHProfileStore

    /// Called when a profile is clicked — sends ssh command to terminal.
    var onSSHConnect: (String) -> Void

    /// Called when a profile is Cmd+Clicked — opens new tab with ssh command.
    var onSSHConnectNewTab: (String) -> Void

    @State private var isAddingProfile: Bool = false
    @State private var newHost: String = ""
    @State private var newHostname: String = ""
    @State private var newUser: String = ""
    @State private var newPort: String = "22"

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if store.profiles.isEmpty && !isAddingProfile {
                emptyState
            } else {
                profileList
            }
        }
        .background(Color(red: 0.11, green: 0.11, blue: 0.11))
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack {
            Text("SSH Profiles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(red: 0.65, green: 0.65, blue: 0.65))
            Spacer()
            Button(action: { store.reload() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.55))
            }
            .buttonStyle(.plain)
            .help("Refresh SSH config")
            Button(action: { isAddingProfile.toggle() }) {
                Image(systemName: "plus")
                    .font(.system(size: 11))
                    .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.55))
            }
            .buttonStyle(.plain)
            .help("Add manual profile")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No SSH profiles")
                .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.55))
                .font(.system(size: 12))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Profile List

    @ViewBuilder
    private var profileList: some View {
        List {
            if isAddingProfile {
                addProfileForm
            }
            ForEach(store.profiles) { profile in
                SSHProfileRow(
                    profile: profile,
                    onConnect: { onSSHConnect(profile.sshCommand()) },
                    onConnectNewTab: { onSSHConnectNewTab(profile.sshCommand()) },
                    onRemove: profile.isManual ? { store.removeManualProfile(profile) } : nil
                )
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Add Profile Form

    @ViewBuilder
    private var addProfileForm: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Host alias", text: $newHost)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
            TextField("Hostname", text: $newHostname)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
            TextField("User", text: $newUser)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
            TextField("Port", text: $newPort)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
            HStack {
                Button("Add") {
                    let port = Int(newPort) ?? 22
                    let hostname = newHostname.isEmpty ? newHost : newHostname
                    guard !newHost.isEmpty else { return }
                    store.addManualProfile(
                        host: newHost,
                        hostname: hostname,
                        user: newUser,
                        port: port
                    )
                    resetForm()
                }
                .buttonStyle(.borderedProminent)
                .font(.system(size: 11))
                .disabled(newHost.isEmpty)
                Button("Cancel") { resetForm() }
                    .buttonStyle(.bordered)
                    .font(.system(size: 11))
            }
        }
        .padding(.vertical, 4)
    }

    private func resetForm() {
        isAddingProfile = false
        newHost = ""
        newHostname = ""
        newUser = ""
        newPort = "22"
    }
}

// MARK: - Row

private struct SSHProfileRow: View {
    let profile: SSHProfile
    var onConnect: () -> Void
    var onConnectNewTab: () -> Void
    var onRemove: (() -> Void)?

    @State private var isHovered: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(profile.host)
                .foregroundColor(isHovered ? Color(red: 0.85, green: 0.85, blue: 0.85) : Color(red: 0.70, green: 0.70, blue: 0.70))
                .lineLimit(1)
                .truncationMode(.tail)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
            Text(profile.displaySubtitle)
                .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.45))
                .lineLimit(1)
                .truncationMode(.tail)
                .font(.system(size: 11, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            if NSEvent.modifierFlags.contains(.command) {
                onConnectNewTab()
            } else {
                onConnect()
            }
        }
        .help(profile.sshCommand().trimmingCharacters(in: .whitespacesAndNewlines))
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .overlay {
            if let onRemove {
                SSHRightClickHandler(action: onRemove)
            }
        }
    }
}

// MARK: - Right Click Handler

private struct SSHRightClickHandler: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> SSHRightClickView {
        SSHRightClickView(action: action)
    }

    func updateNSView(_ nsView: SSHRightClickView, context: Context) {
        nsView.action = action
    }

    class SSHRightClickView: NSView {
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
                        return nil
                    }
                    return event
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

