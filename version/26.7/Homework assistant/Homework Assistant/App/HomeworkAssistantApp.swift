// Filename: HomeworkAssistantApp.swift
// 用途: 应用入口、原生状态栏左右键分离、关闭小窗自动拉起大窗与零延迟全局外观同步

import SwiftUI
import SwiftData
import AppKit

extension Notification.Name {
    static let appAppearanceDidChange = Notification.Name("HomeworkAssistant.appAppearanceDidChange")
    static let closeToMenuBarDidChange = Notification.Name("HomeworkAssistant.closeToMenuBarDidChange")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var sharedContainer: ModelContainer!
    var statusItem: NSStatusItem?
    var popover: NSPopover?

    /// 由 SwiftUI 根视图注入的原生主窗口打开动作（0 延迟重建被关闭的主窗口）
    var openMainWindowAction: (() -> Void)?

    private var lastAppliedEffectiveName: NSAppearance.Name? = nil
    private var lastCloseToMenuBarState: Bool? = nil
    private var isTerminating: Bool = false
    private var suppressWindowCloseHandling: Bool = false
    private var isReopeningMainFromMiniClose: Bool = false

    override init() {
        super.init()
        UserDefaults.standard.register(defaults: [
            "closeToMenuBar": true,
            "appAppearance": AppAppearance.system.rawValue
        ])
        do {
            sharedContainer = try ModelContainer(for: HomeworkItem.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
        }
    }

    // MARK: - 窗口身份识别（兼容 SwiftUI WindowGroup 自动生成的 "mainWindow-AppWindow-1" 后缀）

    private func isMainWindow(_ window: NSWindow) -> Bool {
        guard !window.isSheet, let raw = window.identifier?.rawValue else { return false }
        return raw == "mainWindow" || raw.hasPrefix("mainWindow-")
    }

    private func isMiniWindow(_ window: NSWindow) -> Bool {
        guard !window.isSheet, let raw = window.identifier?.rawValue else { return false }
        return raw == "miniWindow" || raw.hasPrefix("miniWindow-")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyCurrentAppearance(force: true)
        syncMenuBarState(force: true)

        DispatchQueue.main.async {
            self.suppressWindowCloseHandling = true
            for window in NSApp.windows where self.isMiniWindow(window) {
                window.close()
            }
            self.suppressWindowCloseHandling = false

            let hasMainWindow = NSApp.windows.contains {
                self.isMainWindow($0) && ($0.isVisible || $0.isMiniaturized)
            }
            if !hasMainWindow {
                self.wakeUpApp()
            }
            self.applyCurrentAppearance(force: true)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowClosed),
            name: NSWindow.willCloseNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppearanceNotification(_:)),
            name: .appAppearanceDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMenuBarNotification),
            name: .closeToMenuBarDidChange,
            object: nil
        )
        // 监听 macOS 系统本身在控制中心 / 系统设置中切换深浅色
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(systemInterfaceThemeDidChange),
            name: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
    }

    // MARK: - 零杂交全局外观同步（始终使用具名 .aqua / .darkAqua 触发原子刷新）

    private static var currentMacSystemAppearanceName: NSAppearance.Name {
        let isSystemDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        return isSystemDark ? .darkAqua : .aqua
    }

    @objc private func systemInterfaceThemeDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.applyCurrentAppearance(force: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.applyCurrentAppearance(force: true)
        }
    }

    @objc private func handleAppearanceNotification(_ notification: Notification) {
        if let raw = notification.object as? String,
           let mode = AppAppearance(rawValue: raw) {
            applyCurrentAppearance(mode: mode, force: true)
        } else {
            applyCurrentAppearance(force: true)
        }
    }

    @objc private func handleMenuBarNotification() {
        syncMenuBarState(force: true)
    }

    @objc private func userDefaultsDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.applyCurrentAppearance()
            self?.syncMenuBarState()
        }
    }

    func applyCurrentAppearance(mode: AppAppearance? = nil, force: Bool = false) {
        let resolvedMode: AppAppearance = mode ?? {
            let raw = UserDefaults.standard.string(forKey: "appAppearance") ?? AppAppearance.system.rawValue
            return AppAppearance(rawValue: raw) ?? .system
        }()

        let targetName: NSAppearance.Name
        switch resolvedMode {
        case .system:
            targetName = Self.currentMacSystemAppearanceName
        case .light:
            targetName = .aqua
        case .dark:
            targetName = .darkAqua
        }

        if !force, targetName == lastAppliedEffectiveName { return }
        lastAppliedEffectiveName = targetName

        let concreteAppearance = NSAppearance(named: targetName)

        for window in NSApp.windows where window.appearance != nil {
            window.appearance = nil
        }

        NSApp.appearance = concreteAppearance
        popover?.appearance = concreteAppearance

        for window in NSApp.windows where window.isVisible {
            window.invalidateShadow()
            window.contentView?.needsLayout = true
            window.contentView?.needsDisplay = true
        }
    }

    // MARK: - 状态栏图标动态启停

    func syncMenuBarState(force: Bool = false) {
        let shouldShow = UserDefaults.standard.bool(forKey: "closeToMenuBar")
        if !force, shouldShow == lastCloseToMenuBarState { return }
        lastCloseToMenuBarState = shouldShow

        if shouldShow {
            if statusItem == nil {
                setupMenuBar()
            }
        } else {
            popover?.performClose(nil)
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
            }
            statusItem = nil
            popover = nil
            NSApp.setActivationPolicy(.regular)
        }
    }

    func setupMenuBar() {
        guard UserDefaults.standard.bool(forKey: "closeToMenuBar"), statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let isEnglish = UserDefaults.standard.string(forKey: "appLanguage") == AppLanguage.english.rawValue
            button.image = NSImage(
                systemSymbolName: "checklist",
                accessibilityDescription: isEnglish ? "Homework Assistant" : "作业助手"
            )
            button.target = self
            button.action = #selector(statusBarButtonClicked(sender:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item

        let popoverView = MenuBarPopoverBridgeView(appDelegate: self)
            .modelContainer(sharedContainer)

        let pop = NSPopover()
        pop.contentSize = NSSize(width: 320, height: 420)
        pop.behavior = .transient
        pop.appearance = NSApp.appearance
        pop.contentViewController = NSHostingController(rootView: popoverView)
        popover = pop
    }

    @objc func statusBarButtonClicked(sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        let isEnglish = UserDefaults.standard.string(forKey: "appLanguage") == AppLanguage.english.rawValue

        if event.type == .rightMouseUp {
            let menu = NSMenu()
            let wakeItem = NSMenuItem(
                title: isEnglish ? "Show Main Window" : "显示主界面",
                action: #selector(wakeUpApp),
                keyEquivalent: ""
            )
            wakeItem.target = self
            menu.addItem(wakeItem)

            menu.addItem(NSMenuItem.separator())

            let quitItem = NSMenuItem(
                title: isEnglish ? "Quit Homework Assistant" : "退出作业助手",
                action: #selector(quitApp),
                keyEquivalent: "q"
            )
            quitItem.target = self
            menu.addItem(quitItem)

            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            if popover?.isShown == true {
                popover?.performClose(sender)
            } else {
                popover?.appearance = NSApp.appearance
                popover?.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    // MARK: - 窗口关闭流转逻辑（关小窗 -> 自动拉起大窗；关大窗且无小窗 -> 退至菜单栏）

    @objc func windowClosed(notification: Notification) {
        guard !isTerminating, !suppressWindowCloseHandling else { return }
        guard let closedWindow = notification.object as? NSWindow else { return }

        // 1. 用户关闭悬浮小窗：自动恢复并打开主窗口，无需去顶部菜单栏重开
        if isMiniWindow(closedWindow) {
            isReopeningMainFromMiniClose = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                guard let self, !self.isTerminating else { return }
                self.wakeUpApp()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.isReopeningMainFromMiniClose = false
                }
            }
            return
        }

        // 2. 用户关闭主窗口：若悬浮小窗还开着则保留小窗；若无任何窗口且开启驻留则退至菜单栏
        guard isMainWindow(closedWindow) else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self, !self.isTerminating else { return }

            let remainingWindows = NSApplication.shared.windows.filter { window in
                window !== closedWindow &&
                (window.isVisible || window.isMiniaturized) &&
                (self.isMainWindow(window) || self.isMiniWindow(window))
            }

            let closeToMenu = UserDefaults.standard.bool(forKey: "closeToMenuBar")
            if remainingWindows.isEmpty && closeToMenu {
                NSApp.hide(nil)
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    @objc func wakeUpApp() {
        guard !isTerminating else { return }
        NSApp.setActivationPolicy(.regular)
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, !self.isTerminating else { return }
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)

            if let existingMain = NSApp.windows.first(where: { self.isMainWindow($0) && $0.isVisible }) {
                existingMain.makeKeyAndOrderFront(nil)
            } else if let miniMain = NSApp.windows.first(where: { self.isMainWindow($0) && $0.isMiniaturized }) {
                miniMain.deminiaturize(nil)
                miniMain.makeKeyAndOrderFront(nil)
            } else if let openMain = self.openMainWindowAction {
                openMain()
                self.applyCurrentAppearance(force: true)
            } else {
                let appURL = Bundle.main.bundleURL
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                NSWorkspace.shared.openApplication(at: appURL, configuration: config, completionHandler: nil)
            }
        }
    }

    @objc func quitApp() {
        isTerminating = true
        NSApplication.shared.terminate(nil)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        isTerminating = true
        return .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        if isReopeningMainFromMiniClose {
            return false
        }
        return !UserDefaults.standard.bool(forKey: "closeToMenuBar")
    }
}

// MARK: - SwiftUI openWindow 桥接包装器

private struct MainWindowBridgeView: View {
    @Environment(\.openWindow) private var openWindow
    let appDelegate: AppDelegate

    var body: some View {
        ContentView()
            .onAppear {
                appDelegate.openMainWindowAction = {
                    openWindow(id: "mainWindow")
                }
            }
    }
}

private struct MenuBarPopoverBridgeView: View {
    @Environment(\.openWindow) private var openWindow
    weak var appDelegate: AppDelegate?

    var body: some View {
        MenuBarPopoverView(wakeUpAction: {
            appDelegate?.wakeUpApp()
        })
        .onAppear {
            appDelegate?.openMainWindowAction = {
                openWindow(id: "mainWindow")
            }
        }
    }
}

@main
struct HomeworkAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("Homework Assistant", id: "mainWindow") {
            MainWindowBridgeView(appDelegate: appDelegate)
                .modelContainer(appDelegate.sharedContainer)
        }

        Window("Miniplayer", id: "miniWindow") {
            MiniWidgetView()
                .modelContainer(appDelegate.sharedContainer)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.topTrailing)
    }
}
