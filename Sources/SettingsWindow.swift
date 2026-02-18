import AppKit

final class SettingsWindowController: NSWindowController {
    private let configStore = ConfigStore.shared
    private var appSwitcher: AppSwitcher?
    
    convenience init(appSwitcher: AppSwitcher) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AppCmd Settings"
        window.center()
        
        self.init(window: window)
        self.appSwitcher = appSwitcher
        setupContent()
        
        NotificationCenter.default.addObserver(self, selector: #selector(refreshContent), name: ConfigStore.configUpdatedNotification, object: nil)
    }
    
    @objc private func refreshContent() {
        DispatchQueue.main.async {
            self.setupContent()
        }
    }
    
    private func setupContent() {
        guard let window = window else { return }
        
        let contentView = NSView(frame: window.contentView!.bounds)
        
        var y: CGFloat = contentView.bounds.height - 40
        
        // Theme selection
        let themeLabel = NSTextField(labelWithString: "Switcher Theme:")
        themeLabel.frame = NSRect(x: 20, y: y, width: 150, height: 20)
        contentView.addSubview(themeLabel)
        
        let themeSegmented = NSSegmentedControl(labels: ["Clean", "Compact", "Comfortable"], trackingMode: .selectOne, target: self, action: #selector(themeChanged(_:)))
        themeSegmented.frame = NSRect(x: 180, y: y, width: 340, height: 25)
        
        let themeIndex: Int
        switch configStore.theme {
        case .clean: themeIndex = 0
        case .compact: themeIndex = 1
        case .comfortable: themeIndex = 2
        }
        themeSegmented.selectedSegment = themeIndex
        contentView.addSubview(themeSegmented)
        
        y -= 45
        
        // UI toggles
        let overlayLabel = NSTextField(labelWithString: "Visual Feedback:")
        overlayLabel.frame = NSRect(x: 20, y: y, width: 150, height: 20)
        contentView.addSubview(overlayLabel)
        
        let overlayToggle = NSButton(checkboxWithTitle: "Show App Switcher Overlay", target: self, action: #selector(overlayToggled(_:)))
        overlayToggle.frame = NSRect(x: 180, y: y, width: 200, height: 20)
        overlayToggle.state = configStore.isOverlayEnabled ? .on : .off
        contentView.addSubview(overlayToggle)
        
        y -= 25
        
        let cheatSheetToggle = NSButton(checkboxWithTitle: "Enable Long-Press Cheat Sheet", target: self, action: #selector(cheatSheetToggled(_:)))
        cheatSheetToggle.frame = NSRect(x: 180, y: y, width: 250, height: 20)
        cheatSheetToggle.state = configStore.isCheatSheetEnabled ? .on : .off
        contentView.addSubview(cheatSheetToggle)
        
        y -= 45
        
        // Assignments section
        let assignmentsLabel = NSTextField(labelWithString: "Key Assignments:")
        assignmentsLabel.font = NSFont.boldSystemFont(ofSize: 14)
        assignmentsLabel.frame = NSRect(x: 20, y: y, width: 200, height: 20)
        contentView.addSubview(assignmentsLabel)
        
        y -= 25
        
        // Concise Instruction below header
        let helpLabel = NSTextField(labelWithString: "Assign: Focus App + Right ⌘ + Option + [Letter]")
        helpLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        helpLabel.textColor = .secondaryLabelColor
        helpLabel.frame = NSRect(x: 20, y: y, width: 500, height: 18)
        contentView.addSubview(helpLabel)
        
        y -= 30
        
        // Footer (Created with love) - Positioned at the very bottom
        let version = AppVersion.current
        let footerLabel = NSTextField(labelWithString: "v\(version) • Created with love by Utkarsh Raj")
        footerLabel.font = NSFont.systemFont(ofSize: 10, weight: .light)
        footerLabel.textColor = .tertiaryLabelColor
        footerLabel.alignment = .center
        footerLabel.frame = NSRect(x: 0, y: 10, width: contentView.bounds.width, height: 15)
        contentView.addSubview(footerLabel)
        
        // List assignments
        let assignments = configStore.getAllAssignments()
        
        if assignments.isEmpty {
            let noAssignmentsLabel = NSTextField(labelWithString: "No keys assigned.")
            noAssignmentsLabel.frame = NSRect(x: 20, y: y, width: 540, height: 20)
            noAssignmentsLabel.textColor = .tertiaryLabelColor
            contentView.addSubview(noAssignmentsLabel)
        } else {
            let listHeight = CGFloat(assignments.count) * 32
            // Adjusted height to make room for footer (y - 35 instead of y - 10)
            let listScrollView = NSScrollView(frame: NSRect(x: 10, y: 35, width: 540, height: y - 35))
            listScrollView.hasVerticalScroller = true
            listScrollView.drawsBackground = false
            
            let listView = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: max(listScrollView.bounds.height, listHeight)))
            var rowY = listView.bounds.height - 25
            
            for assignment in assignments {
                let keyLabel = NSTextField(labelWithString: "⌘ + \(assignment.key.uppercased()):")
                keyLabel.frame = NSRect(x: 10, y: rowY, width: 80, height: 20)
                listView.addSubview(keyLabel)
                
                let appName = getAppName(for: assignment.bundleIdentifier) ?? assignment.bundleIdentifier
                let appLabel = NSTextField(labelWithString: appName)
                appLabel.frame = NSRect(x: 100, y: rowY, width: 180, height: 20)
                appLabel.lineBreakMode = .byTruncatingTail
                listView.addSubview(appLabel)
                
                let actionPopup = NSPopUpButton(frame: NSRect(x: 290, y: rowY - 2, width: 80, height: 22))
                actionPopup.addItem(withTitle: "Hide")
                actionPopup.addItem(withTitle: "Cycle")
                actionPopup.selectItem(at: assignment.whenFocusedAction == .hide ? 0 : 1)
                actionPopup.target = self
                actionPopup.action = #selector(actionChanged(_:))
                actionPopup.identifier = NSUserInterfaceItemIdentifier("\(assignment.key)_action")
                listView.addSubview(actionPopup)
                
                let removeButton = NSButton(title: "Remove", target: self, action: #selector(removeAssignment(_:)))
                removeButton.bezelStyle = .rounded
                removeButton.frame = NSRect(x: 380, y: rowY - 2, width: 80, height: 24)
                removeButton.identifier = NSUserInterfaceItemIdentifier(assignment.key)
                listView.addSubview(removeButton)
                
                rowY -= 32
            }
            
            listScrollView.documentView = listView
            contentView.addSubview(listScrollView)
        }
        
        window.contentView = contentView
    }
    
    @objc private func themeChanged(_ sender: NSSegmentedControl) {
        let themes: [SwitcherTheme] = [.clean, .compact, .comfortable]
        if sender.selectedSegment < themes.count {
            appSwitcher?.setTheme(themes[sender.selectedSegment])
        }
    }
    
    @objc private func overlayToggled(_ sender: NSButton) {
        appSwitcher?.setOverlayEnabled(sender.state == .on)
    }
    
    @objc private func cheatSheetToggled(_ sender: NSButton) {
        appSwitcher?.setCheatSheetEnabled(sender.state == .on)
    }
    
    @objc private func actionChanged(_ sender: NSPopUpButton) {
        guard let identifier = sender.identifier?.rawValue,
              let keyString = identifier.components(separatedBy: "_").first,
              let key = keyString.first,
              let assignment = configStore.assignment(for: key) else { return }
        
        let newAction: WhenFocusedAction = sender.indexOfSelectedItem == 0 ? .hide : .cycle
        var updatedAssignment = assignment
        updatedAssignment.whenFocusedAction = newAction
        configStore.setAssignment(updatedAssignment, for: key)
        configStore.save()
    }
    
    @objc private func removeAssignment(_ sender: NSButton) {
        guard let keyString = sender.identifier?.rawValue,
              let key = keyString.first else { return }
        configStore.removeAssignment(for: key)
        configStore.save()
        setupContent() // Refresh
    }
    
    private func getAppName(for bundleIdentifier: String) -> String? {
        let workspace = NSWorkspace.shared
        if let app = workspace.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            return app.localizedName
        }
        
        if let url = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier),
           let bundle = Bundle(url: url) {
            return bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String
                ?? bundle.infoDictionary?["CFBundleDisplayName"] as? String
                ?? bundle.localizedInfoDictionary?["CFBundleName"] as? String
                ?? bundle.infoDictionary?["CFBundleName"] as? String
                ?? url.lastPathComponent.replacingOccurrences(of: ".app", with: "")
        }
        
        return nil
    }
}
