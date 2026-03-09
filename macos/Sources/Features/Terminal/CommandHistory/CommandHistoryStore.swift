import Foundation

class CommandHistoryStore: ObservableObject {
    @Published var commands: [String]

    private static let userDefaultsKey = "CommandHistoryCommands"
    private static let maxItems = 36
    private static let ignoredPrefixes = ["gc", "gt", "po", "gb", "log", "git", "ls", "ll", "gs"]

    init() {
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
        if commands.count > Self.maxItems {
            commands = Array(commands.prefix(Self.maxItems))
        }
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

