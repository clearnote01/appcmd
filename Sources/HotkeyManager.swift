import Foundation
import AppKit

final class HotkeyManager {
    var onSwitchKey: ((Character) -> Void)?
    var onAssignKey: ((Character) -> Void)?
    var onKeyRelease: (() -> Void)?
    var onLongPress: (() -> Void)?

    private var eventTap: CFMachPort?
    private var wasRightCommandPressed = false
    private var longPressWorkItem: DispatchWorkItem?
    private let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

    private func startLongPressTimer() {
        longPressWorkItem?.cancel()
        let delay = ConfigStore.shared.longPressDelay
        let item = DispatchWorkItem { [weak self] in
            self?.onLongPress?()
        }
        longPressWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func cancelLongPressTimer() {
        longPressWorkItem?.cancel()
        longPressWorkItem = nil
    }

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
            let cgFlags = cgEvent.flags.rawValue
            let hasRightCommand = (cgFlags & 0x10) != 0
            let hasLeftCommand = (cgFlags & 0x08) != 0
            
            if type == .flagsChanged {
                let isPressedNow = hasRightCommand && !hasLeftCommand
                let wasPressed = hotkeyManager.wasRightCommandPressed
                
                hotkeyManager.wasRightCommandPressed = isPressedNow
                
                if !wasPressed && isPressedNow {
                    // Just pressed
                    hotkeyManager.startLongPressTimer()
                } else if wasPressed && !isPressedNow {
                    // Just released
                    hotkeyManager.cancelLongPressTimer()
                    hotkeyManager.onKeyRelease?()
                }
                return Unmanaged.passRetained(cgEvent)
            }
            
            // On any actual key down (Command + Key), cancel the long press timer
            // so the cheat sheet doesn't pop up while you are actively switching.
            if type == .keyDown {
                hotkeyManager.cancelLongPressTimer()
            }

            if type == .keyUp {
                return Unmanaged.passRetained(cgEvent)
            }
            
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

