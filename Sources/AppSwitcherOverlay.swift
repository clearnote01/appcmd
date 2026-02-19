import AppKit

final class AppSwitcherOverlay {
    private var window: NSWindow?
    private var containerView: NSView?
    private var theme: SwitcherTheme = .comfortable
    private(set) var isVisible = false
    private var hideTimer: DispatchWorkItem?
    
    var onAppSelected: ((NSRunningApplication) -> Void)?
    
    private var currentApps: [NSRunningApplication] = []
    private var currentSelectedIndex: Int = 0
    
    func setTheme(_ theme: SwitcherTheme) {
        self.theme = theme
        if isVisible {
            updateAppearance()
            updateContent(apps: currentApps, selectedIndex: currentSelectedIndex)
        }
    }
    
    func show(apps: [NSRunningApplication], selectedIndex: Int = 0) {
        DispatchQueue.main.async {
            guard !apps.isEmpty else { return }
            self.currentApps = apps
            self.currentSelectedIndex = selectedIndex
            self.hideTimer?.cancel()
            self.hideTimer = nil
            self.ensureWindow()
            let size = self.calculateSize(for: apps.count)
            if let window = self.window, let container = self.containerView {
                let frame = NSRect(x: 0, y: 0, width: size.width, height: size.height)
                window.setContentSize(size)
                container.frame = frame
                self.effectView?.frame = frame
                if let screen = NSScreen.main {
                    let screenFrame = screen.visibleFrame
                    let origin = NSPoint(x: screenFrame.midX - size.width / 2, y: screenFrame.midY + 80)
                    window.setFrameOrigin(origin)
                }
            }
            self.updateContent(apps: apps, selectedIndex: selectedIndex)
            if let window = self.window {
                window.orderFrontRegardless()
                self.isVisible = true
            }
        }
    }
    
    func scheduleHide(after delay: TimeInterval) {
        DispatchQueue.main.async {
            self.hideTimer?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self, self.isVisible else { return }
                self.hide()
            }
            self.hideTimer = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }
    
    func hide() {
        DispatchQueue.main.async {
            self.hideTimer?.cancel()
            self.hideTimer = nil
            self.window?.orderOut(nil)
            self.isVisible = false
        }
    }
    
    private func ensureWindow() {
        if window == nil {
            let style: NSWindow.StyleMask = [.borderless]
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 200), styleMask: style, backing: .buffered, defer: false)
            w.isOpaque = false
            w.backgroundColor = .clear
            w.level = .statusBar
            w.hasShadow = true
            w.collectionBehavior = [.canJoinAllSpaces, .stationary]
            let container = NSView(frame: w.frame)
            container.wantsLayer = true
            w.contentView = container
            self.window = w
            self.containerView = container
            updateAppearance()
        }
    }
    
    private var effectView: NSVisualEffectView?
    
    private func updateAppearance() {
        guard let container = containerView, let layer = container.layer else { return }
        effectView?.removeFromSuperview()
        effectView = nil
        switch theme {
        case .compact:
            layer.backgroundColor = NSColor.controlBackgroundColor.cgColor
            layer.cornerRadius = 8
            layer.shadowOpacity = 0.25
        case .comfortable:
            if #available(macOS 10.14, *) {
                let material: NSVisualEffectView.Material = .hudWindow
                let ev = NSVisualEffectView(frame: container.bounds)
                ev.material = material
                ev.state = .active
                ev.blendingMode = .behindWindow
                ev.autoresizingMask = [.width, .height]
                container.addSubview(ev, positioned: .below, relativeTo: nil)
                effectView = ev
            }
            layer.cornerRadius = 14
            layer.shadowOpacity = 0.4
        }
    }
    
    private func calculateSize(for appCount: Int) -> NSSize {
        let itemHeight: CGFloat = theme == .comfortable ? 60 : 45
        let padding: CGFloat = theme == .comfortable ? 16 : 10
        let spacing: CGFloat = theme == .comfortable ? 8 : 4
        let width: CGFloat = 340
        let totalItemHeight = CGFloat(appCount) * itemHeight
        let totalSpacing = CGFloat(max(0, appCount - 1)) * spacing
        let height = padding * 2 + totalItemHeight + totalSpacing
        return NSSize(width: width, height: max(height, padding * 2 + itemHeight))
    }
    
    private func updateContent(apps: [NSRunningApplication], selectedIndex: Int) {
        guard let container = containerView else { return }
        container.subviews.forEach { if $0 !== effectView { $0.removeFromSuperview() } }
        let itemHeight: CGFloat = theme == .comfortable ? 60 : 45
        let padding: CGFloat = theme == .comfortable ? 16 : 10
        let spacing: CGFloat = theme == .comfortable ? 8 : 4
        var y = container.bounds.height - padding
        for (index, app) in apps.enumerated() {
            let isSelected = index == selectedIndex
            let itemView = createAppItemView(app: app, isSelected: isSelected, index: index, containerWidth: container.bounds.width, itemHeight: itemHeight)
            let itemX: CGFloat = 8
            itemView.frame = NSRect(x: itemX, y: y - itemHeight, width: container.bounds.width - (itemX * 2), height: itemHeight)
            container.addSubview(itemView)
            y -= itemHeight + spacing
        }
    }
    
    private func createAppItemView(app: NSRunningApplication, isSelected: Bool, index: Int, containerWidth: CGFloat, itemHeight: CGFloat) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let iconSize: CGFloat = theme == .comfortable ? 32 : 28
        let iconPadding: CGFloat = theme == .comfortable ? 12 : 10
        if isSelected {
            view.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.25).cgColor
            view.layer?.cornerRadius = 8
        }
        let iconView = NSImageView(frame: NSRect(x: iconPadding, y: (itemHeight - iconSize) / 2, width: iconSize, height: iconSize))
        iconView.image = app.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        view.addSubview(iconView)
        let nameLabel = NSTextField(labelWithString: app.localizedName ?? "Unknown")
        nameLabel.font = NSFont.systemFont(ofSize: theme == .comfortable ? 15 : 13, weight: isSelected ? .bold : .medium)
        nameLabel.textColor = theme == .comfortable ? .white : .labelColor
        nameLabel.alignment = .left
        let nameX = iconSize + iconPadding + 12
        let nameWidth = containerWidth - nameX - 12
        nameLabel.frame = NSRect(x: nameX, y: (itemHeight - 18) / 2, width: nameWidth, height: 18)
        view.addSubview(nameLabel)
        return view
    }

    func showCheatSheet(assignments: [AppAssignment]) {
        DispatchQueue.main.async {
            guard !assignments.isEmpty else { return }
            self.hideTimer?.cancel()
            self.hideTimer = nil
            self.ensureWindow()
            let columns = 2
            let rows = Int(ceil(Double(assignments.count) / Double(columns)))
            let itemHeight: CGFloat = 40
            let itemWidth: CGFloat = 200
            let padding: CGFloat = 20
            let totalWidth = (itemWidth * CGFloat(columns)) + (padding * 3)
            let totalHeight = (itemHeight * CGFloat(rows)) + (padding * 3) + 40
            let size = NSSize(width: totalWidth, height: totalHeight)
            if let window = self.window, let container = self.containerView {
                window.setContentSize(size)
                container.frame = NSRect(origin: .zero, size: size)
                self.effectView?.frame = container.bounds
                if let screen = NSScreen.main {
                    let frame = screen.visibleFrame
                    window.setFrameOrigin(NSPoint(
                        x: frame.midX - size.width / 2,
                        y: frame.midY - size.height / 2
                    ))
                }
                container.subviews.forEach { if $0 !== self.effectView { $0.removeFromSuperview() } }
                let header = NSTextField(labelWithString: "AppCmd Cheat Sheet")
                header.font = NSFont.systemFont(ofSize: 16, weight: .bold)
                header.textColor = self.theme == .comfortable ? .white : .labelColor
                header.frame = NSRect(x: padding, y: totalHeight - padding - 25, width: totalWidth - (padding * 2), height: 25)
                header.alignment = .center
                container.addSubview(header)
                var currentY = totalHeight - padding - 45
                for (index, assignment) in assignments.enumerated() {
                    let col = index % columns
                    let x = padding + (CGFloat(col) * (itemWidth + padding))
                    let rowView = NSView(frame: NSRect(x: x, y: currentY - itemHeight, width: itemWidth, height: itemHeight))
                    let keyLabel = NSTextField(labelWithString: assignment.key.uppercased())
                    keyLabel.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)
                    keyLabel.textColor = NSColor.controlAccentColor
                    keyLabel.frame = NSRect(x: 0, y: (itemHeight - 20) / 2, width: 30, height: 20)
                    rowView.addSubview(keyLabel)
                    let appName = self.getAppName(for: assignment.bundleIdentifier) ?? assignment.bundleIdentifier
                    let nameLabel = NSTextField(labelWithString: appName)
                    nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
                    nameLabel.textColor = self.theme == .comfortable ? .white : .labelColor
                    nameLabel.frame = NSRect(x: 35, y: (itemHeight - 18) / 2, width: itemWidth - 35, height: 18)
                    nameLabel.lineBreakMode = .byTruncatingTail
                    rowView.addSubview(nameLabel)
                    container.addSubview(rowView)
                    if col == columns - 1 { currentY -= itemHeight }
                }
                window.orderFrontRegardless()
                self.isVisible = true
            }
        }
    }
    
    private func getAppName(for bundleIdentifier: String) -> String? {
        let workspace = NSWorkspace.shared
        if let app = workspace.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) { return app.localizedName }
        if let url = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier), let bundle = Bundle(url: url) {
            return bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String ?? bundle.infoDictionary?["CFBundleDisplayName"] as? String ?? url.lastPathComponent.replacingOccurrences(of: ".app", with: "")
        }
        return nil
    }
}
