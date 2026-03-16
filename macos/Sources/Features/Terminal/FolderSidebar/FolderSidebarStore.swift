import Foundation

@MainActor
class FolderSidebarStore: ObservableObject {
    static let shared = FolderSidebarStore()

    @Published var folders: [String]

    private static let userDefaultsKey = "FolderSidebarFolders"

    private init() {
        self.folders = UserDefaults.standard.stringArray(forKey: Self.userDefaultsKey) ?? []
    }

    func addFolder(_ path: String) {
        if let index = folders.firstIndex(of: path) {
            folders.remove(at: index)
        }
        folders.insert(path, at: 0)
        save()
    }

    func removeFolder(_ path: String) {
        folders.removeAll { $0 == path }
        save()
    }

    private func save() {
        UserDefaults.standard.set(folders, forKey: Self.userDefaultsKey)
    }
}

