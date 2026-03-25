import Foundation
import Cocoa
import IOKit
import IOKit.hid
import ApplicationServices
import ServiceManagement

func getHIDDeviceIntProperty(_ device: IOHIDDevice, _ key: CFString) -> Int {
    guard let v = IOHIDDeviceGetProperty(device, key) else { return -1 }
    return (v as? NSNumber)?.intValue ?? -1
}
func getHIDDeviceStringProperty(_ device: IOHIDDevice, _ key: CFString) -> String {
    return IOHIDDeviceGetProperty(device, key) as? String ?? "?"
}
