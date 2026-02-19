import Foundation

enum SwitcherTheme: String, Codable {
    case compact
    case comfortable
}

final class ConfigStore {
    static let shared = ConfigStore()
    static let configUpdatedNotification = Notification.Name("ConfigStoreUpdated")

    private struct Config: Codable {
        var assignments: [AppAssignment] = []
        var isOverlayEnabled: Bool?
        var isCheatSheetEnabled: Bool?
        var theme: SwitcherTheme?
        var longPressDelay: Double?
        
        // Helper to get non-optional values with defaults
        var overlayEnabled: Bool { isOverlayEnabled ?? false }
        var cheatSheetEnabled: Bool { isCheatSheetEnabled ?? true }
        var activeTheme: SwitcherTheme { theme ?? .comfortable }
        var delay: Double { longPressDelay ?? 1.5 }
    }

    private var config = Config()
    private let fileURL: URL
    
    var isOverlayEnabled: Bool {
        get { config.overlayEnabled }
        set { config.isOverlayEnabled = newValue }
    }
    
    var isCheatSheetEnabled: Bool {
        get { config.cheatSheetEnabled }
        set { config.isCheatSheetEnabled = newValue }
    }
    
    var theme: SwitcherTheme {
        get { config.activeTheme }
        set { config.theme = newValue }
    }

    var longPressDelay: Double {
        get { config.delay }
        set { config.longPressDelay = newValue }
    }

    private init() {
        let fileManager = FileManager.default
        let baseDir: URL

        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            baseDir = appSupport.appendingPathComponent("AppCmd", isDirectory: true)
        } else {
            baseDir = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".AppCmd", isDirectory: true)
        }

        if !fileManager.fileExists(atPath: baseDir.path) {
            try? fileManager.createDirectory(at: baseDir, withIntermediateDirectories: true)
        }

        self.fileURL = baseDir.appendingPathComponent("config.json")
        load()
    }

    func assignment(for key: Character) -> AppAssignment? {
        let keyString = String(key)
        return config.assignments.first { $0.key == keyString }
    }

    func setAssignment(_ assignment: AppAssignment, for key: Character) {
        let keyString = String(key)
        if let idx = config.assignments.firstIndex(where: { $0.key == keyString }) {
            config.assignments[idx] = assignment
        } else {
            config.assignments.append(assignment)
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(config)
            try data.write(to: fileURL, options: [.atomic])
            NotificationCenter.default.post(name: ConfigStore.configUpdatedNotification, object: nil)
        } catch {
            print("Failed to save config: \(error)")
        }
    }

    private func load() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(Config.self, from: data)
            self.config = decoded
        } catch {
            print("Failed to load config: \(error)")
        }
    }
    
    func getAllAssignments() -> [AppAssignment] {
        return config.assignments
    }
    
    func removeAssignment(for key: Character) {
        let keyString = String(key)
        config.assignments.removeAll { $0.key == keyString }
    }
}
