import CoreGraphics
import Foundation

protocol EventTapEngineControlling: AnyObject {
    var isActive: Bool { get }
    func start(userInfo: UnsafeMutableRawPointer?) -> Bool
    func setEnabled(_ isEnabled: Bool)
    func stop()
}

final class EventTapEngine: EventTapEngineControlling {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isActive: Bool {
        eventTap != nil
    }

    func start(userInfo: UnsafeMutableRawPointer?) -> Bool {
        guard eventTap == nil else {
            return true
        }

        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.tapDisabledByTimeout.rawValue) |
            (1 << CGEventType.tapDisabledByUserInput.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: tapCallback,
            userInfo: userInfo
        ) else {
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func setEnabled(_ isEnabled: Bool) {
        guard let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: isEnabled)
    }

    func stop() {
        guard let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: false)

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        self.eventTap = nil
        runLoopSource = nil
    }
}
