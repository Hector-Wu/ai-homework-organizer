// Filename: WidgetViews.swift
// 用途：桌面悬浮迷你窗、状态栏弹窗、无延迟打勾与撤销逻辑
// 重构要点：MenuBarPopoverView 和 MiniWidgetView 的重复逻辑统一提炼


import SwiftUI
import SwiftData
import Combine  

// MARK: - 共享：Widget 数据过滤逻辑

/// 为 Widget 视图构建统一的 Query 过滤器（-14天到+30天窗口）
private func makeWidgetQueryFilter() -> Predicate<HomeworkItem> {
    let today       = Calendar.current.startOfDay(for: Date())
    let windowStart = Calendar.current.date(byAdding: .day, value: -14, to: today)!
    let windowEnd   = Calendar.current.date(byAdding: .day, value:  30, to: today)!
    return #Predicate<HomeworkItem> {
        $0.deletedDate == nil &&
        $0.endDate >= windowStart &&
        $0.endDate <= windowEnd
    }
}

/// 从已过滤的 items 中计算今日应显示的作业（含 widgetFilter 逻辑）
private func computeDisplayItems(
    from items:     [HomeworkItem],
    widgetFilter:   WidgetFilterType,
    isEnglish:      Bool
) -> [HomeworkItem] {
    let targetDay = Calendar.current.startOfDay(for: Date())
    let active    = items.filter { !$0.isCompleted }
    var todays    = active.filter { $0.isActiveOn(date: targetDay) }

    if widgetFilter == .onlyDue {
        todays = todays.filter {
            let stat = $0.getSCRStatus(viewedDate: targetDay, isEnglish: isEnglish)
            return stat.isUrgent || stat.status == 9
        }
    }
    return todays.sorted { $0.endDate < $1.endDate }
}

// MARK: - 共享：撤销完成逻辑（用 class 包装避免两个视图各自重复）

@MainActor
class UndoCompletionController: ObservableObject {
    @Published var showUndoToast:        Bool          = false
    private var  recentlyCompletedTask:  HomeworkItem? = nil
    private var  undoTimer:              Timer?        = nil

    func handleCompletion(_ task: HomeworkItem) {
        recentlyCompletedTask = task
        withAnimation(.spring) { showUndoToast = true }
        undoTimer?.invalidate()
        undoTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                withAnimation { self?.showUndoToast = false }
            }
        }
    }

    func performUndo(modelContext: ModelContext) {
        if let task = recentlyCompletedTask {
            withAnimation { task.isCompleted = false }
            try? modelContext.save()
        }
        withAnimation { showUndoToast = false }
        undoTimer?.invalidate()
    }
}

// MARK: - 状态栏气泡视图

struct MenuBarPopoverView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [HomeworkItem]

    @AppStorage("appLanguage")  private var appLang:      AppLanguage      = .chinese
    @AppStorage("widgetFilter") private var widgetFilter: WidgetFilterType = .allToday

    var wakeUpAction: () -> Void
    var isEnglish: Bool { appLang == .english }

    @StateObject private var undoController = UndoCompletionController()

    init(wakeUpAction: @escaping () -> Void) {
        self.wakeUpAction = wakeUpAction
        _items = Query(filter: makeWidgetQueryFilter(), sort: \.endDate)
    }

    var displayItems: [HomeworkItem] {
        computeDisplayItems(from: items, widgetFilter: widgetFilter, isEnglish: isEnglish)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // 标题栏
                HStack {
                    Text(isEnglish ? "Today's Tasks" : "今日作业")
                        .scaledFont(size: 16, weight: .bold)
                    Spacer()
                }
                .padding()
                .background(Material.bar)

                Divider()

                // 任务列表
                ScrollView {
                    if displayItems.isEmpty {
                        VStack {
                            Image(systemName: "cup.and.saucer")
                                .font(.system(size: 30))
                                .padding(.bottom, 4)
                            Text(isEnglish ? "All caught up!" : "今天没有任务啦！")
                                .scaledFont(size: 12)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 40)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(displayItems) { item in
                                TapToCompleteRow(task: item, isEnglish: isEnglish) { completed in
                                    undoController.handleCompletion(completed)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }

            // 撤销 Toast
            if undoController.showUndoToast {
                UndoToastView(isEnglish: isEnglish) {
                    undoController.performUndo(modelContext: modelContext)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .frame(width: 320, height: 420)
    }
}

// MARK: - 桌面悬浮迷你窗

struct MiniWidgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [HomeworkItem]

    @AppStorage("appLanguage")  private var appLang:      AppLanguage      = .chinese
    @AppStorage("widgetFilter") private var widgetFilter: WidgetFilterType = .allToday

    var isEnglish: Bool { appLang == .english }

    @StateObject private var undoController = UndoCompletionController()

    init() {
        _items = Query(filter: makeWidgetQueryFilter(), sort: \.endDate)
    }

    var displayItems: [HomeworkItem] {
        computeDisplayItems(from: items, widgetFilter: widgetFilter, isEnglish: isEnglish)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // 拖拽把手区域（透明，覆盖在红绿灯上方）
                Color.clear
                    .frame(height: 4)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture().onChanged { _ in
                            if let event = NSApp.currentEvent {
                                NSApp.keyWindow?.performDrag(with: event)
                            }
                        }
                    )

                // 任务列表
                ScrollView {
                    if displayItems.isEmpty {
                        Text(isEnglish ? "No Tasks" : "无任务")
                            .scaledFont(size: 13)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 40)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(displayItems) { item in
                                TapToCompleteRow(task: item, isEnglish: isEnglish) { completed in
                                    undoController.handleCompletion(completed)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 14)
                    }
                }
            }

            // 撤销 Toast
            if undoController.showUndoToast {
                UndoToastView(isEnglish: isEnglish) {
                    undoController.performUndo(modelContext: modelContext)
                }
                .padding(.bottom, 15)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .frame(width: 280)
        .frame(minHeight: 180, maxHeight: 450)
        .background(Material.thick)
        .onAppear {
            // 延迟设置窗口置顶，确保窗口已完成初始化
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let window = NSApplication.shared.windows.first(where: {
                    $0.identifier?.rawValue == "miniWindow"
                }) {
                    window.level = .floating
                }
            }
        }
    }
}

// MARK: - 撤销提示 Toast

struct UndoToastView: View {
    var isEnglish: Bool
    var onUndo:    () -> Void

    var body: some View {
        HStack {
            Text(isEnglish ? "Completed" : "已完成")
                .scaledFont(size: 12)
                .foregroundStyle(.white)
            Spacer()
            Button(action: onUndo) {
                Text(isEnglish ? "Undo" : "撤销")
                    .scaledFont(size: 12, weight: .bold)
                    .foregroundStyle(.yellow)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.8))
        .cornerRadius(20)
        .padding(.horizontal, 40)
    }
}

// MARK: - 一键无延迟打勾组件

struct TapToCompleteRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task:       HomeworkItem
    var isEnglish:            Bool
    var onComplete:           (HomeworkItem) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // 圆形打勾按钮
            ZStack {
                if task.isCompleted {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 20, height: 20)
                    Image(systemName: "checkmark")
                        .scaledFont(size: 10, weight: .bold)
                        .foregroundStyle(.white)
                } else {
                    Circle()
                        .stroke(Color.gray.opacity(0.4), lineWidth: 2)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(.top, 2)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    task.isCompleted = true
                }
                try? modelContext.save()
                onComplete(task)
            }

            // 内容区
            VStack(alignment: .leading, spacing: 4) {
                Text(task.subject)
                    .scaledFont(size: 12, weight: .bold)
                    .foregroundStyle(.blue)
                Text(task.content)
                    .scaledFont(size: 14)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .cornerRadius(10)
    }
}
