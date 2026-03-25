import Foundation
import Cocoa
import IOKit
import IOKit.hid
import ApplicationServices
import ServiceManagement

// TOUCH STATE MANAGERS
class TouchState {
    let vendorID: Int
    let productID: Int
    let name: String
    let defaultsPrefix: String
    
    var targetDisplayID: CGDirectDisplayID?
    var targetDisplayRect: CGRect = .zero
    
    var invertX: Bool = false
    var invertY: Bool = false
    var swapXY: Bool = false
    var restoreOnUp: Bool = false
    var enabled: Bool = true
    var scrollMode: Bool = false
    
    var lastX: Double = 0
    var lastY: Double = 0
    var isTouching: Bool = false
    var ignoreAxisUntil: Date?
    var isConnected: Bool = false
    var lastClickTime: Date = Date.distantPast
    var lastClickPosition: CGPoint = .zero
    var currentClickCount: Int64 = 1
    var savedCursorPosition: CGPoint?
    
    var isRightClicking: Bool = false
    var rightClickMenuOpened: Bool = false
    
    var scrollTouchStartPoint: CGPoint = .zero
    var lastScrollMappedPoint: CGPoint = .zero
    var scrollMovedBeyondThreshold: Bool = false
    var savedScrollCursorPosition: CGPoint?
    
    var isLongPressDragSession: Bool = false
    var currentTouchToken: UUID = UUID()
    
    struct ScrollPoint { let point: CGPoint; let time: Date }
    var scrollHistory: [ScrollPoint] = []
    var inertiaTimer: Timer?
    var inertiaVelocityX: Double = 0
    var inertiaVelocityY: Double = 0
    
    init(vendorID: Int, productID: Int, name: String, defaultsPrefix: String) {
        self.vendorID = vendorID
        self.productID = productID
        self.name = name
        self.defaultsPrefix = defaultsPrefix
        loadPrefs()
    }
    
    private var prefDomainName: String {
        return Bundle.main.bundleIdentifier ?? "io.xperiments.nativetouch"
    }

    private var fallbackPrefDomainName: String {
        return "io.xperiments.nativetouch"
    }

    private var standardDefaults: UserDefaults {
        return UserDefaults.standard
    }

    private func boolPref(_ key: String, defaultValue: Bool) -> Bool {
        let std = standardDefaults
        if let v = std.object(forKey: key) as? Bool { return v }
        if let fallbackDomain = std.persistentDomain(forName: fallbackPrefDomainName), let v = fallbackDomain[key] as? Bool { return v }
        return defaultValue
    }

    private func uint32Pref(_ key: String) -> UInt32? {
        let std = standardDefaults
        if let v = std.object(forKey: key) as? UInt32 { return v }
        if let v = std.object(forKey: key) as? Int { return UInt32(v) }
        if let fallbackDomain = std.persistentDomain(forName: fallbackPrefDomainName) {
            if let v = fallbackDomain[key] as? UInt32 { return v }
            if let v = fallbackDomain[key] as? Int { return UInt32(v) }
        }
        return nil
    }

    func loadPrefs() {
        invertX = boolPref("\(defaultsPrefix)InvertX", defaultValue: false)
        invertY = boolPref("\(defaultsPrefix)InvertY", defaultValue: false)
        enabled = boolPref("\(defaultsPrefix)Enabled", defaultValue: true)
        swapXY = boolPref("\(defaultsPrefix)SwapXY", defaultValue: false)
        restoreOnUp = boolPref("\(defaultsPrefix)RestoreOnUp", defaultValue: false)
        scrollMode = boolPref("\(defaultsPrefix)ScrollMode", defaultValue: false)
        
        let displays = activeDisplayList()
        if let savedID = uint32Pref("\(defaultsPrefix)TargetDisplayID"), displays.contains(savedID) {
            targetDisplayID = savedID
            targetDisplayRect = CGDisplayBounds(savedID)
            log("[\(name)] Loaded saved display ID = \(savedID)")
        } else {
            var found = false
            for d in displays {
                let dName = displayName(for: d) ?? ""
                if dName.localizedCaseInsensitiveContains(name) {
                    targetDisplayID = d
                    targetDisplayRect = CGDisplayBounds(d)
                    log("[\(name)] Auto-detected display \(dName) id=\(d)")
                    found = true
                    break
                }
            }
            if !found {
                let main = CGMainDisplayID()
                targetDisplayID = main
                targetDisplayRect = CGDisplayBounds(main)
                log("[\(name)] Fallback to main display id=\(main)")
            }
        }
    }
    
    func mapToDisplay(x: Double, y: Double) -> CGPoint {
        var nx = x; var ny = y
        if swapXY { swap(&nx, &ny) }
        if invertX { nx = 1 - nx }
        if invertY { ny = 1 - ny }
        let mappedX = targetDisplayRect.origin.x + nx * targetDisplayRect.size.width
        let mappedY = targetDisplayRect.origin.y + (1 - ny) * targetDisplayRect.size.height
        return CGPoint(x: mappedX, y: mappedY)
    }
    
    func savePref(_ key: String, _ value: Any) {
        let fullKey = "\(defaultsPrefix)\(key)"
        let std = standardDefaults

        std.set(value, forKey: fullKey)
        std.synchronize()

        // mirror to legacy fallback domain if exists
        if let fallbackDomain = std.persistentDomain(forName: fallbackPrefDomainName) {
            var newDomain = fallbackDomain
            newDomain[fullKey] = value
            std.setPersistentDomain(newDomain, forName: fallbackPrefDomainName)
        }

        log("[\(name)] savePref: standard key=\(fullKey), value=\(value)")
        if let domainData = std.persistentDomain(forName: prefDomainName) {
            log("[\(name)] std persistentDomain keys: \(Array(domainData.keys))")
        }
        if let fallbackData = std.persistentDomain(forName: fallbackPrefDomainName) {
            log("[\(name)] fallback persistentDomain keys: \(Array(fallbackData.keys))")
        }
    }
}

struct DeviceConfig: Codable {
    let vendorID: Int
    let productID: Int
    let name: String
    let defaultsPrefix: String
}

func classifyDeviceName(_ name: String) -> Bool {
    let n = name.lowercased()
    return n.contains("touch") || n.contains("digitizer") || n.contains("tablet") || n.contains("pen")
}

func isSafeTouchDevice(device: IOHIDDevice, vendorID: Int, productID: Int) -> Bool {
    if vendorID == 0x05AC { return false }

    guard let elements = IOHIDDeviceCopyMatchingElements(device, nil, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement] else {
        return false
    }

    var hasX = false
    var hasY = false
    var isRelative = false
    var hasTouchIndicator = false

    for element in elements {
        let usagePage = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)

        if usagePage == kHIDPage_GenericDesktop || usagePage == kHIDPage_Digitizer {
            if usage == kHIDUsage_GD_X { hasX = true }
            if usage == kHIDUsage_GD_Y { hasY = true }
            if IOHIDElementIsRelative(element) { isRelative = true }
        }

        if usagePage == kHIDPage_Digitizer && usage == 0x42 { hasTouchIndicator = true }
        if usagePage == kHIDPage_Button && usage == 0x01 { hasTouchIndicator = true }
    }

    return hasX && hasY && !isRelative && hasTouchIndicator
}

func autoGenerateDeviceConfigs() -> [DeviceConfig] {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    IOHIDManagerSetDeviceMatching(manager, nil)
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

    let openRes = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    if openRes != kIOReturnSuccess {
        log("⚠️ Could not open IOHIDManager: \(openRes)")
    }

    defer {
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
        return []
    }

    var configs = [DeviceConfig]()

    for device in devices {
        let vendor = getHIDDeviceIntProperty(device, kIOHIDVendorIDKey as CFString)
        let product = getHIDDeviceIntProperty(device, kIOHIDProductIDKey as CFString)
        let name = getHIDDeviceStringProperty(device, kIOHIDProductKey as CFString)

        guard vendor != -1, product != -1 else { continue }
        guard !name.isEmpty else { continue }

        // Final safety check from actual HID descriptor/elements
        if !isSafeTouchDevice(device: device, vendorID: vendor, productID: product) {
            log("⏭️ Skipping non-touch HID device during auto-discovery: \(name) [v:\(vendor) p:\(product)]")
            continue
        }

        let location = getHIDDeviceIntProperty(device, kIOHIDLocationIDKey as CFString)
        let serial = getHIDDeviceStringProperty(device, kIOHIDSerialNumberKey as CFString)

        var instanceTag = ""
        if location != -1 {
            instanceTag = "_loc\(location)"
            if !serial.isEmpty && serial != "?" {
                instanceTag += "_\(serial)"
            }
        } else if !serial.isEmpty && serial != "?" {
            // Use serial only if we have no location; if location exists it is stronger
            instanceTag = "_\(serial)"
        }

        let keyFactory = "DEVICE_\(vendor)_\(product)\(instanceTag)_"
        let config = DeviceConfig(vendorID: vendor, productID: product, name: name, defaultsPrefix: keyFactory)

        if !configs.contains(where: { $0.vendorID == vendor && $0.productID == product }) {
            configs.append(config)
        }
    }

    return configs
}

func loadDeviceConfigs() -> [DeviceConfig] {
    // Use only runtime discovery. No devices.json persistence required.
    return autoGenerateDeviceConfigs()
}

// Active profiles by model (VID_PID) for defaults and settings templates
var activeStates: [String: TouchState] = {
    var states = [String: TouchState]()
    for config in loadDeviceConfigs() {
        let key = "\(config.vendorID)_\(config.productID)"
        states[key] = TouchState(vendorID: config.vendorID, productID: config.productID, name: config.name, defaultsPrefix: config.defaultsPrefix)
    }
    return states
}()

// Active connected devices by unique HID device key (one entry per physical device)
var activeDeviceStates: [String: TouchState] = [:]


