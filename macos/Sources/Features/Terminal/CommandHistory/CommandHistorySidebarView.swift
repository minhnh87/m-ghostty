import SwiftUI

struct CommandHistorySidebarView: View {
    @ObservedObject var store: CommandHistoryStore

    /// Called when a command is clicked (left click) — sends command to terminal.
    var onCommandClick: (String) -> Void

    /// Called when a command is Cmd+Clicked — removes it from history.
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
        List {
            ForEach(store.commands, id: \.self) { command in
                CommandHistoryRow(
                    command: command,
                    onCommandClick: onCommandClick,
                    onRemove: { onCommandRemove(command) }
                )
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Row

private struct CommandHistoryRow: View {
    let command: String
    var onCommandClick: (String) -> Void
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
                if NSEvent.modifierFlags.contains(.command) {
                    onRemove()
                } else {
                    onCommandClick(command)
                }
            }
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

