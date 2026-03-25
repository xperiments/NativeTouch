import Foundation
import Cocoa
import IOKit
import IOKit.hid
import ApplicationServices
import ServiceManagement

private enum HIDUsagePage: UInt32 {
    case genericDesktop = 0x01
    case digitizer = 0x0D
    case button = 0x09
}

private enum GenericDesktopUsage: UInt32 {
    case x = 0x30
    case y = 0x31
}

private enum TouchUsage: UInt32 {
    case tipSwitch = 0x42
}

private enum ButtonUsage: UInt32 {
    case button1 = 0x01
}

private func postMouseEvent(type: CGEventType, button: CGMouseButton, at point: CGPoint, clickCount: Int64 = 1) {
    guard let ev = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: button) else { return }
    ev.setIntegerValueField(.mouseEventClickState, value: clickCount)
    ev.post(tap: .cghidEventTap)
}

private func postScrollWheelEvent(deltaX: Int32, deltaY: Int32, at location: CGPoint) {
    guard let ev = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: deltaY, wheel2: deltaX, wheel3: 0) else { return }
    ev.location = location
    ev.post(tap: .cghidEventTap)
}

private func startRightClickSequence(state: TouchState, point: CGPoint, mappedPoint: CGPoint) {
    state.rightClickMenuOpened = true
    state.isRightClicking = true
    
    if state.scrollMode {
        if state.isLongPressDragSession {
            postMouseEvent(type: .leftMouseUp, button: .left, at: state.scrollTouchStartPoint)
            state.isLongPressDragSession = false
        }
        state.scrollMovedBeyondThreshold = true
        state.savedScrollCursorPosition = nil
    } else {
        postMouseEvent(type: .leftMouseUp, button: .left, at: mappedPoint)
        state.savedCursorPosition = nil
    }

    postMouseEvent(type: .rightMouseDown, button: .right, at: mappedPoint)
    postMouseEvent(type: .rightMouseUp, button: .right, at: mappedPoint)
}

private func handleAxisEvent(state: TouchState) {
    let mapped = state.mapToDisplay(x: state.lastX, y: state.lastY)

    if state.scrollMode {
        let dx = mapped.x - state.scrollTouchStartPoint.x
        let dy = mapped.y - state.scrollTouchStartPoint.y
        let distanceSq = dx*dx + dy*dy

        if state.isLongPressDragSession {
            CGWarpMouseCursorPosition(mapped)
            moveCursor(to: mapped, isDragging: true, clickCount: 1)
            state.lastScrollMappedPoint = mapped
            return
        }

        if !state.scrollMovedBeyondThreshold && distanceSq > 1600 {
            state.scrollMovedBeyondThreshold = true
        }

        if state.scrollMovedBeyondThreshold {
            let dScrollX = mapped.x - state.lastScrollMappedPoint.x
            let dScrollY = mapped.y - state.lastScrollMappedPoint.y
            postScrollWheelEvent(deltaX: Int32(dScrollX), deltaY: Int32(dScrollY), at: mapped)

            let now = Date()
            state.scrollHistory.append(TouchState.ScrollPoint(point: mapped, time: now))
            state.scrollHistory.removeAll(where: { now.timeIntervalSince($0.time) > 0.15 })
        }

        state.lastScrollMappedPoint = mapped
        return
    }

    var shouldDropMove = false
    if let ignoreUntil = state.ignoreAxisUntil, Date() < ignoreUntil {
        let dx = mapped.x - state.lastClickPosition.x
        let dy = mapped.y - state.lastClickPosition.y
        if (dx*dx + dy*dy) < 1600 {
            shouldDropMove = true
        } else {
            state.ignoreAxisUntil = nil
        }
    }

    if !shouldDropMove {
        moveCursor(to: mapped, isDragging: true, clickCount: state.currentClickCount)
    }
}

private func initializeTouch(state: TouchState, point: CGPoint) {
    state.isRightClicking = false
    state.rightClickMenuOpened = false

    let now = Date()
    let timeSinceLast = now.timeIntervalSince(state.lastClickTime)
    let dx = point.x - state.lastClickPosition.x
    let dy = point.y - state.lastClickPosition.y
    let distanceSq = dx * dx + dy * dy

    if timeSinceLast < 0.6 && distanceSq < 10000 {
        state.currentClickCount += 1
        if state.currentClickCount > 3 { state.currentClickCount = 3 }
    } else {
        state.currentClickCount = 1
    }

    state.lastClickTime = now
    state.lastClickPosition = point
    state.ignoreAxisUntil = now.addingTimeInterval(0.25)

    let token = UUID()
    state.currentTouchToken = token
    state.isLongPressDragSession = false

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
        if state.isTouching && state.currentTouchToken == token {
            let currentPoint = state.mapToDisplay(x: state.lastX, y: state.lastY)
            let dDx = currentPoint.x - point.x
            let dDy = currentPoint.y - point.y

            if (dDx * dDx + dDy * dDy) < 1600 {
                log("👉 Long press >1.2s detected! Triggering Right Click.")
                startRightClickSequence(state: state, point: point, mappedPoint: currentPoint)
            }
        }
    }

    if state.scrollMode {
        state.inertiaTimer?.invalidate()
        state.inertiaTimer = nil
        state.scrollHistory.removeAll()

        state.scrollTouchStartPoint = point
        state.lastScrollMappedPoint = point
        state.scrollMovedBeyondThreshold = false

        let currentPos = getRealCursorLocation()
        if !state.targetDisplayRect.contains(currentPos) {
            state.savedScrollCursorPosition = currentPos
        }

        jumpCursor(from: currentPos, to: point)
        setCursorVisible(false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.200) {
            if state.isTouching && state.currentTouchToken == token && !state.scrollMovedBeyondThreshold {
                state.isLongPressDragSession = true
                CGWarpMouseCursorPosition(state.scrollTouchStartPoint)
                postMouseEvent(type: .leftMouseDown, button: .left, at: state.scrollTouchStartPoint)
            }
        }

        state.scrollHistory.append(TouchState.ScrollPoint(point: point, time: now))
    } else if state.restoreOnUp {
        if let ev = CGEvent(source: nil) {
            let currentPos = ev.location
            if !state.targetDisplayRect.contains(currentPos) {
                state.savedCursorPosition = currentPos
            } else {
                state.savedCursorPosition = nil
            }
        }
    }
}

private func finishTouch(state: TouchState, point: CGPoint) {
    if state.isLongPressDragSession {
        postMouseEvent(type: .leftMouseUp, button: .left, at: point)
        state.isLongPressDragSession = false
        queueCursorReturn(state: state, from: point)
        return
    }

    if !state.scrollMovedBeyondThreshold {
        setCursorVisible(true)
        moveCursor(to: state.scrollTouchStartPoint, isDragging: false, clickCount: state.currentClickCount)
        postMouseEvent(type: .leftMouseDown, button: .left, at: state.scrollTouchStartPoint, clickCount: state.currentClickCount)
        postMouseEvent(type: .leftMouseUp, button: .left, at: state.scrollTouchStartPoint, clickCount: state.currentClickCount)
        queueCursorReturn(state: state, from: point)
        return
    }

    if let first = state.scrollHistory.first, let last = state.scrollHistory.last, state.scrollHistory.count > 1 {
        let dt = last.time.timeIntervalSince(first.time)
        if dt > 0 && dt < 0.25 {
            let vx = Double(last.point.x - first.point.x) / dt
            let vy = Double(last.point.y - first.point.y) / dt
            if abs(vx) > 300 || abs(vy) > 300 {
                state.inertiaVelocityX = vx * 0.016
                state.inertiaVelocityY = vy * 0.016
                let mappedLoc = state.lastScrollMappedPoint
                let captureSaved = state.savedScrollCursorPosition
                let capturePoint = point

                state.inertiaTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
                    state.inertiaVelocityX *= 0.95
                    state.inertiaVelocityY *= 0.95
                    if abs(state.inertiaVelocityX) < 0.5 && abs(state.inertiaVelocityY) < 0.5 {
                        timer.invalidate()
                        if let saved = captureSaved { jumpCursor(from: capturePoint, to: saved); state.savedScrollCursorPosition = nil }
                        setCursorVisible(true)
                        return
                    }
                    postScrollWheelEvent(deltaX: Int32(state.inertiaVelocityX), deltaY: Int32(state.inertiaVelocityY), at: mappedLoc)
                }

                state.scrollHistory.removeAll()
                return
            }
        }
    }

    state.scrollHistory.removeAll()
    queueCursorReturn(state: state, from: point)
}

private func queueCursorReturn(state: TouchState, from: CGPoint) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        if let saved = state.savedScrollCursorPosition {
            jumpCursor(from: from, to: saved)
            state.savedScrollCursorPosition = nil
        }
        setCursorVisible(true)
    }
}

private func handleNormalTouchEnd(state: TouchState, point: CGPoint) {
    let isRight = state.isRightClicking
    let eventType: CGEventType = isRight ? .rightMouseUp : .leftMouseUp
    let mouseBtn: CGMouseButton = isRight ? .right : .left

    let skipPost = state.rightClickMenuOpened
    if !skipPost {
        postMouseEvent(type: eventType, button: mouseBtn, at: point, clickCount: state.currentClickCount)
    }

    state.isRightClicking = false
    state.rightClickMenuOpened = false

    if state.restoreOnUp, let saved = state.savedCursorPosition {
        moveCursor(to: saved, isDragging: false)
        state.savedCursorPosition = nil
        state.ignoreAxisUntil = Date().addingTimeInterval(0.1)
    }
}

private func deviceUniqueKey(_ device: IOHIDDevice) -> String {
    let vendor = getHIDDeviceIntProperty(device, kIOHIDVendorIDKey as CFString)
    let product = getHIDDeviceIntProperty(device, kIOHIDProductIDKey as CFString)

    if let uniqueId = IOHIDDeviceGetProperty(device, kIOHIDPhysicalDeviceUniqueIDKey as CFString) as? String, !uniqueId.isEmpty {
        return "\(vendor)_\(product)_\(uniqueId)"
    }

    let location = getHIDDeviceIntProperty(device, kIOHIDLocationIDKey as CFString)
    let serial = getHIDDeviceStringProperty(device, kIOHIDSerialNumberKey as CFString)

    if location != -1 || serial != "?" {
        return "\(vendor)_\(product)_\(location)_\(serial)"
    }

    return "\(vendor)_\(product)_\(Unmanaged.passUnretained(device).toOpaque())"
}

private func deviceProfileKey(_ vendor: Int, _ product: Int) -> String {
    return "\(vendor)_\(product)"
}

let onHIDDeviceConnected: IOHIDDeviceCallback = { context, result, sender, device in
    let vendor = getHIDDeviceIntProperty(device, kIOHIDVendorIDKey as CFString)
    let product = getHIDDeviceIntProperty(device, kIOHIDProductIDKey as CFString)
    let name = getHIDDeviceStringProperty(device, kIOHIDProductKey as CFString)
    let uniqueKey = deviceUniqueKey(device)
    let profileKey = deviceProfileKey(vendor, product)
    log("🔌 CONNECTED -> \(name) [v:\(vendor) p:\(product)] uid:\(uniqueKey)")

    if activeDeviceStates[uniqueKey] != nil {
        activeDeviceStates[uniqueKey]?.isConnected = true
    } else if let profile = activeStates[profileKey] {
        let dup = TouchState(vendorID: profile.vendorID, productID: profile.productID, name: profile.name, defaultsPrefix: profile.defaultsPrefix)
        dup.isConnected = true
        activeDeviceStates[uniqueKey] = dup
    } else {
        let dup = TouchState(vendorID: vendor, productID: product, name: name, defaultsPrefix: "UNKNOWN_")
        dup.isConnected = true
        activeDeviceStates[uniqueKey] = dup
    }

    DispatchQueue.main.async { (NSApplication.shared.delegate as? AppDelegate)?.buildMenu() }
}

let onHIDDeviceRemoval: IOHIDDeviceCallback = { context, result, sender, device in
    let vendor = getHIDDeviceIntProperty(device, kIOHIDVendorIDKey as CFString)
    let product = getHIDDeviceIntProperty(device, kIOHIDProductIDKey as CFString)
    let name = getHIDDeviceStringProperty(device, kIOHIDProductKey as CFString)
    let uniqueKey = deviceUniqueKey(device)
    log("🛑 DISCONNECTED -> \(name) [v:\(vendor) p:\(product)] uid:\(uniqueKey)")

    if let state = activeDeviceStates[uniqueKey] {
        state.isConnected = false
        activeDeviceStates.removeValue(forKey: uniqueKey)
    }
    DispatchQueue.main.async { (NSApplication.shared.delegate as? AppDelegate)?.buildMenu() }
}

let onHIDDeviceInput: IOHIDValueCallback = { context, result, sender, value in
    let element = IOHIDValueGetElement(value)
    let device = IOHIDElementGetDevice(element)

    let uniqueKey = deviceUniqueKey(device)
    guard let state = activeDeviceStates[uniqueKey], state.enabled else { return }

    let usagePage = IOHIDElementGetUsagePage(element)
    let usage = IOHIDElementGetUsage(element)
    let intValue = IOHIDValueGetIntegerValue(value)
    let min = IOHIDElementGetLogicalMin(element)
    let max = IOHIDElementGetLogicalMax(element)

    if usagePage == HIDUsagePage.genericDesktop.rawValue {
        let norm = Double(intValue - min) / Double(max - min)
        if usage == GenericDesktopUsage.x.rawValue { state.lastX = norm }
        if usage == GenericDesktopUsage.y.rawValue { state.lastY = norm }

        if state.isTouching {
            handleAxisEvent(state: state)
        }
        return
    }

    let isTouchEvent = (usagePage == HIDUsagePage.digitizer.rawValue && usage == TouchUsage.tipSwitch.rawValue) || (usagePage == HIDUsagePage.button.rawValue && usage == ButtonUsage.button1.rawValue)
    if !isTouchEvent { return }

    let touching = intValue != 0
    if touching == state.isTouching { return }

    state.isTouching = touching
    let point = state.mapToDisplay(x: state.lastX, y: state.lastY)

    if touching {
        initializeTouch(state: state, point: point)
    } else if state.scrollMode {
        finishTouch(state: state, point: point)
    } else {
        handleNormalTouchEnd(state: state, point: point)
    }
}
