// Filename: HomeworkAssistantApp.swift
// 用途:应用入口、原生状态栏左右键分离、强制后台

import SwiftUI
import SwiftData
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var sharedContainer: ModelContainer!
    var statusItem: NSStatusItem?
    var popover: NSPopover?

    override init() {
        super.init()
        do {
            sharedContainer = try ModelContainer(for: HomeworkItem.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()

        DispatchQueue.main.async {
            for window in NSApp.windows {
                if window.identifier?.rawValue == "miniWindow" {
                    window.close()
                }
            }

            let hasMainWindow = NSApp.windows.contains {
                $0.identifier?.rawValue == "mainWindow" && $0.isVisible
            }
            if !hasMainWindow { self.wakeUpApp() }
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowClosed),
            name: NSWindow.willCloseNotification,
            object: nil
        )
    }
    
    func setupMenuBar() {
        guard UserDefaults.standard.bool(forKey: "closeToMenuBar") else { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            // 修复 #1: 使用正确的 AppKit 参数标签 systemSymbolName
            button.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: nil)
            button.action = #selector(statusBarButtonClicked(sender:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let popoverView = MenuBarPopoverView(wakeUpAction: { [weak self] in
            self?.wakeUpApp()
        })
        .modelContainer(sharedContainer)

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 420)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: popoverView)
    }

    @objc func statusBarButtonClicked(sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(
                title: "显示主界面 (Show App)",
                action: #selector(wakeUpApp),
                keyEquivalent: ""
            ))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(
                title: "退出软件 (Quit)",
                action: #selector(quitApp),
                keyEquivalent: "q"
            ))
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            if popover?.isShown == true {
                popover?.performClose(sender)
            } else {
                popover?.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    @objc func windowClosed(notification: Notification) {
        guard let closedWindow = notification.object as? NSWindow else { return }
        let closedID = closedWindow.identifier?.rawValue ?? ""
        guard closedID == "mainWindow" || closedID == "miniWindow" else {
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let activeWindows = NSApplication.shared.windows.filter {
                $0.isVisible && ($0.identifier?.rawValue == "mainWindow" || $0.identifier?.rawValue == "miniWindow")
            }
            
            let closeToMenu = UserDefaults.standard.bool(forKey: "closeToMenuBar")
            
            if activeWindows.isEmpty && closeToMenu {
                NSApp.hide(nil)
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    @objc func wakeUpApp() {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
            let appURL = Bundle.main.bundleURL
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: appURL, configuration: config, completionHandler: nil)
        }
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return !UserDefaults.standard.bool(forKey: "closeToMenuBar")
    }
}


@main
struct HomeworkAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("Homework Assistant", id: "mainWindow") {
            ContentView()
                .modelContainer(appDelegate.sharedContainer)
        }

        // 将窗口修饰符应用于 Window Scene，而不是其内部的 View
        Window("Miniplayer", id: "miniWindow") {
            MiniWidgetView()
                .modelContainer(appDelegate.sharedContainer)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.topTrailing)
    }
}
