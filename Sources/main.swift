import AppKit

// Ensure only one instance is running
let runningApps = NSWorkspace.shared.runningApplications
let otherInstances = runningApps.filter { 
    $0.bundleIdentifier == Bundle.main.bundleIdentifier && $0 != NSRunningApplication.current 
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
    
    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

