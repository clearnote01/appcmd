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
    private let overlay = AppSwitcherOverlay()
    private var currentApps: [NSRunningApplication] = []
    private var currentSelectedIndex = 0
    private var currentLetter: Character?
    
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

        // If we are already holding Right Command and pressing the SAME letter,
        // we should ALWAYS just cycle forward.
        if lower == currentLetter && !currentApps.isEmpty {
            cycleForward(showUI: showUI)
            return
        }

        // New interaction (different letter or first press)
        currentLetter = lower
        currentApps = associatedApps

        if let assignment = configStore.assignment(for: lower) {
            handleStaticAssignment(letter: lower, assignment: assignment, apps: associatedApps, showUI: showUI)
        } else {
            // No assignment, just start cycling
            currentSelectedIndex = -1 // Let cycleDynamic find the start
            cycleForward(showUI: showUI)
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
        
        if let assignment = configStore.assignment(for: lower),
           let assignedApp = workspace.runningApplications.first(where: { $0.bundleIdentifier == assignment.bundleIdentifier }) {
            if !results.contains(assignedApp) {
                results.append(assignedApp)
            }
        }
        
        return results.sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    func handleKeyRelease() {
        overlay.hide()
        currentLetter = nil
    }
    
    func updateOverlaySelection(offset: Int) {
        guard !currentApps.isEmpty else { return }
        currentSelectedIndex = (currentSelectedIndex + offset + currentApps.count) % currentApps.count
        overlay.show(apps: currentApps, selectedIndex: currentSelectedIndex)
        overlay.scheduleHide(after: 8.0)
        if currentSelectedIndex < currentApps.count {
            activate(app: currentApps[currentSelectedIndex])
        }
    }
    
    func hideOverlay() {
        overlay.hide()
        currentApps = []
        currentSelectedIndex = 0
        currentLetter = nil
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

        if configStore.isOverlayEnabled {
            overlay.show(apps: [frontmost], selectedIndex: 0)
            overlay.scheduleHide(after: 2.0)
        }
    }

    private func handleStaticAssignment(letter: Character, assignment: AppAssignment, apps: [NSRunningApplication], showUI: Bool = false) {
        let matchingRunning = workspace.runningApplications.first { $0.bundleIdentifier == assignment.bundleIdentifier }
        let frontmost = workspace.frontmostApplication

        if let app = matchingRunning {
            if let front = frontmost, front == app {
                // Already on assigned app, cycle forward
                cycleForward(showUI: showUI)
                return
            } else {
                // Not on assigned app, jump to it
                activate(app: app)
                if let index = apps.firstIndex(of: app) {
                    currentSelectedIndex = index
                }
                if showUI {
                    overlay.show(apps: apps, selectedIndex: currentSelectedIndex)
                    overlay.scheduleHide(after: apps.count > 1 ? 8.0 : 2.0)
                }
            }
        } else {
            // Assigned app not running - launch it
            launch(assignment: assignment)
            if showUI {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if let appURL = self.getAppURL(for: assignment),
                       let app = self.workspace.runningApplications.first(where: { $0.bundleURL == appURL }) {
                        self.overlay.show(apps: [app], selectedIndex: 0)
                        self.overlay.scheduleHide(after: 2.0)
                    }
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

    private func cycleForward(showUI: Bool = false) {
        let apps = currentApps
        guard !apps.isEmpty else { return }
        
        let frontmost = workspace.frontmostApplication
        
        // If we have a valid index and the frontmost is what we expect, just increment.
        // Otherwise, find where we are based on the frontmost app.
        if currentSelectedIndex >= 0 && currentSelectedIndex < apps.count && apps[currentSelectedIndex] == frontmost {
            currentSelectedIndex = (currentSelectedIndex + 1) % apps.count
        } else if let front = frontmost, let idx = apps.firstIndex(of: front) {
            currentSelectedIndex = (idx + 1) % apps.count
        } else {
            currentSelectedIndex = 0
        }

        let target = apps[currentSelectedIndex]
        activate(app: target)
        
        if showUI {
            overlay.show(apps: apps, selectedIndex: currentSelectedIndex)
            overlay.scheduleHide(after: 8.0)
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

        guard let appURL = url else { return }

        let configuration = NSWorkspace.OpenConfiguration()
        workspace.openApplication(at: appURL, configuration: configuration) { _, _ in }
    }
}
