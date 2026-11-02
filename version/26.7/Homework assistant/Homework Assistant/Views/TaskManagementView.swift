// Filename: Views/TaskManagementView.swift
// 用途: 作业管理视图 —— 支持按日期筛选、多选批量移动、单条/批量删除撤销联动与暗色模式适配

import SwiftUI
import SwiftData

struct TaskManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    var items: [HomeworkItem]
    var isEnglish: Bool
    var language: AppLanguage
    var allSubjects: [String]
    var onEdit: (HomeworkItem) -> Void
    var onItemsDeleted: (([HomeworkItem]) -> Void)? = nil

    @State private var selectedDate: Date = Date()
    @State private var filterByDate: Bool = false
    @State private var selectedItems: Set<HomeworkItem.ID> = []
    @State private var showMoveSheet: Bool = false
    @State private var moveInitialSubject: String = ""

    private var isDark: Bool { colorScheme == .dark }

    private var displayItems: [HomeworkItem] {
        let active = items
            .filter { $0.deletedDate == nil }
            .sorted { $0.creationDate > $1.creationDate }
        if filterByDate {
            return active.filter { Calendar.current.isDate($0.endDate, inSameDayAs: selectedDate) }
        }
        return active
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbarBar
            Divider()
            listContent
            if !selectedItems.isEmpty {
                Divider()
                selectionActionBar
            }
        }
        .onAppear {
            filterByDate = false
            selectedItems.removeAll()
        }
        .sheet(isPresented: $showMoveSheet) {
            MoveToSubjectSheet(
                isEnglish: isEnglish,
                allSubjects: allSubjects,
                initialSubject: moveInitialSubject,
                isRestoring: false,
                onMove: { targetSubject in
                    for id in selectedItems {
                        if let item = items.first(where: { $0.id == id }) {
                            item.subject = targetSubject
                        }
                    }
                    try? modelContext.save()
                    selectedItems.removeAll()
                    showMoveSheet = false
                },
                onCancel: { showMoveSheet = false }
            )
        }
    }

    @ViewBuilder private var toolbarBar: some View {
        HStack(spacing: 12) {
            Toggle(isOn: $filterByDate) {
                Text(isEnglish ? "Filter Date" : "按日期筛选")
                    .scaledFont(size: 14)
            }
            .toggleStyle(.switch)

            if filterByDate {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .labelsHidden()
            }

            Spacer()

            Text(isEnglish ? "Tip: Hold Shift/Cmd to multi-select" : "💡 提示：按住 Shift 或 Cmd 键进行多选")
                .scaledFont(size: 12)
                .foregroundStyle(.secondary)

            Text("\(displayItems.count)")
                .scaledFont(size: 12, weight: .semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.06))
                )
        }
        .padding()
        .background(isDark ? Color.white.opacity(0.04) : Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder private var listContent: some View {
        if displayItems.isEmpty {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "tray")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary.opacity(0.5))
                Text(isEnglish ? "No tasks found" : "暂无符合条件的作业")
                    .scaledFont(size: 14)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        } else {
            List(selection: $selectedItems) {
                ForEach(displayItems) { item in
                    HStack(spacing: 10) {
                        if item.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.subject)
                                .scaledFont(size: 15, weight: .bold)
                                .foregroundStyle(item.isCompleted ? .secondary : .primary)
                            Text(item.content)
                                .scaledFont(size: 14)
                                .strikethrough(item.isCompleted)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(formatDate(item.endDate))
                            .scaledFont(size: 12, weight: .medium)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .tag(item.id)
                    .contextMenu {
                        Button(action: { onEdit(item) }) {
                            Label(isEnglish ? "Edit" : "修改", systemImage: "pencil")
                        }
                        Divider()
                        Button(role: .destructive, action: {
                            deleteTasks([item])
                        }) {
                            Label(isEnglish ? "Delete" : "删除", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    @ViewBuilder private var selectionActionBar: some View {
        HStack(spacing: 12) {
            Text(isEnglish ? "\(selectedItems.count) Selected" : "已选 \(selectedItems.count) 项")
                .scaledFont(size: 13, weight: .medium)
            Spacer()
            Button(isEnglish ? "Select All" : "全选") {
                selectedItems = Set(displayItems.map(\.id))
            }
            Button(isEnglish ? "Move to..." : "移动到...") {
                if let firstId = selectedItems.first,
                   let firstItem = items.first(where: { $0.id == firstId }) {
                    moveInitialSubject = firstItem.subject
                    showMoveSheet = true
                }
            }
            .disabled(allSubjects.isEmpty)

            Button(role: .destructive) {
                let targets = items.filter { selectedItems.contains($0.id) && $0.deletedDate == nil }
                deleteTasks(targets)
            } label: {
                Text(isEnglish ? "Delete" : "删除")
            }
            .tint(.red)
        }
        .padding()
        .background(.bar)
    }

    private func deleteTasks(_ targets: [HomeworkItem]) {
        guard !targets.isEmpty else { return }
        let targetIDs = Set(targets.map(\.id))
        selectedItems.subtract(targetIDs)

        if let onItemsDeleted {
            onItemsDeleted(targets)
        } else {
            let now = Date()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                for item in targets {
                    item.deletedDate = now
                }
            }
            try? modelContext.save()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: language.id)
        f.dateFormat = isEnglish ? "MMM d" : "M月d日"
        return f.string(from: date)
    }
}
