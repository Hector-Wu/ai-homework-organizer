// Filename: Views/ContentView.swift
// 用途: 主界面框架、导航和数据中枢

import SwiftUI
import SwiftData
import Combine

struct ContentView: View {
    // MARK: - 环境 & 查询
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \HomeworkItem.endDate) private var allItems: [HomeworkItem]

    // MARK: - 管理器
    @StateObject private var subjectManager = SubjectManager()
    @State private var manager = HomeworkManager()
    
    // MARK: - 导航状态
    @State private var selectedTab: String = "day"
    @State private var subjectFilter: String? = nil
    
    // MARK: - AI 输入状态
    @State private var inputText: String = ""
    @State private var isProcessing: Bool = false
    @State private var statusMessage: String? = nil
    @State private var isError: Bool = false
    
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

    // MARK: - Toast
    @State private var showSubjectDeletedToast: Bool = false
    
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
        .alert(isEnglish ? "API Error" : "API 错误", isPresented: $show401Alert) {
            Button("OK", role: .cancel) {}
        } message: { Text("401 Unauthorized. Check your API Key.") }
        .alert(isEnglish ? "API Key Missing" : "未填写 API Key", isPresented: $showKeyMissingAlert) {
            Button(isEnglish ? "Enter Key" : "去填写") { showAPISheet = true }
            Button(isEnglish ? "Cancel" : "取消", role: .cancel) {}
        } message: { Text(isEnglish ? "Do you want to open API settings?" : "是否跳转到 API 输入窗口?") }
        .alert(isEnglish ? "Delete Subject?" : "确认删除学科?", isPresented: $showDeleteSubjectAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { performDeleteSubject(subjectToDelete) }
        } message: { Text(isEnglish ? "All assignments will be moved to Recycle Bin." : "确认后,该学科下的所有作业将被移至回收站。") }
        .sheet(isPresented: $showAPISheet) {
            AIEngineManagerSheet(
                preferredProviderRaw: $providerRaw,
                groqKey: $groqKey,
                zhipuKey: $zhipuKey,
                isEnglish: isEnglish
            )
        }
        .sheet(isPresented: $showPrivacySheet) { PrivacyView(isPresented: $showPrivacySheet, language: appLang) }
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
                oldName: subjectToRename, isEnglish: isEnglish,
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
                isEnglish: isEnglish, contextDate: currentViewingDate,
                contextSubject: subjectFilter, allSubjects: allSubjects, subjectManager: subjectManager
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
                    SidebarRow(title: subject, icon: "tag.fill", color: subjectManager.getColor(for: subject), isSelected: subjectFilter == subject) {
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
                        } label: { Text(isEnglish ? "Delete Subject" : "删除学科") }
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
                .foregroundStyle(.blue)
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
                    HStack {
                        Text(isEnglish ? "Filter: \(filter)" : "当前筛选: \(filter)")
                            .scaledFont(size: 16, weight: .bold)
                        Spacer()
                        Button(isEnglish ? "Clear" : "清除") { subjectFilter = nil; selectedTab = "day" }
                    }
                    .padding().background(Color.yellow.opacity(0.1))
                }
                
                Group {
                    switch selectedTab {
                    case "day":
                        DayView(currentDate: $currentViewingDate, allItems: allItems, subjectManager: subjectManager, isEnglish: isEnglish, subjectFilter: subjectFilter, onEdit: { item in editingItem = item })
                    case "calendar":
                        // 👇 修复点：添加 .equatable() 激活性能隔离机制
                        CalendarListView(currentDate: $currentViewingDate, allItems: allItems, language: appLang, subjectManager: subjectManager, subjectFilter: subjectFilter, onEdit: { item in editingItem = item })
                            .equatable()
                    case "manage":
                        TaskManagementView(items: allItems, isEnglish: isEnglish, language: appLang, allSubjects: allSubjects, onEdit: { item in editingItem = item })
                    case "trash":
                        RecycleBinView(items: allItems, isEnglish: isEnglish, language: appLang, allSubjects: allSubjects)
                    case "settings":
                        SettingsView(appLang: $appLang, outputLang: $outputLang, developerMode: $developerMode, groqKey: $groqKey, zhipuKey: $zhipuKey, preferredProviderRaw: $providerRaw, closeToMenuBar: $closeToMenuBar, subjectManager: subjectManager, showAPISheet: $showAPISheet, showPrivacySheet: $showPrivacySheet, allSubjects: allSubjects)
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Spacer().frame(height: developerMode ? 200 : 80)
            }
            
            VStack(spacing: 0) {
                if showSubjectDeletedToast {
                    Text(isEnglish ? "Assignments moved to Trash" : "作业已移至回收站")
                        .font(.caption).foregroundStyle(.white).padding(8).background(Color.black.opacity(0.8)).cornerRadius(8).padding(.bottom, 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                if let msg = statusMessage {
                    Text(msg).font(.caption).foregroundStyle(isError ? .red : .green).padding(4).background(.thinMaterial).cornerRadius(4)
                }
                
                if selectedTab != "settings" {
                    InputBar(text: $inputText, isProcessing: isProcessing, isEnglish: isEnglish, hasApiKey: (!groqKey.isEmpty || !zhipuKey.isEmpty), submitAction: sendMessage, onMissingKeyTap: { showKeyMissingAlert = true }, onManualAddTap: { showManualAddSheet = true })
                        .padding(.bottom, 10)
                }
                
                if developerMode {
                    DeveloperConsoleView(logs: logs, clearAction: { logs.removeAll() })
                        .frame(height: 160).transition(.move(edge: .bottom))
                }
            }
            .padding(.bottom, 4)
        }
    }
    
    // MARK: - 业务操作
    func performDeleteSubject(_ subject: String) {
        subjectManager.removeSubject(subject)
        let itemsToMove = allItems.filter { $0.subject == subject && $0.deletedDate == nil }
        for item in itemsToMove { item.deletedDate = Date() }
        try? modelContext.save()
        if !itemsToMove.isEmpty {
            withAnimation { showSubjectDeletedToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation { showSubjectDeletedToast = false } }
        }
        if subjectFilter == subject { subjectFilter = nil }
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
    
    func sendMessage() {
        guard !inputText.isEmpty else { return }
        isProcessing = true; statusMessage = nil
        logs.append(AppLog(type: .info, message: "UI: 用户发送"))
        Task {
            do {
                try await manager.processInput(text: inputText, outputLang: outputLang.displayName, modelContext: modelContext, onLog: { log in logs.append(log) })
                isError = false; statusMessage = isEnglish ? "Success!" : "发送成功！"
                inputText = ""
                try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                statusMessage = nil
            } catch let error as LLMError {
                isError = true; statusMessage = error.localizedDescription
                logs.append(AppLog(type: .error, message: "Error: \(error.localizedDescription)"))
                if case .invalidKey = error { show401Alert = true }
            } catch { isError = true; statusMessage = error.localizedDescription }
            isProcessing = false
        }
    }
}

// MARK: - 当日视图
private struct DayView: View {
    @Binding var currentDate: Date
    var allItems: [HomeworkItem]
    @ObservedObject var subjectManager: SubjectManager
    var isEnglish: Bool
    var subjectFilter: String?
    var onEdit: (HomeworkItem) -> Void
    
    @State private var showDatePicker = false
    
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
                    Button(action: { changeDay(by: -1) }) { Image(systemName: "chevron.left").font(.title2) }.buttonStyle(.plain)
                    Text(dateFormatter.string(from: currentDate)).scaledFont(size: 16, weight: .bold).frame(minWidth: 180, alignment: .center)
                    Button(action: { changeDay(by: 1) }) { Image(systemName: "chevron.right").font(.title2) }.buttonStyle(.plain)
                }
                HStack {
                    Button(action: { showDatePicker.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text(isEnglish ? "Select Date" : "选择日期").scaledFont(size: 14)
                        }
                    }
                    .buttonStyle(.plain).foregroundStyle(.blue)
                    .popover(isPresented: $showDatePicker, arrowEdge: .bottom) {
                        DatePicker("", selection: $currentDate, displayedComponents: .date).datePickerStyle(.graphical).padding().frame(width: 280)
                    }
                    Spacer()
                    let isToday = Calendar.current.isDateInToday(currentDate)
                    Button(action: { currentDate = Date() }) {
                        HStack(spacing: 4) {
                            Image(systemName: isToday ? "checkmark.circle.fill" : "arrow.uturn.backward.circle")
                            Text(isToday ? (isEnglish ? "Today" : "当前: 今天") : (isEnglish ? "Back to Today" : "回到今天")).scaledFont(size: 14)
                        }
                    }
                    .buttonStyle(.plain).foregroundStyle(isToday ? .green : .blue).disabled(isToday)
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 12).background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            if displayItems.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle").font(.system(size: 50)).foregroundStyle(.secondary.opacity(0.5))
                    Text(isEnglish ? "No assignments for this day" : "当日无任务").scaledFont(size: 14).foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(displayItems) { item in
                            HomeworkRowCard(task: item, subjectManager: subjectManager, onEdit: onEdit, viewedDate: currentDate, isEnglish: isEnglish)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - 列表视图 (唯一标识符与性能隔离终极版)
struct CalendarListView: View, Equatable {
    @Binding var currentDate: Date
    var allItems: [HomeworkItem]
    var language: AppLanguage
    @ObservedObject var subjectManager: SubjectManager
    var subjectFilter: String?
    var onEdit: (HomeworkItem) -> Void
    
    private var isEnglish: Bool { language == .english }
    
    // 实现 Equatable 协议：只有当核心过滤条件或数据源长度变化时才允许重绘，彻底隔离输入框打字带来的高频打断
    static func == (lhs: CalendarListView, rhs: CalendarListView) -> Bool {
        lhs.currentDate == rhs.currentDate &&
        lhs.subjectFilter == rhs.subjectFilter &&
        lhs.language == rhs.language &&
        lhs.allItems.count == rhs.allItems.count &&
        lhs.allItems.last?.persistentModelID == rhs.allItems.last?.persistentModelID
    }
    
    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    // 🔥【关键修复】：引入绝对唯一的渲染包装模型，解决跨天作业 ID 重复导致的列表塌陷
    struct RenderTask: Identifiable {
        let id: String         // 复合唯一 ID: "\(dateKey)-\(persistentModelID)"
        let task: HomeworkItem
    }
    
    struct RenderSection: Identifiable {
        let id: String         // "yyyy-MM-dd"
        let date: Date
        let tasks: [RenderTask] // 必须使用拥有唯一 ID 的包装卡片
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
            
            // 🔥【核心修复点】：在这里为每张卡片在这个特定日期生成全局唯一的 ID
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
                                        .scaledFont(size: 13).foregroundStyle(.secondary)
                                        .padding(.vertical, 10).frame(maxWidth: .infinity)
                                        .background(Color.gray.opacity(0.05)).cornerRadius(8)
                                }
                            } else {
                                // 🔥【核心修复点】：传递唯一的 renderTask.id，解救 SwiftUI 渲染重用队列
                                ForEach(section.tasks) { renderTask in
                                    HomeworkRowCard(
                                        task: renderTask.task,
                                        subjectManager: subjectManager,
                                        onEdit: onEdit,
                                        viewedDate: section.date,
                                        isEnglish: isEnglish
                                    )
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .onAppear {
                if let todayNode = sectionsToRender.first(where: { cal.isDate($0.date, inSameDayAs: midnightCurrent) }) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo(todayNode.id, anchor: .top)
                    }
                }
            }
        }
    }
}
