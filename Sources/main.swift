import AppKit

// Ensure only one instance is running - be aggressive about checking old names too
let runningApps = NSWorkspace.shared.runningApplications
let otherInstances = runningApps.filter { 
    let bundleID = $0.bundleIdentifier ?? ""
    let name = $0.localizedName ?? ""
    let isSameApp = bundleID == "com.clearnote01.appcmd" || name == "appcmd"
    return isSameApp && $0 != NSRunningApplication.current 
}

for instance in otherInstances {
    instance.terminate()
}

// Give a tiny moment for the other instance to quit
if !otherInstances.isEmpty {
    Thread.sleep(forTimeInterval: 0.2)
}

private let app = NSApplication.shared
private let delegate = AppDelegate()

app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appSwitcher = AppSwitcher()
    private let hotkeyManager = HotkeyManager()
    private var statusItem: NSStatusItem!
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                button.image = NSImage(systemSymbolName: "command", accessibilityDescription: "AppCmd")
            } else {
                button.title = "⌘"
            }
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettings), keyEquivalent: ","))
        menu.items.last?.target = self
        menu.addItem(NSMenuItem(title: "Restart", action: #selector(restart), keyEquivalent: "r"))
        menu.items.last?.target = self
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit AppCmd", action: #selector(quit), keyEquivalent: "q"))
        menu.items.last?.target = self
        statusItem.menu = menu

        // Wire hotkeys to the core app switcher.
        hotkeyManager.onSwitchKey = { [weak self] letter in
            self?.appSwitcher.handleSwitchKey(letter: letter)
        }

        hotkeyManager.onAssignKey = { [weak self] letter in
            self?.appSwitcher.handleAssignKey(letter: letter)
        }
        
        hotkeyManager.onLongPress = { [weak self] in
            self?.appSwitcher.handleLongPress()
        }
        
        hotkeyManager.onKeyRelease = { [weak self] in
            self?.appSwitcher.handleKeyRelease()
        }

        hotkeyManager.start()
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(appSwitcher: appSwitcher)
        }
        settingsWindow?.showWindow(nil)
        settingsWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func restart() {
        let url = URL(fileURLWithPath: Bundle.main.bundlePath)
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }
    
    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

