import AppKit

/// Menu-bar menu. Only the capture rows carry icons, where they tell three similar
/// items apart. Settings, About and Quit are standard items and stay text-only, like
/// Apple menus. Capture shortcuts are user-editable in Settings, so only the fixed
/// Settings and Quit keys show. Launch at Login lives in Settings under App.
/// Check for Updates appears only when a build carries an update feed.
@MainActor
final class StatusMenu: NSObject {
    private let coordinator: Coordinator
    private let checkForUpdates: (() -> Void)?
    private var statusItem: NSStatusItem?
    let menu: NSMenu

    init(coordinator: Coordinator, checkForUpdates: (() -> Void)? = nil, statusItem: NSStatusItem? = nil) {
        self.coordinator = coordinator
        self.checkForUpdates = checkForUpdates
        self.statusItem = statusItem
        self.menu = NSMenu()
        super.init()

        statusItem?.button?.image = BundledIcon.image("snimach-mark")
        statusItem?.button?.image?.accessibilityDescription = "Snimach"

        menu.addItem(item("Capture Area", #selector(captureArea), icon: "crop-linear"))
        menu.addItem(item("Capture Window", #selector(captureWindow), icon: "window-frame-linear"))
        menu.addItem(item("Capture Screen", #selector(captureScreen), icon: "monitor-linear"))
        menu.addItem(.separator())
        menu.addItem(item("Settings…", #selector(showSettings), key: ","))
        if checkForUpdates != nil {
            menu.addItem(item("Check for Updates…", #selector(checkForUpdatesAction)))
        }
        menu.addItem(item("About Snimach", #selector(showAbout)))
        menu.addItem(.separator())
        menu.addItem(item("Quit Snimach", #selector(quit), key: "q"))
        if let statusItem {
            statusItem.menu = menu
        } else if NSClassFromString("XCTestCase") == nil {
            let created = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            created.button?.image = BundledIcon.image("snimach-mark")
            created.button?.image?.accessibilityDescription = "Snimach"
            created.menu = menu
            self.statusItem = created
        }
    }

    private func item(_ title: String, _ action: Selector, key: String = "", icon: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        if let icon, let image = BundledIcon.image(icon) {
            image.size = NSSize(width: 16, height: 16)
            image.accessibilityDescription = icon
            item.image = image
        }
        return item
    }

    @objc private func captureArea() {
        coordinator.capture(.area)
    }

    @objc private func captureWindow() {
        coordinator.capture(.activeWindow())
    }

    @objc private func captureScreen() {
        coordinator.capture(.fullScreen)
    }

    @objc private func showSettings() {
        coordinator.showSettings()
    }

    @objc private func showAbout() {
        coordinator.showAbout()
    }

    @objc private func checkForUpdatesAction() {
        checkForUpdates?()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
