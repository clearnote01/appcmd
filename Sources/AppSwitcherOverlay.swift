import AppKit

enum SwitcherTheme: String, Codable {
    case clean
    case compact
    case comfortable
}

final class AppSwitcherOverlay {
    private var window: NSWindow?
    private var containerView: NSView?
    private var theme: SwitcherTheme = .comfortable
    private var isVisible = false
    private var hideTimer: DispatchWorkItem?
    
    var onAppSelected: ((NSRunningApplication) -> Void)?
    
    private var currentApps: [NSRunningApplication] = []
    private var currentSelectedIndex: Int = 0
    
    func setTheme(_ theme: SwitcherTheme) {
        self.theme = theme
        if isVisible {
            updateAppearance()
            // Re-render content with new theme
            updateContent(apps: currentApps, selectedIndex: currentSelectedIndex)
        }
    }
    
    func show(apps: [NSRunningApplication], selectedIndex: Int = 0) {
        DispatchQueue.main.async {
            guard !apps.isEmpty else { return }
            
            // Store current apps and selection for theme updates
            self.currentApps = apps
            self.currentSelectedIndex = selectedIndex
            
            // Cancel any existing hide timer
            self.hideTimer?.cancel()
            self.hideTimer = nil
            
            self.ensureWindow()
            let size = self.calculateSize(for: apps.count)
            
            // Update window and container size first
            if let window = self.window, let container = self.containerView {
                let frame = NSRect(x: 0, y: 0, width: size.width, height: size.height)
                window.setContentSize(size)
                container.frame = frame
                
                // Update effect view size if it exists
                self.effectView?.frame = frame
                
                // Position window centered on screen
                if let screen = NSScreen.main {
                    let screenFrame = screen.visibleFrame
                    let origin = NSPoint(
                        x: screenFrame.midX - size.width / 2,
                        y: screenFrame.midY + 80 // Position above center
                    )
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
            // Cancel any existing timer
            self.hideTimer?.cancel()
            
            // Create new timer
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
            // Cancel any pending timer
            self.hideTimer?.cancel()
            self.hideTimer = nil
            
            self.window?.orderOut(nil)
            self.isVisible = false
        }
    }
    
    private func ensureWindow() {
        if window == nil {
            let style: NSWindow.StyleMask = [.borderless]
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
                styleMask: style,
                backing: .buffered,
                defer: false
            )
            w.isOpaque = false
            w.backgroundColor = .clear
            w.level = .statusBar
            w.hasShadow = true
            w.ignoresMouseEvents = false
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
        
        // Remove existing effect view if any
        effectView?.removeFromSuperview()
        effectView = nil
        
        switch theme {
        case .clean:
            layer.backgroundColor = NSColor.windowBackgroundColor.cgColor
            layer.cornerRadius = 10
            layer.shadowOpacity = 0.3
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
        let itemHeight: CGFloat = theme == .comfortable ? 60 : (theme == .compact ? 45 : 50)
        let padding: CGFloat = theme == .comfortable ? 16 : (theme == .compact ? 10 : 12)
        let spacing: CGFloat = theme == .comfortable ? 8 : (theme == .compact ? 4 : 6)
        let width: CGFloat = 340
        let totalItemHeight = CGFloat(appCount) * itemHeight
        let totalSpacing = CGFloat(max(0, appCount - 1)) * spacing
        let height = padding * 2 + totalItemHeight + totalSpacing
        // Ensure minimum height for single app
        let minHeight = padding * 2 + itemHeight
        return NSSize(width: width, height: max(height, minHeight))
    }
    
    private func updateContent(apps: [NSRunningApplication], selectedIndex: Int) {
        guard let container = containerView else { return }
        
        currentApps = apps
        currentSelectedIndex = selectedIndex
        
        // Remove existing subviews except effect view
        container.subviews.forEach { view in
            if view !== effectView {
                view.removeFromSuperview()
            }
        }
        
        let itemHeight: CGFloat = theme == .comfortable ? 60 : (theme == .compact ? 45 : 50)
        let padding: CGFloat = theme == .comfortable ? 16 : (theme == .compact ? 10 : 12)
        let spacing: CGFloat = theme == .comfortable ? 8 : (theme == .compact ? 4 : 6)
        
        var y = container.bounds.height - padding
        
        for (index, app) in apps.enumerated() {
            let isSelected = index == selectedIndex
            let itemView = createAppItemView(app: app, isSelected: isSelected, index: index, containerWidth: container.bounds.width, itemHeight: itemHeight)
            // Center the items horizontally within the container, account for padding
            let itemX: CGFloat = 8
            itemView.frame = NSRect(x: itemX, y: y - itemHeight, width: container.bounds.width - (itemX * 2), height: itemHeight)
            container.addSubview(itemView)
            y -= itemHeight + spacing
        }
    }
    
    private func createAppItemView(app: NSRunningApplication, isSelected: Bool, index: Int, containerWidth: CGFloat, itemHeight: CGFloat) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        
        let iconSize: CGFloat = theme == .comfortable ? 32 : (theme == .compact ? 28 : 30)
        let iconPadding: CGFloat = theme == .comfortable ? 12 : 10
        
        // Selection indicator - subtle but clear
        if isSelected {
            view.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.25).cgColor
            view.layer?.cornerRadius = 8
        }
        
        // Icon
        let iconView = NSImageView(frame: NSRect(x: iconPadding, y: (itemHeight - iconSize) / 2, width: iconSize, height: iconSize))
        iconView.image = app.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        view.addSubview(iconView)
        
        // App name
        let nameLabel = NSTextField(labelWithString: app.localizedName ?? "Unknown")
        nameLabel.font = NSFont.systemFont(ofSize: theme == .comfortable ? 15 : (theme == .compact ? 13 : 14), weight: isSelected ? .bold : .medium)
        
        // Legibility fix: Use adaptive colors
        if theme == .comfortable {
            // HUD material is usually dark, force white for better contrast
            nameLabel.textColor = .white
        } else {
            nameLabel.textColor = .labelColor
        }
        
        nameLabel.alignment = .left
        let nameX = iconSize + iconPadding + 12
        let nameWidth = containerWidth - nameX - 12
        nameLabel.frame = NSRect(x: nameX, y: (itemHeight - 18) / 2, width: nameWidth, height: 18)
        view.addSubview(nameLabel)
        
        return view
    }
}
