import Foundation
import Cocoa
import IOKit
import IOKit.hid
import ApplicationServices
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var activityInfo: NSObjectProtocol?

    var settingsController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Evitar que macOS suspenda la aplicación (App Nap) porque "no tiene ventanas"
        activityInfo = ProcessInfo.processInfo.beginActivity(options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical], reason: "Prevent App Nap for NativeTouch Daemon")

        // 2. Escuchar cuando el Mac despierta del reposo o la pantalla cambia de resolución/ID
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(handleDisplayChange), name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(handleDisplayChange), name: NSWorkspace.screensDidWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDisplayChange), name: NSApplication.didChangeScreenParametersNotification, object: nil)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if #available(macOS 11.0, *) {
            let symbolConfig = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
            if let image = NSImage(systemSymbolName: "hand.tap.fill", accessibilityDescription: "Touch") {
                statusItem.button?.image = image.withSymbolConfiguration(symbolConfig)
            } else { statusItem.button?.title = "Target" }
        } else { statusItem.button?.title = "Target" }

        buildMenu()
    }

    @objc func handleDisplayChange() {
        log("🔄 Detectado cambio de pantallas o despertar del reposo. Reajustando monitores...")
        displayNameLookup = nil // Forzamos al sistema a consultar otra vez nombres porque pueden haber cambiado IDs

        for state in activeDeviceStates.values {
            state.isTouching = false
            state.ignoreAxisUntil = nil
            state.loadPrefs() // Re-conecta el ID a la pantalla salvada
        }

        buildMenu()
        settingsController?.refreshSidebarIfNeeded()
    }

    // MARK: - Settings Window

    @objc func openSettingsWindow(_ sender: Any? = nil) {
        if settingsController == nil {
            settingsController = SettingsWindowController(delegate: self)
        }
        settingsController?.showWindow()
        NSApp.activate(ignoringOtherApps: true)
    }


    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // Settings window logic moved to SettingsWindowController
}


