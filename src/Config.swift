import Foundation
import Cocoa
import IOKit
import IOKit.hid
import ApplicationServices
import ServiceManagement

// CONFIG
// let ANMITE_VENDOR_ID = 0x27c0
// let ANMITE_PRODUCT_ID = 0x0859
// let PRECHEN_VENDOR_ID = 0x1a86
// let PRECHEN_PRODUCT_ID = 0xe5e3

// Optional logging to file
let logFilePath = ProcessInfo.processInfo.environment["TSDAEMON_LOG_FILE"] ?? "/tmp/tsdaemon.log"
let logFileHandle: FileHandle? = {
    let fm = FileManager.default
    if !fm.fileExists(atPath: logFilePath) {
        fm.createFile(atPath: logFilePath, contents: nil, attributes: nil)
    }
    guard let handle = FileHandle(forWritingAtPath: logFilePath) else { return nil }
    handle.seekToEndOfFile()
    return handle
}()

func log(_ msg: String) {
    let line = "[NativeTouch] \(msg)\n"
    print(line, terminator: "")
    if let handle = logFileHandle, let data = line.data(using: .utf8) {
        handle.write(data)
    }
}

