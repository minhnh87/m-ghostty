import Foundation

@MainActor
class CommandHistoryStore: ObservableObject {
    static let shared = CommandHistoryStore()

    @Published var commands: [String]

    private static let userDefaultsKey = "CommandHistoryCommands"
    private static let ignoredPrefixes = ["gc", "gt", "po", "gb", "log", "git", "ls", "ll", "gs"]

    private init() {
        self.commands = UserDefaults.standard.stringArray(forKey: Self.userDefaultsKey) ?? []
    }

    func addCommand(_ command: String) {
        if Self.ignoredPrefixes.contains(where: { command.hasPrefix($0) }) {
            return
        }
        if let index = commands.firstIndex(of: command) {
            commands.remove(at: index)
        }
        commands.insert(command, at: 0)
        save()
    }

    func removeCommand(_ command: String) {
        commands.removeAll { $0 == command }
        save()
    }

    private func save() {
        UserDefaults.standard.set(commands, forKey: Self.userDefaultsKey)
    }
}

