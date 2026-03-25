import Foundation
import Cocoa
import IOKit
import IOKit.hid
import ApplicationServices
import ServiceManagement

func getRealCursorLocation() -> CGPoint {
    // Tomamos la posición real validándola al vuelo
    if let ev = CGEvent(source: nil) {
        let loc = ev.location
        if loc.x != 0 || loc.y != 0 { return loc }
    }
    // Fallback: AppKit coordinate space to CoreGraphics
    let ns = NSEvent.mouseLocation
    let mainH = CGDisplayBounds(CGMainDisplayID()).height
    return CGPoint(x: ns.x, y: mainH - ns.y)
}

func jumpCursor(from currentPos: CGPoint, to targetPos: CGPoint) {
    let originBounds = displayBounds(for: currentPos)
    let targetBounds = displayBounds(for: targetPos)
    
    CGAssociateMouseAndMouseCursorPosition(boolean_t(0))
    
    // Si saltamos entre pantallas dispares
    if originBounds != targetBounds {
        let safePoint = CGPoint(x: originBounds.maxX - 5, y: originBounds.maxY - 5)
        CGWarpMouseCursorPosition(safePoint)
        
        // Disparamos eventos falsos en la esquina muerta para forzar al OS a cortar el "drag"
        let breakUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: safePoint, mouseButton: .left)
        breakUp?.post(tap: .cghidEventTap)
        let breakMove = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: safePoint, mouseButton: .left)
        breakMove?.post(tap: .cghidEventTap)
        
        usleep(1500) // 1.5ms para que WindowServer engulla el evento
    }
    
    CGWarpMouseCursorPosition(targetPos)
    CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
    
    // Confirmamos la posición de destino
    let settleMove = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: targetPos, mouseButton: .left)
    settleMove?.post(tap: .cghidEventTap)
}

func setCursorVisible(_ visible: Bool) {
    if visible {
        CGDisplayShowCursor(CGMainDisplayID())
    } else {
        CGDisplayHideCursor(CGMainDisplayID())
    }
}

// Cursor tracking
var trackedCursorPos = CGEvent(source: nil)?.location ?? .zero
let cursorTrackerTap = CGEvent.tapCreate(
    tap: .cghidEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: CGEventMask((1 << CGEventType.mouseMoved.rawValue) | (1 << CGEventType.leftMouseDragged.rawValue)),
    callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
        trackedCursorPos = event.location
        return Unmanaged.passUnretained(event)
    },
    userInfo: nil
)

func moveCursor(to point: CGPoint, isDragging: Bool = false, clickCount: Int64 = 1) {
    let eventType: CGEventType = isDragging ? .leftMouseDragged : .mouseMoved
    if let event = CGEvent(mouseEventSource: nil, mouseType: eventType, mouseCursorPosition: point, mouseButton: .left) {
        if isDragging {
            event.setIntegerValueField(.mouseEventButtonNumber, value: Int64(CGMouseButton.left.rawValue))
        }
        event.setIntegerValueField(.mouseEventClickState, value: clickCount)
        event.post(tap: .cghidEventTap)
    }
}

