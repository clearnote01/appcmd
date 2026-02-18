import AppKit

final class HUDWindowController {
    private var window: NSWindow?
    private var label: NSTextField?
    private var iconView: NSImageView?
    private var hideWorkItem: DispatchWorkItem?
    private var effectView: NSVisualEffectView?

    // Toggle this to enable/disable visual feedback.
    var isEnabled: Bool = true

    func show(message: String, appIcon: NSImage? = nil) {
        guard isEnabled else { return }

        DispatchQueue.main.async {
            self.ensureWindow()
            self.label?.stringValue = message
            
            // Update icon if provided
            if let icon = appIcon, let iconView = self.iconView, let label = self.label {
                iconView.image = icon
                iconView.isHidden = false
                // Reposition label when icon is shown
                label.frame = NSRect(x: 80, y: 30, width: 220, height: 30)
            } else if let iconView = self.iconView, let label = self.label {
                iconView.isHidden = true
                // Center label when no icon
                label.frame = NSRect(x: 20, y: 30, width: 280, height: 30)
            }

            if let screen = NSScreen.main, let window = self.window {
                let frame = screen.visibleFrame
                let hasIcon = appIcon != nil
                let size = NSSize(width: hasIcon ? 320 : 280, height: 90)
                let origin = NSPoint(
                    x: frame.midX - size.width / 2,
                    y: frame.midY - size.height / 2
                )
                window.setContentSize(size)
                window.setFrameOrigin(origin)
                window.orderFrontRegardless()
            }

            self.scheduleHide()
        }
    }

    private func ensureWindow() {
        if window == nil {
            let style: NSWindow.StyleMask = [.borderless]
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 90),
                styleMask: style,
                backing: .buffered,
                defer: false
            )
            w.isOpaque = false
            w.backgroundColor = .clear
            w.level = .statusBar
            w.hasShadow = true
            w.ignoresMouseEvents = true

            let content = NSView(frame: w.frame)
            content.wantsLayer = true
            
            // Add visual effect background
            if #available(macOS 10.14, *) {
                let ev = NSVisualEffectView(frame: content.bounds)
                ev.material = .hudWindow
                ev.state = .active
                ev.blendingMode = .behindWindow
                ev.autoresizingMask = [.width, .height]
                content.addSubview(ev, positioned: .below, relativeTo: nil)
                effectView = ev
            }
            
            content.layer?.cornerRadius = 12
            content.layer?.shadowOpacity = 0.4
            
            // App icon
            let icon = NSImageView(frame: NSRect(x: 20, y: 20, width: 50, height: 50))
            icon.imageScaling = .scaleProportionallyUpOrDown
            icon.isHidden = true
            content.addSubview(icon)
            self.iconView = icon

            // Text label - will be repositioned based on icon presence
            let text = NSTextField(labelWithString: "")
            text.alignment = .center
            text.textColor = .labelColor
            text.font = NSFont.systemFont(ofSize: 17, weight: .semibold)
            text.frame = NSRect(x: 20, y: 30, width: 280, height: 30)
            text.autoresizingMask = [.width]
            content.addSubview(text)

            w.contentView = content
            self.window = w
            self.label = text
        }
    }

    private func scheduleHide() {
        hideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.window?.orderOut(nil)
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }
}

