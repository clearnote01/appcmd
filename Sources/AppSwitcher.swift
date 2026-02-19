import Foundation
import AppKit

enum WhenFocusedAction: String, Codable {
    case hide
    case cycle
}

struct AppAssignment: Codable {
    var key: String
    var bundleIdentifier: String
    var bundlePath: String?
    var whenFocusedAction: WhenFocusedAction
}

final class AppSwitcher {
    private let workspace = NSWorkspace.shared
    private let configStore = ConfigStore.shared
    private let hud = HUDWindowController()
    private let overlay = AppSwitcherOverlay()
    private var currentApps: [NSRunningApplication] = []
    private var currentSelectedIndex = 0
    
    init() {
        overlay.setTheme(configStore.theme)
    }
    
    func setTheme(_ theme: SwitcherTheme) {
        configStore.theme = theme
        overlay.setTheme(theme)
        configStore.save()
    }
    
    func setOverlayEnabled(_ enabled: Bool) {
        configStore.isOverlayEnabled = enabled
        configStore.save()
    }
    
    func setCheatSheetEnabled(_ enabled: Bool) {
        configStore.isCheatSheetEnabled = enabled
        configStore.save()
    }

    func handleLongPress() {
        guard configStore.isCheatSheetEnabled else { return }
        overlay.showCheatSheet(assignments: configStore.getAllAssignments())
    }

    func handleSwitchKey(letter: Character) {
        let lower = Character(letter.lowercased())
        let associatedApps = apps(for: lower)
        let showUI = configStore.isOverlayEnabled

        if let assignment = configStore.assignment(for: lower) {
            handleStaticAssignment(letter: lower, assignment: assignment, apps: associatedApps, showUI: showUI)
        } else {
            cycleDynamic(letter: lower, apps: associatedApps, showUI: showUI)
        }
    }
    
    private func apps(for letter: Character) -> [NSRunningApplication] {
        let lower = Character(letter.lowercased())
        var results = workspace.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter {
                guard let name = $0.localizedName?.lowercased(), let first = name.first else {
                    return false
                }
                return first == lower
            }
        
        // Ensure the assigned app is included if it's running, even if its name doesn't match the letter
        if let assignment = configStore.assignment(for: lower),
           let assignedApp = workspace.runningApplications.first(where: { $0.bundleIdentifier == assignment.bundleIdentifier }) {
            if !results.contains(assignedApp) {
                results.append(assignedApp)
            }
        }
        
        return results.sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    func handleKeyRelease() {
        // Hide overlay when Right Command is released
        overlay.hide()
    }
    
    func updateOverlaySelection(offset: Int) {
        guard !currentApps.isEmpty else { return }
        currentSelectedIndex = (currentSelectedIndex + offset + currentApps.count) % currentApps.count
        overlay.show(apps: currentApps, selectedIndex: currentSelectedIndex)
        // Reset the hide timer when cycling
        overlay.scheduleHide(after: 8.0)
        // Activate the newly selected app
        if currentSelectedIndex < currentApps.count {
            activate(app: currentApps[currentSelectedIndex])
        }
    }
    
    func hideOverlay() {
        overlay.hide()
        currentApps = []
        currentSelectedIndex = 0
    }

    func handleAssignKey(letter: Character) {
        let lower = Character(letter.lowercased())

        guard let frontmost = workspace.frontmostApplication,
              let bundleIdentifier = frontmost.bundleIdentifier
        else { return }

        let assignment = AppAssignment(
            key: String(lower),
            bundleIdentifier: bundleIdentifier,
            bundlePath: frontmost.bundleURL?.path,
            whenFocusedAction: .cycle
        )

        configStore.setAssignment(assignment, for: lower)
        configStore.save()

        let name = frontmost.localizedName ?? bundleIdentifier
        hud.show(message: "Assigned '\(lower)' to \(name)")
    }

    private func handleStaticAssignment(letter: Character, assignment: AppAssignment, apps: [NSRunningApplication], showUI: Bool = false) {
        let matchingRunning = workspace.runningApplications.first { $0.bundleIdentifier == assignment.bundleIdentifier }
        let frontmost = workspace.frontmostApplication

        // If UI is enabled and we have multiple apps, show overlay
        if showUI && apps.count > 1 {
            currentApps = apps
            
            if let app = matchingRunning {
                if let front = frontmost, front == app {
                    // App is already focused
                    switch assignment.whenFocusedAction {
                    case .hide:
                        app.hide()
                        // Still show overlay with other apps
                        if let assignedIndex = apps.firstIndex(of: app) {
                            currentSelectedIndex = (assignedIndex + 1) % apps.count
                        } else {
                            currentSelectedIndex = 0
                        }
                        overlay.show(apps: apps, selectedIndex: currentSelectedIndex)
                        if currentSelectedIndex < apps.count {
                            activate(app: apps[currentSelectedIndex])
                        }
                        overlay.scheduleHide(after: 8.0)
                    case .cycle:
                        // Cycle to next app
                        if let assignedIndex = apps.firstIndex(of: app) {
                            currentSelectedIndex = (assignedIndex + 1) % apps.count
                        } else {
                            currentSelectedIndex = 0
                        }
                        let target = apps[currentSelectedIndex]
                        overlay.show(apps: apps, selectedIndex: currentSelectedIndex)
                        activate(app: target)
                        overlay.scheduleHide(after: 8.0)
                    }
                } else {
                    // App is running but not focused - activate it and show overlay
                    if let assignedIndex = apps.firstIndex(of: app) {
                        currentSelectedIndex = assignedIndex
                    } else {
                        currentSelectedIndex = 0
                    }
                    overlay.show(apps: apps, selectedIndex: currentSelectedIndex)
                    activate(app: app)
                    overlay.scheduleHide(after: 8.0)
                }
            } else {
                // Assigned app not running - launch it and show overlay
                launch(assignment: assignment)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // Refresh the list after launch
                    let updatedApps = self.apps(for: letter)
                    
                    if let launchedApp = self.workspace.runningApplications.first(where: { $0.bundleIdentifier == assignment.bundleIdentifier }),
                       let index = updatedApps.firstIndex(of: launchedApp) {
                        self.currentApps = updatedApps
                        self.currentSelectedIndex = index
                        self.overlay.show(apps: updatedApps, selectedIndex: index)
                        self.overlay.scheduleHide(after: 8.0)
                    }
                }
            }
            return
        }

        // Fallback to HUD if UI enabled but ONLY IF overlay is not shown
        if let app = matchingRunning {
            if let front = frontmost, front == app {
                switch assignment.whenFocusedAction {
                case .hide:
                    app.hide()
                case .cycle:
                    cycleDynamic(letter: letter, apps: apps, showUI: showUI)
                }
            } else {
                activate(app: app)
                // Only show HUD if multi-app overlay is NOT active
                if showUI {
                    let name = app.localizedName ?? assignment.bundleIdentifier
                    hud.show(message: name, appIcon: app.icon)
                }
            }
        } else {
            launch(assignment: assignment)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Only show HUD if multi-app overlay is NOT active
                if showUI,
                   let appURL = self.getAppURL(for: assignment),
                   let app = self.workspace.runningApplications.first(where: { $0.bundleURL == appURL }) {
                    let name = app.localizedName ?? assignment.bundleIdentifier
                    self.hud.show(message: name, appIcon: app.icon)
                }
            }
        }
    }
    
    private func getAppURL(for assignment: AppAssignment) -> URL? {
        if let path = assignment.bundlePath {
            return URL(fileURLWithPath: path)
        } else if let bundleID = assignment.bundleIdentifier as String?,
                  let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) {
            return appURL
        }
        return nil
    }

    private func cycleDynamic(letter: Character, apps: [NSRunningApplication], showUI: Bool = false) {
        guard !apps.isEmpty else { return }
        
        currentApps = apps
        let frontmost = workspace.frontmostApplication

        let target: NSRunningApplication
        if let front = frontmost, let idx = apps.firstIndex(of: front) {
            currentSelectedIndex = (idx + 1) % apps.count
            target = apps[currentSelectedIndex]
        } else {
            currentSelectedIndex = 0
            target = apps[0]
        }

        if showUI && apps.count > 1 {
            overlay.show(apps: apps, selectedIndex: currentSelectedIndex)
            activate(app: target)
            overlay.scheduleHide(after: 8.0)
        } else {
            activate(app: target)
            // Show HUD only if we are NOT showing the multi-app overlay
            if showUI {
                let name = target.localizedName ?? "App"
                hud.show(message: name, appIcon: target.icon)
            }
        }
    }


    private func activate(app: NSRunningApplication) {
        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }

    private func launch(assignment: AppAssignment) {
        let url: URL?

        if let path = assignment.bundlePath {
            url = URL(fileURLWithPath: path)
        } else if let bundleID = assignment.bundleIdentifier as String?,
                  let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) {
            url = appURL
        } else {
            url = nil
        }

        guard let appURL = url else {
            print("Cannot locate app for bundle id \(assignment.bundleIdentifier)")
            return
        }

        do {
            try workspace.launchApplication(
                at: appURL,
                options: [.default],
                configuration: [:]
            )
        } catch {
            print("Failed to launch app at \(appURL.path): \(error)")
        }
    }
}

