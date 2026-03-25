import Foundation
import Cocoa
import IOKit
import IOKit.hid
import ApplicationServices
import ServiceManagement

func activeDisplayList() -> [CGDirectDisplayID] {
    var displayCount: UInt32 = 0
    guard CGGetActiveDisplayList(0, nil, &displayCount) == .success else { return [] }
    var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
    guard CGGetActiveDisplayList(displayCount, &displays, &displayCount) == .success else { return [] }
    return displays
}

var displayNameLookup: [UInt32: String]?
func buildDisplayNameLookup() -> [UInt32: String] {
    var map = [UInt32: String]()
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
    task.arguments = ["SPDisplaysDataType", "-json"]
    let pipe = Pipe()
    task.standardOutput = pipe
    do { try task.run() } catch { return map }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    task.waitUntilExit()
    guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
          let displays = json["SPDisplaysDataType"] as? [Any] else { return map }
    for case let display as [String: Any] in displays {
        guard let ndrvs = display["spdisplays_ndrvs"] as? [Any] else { continue }
        for case let drv as [String: Any] in ndrvs {
            guard let idStr = drv["_spdisplays_displayID"] as? String,
                  let id = UInt32(idStr),
                  let name = drv["_name"] as? String else { continue }
            map[id] = name
        }
    }
    return map
}

func displayName(for id: CGDirectDisplayID) -> String? {
    if displayNameLookup == nil { displayNameLookup = buildDisplayNameLookup() }
    return displayNameLookup?[id]
}

func displayBounds(for point: CGPoint) -> CGRect {
    var displayCount: UInt32 = 0
    var displayID: CGDirectDisplayID = 0
    let err = CGGetDisplaysWithPoint(point, 1, &displayID, &displayCount)
    if err == .success && displayCount > 0 {
        return CGDisplayBounds(displayID)
    }
    return CGDisplayBounds(CGMainDisplayID())
}
