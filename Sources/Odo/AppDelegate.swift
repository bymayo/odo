import AppKit
import SwiftUI

class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func open(viewModel: StravaViewModel) {
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Odo Settings"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 420, height: 560))
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = window
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var viewModel: StravaViewModel!
    private var eventMonitor: Any?
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        LegacyMigration.run() // before anything reads settings
        _ = Updater.shared    // starts Sparkle's scheduled checks (Odo.app only)
        setupMainMenu()
        viewModel = StravaViewModel()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = OdoMark.menuBarImage()
            button.imagePosition = .imageLeading
            button.title = " —"
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.behavior = .transient
        // The popover follows PopoverView's own height, which fits its content
        let host = NSHostingController(rootView: PopoverView(viewModel: viewModel))
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host

        // If already authenticated, fetch fresh data (cache was loaded in init)
        if viewModel.isAuthenticated && viewModel.activities.isEmpty {
            Task {
                await viewModel.fetchAllData()
            }
        }

        // Update the menu bar text when data changes
        updateMenuBarText()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMenuBarText()
            }
        }
    }

    @MainActor @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else if let button = statusItem.button {
            // Open on the sport the menu bar shows, whichever tab was left open
            viewModel.selectMenuBarSport()
            // Leave room for the menu bar, the popover's arrow and a margin below
            if let screen = button.window?.screen {
                PopoverLayout.shared.maxHeight = max(screen.visibleFrame.height - 30, 320)
            }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            // Activate the app and make the popover key so text fields get full keyboard support (paste, etc.)
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()

            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.closePopover()
            }
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    /// Accessory apps have no menu bar, so Cmd+C/V/X/A don't work unless
    /// we wire up an Edit menu manually.
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let editItem = NSMenuItem()
        editItem.submenu = {
            let menu = NSMenu(title: "Edit")
            menu.addItem(withTitle: "Undo",       action: Selector(("undo:")),       keyEquivalent: "z")
            menu.addItem(withTitle: "Redo",       action: Selector(("redo:")),       keyEquivalent: "Z")
            menu.addItem(.separator())
            menu.addItem(withTitle: "Cut",        action: #selector(NSText.cut(_:)),        keyEquivalent: "x")
            menu.addItem(withTitle: "Copy",       action: #selector(NSText.copy(_:)),       keyEquivalent: "c")
            menu.addItem(withTitle: "Paste",      action: #selector(NSText.paste(_:)),      keyEquivalent: "v")
            menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)),  keyEquivalent: "a")
            return menu
        }()

        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }

    @MainActor
    private func updateMenuBarText() {
        guard viewModel.isAuthenticated, !viewModel.activities.isEmpty else {
            statusItem.button?.title = " —"
            return
        }
        guard let button = statusItem.button else { return }

        let font = NSFont.menuBarFont(ofSize: 0)
        let title = NSMutableAttributedString(string: " ", attributes: [.font: font])

        // Pace dot: green on/ahead of pace, red behind
        if AppSettings.shared.menuBarShowPace, let onPace = viewModel.menuBarOnPace {
            title.append(NSAttributedString(string: "●", attributes: [
                .font: NSFont.systemFont(ofSize: 7),
                .foregroundColor: onPace ? NSColor.systemGreen : NSColor.systemRed,
                .baselineOffset: 2,
            ]))
            title.append(NSAttributedString(string: " ", attributes: [.font: font]))
        }

        title.append(NSAttributedString(string: viewModel.menuBarText, attributes: [.font: font]))
        button.attributedTitle = title
    }
}
