// Filename: Views/ContentView.swift
// 用途: 主界面框架、导航和数据中枢 — 统一反色弹性撤销胶囊、原生 NSApp 外观继承与列表首帧零闪跳定位

import SwiftUI
import SwiftData
import Combine

struct ContentView: View {
    // MARK: - 统一反色胶囊状态模型
    fileprivate enum ToastUndoAction {
        case aiImport([HomeworkItem])
        case deletedTasks([HomeworkItem])
        case deletedSubject(
            name: String,
            wasManual: Bool,
            colorHex: String?,
            movedTasks: [HomeworkItem],
            wasFiltered: Bool
        )
    }

    fileprivate struct ActiveToast: Identifiable {
        let id = UUID()
        let message: String
        let isError: Bool
        let undoAction: ToastUndoAction?
    }

    static let toastSpring: Animation = .spring(response: 0.35, dampingFraction: 0.78)

    // MARK: - 环境 & 查询
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \HomeworkItem.endDate) private var allItems: [HomeworkItem]

    // MARK: - 管理器
    @StateObject private var subjectManager = SubjectManager()
    @ObservedObject private var aiConfig = AIConfigManager.shared
    @State private var manager = HomeworkManager()

    // MARK: - 导航状态
    @State private var selectedTab: String = "day"
    @State private var subjectFilter: String? = nil

    // MARK: - AI 处理与统一反色 Toast 状态
    @State private var isProcessing: Bool = false
    @State private var activeToast: ActiveToast? = nil
    @State private var toastDismissTask: Task<Void, Never>? = nil

    // MARK: - 日期
    @State private var currentViewingDate: Date = Date()

    // MARK: - Sheet 开关
    @State private var showAPISheet: Bool = false
    @State private var showPrivacySheet: Bool = false
    @State private var showManualAddSheet: Bool = false
    @State private var showAddSubjectSheet: Bool = false
    @State private var addSubjectSheetID = UUID()
    @State private var showRenameSubjectSheet: Bool = false
    @State private var subjectToRename: String = ""

    // MARK: - Alert 开关
    @State private var show401Alert: Bool = false
    @State private var showKeyMissingAlert: Bool = false
    @State private var showDeleteSubjectAlert: Bool = false
    @State private var subjectToDelete: String = ""

    // MARK: - 编辑
    @State private var editingItem: HomeworkItem? = nil

    // MARK: - 开发者模式
    @State private var developerMode: Bool = false
    @State private var logs: [AppLog] = []

    // MARK: - AppStorage 持久化设置
    @AppStorage("appLanguage") private var appLang: AppLanguage = .chinese
    @AppStorage("outputLanguage") private var outputLang: OutputLanguage = .chinese
    @AppStorage("appFontSize") private var appFontSize: AppFontSize = .medium
    @AppStorage("user_groq_api_key") private var groqKey: String = ""
    @AppStorage("user_zhipu_api_key") private var zhipuKey: String = ""
    @AppStorage("preferred_api_provider") private var providerRaw: String = "Groq (Llama 3)"
    @AppStorage("closeToMenuBar") private var closeToMenuBar: Bool = true

    // MARK: - 便捷计算属性
    var isEnglish: Bool { appLang == .english }
    private var isDark: Bool { colorScheme == .dark }

    var allSubjects: [String] {
        let activeItems = allItems.filter { $0.deletedDate == nil }
        let dbSubjects = Set(activeItems.map { $0.subject })
        return Array(dbSubjects.union(subjectManager.manuallyAddedSubjects))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    let dayChangedPublisher = NotificationCenter.default.publisher(for: .NSCalendarDayChanged)

    // MARK: - Body
    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .frame(minWidth: 800, minHeight: 600)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { openWindow(id: "miniWindow") }) {
                    Label(isEnglish ? "Mini Widget" : "悬浮窗", systemImage: "pip.enter")
                }
                .help(isEnglish ? "Open Mini Widget (Always on top)" : "打开桌面悬浮窗 (置顶)")
            }
        }
        .onAppear { cleanTrashOnStart() }
        .onReceive(dayChangedPublisher) { _ in currentViewingDate = Date() }
        .alert(isEnglish ? "API Error" : "API 鉴权错误", isPresented: $show401Alert) {
            Button(isEnglish ? "Open Settings" : "去检查密钥") { showAPISheet = true }
            Button(isEnglish ? "OK" : "确定", role: .cancel) {}
        } message: {
            Text(
                isEnglish
                    ? "401 Unauthorized. Please check your API Key."
                    : "401 鉴权失败，请检查当前引擎的 API Key 是否正确。"
            )
        }
        .alert(isEnglish ? "API Key Missing" : "未填写 API Key", isPresented: $showKeyMissingAlert) {
            Button(isEnglish ? "Enter Key" : "去填写") { showAPISheet = true }
            Button(isEnglish ? "Cancel" : "取消", role: .cancel) {}
        } message: {
            Text(isEnglish ? "Do you want to open API settings?" : "是否跳转到 AI 引擎配置窗口?")
        }
        .alert(isEnglish ? "Delete Subject?" : "确认删除学科?", isPresented: $showDeleteSubjectAlert) {
            Button(isEnglish ? "Cancel" : "取消", role: .cancel) {}
            Button(isEnglish ? "Delete" : "删除", role: .destructive) {
                performDeleteSubject(subjectToDelete)
            }
        } message: {
            Text(
                isEnglish
                    ? "All assignments under this subject will be moved to Recycle Bin."
                    : "确认后，该学科下的所有作业将被移至回收站（可立即点击撤销恢复）。"
            )
        }
        .sheet(isPresented: $showAPISheet) {
            AIEngineManagerSheet(
                preferredProviderRaw: $providerRaw,
                groqKey: $groqKey,
                zhipuKey: $zhipuKey,
                isEnglish: isEnglish
            )
        }
        .sheet(isPresented: $showPrivacySheet) {
            PrivacyView(isPresented: $showPrivacySheet, language: appLang)
        }
        .sheet(item: $editingItem) { item in
            EditHomeworkSheet(item: item, allSubjects: allSubjects, isEnglish: isEnglish)
        }
        .sheet(isPresented: $showAddSubjectSheet) {
            AddSubjectSheet(isEnglish: isEnglish, initialZh: "") { en, zh in
                let name = "\(zh) \(en)".trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { subjectManager.addSubject(name) }
            }
        }
        .id(addSubjectSheetID)
        .sheet(isPresented: $showRenameSubjectSheet) {
            RenameSubjectSheet(
                oldName: subjectToRename,
                isEnglish: isEnglish,
                onRename: { en, zh in
                    let name = "\(zh) \(en)".trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { performSubjectRename(from: subjectToRename, to: name) }
                },
                onDelete: {
                    subjectToDelete = subjectToRename
                    showDeleteSubjectAlert = true
                }
            )
        }
        .sheet(isPresented: $showManualAddSheet) {
            ManualAddSheet(
                isEnglish: isEnglish,
                contextDate: currentViewingDate,
                contextSubject: subjectFilter,
                allSubjects: allSubjects,
                subjectManager: subjectManager
            )
        }
    }

    // MARK: - 侧边栏
    @ViewBuilder var sidebarContent: some View {
        List {
            Section(header: Text(isEnglish ? "Views" : "视图").scaledFont(size: 11, weight: .bold)) {
                SidebarRow(title: isEnglish ? "Today" : "当天查看", icon: "calendar", isSelected: selectedTab == "day") {
                    selectedTab = "day"; subjectFilter = nil
                }
                SidebarRow(title: isEnglish ? "List View" : "列表查看", icon: "list.bullet.rectangle", isSelected: selectedTab == "calendar") {
                    selectedTab = "calendar"; subjectFilter = nil
                }
                SidebarRow(title: isEnglish ? "Manage" : "作业管理", icon: "list.bullet.clipboard", isSelected: selectedTab == "manage") {
                    selectedTab = "manage"; subjectFilter = nil
                }
                SidebarRow(title: isEnglish ? "Recycle Bin" : "回收站", icon: "trash", isSelected: selectedTab == "trash") {
                    selectedTab = "trash"; subjectFilter = nil
                }
            }

            Section(header: Text(isEnglish ? "Subjects" : "科目筛选").scaledFont(size: 11, weight: .bold)) {
                ForEach(allSubjects, id: \.self) { subject in
                    SidebarRow(
                        title: subject,
                        icon: "tag.fill",
                        color: subjectManager.getColor(for: subject),
                        isSelected: subjectFilter == subject
                    ) {
                        subjectFilter = subject
                        selectedTab = "day"
                    }
                    .contextMenu {
                        Button(isEnglish ? "Rename" : "重命名") {
                            subjectToRename = subject
                            showRenameSubjectSheet = true
                        }
                        Divider()
                        Button(role: .destructive) {
                            subjectToDelete = subject
                            showDeleteSubjectAlert = true
                        } label: {
                            Text(isEnglish ? "Delete Subject" : "删除学科")
                        }
                    }
                }
                Button(action: {
                    addSubjectSheetID = UUID()
                    showAddSubjectSheet = true
                }) {
                    HStack {
                        Image(systemName: "plus").frame(width: 20, alignment: .center)
                        Text(isEnglish ? "Add Subject" : "新建学科").scaledFont(size: 14)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(isDark ? Color(red: 0.38, green: 0.68, blue: 1.0) : .blue)
            }

            Section {
                SidebarRow(title: isEnglish ? "Settings" : "设置", icon: "gear", isSelected: selectedTab == "settings") {
                    selectedTab = "settings"
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 220, ideal: 250)
    }
}

extension ContentView {
    // MARK: - 主内容区
    @ViewBuilder var detailContent: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if let filter = subjectFilter {
                    let filterColor = subjectManager.getColor(for: filter)
                    HStack(spacing: 8) {
                        Image(systemName: "tag.fill")
                            .foregroundStyle(filterColor)
                        Text(isEnglish ? "Filter: \(filter)" : "当前筛选: \(filter)")
                            .scaledFont(size: 16, weight: .bold)
                        Spacer()
                        Button(isEnglish ? "Clear" : "清除") {
                            subjectFilter = nil
                            selectedTab = "day"
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(filterColor.opacity(isDark ? 0.18 : 0.10))
                    Divider()
                }

                Group {
                    switch selectedTab {
                    case "day":
                        DayView(
                            currentDate: $currentViewingDate,
                            allItems: allItems,
                            subjectManager: subjectManager,
                            isEnglish: isEnglish,
                            subjectFilter: subjectFilter,
                            onEdit: { item in editingItem = item },
                            onDelete: { item in handleTasksDeleted([item]) }
                        )
                    case "calendar":
                        CalendarListView(
                            currentDate: $currentViewingDate,
                            allItems: allItems,
                            language: appLang,
                            subjectManager: subjectManager,
                            subjectFilter: subjectFilter,
                            onEdit: { item in editingItem = item },
                            onDelete: { item in handleTasksDeleted([item]) }
                        )
                    case "manage":
                        TaskManagementView(
                            items: allItems,
                            isEnglish: isEnglish,
                            language: appLang,
                            allSubjects: allSubjects,
                            onEdit: { item in editingItem = item },
                            onItemsDeleted: { deleted in handleTasksDeleted(deleted) }
                        )
                    case "trash":
                        RecycleBinView(
                            items: allItems,
                            isEnglish: isEnglish,
                            language: appLang,
                            allSubjects: allSubjects
                        )
                    case "settings":
                        SettingsView(
                            appLang: $appLang,
                            outputLang: $outputLang,
                            developerMode: $developerMode,
                            groqKey: $groqKey,
                            zhipuKey: $zhipuKey,
                            preferredProviderRaw: $providerRaw,
                            closeToMenuBar: $closeToMenuBar,
                            subjectManager: subjectManager,
                            showAPISheet: $showAPISheet,
                            showPrivacySheet: $showPrivacySheet,
                            allSubjects: allSubjects
                        )
                    default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Spacer().frame(height: developerMode ? 200 : (selectedTab == "settings" ? 0 : 80))
            }

            // 底部悬浮区：反色撤销胶囊 + AI 输入栏 + 开发者控制台
            VStack(spacing: 10) {
                if let toast = activeToast {
                    InvertedToastCapsule(
                        message: toast.message,
                        undoTitle: toast.undoAction != nil ? (isEnglish ? "Undo" : "撤销") : nil,
                        isError: toast.isError,
                        onUndo: toast.undoAction != nil ? { performToastUndo(toast) } : nil
                    )
                    .id(toast.id)
                    .padding(.bottom, selectedTab == "settings" ? 18 : 2)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
                }

                if selectedTab != "settings" {
                    InputBar(
                        isProcessing: isProcessing,
                        isEnglish: isEnglish,
                        hasApiKey: aiConfig.hasAnyReadyProvider,
                        onSubmitText: { submittedText, clearDraft in
                            sendMessage(text: submittedText, onSuccessClear: clearDraft)
                        },
                        onMissingKeyTap: { showKeyMissingAlert = true },
                        onManualAddTap: { showManualAddSheet = true },
                        onOpenEngineSettings: { showAPISheet = true }
                    )
                    .padding(.bottom, 10)
                }

                if developerMode {
                    DeveloperConsoleView(logs: logs, clearAction: { logs.removeAll() })
                        .frame(height: 160)
                        .transition(.move(edge: .bottom))
                }
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: - 统一反色胶囊调度与全场景撤销

    private func presentToast(
        message: String,
        isError: Bool = false,
        undoAction: ToastUndoAction? = nil,
        duration: Double = 4.0
    ) {
        toastDismissTask?.cancel()
        let nextToast = ActiveToast(message: message, isError: isError, undoAction: undoAction)
        withAnimation(Self.toastSpring) {
            activeToast = nextToast
        }
        let currentID = nextToast.id
        toastDismissTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            if activeToast?.id == currentID {
                withAnimation(Self.toastSpring) {
                    activeToast = nil
                }
            }
        }
    }

    private func performToastUndo(_ toast: ActiveToast) {
        guard let action = toast.undoAction else { return }
        toastDismissTask?.cancel()

        switch action {
        case .aiImport(let items):
            let count = items.count
            withAnimation(Self.toastSpring) {
                for item in items {
                    modelContext.delete(item)
                }
            }
            try? modelContext.save()
            logs.append(AppLog(type: .info, message: "Undid \(count) tasks"))
            presentToast(
                message: isEnglish ? "Undid \(count) task(s)" : "已撤销添加 \(count) 项作业",
                duration: 2.2
            )

        case .deletedTasks(let items):
            let count = items.count
            withAnimation(Self.toastSpring) {
                for item in items {
                    item.deletedDate = nil
                }
            }
            try? modelContext.save()
            presentToast(
                message: isEnglish
                    ? "Restored \(count) task(s)"
                    : (count == 1 ? "已恢复作业" : "已恢复 \(count) 项作业"),
                duration: 2.2
            )

        case .deletedSubject(let name, let wasManual, let colorHex, let movedTasks, let wasFiltered):
            withAnimation(Self.toastSpring) {
                if wasManual {
                    subjectManager.addSubject(name)
                }
                if let hex = colorHex {
                    subjectManager.setColor(for: name, color: Color(hex: hex))
                }
                for item in movedTasks {
                    item.deletedDate = nil
                }
                if wasFiltered {
                    subjectFilter = name
                }
            }
            try? modelContext.save()
            presentToast(
                message: isEnglish ? "Restored \"\(name)\"" : "已恢复学科「\(name)」",
                duration: 2.2
            )
        }
    }

    // MARK: - 删除与学科管理业务操作

    func handleTasksDeleted(_ tasks: [HomeworkItem]) {
        guard !tasks.isEmpty else { return }
        let now = Date()
        withAnimation(Self.toastSpring) {
            for item in tasks {
                item.deletedDate = now
            }
        }
        try? modelContext.save()

        let msg: String
        if tasks.count == 1 {
            msg = isEnglish ? "Moved to Recycle Bin" : "已移至回收站"
        } else {
            msg = isEnglish
                ? "Moved \(tasks.count) tasks to Recycle Bin"
                : "已将 \(tasks.count) 项作业移至回收站"
        }
        presentToast(
            message: msg,
            undoAction: .deletedTasks(tasks),
            duration: 4.5
        )
    }

    func performDeleteSubject(_ subject: String) {
        let wasManual = subjectManager.manuallyAddedSubjects.contains(subject)
        let savedColorHex = subjectManager.subjectColors[subject]
        let itemsToMove = allItems.filter { $0.subject == subject && $0.deletedDate == nil }
        let wasFiltered = (subjectFilter == subject)
        let now = Date()

        withAnimation(Self.toastSpring) {
            subjectManager.removeSubject(subject)
            for item in itemsToMove {
                item.deletedDate = now
            }
            if wasFiltered {
                subjectFilter = nil
            }
        }
        try? modelContext.save()

        let msg: String
        if itemsToMove.isEmpty {
            msg = isEnglish ? "Deleted \"\(subject)\"" : "已删除学科「\(subject)」"
        } else {
            msg = isEnglish
                ? "Deleted \"\(subject)\" (\(itemsToMove.count) moved to Trash)"
                : "已删除「\(subject)」，\(itemsToMove.count) 项移至回收站"
        }
        presentToast(
            message: msg,
            undoAction: .deletedSubject(
                name: subject,
                wasManual: wasManual,
                colorHex: savedColorHex,
                movedTasks: itemsToMove,
                wasFiltered: wasFiltered
            ),
            duration: 5.0
        )
    }

    func performSubjectRename(from old: String, to new: String) {
        subjectManager.renameSubject(from: old, to: new)
        let itemsToUpdate = allItems.filter { $0.subject == old }
        for item in itemsToUpdate { item.subject = new }
        try? modelContext.save()
        if subjectFilter == old { subjectFilter = new }
    }

    func cleanTrashOnStart() {
        let now = Date()
        let trashItems = allItems.filter { $0.deletedDate != nil }
        for item in trashItems {
            if let date = item.deletedDate, now.timeIntervalSince(date) > 7 * 24 * 3600 {
                modelContext.delete(item)
            }
        }
    }

    func sendMessage(text: String, onSuccessClear: @escaping () -> Void) {
        guard !text.isEmpty else { return }
        toastDismissTask?.cancel()
        isProcessing = true
        withAnimation(Self.toastSpring) {
            activeToast = nil
        }
        logs.append(AppLog(type: .info, message: "UI: Submit"))

        Task {
            do {
                let added = try await manager.processInput(
                    text: text,
                    outputLang: outputLang.displayName,
                    modelContext: modelContext,
                    onLog: { log in logs.append(log) }
                )
                onSuccessClear()
                if added.isEmpty {
                    presentToast(
                        message: isEnglish
                            ? "No new tasks added (already exists or empty)"
                            : "未新增作业（内容已存在或无可提取项）",
                        duration: 3.2
                    )
                } else {
                    presentToast(
                        message: isEnglish
                            ? "Added \(added.count) task(s)"
                            : "已添加 \(added.count) 项作业",
                        undoAction: .aiImport(added),
                        duration: 5.0
                    )
                }
            } catch let error as LLMError {
                presentToast(
                    message: error.localizedDescription,
                    isError: true,
                    duration: 4.5
                )
                logs.append(AppLog(type: .error, message: "Error: \(error.localizedDescription)"))
                if case .invalidKey = error { show401Alert = true }
            } catch {
                presentToast(
                    message: error.localizedDescription,
                    isError: true,
                    duration: 4.5
                )
            }
            isProcessing = false
        }
    }
}

// MARK: - 当日视图
private struct DayView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var currentDate: Date
    var allItems: [HomeworkItem]
    @ObservedObject var subjectManager: SubjectManager
    var isEnglish: Bool
    var subjectFilter: String?
    var onEdit: (HomeworkItem) -> Void
    var onDelete: (HomeworkItem) -> Void

    @State private var showDatePicker = false

    private var isDark: Bool { colorScheme == .dark }
    private var adaptiveBlue: Color { isDark ? Color(red: 0.38, green: 0.68, blue: 1.0) : .blue }

    private var displayItems: [HomeworkItem] {
        let activeItems = allItems.filter { $0.isActiveOn(date: currentDate) && $0.deletedDate == nil }
        let filteredBySubject = subjectFilter == nil ? activeItems : activeItems.filter { $0.subject == subjectFilter }
        return filteredBySubject.scrSorted(for: currentDate, isEnglish: isEnglish)
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: isEnglish ? "en" : "zh-Hans")
        f.dateStyle = .full
        return f
    }

    private func changeDay(by value: Int) {
        currentDate = Calendar.current.date(byAdding: .day, value: value, to: currentDate) ?? currentDate
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 20) {
                    Button(action: { changeDay(by: -1) }) {
                        Image(systemName: "chevron.left").font(.title2)
                    }
                    .buttonStyle(.plain)

                    Text(dateFormatter.string(from: currentDate))
                        .scaledFont(size: 16, weight: .bold)
                        .frame(minWidth: 180, alignment: .center)

                    Button(action: { changeDay(by: 1) }) {
                        Image(systemName: "chevron.right").font(.title2)
                    }
                    .buttonStyle(.plain)
                }

                HStack {
                    Button(action: { showDatePicker.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text(isEnglish ? "Select Date" : "选择日期").scaledFont(size: 14)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(adaptiveBlue)
                    .popover(isPresented: $showDatePicker, arrowEdge: .bottom) {
                        DatePicker("", selection: $currentDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding()
                            .frame(width: 280)
                    }

                    Spacer()

                    let isToday = Calendar.current.isDateInToday(currentDate)
                    Button(action: { currentDate = Date() }) {
                        HStack(spacing: 4) {
                            Image(systemName: isToday ? "checkmark.circle.fill" : "arrow.uturn.backward.circle")
                            Text(isToday ? (isEnglish ? "Today" : "当前: 今天") : (isEnglish ? "Back to Today" : "回到今天"))
                                .scaledFont(size: 14)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isToday ? .green : adaptiveBlue)
                    .disabled(isToday)
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            if displayItems.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text(isEnglish ? "No assignments for this day" : "当日无任务")
                        .scaledFont(size: 14)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(displayItems) { item in
                            HomeworkRowCard(
                                task: item,
                                subjectManager: subjectManager,
                                onEdit: onEdit,
                                viewedDate: currentDate,
                                isEnglish: isEnglish,
                                onDelete: onDelete
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - 列表视图（预定位到当日后再显示，彻底消除首帧闪跳与“弹一下”问题）
struct CalendarListView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var currentDate: Date
    var allItems: [HomeworkItem]
    var language: AppLanguage
    @ObservedObject var subjectManager: SubjectManager
    var subjectFilter: String?
    var onEdit: (HomeworkItem) -> Void
    var onDelete: (HomeworkItem) -> Void

    @State private var isInitialScrollReady: Bool = false

    private var isEnglish: Bool { language == .english }
    private var isDark: Bool { colorScheme == .dark }

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    struct RenderTask: Identifiable {
        let id: String
        let task: HomeworkItem
    }

    struct RenderSection: Identifiable {
        let id: String
        let date: Date
        let tasks: [RenderTask]
        let isToday: Bool
        let isCurrentDay: Bool
    }

    private var preparedSections: [RenderSection] {
        let cal = Calendar.current
        let formatter = Self.dayKeyFormatter
        let midnightCurrent = cal.startOfDay(for: currentDate)

        let activeItems = allItems.filter { $0.deletedDate == nil }
        let filteredItems = subjectFilter == nil ? activeItems : activeItems.filter { $0.subject == subjectFilter }

        let minDate = filteredItems.map { cal.startOfDay(for: $0.startDate) }.min() ?? midnightCurrent
        let maxDate = filteredItems.map { cal.startOfDay(for: $0.endDate) }.max() ?? midnightCurrent

        let startDate = cal.startOfDay(for: min(minDate, cal.date(byAdding: .day, value: -7, to: midnightCurrent)!))
        let endDate = cal.startOfDay(for: max(maxDate, cal.date(byAdding: .day, value: 14, to: midnightCurrent)!))

        var dateArray: [Date] = []
        var runDate = startDate
        while runDate <= endDate {
            dateArray.append(runDate)
            if let next = cal.date(byAdding: .day, value: 1, to: runDate) {
                runDate = cal.startOfDay(for: next)
            } else { break }
        }
        dateArray.reverse()

        var tempGroup = [String: [HomeworkItem]]()

        for item in filteredItems {
            let itemStart = cal.startOfDay(for: item.startDate)
            let itemEnd = cal.startOfDay(for: item.endDate)

            var loopDate = itemStart
            while loopDate <= itemEnd {
                if loopDate >= startDate && loopDate <= endDate {
                    let key = formatter.string(from: loopDate)
                    tempGroup[key, default: []].append(item)
                }
                guard let next = cal.date(byAdding: .day, value: 1, to: loopDate) else { break }
                loopDate = cal.startOfDay(for: next)
            }
        }

        var sections: [RenderSection] = []
        for date in dateArray {
            let key = formatter.string(from: date)
            let isCurrentDay = cal.isDate(date, inSameDayAs: midnightCurrent)
            let isToday = cal.isDateInToday(date)

            let dayTasks = tempGroup[key] ?? []
            let sortedTasks = dayTasks.isEmpty ? [] : dayTasks.scrSorted(for: date, isEnglish: isEnglish)

            let uniqueRenderTasks = sortedTasks.map { task in
                RenderTask(
                    id: "\(key)-\(task.persistentModelID.hashValue)",
                    task: task
                )
            }

            if !uniqueRenderTasks.isEmpty || isToday || isCurrentDay {
                sections.append(
                    RenderSection(
                        id: key,
                        date: date,
                        tasks: uniqueRenderTasks,
                        isToday: isToday,
                        isCurrentDay: isCurrentDay
                    )
                )
            }
        }

        return sections
    }

    var body: some View {
        let sectionsToRender = preparedSections
        let cal = Calendar.current
        let midnightCurrent = cal.startOfDay(for: currentDate)

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 15, pinnedViews: [.sectionHeaders]) {
                    ForEach(sectionsToRender) { section in
                        Section(header: DateHeader(date: section.date, language: language)) {
                            if section.tasks.isEmpty {
                                VStack(spacing: 5) {
                                    Text(isEnglish ? "No Homework" : "无作业")
                                        .scaledFont(size: 13)
                                        .foregroundStyle(.secondary)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.035))
                                        )
                                }
                            } else {
                                ForEach(section.tasks) { renderTask in
                                    HomeworkRowCard(
                                        task: renderTask.task,
                                        subjectManager: subjectManager,
                                        onEdit: onEdit,
                                        viewedDate: section.date,
                                        isEnglish: isEnglish,
                                        onDelete: onDelete
                                    )
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .opacity(isInitialScrollReady ? 1 : 0)
            .onAppear {
                let targetID = sectionsToRender.first(where: { cal.isDate($0.date, inSameDayAs: midnightCurrent) })?.id
                if let targetID {
                    var tx = Transaction()
                    tx.disablesAnimations = true
                    withTransaction(tx) {
                        proxy.scrollTo(targetID, anchor: .top)
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(25))
                        var tx2 = Transaction()
                        tx2.disablesAnimations = true
                        withTransaction(tx2) {
                            proxy.scrollTo(targetID, anchor: .top)
                            isInitialScrollReady = true
                        }
                    }
                } else {
                    isInitialScrollReady = true
                }
            }
        }
    }
}
