import Foundation
import Cocoa
import IOKit
import IOKit.hid
import ApplicationServices
import ServiceManagement
import UserNotifications

// Ensure Accessibility Permissions
let _ = NSApplication.shared
NSApp.setActivationPolicy(.accessory)
// Do not automatically prompt with the system accessibility dialog at startup.
// We guide users to System Settings manually and watch for permission changes.
let axOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
let axTrusted = AXIsProcessTrustedWithOptions(axOptions)

func postRelaunchNotification() {
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
        guard granted, error == nil else { return }
        let content = UNMutableNotificationContent()
        content.title = "NativeTouch is live"
        content.body = "NativeTouch is running and touch input is active."
        content.sound = .default

        let request = UNNotificationRequest(identifier: "NativeTouchLive", content: content, trigger: nil)
        center.add(request, withCompletionHandler: nil)
    }
}

if !axTrusted {
    log("⚠️ Missing Accessibility permissions. Showing alert to user...")
    let alert = NSAlert()
    alert.alertStyle = .critical
    alert.messageText = "Permissions Required"
    alert.informativeText = "NativeTouch needs Accessibility access to receive touch input from your devices.\n\nClick 'Open Privacy Settings' and enable NativeTouch under Accessibility. We will detect when access is granted and then prompt you to relaunch the app."
    alert.addButton(withTitle: "Open Privacy Settings")
    NSApp.activate(ignoringOtherApps: true)
    
    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
        // Best practice flow: close alert first, small delay, then open System Settings
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)

            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                if AXIsProcessTrusted() {
                    timer.invalidate()

                    // Ask user before relaunching
                    let bundlePath = Bundle.main.bundlePath
                    var relaunched = false
                    var countdown = 10

                    let autoRelaunch = DispatchWorkItem {
                        guard !relaunched else { return }
                        relaunched = true
                        let _ = Process.launchedProcess(launchPath: "/usr/bin/open", arguments: [bundlePath])
                        NSApp.terminate(nil)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(countdown), execute: autoRelaunch)

                    let doneAlert = NSAlert()
                    doneAlert.alertStyle = .informational
                    doneAlert.messageText = "Accessibility Permission Granted"
                    doneAlert.informativeText = "NativeTouch is now approved. Relaunching in 10s..."
                    let actionButton = doneAlert.addButton(withTitle: "Relaunch (10s)")

                    let countdownSource = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
                    countdownSource.schedule(deadline: .now() + 1, repeating: 1)
                    countdownSource.setEventHandler {
                        countdown -= 1
                        if countdown <= 0 {
                            countdownSource.cancel()
                            if !relaunched {
                                relaunched = true
                                let _ = Process.launchedProcess(launchPath: "/usr/bin/open", arguments: [bundlePath])
                                postRelaunchNotification()
                            }
                            doneAlert.window.close()
                            NSApp.terminate(nil)
                            return
                        }
                        DispatchQueue.main.async {
                            doneAlert.informativeText = "NativeTouch is now approved\nRelaunching in \(countdown)s..."
                            actionButton.title = "Relaunch (\(countdown)s)"
                        }
                    }
                    countdownSource.resume()

                    let result = doneAlert.runModal()
                    countdownSource.cancel()

                    if result == .alertFirstButtonReturn {
                        autoRelaunch.cancel()
                        relaunched = true
                        let _ = Process.launchedProcess(launchPath: "/usr/bin/open", arguments: [bundlePath])
                        postRelaunchNotification()
                    }

                    NSApp.terminate(nil)
                }
            }
        }
        RunLoop.main.run() // Keeps the thread alive enough for the async task to execute
    } else {
        NSApp.terminate(nil)
    }
}

if axTrusted {
    postRelaunchNotification()
}

// Force initialization of activeStates BEFORE we set up HID callbacks
// This prevents a dispatch_once deadlock if TouchState.init triggers a nested RunLoop via Process().run() for system_profiler
_ = activeStates

// HID MANAGEMENT
let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
var matchArray = [CFDictionary]()
for (_, state) in activeStates {
    let match = [
        kIOHIDVendorIDKey: state.vendorID,
        kIOHIDProductIDKey: state.productID
    ] as CFDictionary
    matchArray.append(match)
}

IOHIDManagerSetDeviceMatchingMultiple(manager, matchArray as CFArray)
IOHIDManagerRegisterDeviceMatchingCallback(manager, onHIDDeviceConnected, nil)
IOHIDManagerRegisterDeviceRemovalCallback(manager, onHIDDeviceRemoval, nil)
IOHIDManagerRegisterInputValueCallback(manager, onHIDDeviceInput, nil)
IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
if openResult != kIOReturnSuccess {
    log("⚠️ Could not open manager with SeizeDevice. Falling back to None. Error: \(openResult)")
    IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
} else {
    log("🔒 Successfully seized HID devices! macOS won't interfere.")
}

// Dump existing devices
if let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> {
    for d in devices { onHIDDeviceConnected(nil, 0, nil, d) }
}

log("🚀 Touch mapper running and listening to configured devices...")

// Prevent multiple instances of the app running concurrently.
if let bundleId = Bundle.main.bundleIdentifier {
    let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
    let currentPID = ProcessInfo.processInfo.processIdentifier
    if running.contains(where: { $0.processIdentifier != currentPID }) {
        log("⚠️ NativeTouch is already running. Exiting duplicate instance.")
        exit(0)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()