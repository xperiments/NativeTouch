import Foundation
import Cocoa
import IOKit
import IOKit.hid
import ApplicationServices
import ServiceManagement

extension AppDelegate {
    func buildMenu() {
        guard statusItem != nil else { return }

        let menu = NSMenu()

        let copyrightItem = NSMenuItem(title: "© 2026 Pedro Casaubon", action: #selector(openCopyrightLink), keyEquivalent: "")
        copyrightItem.target = self
        menu.addItem(copyrightItem)
        

        let buyMeCoffe = NSMenuItem(title: "☕️ Buy Me a Coffee", action: #selector(openBuyMeCoffeeLink), keyEquivalent: "")
        buyMeCoffe.target = self
        menu.addItem(buyMeCoffe)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "⚙️ Settings…", action: #selector(openSettingsWindow(_:)), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "❌ Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    @objc func openCopyrightLink() {
        if let url = URL(string: "https://github.com/xperiments") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc func openBuyMeCoffeeLink() {
        if let url = URL(string: "https://ko-fi.com/I3I8PSAYU") {
            NSWorkspace.shared.open(url)
        }
    }
}
