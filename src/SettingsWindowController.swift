import Foundation
import Cocoa
import ServiceManagement

class SettingsWindowController: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate {
    weak var delegate: AppDelegate?

    let generalSettingsKey = "__GENERAL__"
    var window: NSWindow?
    var sidebarTableView: NSTableView?
    var detailContainer: NSView?
    var settingsItems: [String] = []

    init(delegate: AppDelegate) {
        self.delegate = delegate
        super.init()
    }

    func showWindow() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 420), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "NativeTouch Settings"
        window.center()
        window.delegate = self

        let sidebarContainer = NSScrollView()
        sidebarContainer.hasVerticalScroller = true
        sidebarContainer.translatesAutoresizingMaskIntoConstraints = false
        sidebarContainer.widthAnchor.constraint(equalToConstant: 210).isActive = true
        sidebarContainer.drawsBackground = true
        sidebarContainer.backgroundColor = NSColor.black
        sidebarContainer.wantsLayer = true
        sidebarContainer.layer?.cornerRadius = 14
        sidebarContainer.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        sidebarContainer.layer?.masksToBounds = true

        let tableView = NSTableView(frame: .zero)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SettingsColumn"))
        column.title = "Categories"
        column.width = 210
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 30
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.backgroundColor = NSColor.black
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.selectionHighlightStyle = .regular
        tableView.focusRingType = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        if let enclosing = tableView.enclosingScrollView {
            enclosing.wantsLayer = true
            enclosing.layer?.cornerRadius = 14
            enclosing.layer?.masksToBounds = true
        }

        if #available(macOS 10.14, *) {
            tableView.appearance = NSAppearance(named: .darkAqua)
        }

        sidebarContainer.documentView = tableView

        let detailView = NSView()
        detailView.translatesAutoresizingMaskIntoConstraints = false
        detailView.wantsLayer = true
        detailView.layer?.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 1.0).cgColor
        detailView.layer?.cornerRadius = 14
        detailView.layer?.masksToBounds = true

        window.contentView?.addSubview(sidebarContainer)
        window.contentView?.addSubview(detailView)

        NSLayoutConstraint.activate([
            sidebarContainer.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 10),
            sidebarContainer.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 10),
            sidebarContainer.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor, constant: -10),

            detailView.leadingAnchor.constraint(equalTo: sidebarContainer.trailingAnchor, constant: 10),
            detailView.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 10),
            detailView.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -10),
            detailView.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor, constant: -10)
        ])

        self.window = window
        self.sidebarTableView = tableView
        self.detailContainer = detailView

        refreshSidebar()

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === window {
            sender.orderOut(nil)
            window = nil
            sidebarTableView = nil
            detailContainer = nil
            return false
        }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        if let w = notification.object as? NSWindow, w === window {
            window = nil
            sidebarTableView = nil
            detailContainer = nil
        }
    }

    func refreshSidebarIfNeeded() {
        guard window != nil else { return }
        refreshSidebar()
    }

    func refreshSidebar() {
        settingsItems = [generalSettingsKey] + activeDeviceStates.keys.sorted()
        sidebarTableView?.reloadData()

        if !settingsItems.isEmpty {
            sidebarTableView?.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            updateDetail(for: settingsItems[0])
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return settingsItems.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("SettingCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()

        if cell.identifier == nil { cell.identifier = identifier }
        let itemKey = settingsItems[row]
        let text = itemKey == generalSettingsKey ? "General" : (activeDeviceStates[itemKey]?.name ?? "Unknown")

        cell.wantsLayer = true
        cell.layer?.backgroundColor = NSColor.black.cgColor

        if cell.textField == nil {
            let textField = NSTextField(labelWithString: text)
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.textColor = NSColor.white
            textField.font = NSFont.systemFont(ofSize: 13, weight: .regular)
            cell.addSubview(textField)
            cell.textField = textField
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 12),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -12)
            ])
        } else {
            cell.textField?.stringValue = text
            cell.textField?.textColor = NSColor.white
        }

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < settingsItems.count else { return }
        updateDetail(for: settingsItems[selectedRow])
    }

    func updateDetail(for itemKey: String) {
        guard let detail = detailContainer else { return }
        detail.subviews.forEach { $0.removeFromSuperview() }

        if itemKey == generalSettingsKey {
            buildGeneralSettingsView(in: detail)
            return
        }

        guard let state = activeDeviceStates[itemKey] else {
            let label = NSTextField(labelWithString: "Dispositivo no conectado")
            label.alignment = .center
            label.frame = detail.bounds
            label.autoresizingMask = [.width, .height]
            detail.addSubview(label)
            return
        }

        buildDeviceSettingsView(for: state, deviceKey: itemKey, in: detail)
    }

    func buildGeneralSettingsView(in container: NSView) {
        let title = NSTextField(labelWithString: "General settings")
        title.font = NSFont.boldSystemFont(ofSize: 16)
        title.translatesAutoresizingMaskIntoConstraints = false

        let loginCheckbox = NSButton(checkboxWithTitle: "Launch at Login", target: self, action: #selector(toggleLaunchAtLoginFromSettings(_:)))
        loginCheckbox.translatesAutoresizingMaskIntoConstraints = false
        if #available(macOS 13.0, *) {
            loginCheckbox.state = SMAppService.mainApp.status == .enabled ? NSControl.StateValue.on : NSControl.StateValue.off
        } else {
            loginCheckbox.state = NSControl.StateValue.off
        }
        loginCheckbox.identifier = NSUserInterfaceItemIdentifier("LaunchAtLoginCheckbox")

        container.addSubview(title)
        container.addSubview(loginCheckbox)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            loginCheckbox.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 14),
            loginCheckbox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
        ])
    }

    @objc func toggleLaunchAtLoginFromSettings(_ sender: NSButton) {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    log("Removed from login items")
                } else {
                    try SMAppService.mainApp.register()
                    log("Added to login items")
                }
                sender.state = SMAppService.mainApp.status == .enabled ? NSControl.StateValue.on : NSControl.StateValue.off
            } catch {
                log("Failed to toggle Launch at Login: \(error)")
            }
        } else {
            log("Launch at Login is not available before macOS 13")
        }
    }

    @objc func toggleDeviceEnabledFromSettings(_ sender: NSButton) {
        guard let deviceKey = sender.identifier?.rawValue,
              let state = activeDeviceStates[deviceKey]
        else { return }

        let isEnabled = sender.state == NSControl.StateValue.on
        state.enabled = isEnabled
        state.savePref("Enabled", isEnabled)
        log("[\(state.name)] Enabled set to \(isEnabled) via settings")

        if !isEnabled {
            state.isTouching = false
            state.isRightClicking = false
            state.rightClickMenuOpened = false
        }

        delegate?.buildMenu()
    }

    func buildDeviceSettingsView(for state: TouchState, deviceKey: String, in container: NSView) {
        let title = NSTextField(labelWithString: "Device: \(state.name)")
        title.font = NSFont.boldSystemFont(ofSize: 16)
        title.translatesAutoresizingMaskIntoConstraints = false

        let monitorLabel = NSTextField(labelWithString: "Target Monitor")
        monitorLabel.font = NSFont.systemFont(ofSize: 12)
        monitorLabel.translatesAutoresizingMaskIntoConstraints = false

        let displaySelector = NSPopUpButton(frame: .zero, pullsDown: false)
        displaySelector.translatesAutoresizingMaskIntoConstraints = false
        displaySelector.target = self
        displaySelector.action = #selector(setDeviceDisplayFromSettings(_:))
        displaySelector.identifier = NSUserInterfaceItemIdentifier(deviceKey)

        let displays = activeDisplayList()
        for d in displays {
            let name = displayName(for: d) ?? "Unknown (\(d))"
            let item = NSMenuItem(title: "\(name) (ID: \(d))", action: nil, keyEquivalent: "")
            item.tag = Int(d)
            displaySelector.menu?.addItem(item)
            if state.targetDisplayID == d {
                displaySelector.select(item)
            }
        }
        if state.targetDisplayID == nil {
            displaySelector.selectItem(at: -1)
        }

        let enabledCheckbox = NSButton(checkboxWithTitle: "Enabled", target: self, action: #selector(toggleDeviceEnabledFromSettings(_:)))
        enabledCheckbox.state = state.enabled ? NSControl.StateValue.on : NSControl.StateValue.off
        enabledCheckbox.identifier = NSUserInterfaceItemIdentifier(deviceKey)
        enabledCheckbox.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(title)
        container.addSubview(enabledCheckbox)
        container.addSubview(monitorLabel)
        container.addSubview(displaySelector)

        var lastView: NSView = displaySelector

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            enabledCheckbox.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 12),
            enabledCheckbox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            monitorLabel.topAnchor.constraint(equalTo: enabledCheckbox.bottomAnchor, constant: 16),
            monitorLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            displaySelector.topAnchor.constraint(equalTo: monitorLabel.bottomAnchor, constant: 5),
            displaySelector.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
        ])

        let toggles = [
            ("iOS Scroll Mode", "ScrollMode", state.scrollMode),
            ("Restore on Touch Up", "RestoreOnUp", state.restoreOnUp),
            ("Invert X", "InvertX", state.invertX),
            ("Invert Y", "InvertY", state.invertY),
            ("Swap X/Y", "SwapXY", state.swapXY)
        ]

        for (titleText, prefKey, enabled) in toggles {
            let check = NSButton(checkboxWithTitle: titleText, target: self, action: #selector(toggleDevicePrefFromSettings(_:)))
            check.state = enabled ? NSControl.StateValue.on : NSControl.StateValue.off
            check.identifier = NSUserInterfaceItemIdentifier("\(deviceKey)::\(prefKey)")
            check.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(check)
            NSLayoutConstraint.activate([
                check.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: 12),
                check.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16)
            ])
            lastView = check
        }
    }

    @objc func setDeviceDisplayFromSettings(_ sender: NSPopUpButton) {
        guard let deviceKey = sender.identifier?.rawValue,
              let state = activeDeviceStates[deviceKey],
              let selectedItem = sender.selectedItem
        else { return }

        let selectedDisplay = CGDirectDisplayID(selectedItem.tag)
        state.targetDisplayID = selectedDisplay
        state.targetDisplayRect = CGDisplayBounds(selectedDisplay)
        state.savePref("TargetDisplayID", selectedDisplay)
        log("[\(state.name)] Switched display to \(selectedDisplay) via settings")
        delegate?.buildMenu()
    }

    @objc func toggleDevicePrefFromSettings(_ sender: NSButton) {
        guard let identity = sender.identifier?.rawValue else { return }
        let pieces = identity.components(separatedBy: "::")
        guard pieces.count == 2 else {
            log("[SettingsWindowController] invalid toggle identifier: \(identity)")
            return
        }

        let deviceKey = pieces[0]
        let prefKey = pieces[1]
        guard let state = activeDeviceStates[deviceKey] else { return }

        let newValue = (sender.state == NSControl.StateValue.on)
        switch prefKey {
        case "ScrollMode": state.scrollMode = newValue
        case "RestoreOnUp": state.restoreOnUp = newValue
        case "InvertX": state.invertX = newValue
        case "InvertY": state.invertY = newValue
        case "SwapXY": state.swapXY = newValue
        default: break
        }
        state.savePref(prefKey, newValue)
        log("[\(state.name)] Toggled \(prefKey) = \(newValue) via settings")
        delegate?.buildMenu()
    }
}
