import Foundation
import AppKit

final class HotkeyManager {
    var onSwitchKey: ((Character) -> Void)?
    var onAssignKey: ((Character) -> Void)?
    var onKeyRelease: (() -> Void)?

    private var eventTap: CFMachPort?
    private var wasRightCommandPressed = false
    private let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

    func start() {
        guard eventTap == nil else { return }

        let callback: CGEventTapCallBack = { proxy, type, cgEvent, refcon in
            guard let refcon = refcon else {
                return Unmanaged.passRetained(cgEvent)
            }

            let unmanagedSelf = Unmanaged<HotkeyManager>.fromOpaque(refcon)
            let hotkeyManager = unmanagedSelf.takeUnretainedValue()

            guard let nsEvent = NSEvent(cgEvent: cgEvent) else {
                return Unmanaged.passRetained(cgEvent)
            }

            let flags = nsEvent.modifierFlags
            
            // Check for Right Command specifically, NOT Left Command.
            // NX_DEVICE_LCMD_KEYMASK = 0x08 (left command)
            // NX_DEVICE_RCMD_KEYMASK = 0x10 (right command)
            let cgFlags = cgEvent.flags.rawValue
            let hasRightCommand = (cgFlags & 0x10) != 0  // Right Command mask
            let hasLeftCommand = (cgFlags & 0x08) != 0   // Left Command mask
            
            // Handle flags changed (modifier keys)
            if type == .flagsChanged {
                let wasPressed = hotkeyManager.wasRightCommandPressed
                hotkeyManager.wasRightCommandPressed = hasRightCommand && !hasLeftCommand
                
                // If Right Command was just released (was pressed, now not)
                if wasPressed && !hotkeyManager.wasRightCommandPressed {
                    hotkeyManager.onKeyRelease?()
                }
                return Unmanaged.passRetained(cgEvent)
            }
            
            // Handle key release
            if type == .keyUp {
                return Unmanaged.passRetained(cgEvent)
            }
            
            // Handle key down
            guard type == .keyDown else {
                return Unmanaged.passRetained(cgEvent)
            }
            
            // Only trigger if Right Command is pressed AND Left Command is NOT pressed
            if !hasRightCommand || hasLeftCommand {
                return Unmanaged.passRetained(cgEvent)
            }
            
            // Track that Right Command is pressed
            hotkeyManager.wasRightCommandPressed = true

            guard let characters = nsEvent.charactersIgnoringModifiers?.lowercased(),
                  let letter = characters.first,
                  ("a"..."z").contains(String(letter))
            else {
                return Unmanaged.passRetained(cgEvent)
            }

            let isOption = flags.contains(.option)

            if isOption {
                // Assignment: Right Command + Option + letter
                hotkeyManager.onAssignKey?(letter)
            } else {
                // Normal switch: Right Command + letter
                hotkeyManager.onSwitchKey?(letter)
            }

            // Swallow the event so it doesn't type into the frontmost app.
            return nil
        }

        let refcon = Unmanaged.passRetained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: refcon
        ) else {
            fputs("Failed to create event tap. Make sure the app has Accessibility permissions.\n", stderr)
            return
        }

        eventTap = tap

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
}

