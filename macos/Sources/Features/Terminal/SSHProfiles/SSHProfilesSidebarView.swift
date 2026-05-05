import SwiftUI

struct SSHProfilesSidebarView: View {
    @ObservedObject var store: SSHProfileStore

    /// Called when a profile is clicked — sends ssh command to terminal.
    var onSSHConnect: (SSHProfile) -> Void

    /// Called when a profile is Cmd+Clicked — opens new tab with ssh command.
    var onSSHConnectNewTab: (SSHProfile) -> Void

    /// Called when a quick password is clicked — sends password to terminal.
    var onPasswordFill: (String) -> Void

    /// Store for the active session-only custom background override.
    @ObservedObject var customBackgroundStore: CustomBackgroundStore

    /// The current effective background as `#rrggbb`, used by the section to pre-fill the field
    /// and to revert it on Clear.
    var initialBackgroundHex: String

    /// Called after the custom background store updates so the caller can broadcast the OSC 11
    /// background override to all surfaces.
    var onCustomBackgroundApply: (String?) -> Void

    @State private var isAddingProfile: Bool = false
    @State private var newHost: String = ""
    @State private var newHostname: String = ""
    @State private var newUser: String = ""
    @State private var newPort: String = "22"
    @State private var newPassword: String = ""

    @State private var isChangingPassword: Bool = false
    @State private var changePasswordProfile: SSHProfile?
    @State private var changePasswordValue: String = ""

    @State private var isAddingQuickPassword: Bool = false
    @State private var newQuickPasswordName: String = ""
    @State private var newQuickPasswordValue: String = ""

    @State private var isChangingQuickPassword: Bool = false
    @State private var changeQuickPasswordEntry: QuickPassword?
    @State private var changeQuickPasswordValue: String = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if store.profiles.isEmpty && !isAddingProfile && store.quickPasswords.isEmpty && !isAddingQuickPassword {
                emptyState
            } else {
                profileList
            }
            Divider()
            CustomBackgroundSection(
                store: customBackgroundStore,
                initialBackgroundHex: initialBackgroundHex,
                onApply: onCustomBackgroundApply
            )
        }
        .background(Color(red: 0.11, green: 0.11, blue: 0.11))
        .sheet(isPresented: $isChangingPassword) {
            changePasswordDialog
        }
        .sheet(isPresented: $isChangingQuickPassword) {
            changeQuickPasswordDialog
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SSH Profiles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(red: 0.65, green: 0.65, blue: 0.65))
                Button(action: openSSHConfig) {
                    Text("~/.ssh/config")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(red: 0.50, green: 0.50, blue: 0.50))
                }
                .buttonStyle(.plain)
                .help("Open SSH config file")
            }
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
            .help("Add profile")
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
                    onConnect: { onSSHConnect(profile) },
                    onConnectNewTab: { onSSHConnectNewTab(profile) },
                    onRemove: { store.removeProfile(profile) },
                    onChangePassword: { showChangePasswordDialog(for: profile) },
                    onRemovePassword: { removePassword(for: profile) }
                )
            }

            // Quick Passwords section
            quickPasswordsSection
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Quick Passwords Section

    @ViewBuilder
    private var quickPasswordsSection: some View {
        Section {
            if isAddingQuickPassword {
                addQuickPasswordForm
            }
            ForEach(store.quickPasswords) { entry in
                QuickPasswordRow(
                    entry: entry,
                    onFill: {
                        if let password = store.getQuickPassword(entry) {
                            onPasswordFill(password)
                        }
                    },
                    onChangePassword: { showChangeQuickPasswordDialog(for: entry) },
                    onRemove: { store.removeQuickPassword(entry) }
                )
            }
        } header: {
            HStack {
                Text("Passwords")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.55))
                Spacer()
                Button(action: { isAddingQuickPassword.toggle() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.55))
                }
                .buttonStyle(.plain)
                .help("Add quick password")
            }
        }
    }

    // MARK: - Add Quick Password Form

    @ViewBuilder
    private var addQuickPasswordForm: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Name", text: $newQuickPasswordName)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
            SecureField("Password", text: $newQuickPasswordValue)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
            HStack {
                Button("Add") {
                    guard !newQuickPasswordName.isEmpty, !newQuickPasswordValue.isEmpty else { return }
                    store.addQuickPassword(name: newQuickPasswordName, password: newQuickPasswordValue)
                    resetQuickPasswordForm()
                }
                .buttonStyle(.borderedProminent)
                .font(.system(size: 11))
                .disabled(newQuickPasswordName.isEmpty || newQuickPasswordValue.isEmpty)
                Button("Cancel") { resetQuickPasswordForm() }
                    .buttonStyle(.bordered)
                    .font(.system(size: 11))
            }
        }
        .padding(.vertical, 4)
    }

    private func resetQuickPasswordForm() {
        isAddingQuickPassword = false
        newQuickPasswordName = ""
        newQuickPasswordValue = ""
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
            SecureField("Password (optional)", text: $newPassword)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
            Text("Password will be stored securely in Keychain")
                .font(.system(size: 9))
                .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.45))
            HStack {
                Button("Add") {
                    let port = Int(newPort) ?? 22
                    let hostname = newHostname.isEmpty ? newHost : newHostname
                    guard !newHost.isEmpty else { return }
                    store.addProfile(
                        host: newHost,
                        hostname: hostname,
                        user: newUser,
                        port: port
                    )
                    // Save password if provided
                    if !newPassword.isEmpty {
                        try? store.savePassword(for: newHost, password: newPassword)
                    }
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
        newPassword = ""
    }

    // MARK: - Password Management

    private func showChangePasswordDialog(for profile: SSHProfile) {
        changePasswordProfile = profile
        changePasswordValue = ""
        isChangingPassword = true
    }

    private func removePassword(for profile: SSHProfile) {
        try? store.deletePassword(for: profile.host)
        store.reload()
    }

    @ViewBuilder
    private var changePasswordDialog: some View {
        if let profile = changePasswordProfile {
            VStack(spacing: 16) {
                Text("Change Password for \(profile.host)")
                    .font(.headline)
                SecureField("New Password", text: $changePasswordValue)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                HStack {
                    Button("Cancel") {
                        isChangingPassword = false
                        changePasswordProfile = nil
                        changePasswordValue = ""
                    }
                    .buttonStyle(.bordered)
                    Button("Save") {
                        if !changePasswordValue.isEmpty {
                            try? store.savePassword(for: profile.host, password: changePasswordValue)
                        }
                        isChangingPassword = false
                        changePasswordProfile = nil
                        changePasswordValue = ""
                        store.reload()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(changePasswordValue.isEmpty)
                }
            }
            .padding(24)
        }
    }

    // MARK: - Open SSH Config

    // MARK: - Quick Password Management

    private func showChangeQuickPasswordDialog(for entry: QuickPassword) {
        changeQuickPasswordEntry = entry
        changeQuickPasswordValue = ""
        isChangingQuickPassword = true
    }

    @ViewBuilder
    private var changeQuickPasswordDialog: some View {
        if let entry = changeQuickPasswordEntry {
            VStack(spacing: 16) {
                Text("Change Password for \(entry.name)")
                    .font(.headline)
                SecureField("New Password", text: $changeQuickPasswordValue)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 300)
                HStack {
                    Button("Cancel") {
                        isChangingQuickPassword = false
                        changeQuickPasswordEntry = nil
                        changeQuickPasswordValue = ""
                    }
                    .buttonStyle(.bordered)
                    Button("Save") {
                        if !changeQuickPasswordValue.isEmpty {
                            store.changeQuickPassword(entry, newPassword: changeQuickPasswordValue)
                        }
                        isChangingQuickPassword = false
                        changeQuickPasswordEntry = nil
                        changeQuickPasswordValue = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(changeQuickPasswordValue.isEmpty)
                }
            }
            .padding(24)
        }
    }

    // MARK: - Open SSH Config

    private func openSSHConfig() {
        let configPath = NSString(string: "~/.ssh/config").expandingTildeInPath

        // Try VS Code first
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["code"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                // VS Code is available
                let codeProcess = Process()
                codeProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                codeProcess.arguments = ["code", configPath]
                try? codeProcess.run()

                // Auto-reload after opening
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    store.reload()
                }
                return
            }
        } catch {
            // Fall through to next option
        }

        // Try Vim in terminal
        // Note: This would require access to the terminal surface to send the command
        // For now, skip to fallback

        // Fallback: TextEdit
        let workspace = NSWorkspace.shared
        workspace.openFile(configPath, withApplication: "TextEdit")

        // Auto-reload after opening
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            store.reload()
        }
    }
}

// MARK: - Row

private struct SSHProfileRow: View {
    let profile: SSHProfile
    var onConnect: () -> Void
    var onConnectNewTab: () -> Void
    var onRemove: (() -> Void)?
    var onChangePassword: (() -> Void)?
    var onRemovePassword: (() -> Void)?

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(profile.host)
                        .foregroundColor(isHovered ? Color(red: 0.85, green: 0.85, blue: 0.85) : Color(red: 0.70, green: 0.70, blue: 0.70))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    if profile.hasPassword {
                        Text("🔑")
                            .font(.system(size: 10))
                            .foregroundColor(Color(red: 0.50, green: 0.50, blue: 0.50))
                    }
                }
                Text(profile.displaySubtitle)
                    .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.45))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .font(.system(size: 11, design: .monospaced))
            }
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
            if onRemove != nil || onChangePassword != nil || onRemovePassword != nil {
                SSHRightClickHandler(
                    profile: profile,
                    onRemove: onRemove,
                    onChangePassword: onChangePassword,
                    onRemovePassword: onRemovePassword
                )
            }
        }
    }
}

// MARK: - Right Click Handler

private struct SSHRightClickHandler: NSViewRepresentable {
    let profile: SSHProfile
    let onRemove: (() -> Void)?
    let onChangePassword: (() -> Void)?
    let onRemovePassword: (() -> Void)?

    func makeNSView(context: Context) -> SSHRightClickView {
        SSHRightClickView(
            profile: profile,
            onRemove: onRemove,
            onChangePassword: onChangePassword,
            onRemovePassword: onRemovePassword
        )
    }

    func updateNSView(_ nsView: SSHRightClickView, context: Context) {
        nsView.profile = profile
        nsView.onRemove = onRemove
        nsView.onChangePassword = onChangePassword
        nsView.onRemovePassword = onRemovePassword
    }

    class SSHRightClickView: NSView {
        var profile: SSHProfile
        var onRemove: (() -> Void)?
        var onChangePassword: (() -> Void)?
        var onRemovePassword: (() -> Void)?
        private var monitor: Any?

        init(profile: SSHProfile, onRemove: (() -> Void)?, onChangePassword: (() -> Void)?, onRemovePassword: (() -> Void)?) {
            self.profile = profile
            self.onRemove = onRemove
            self.onChangePassword = onChangePassword
            self.onRemovePassword = onRemovePassword
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
                        self.showContextMenu(at: locationInWindow)
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

        private func showContextMenu(at point: NSPoint) {
            let menu = NSMenu()

            // Add password-related menu items if profile has password
            if profile.hasPassword {
                if let onChangePassword {
                    let changeItem = NSMenuItem(title: "Change Password", action: #selector(changePasswordAction), keyEquivalent: "")
                    changeItem.target = self
                    menu.addItem(changeItem)
                }

                if let onRemovePassword {
                    let removePasswordItem = NSMenuItem(title: "Remove Password", action: #selector(removePasswordAction), keyEquivalent: "")
                    removePasswordItem.target = self
                    menu.addItem(removePasswordItem)
                }

                if onRemove != nil {
                    menu.addItem(NSMenuItem.separator())
                }
            }

            // Add remove profile menu item
            if let onRemove {
                let removeItem = NSMenuItem(title: "Remove", action: #selector(removeAction), keyEquivalent: "")
                removeItem.target = self
                menu.addItem(removeItem)
            }

            if menu.items.isEmpty {
                return
            }

            menu.popUp(positioning: nil, at: convert(point, from: nil), in: self)
        }

        @objc private func changePasswordAction() {
            onChangePassword?()
        }

        @objc private func removePasswordAction() {
            onRemovePassword?()
        }

        @objc private func removeAction() {
            onRemove?()
        }
    }
}


// MARK: - Quick Password Row

private struct QuickPasswordRow: View {
    let entry: QuickPassword
    var onFill: () -> Void
    var onChangePassword: () -> Void
    var onRemove: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Text("🔑")
                .font(.system(size: 10))
            Text(entry.name)
                .foregroundColor(isHovered ? Color(red: 0.85, green: 0.85, blue: 0.85) : Color(red: 0.70, green: 0.70, blue: 0.70))
                .lineLimit(1)
                .truncationMode(.tail)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            onFill()
        }
        .help("Fill password: \(entry.name)")
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .contextMenu {
            Button("Change Password") { onChangePassword() }
            Button("Remove") { onRemove() }
        }
    }
}
