// Filename: Views/TaskManagementView.swift

import SwiftUI
import SwiftData

struct TaskManagementView: View {
    @Environment(\.modelContext) private var modelContext
    var items: [HomeworkItem]
    var isEnglish: Bool
    var language: AppLanguage
    var allSubjects: [String]
    var onEdit: (HomeworkItem) -> Void
    
    @State private var selectedDate: Date = Date()
    @State private var filterByDate: Bool = false
    @State private var selectedItems: Set<HomeworkItem.ID> = []
    @State private var showMoveSheet: Bool = false
    @State private var moveInitialSubject: String = ""
    
    private var displayItems: [HomeworkItem] {
        let active = items.filter { $0.deletedDate == nil }.sorted { $0.creationDate > $1.creationDate }
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
            if !selectedItems.isEmpty { selectionActionBar }
        }
        .onAppear { filterByDate = false; selectedItems.removeAll() }
        .sheet(isPresented: $showMoveSheet) {
            MoveToSubjectSheet(
                isEnglish: isEnglish, allSubjects: allSubjects, initialSubject: moveInitialSubject, isRestoring: false,
                onMove: { targetSubject in
                    for id in selectedItems { if let item = items.first(where: { $0.id == id }) { item.subject = targetSubject } }
                    try? modelContext.save()
                    selectedItems.removeAll()
                    showMoveSheet = false
                },
                onCancel: { showMoveSheet = false }
            )
        }
    }
    
    @ViewBuilder private var toolbarBar: some View {
        HStack {
            Toggle(isOn: $filterByDate) { Text(isEnglish ? "Filter Date" : "按日期筛选").scaledFont(size: 14) }.toggleStyle(.switch)
            if filterByDate {
                DatePicker("", selection: $selectedDate, displayedComponents: .date).labelsHidden()
            }
            Spacer()
            Text(isEnglish ? "Tip: Hold Shift/Cmd to multi-select" : "💡 提示: 按住 Shift 或 Cmd 键进行多选").scaledFont(size: 12).foregroundStyle(.secondary)
            Text("\(displayItems.count)").scaledFont(size: 12).padding(.leading)
        }
        .padding().background(Color(nsColor: .controlBackgroundColor))
    }
    
    @ViewBuilder private var listContent: some View {
        List(selection: $selectedItems) {
            ForEach(displayItems) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.subject).scaledFont(size: 15, weight: .bold)
                        Text(item.content).scaledFont(size: 14).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(formatDate(item.endDate)).scaledFont(size: 12)
                }
                .tag(item.id)
                .contextMenu {
                    Button(action: { onEdit(item) }) { Label(isEnglish ? "Edit" : "修改", systemImage: "pencil") }
                    Button(role: .destructive, action: {
                        item.deletedDate = Date()
                        try? modelContext.save()
                    }) { Label(isEnglish ? "Delete" : "删除", systemImage: "trash") }
                }
            }
        }
        .listStyle(.inset)
    }
    
    @ViewBuilder private var selectionActionBar: some View {
        HStack {
            Text(isEnglish ? "\(selectedItems.count) Selected" : "已选 \(selectedItems.count) 项")
            Spacer()
            Button(isEnglish ? "Select All" : "全选") { selectedItems = Set(displayItems.map { $0.id }) }
            Button(isEnglish ? "Move to..." : "移动到...") {
                if let firstId = selectedItems.first, let firstItem = items.first(where: { $0.id == firstId }) {
                    moveInitialSubject = firstItem.subject
                    showMoveSheet = true
                }
            }
            Button(isEnglish ? "Delete" : "删除") {
                for id in selectedItems { if let item = items.first(where: { $0.id == id }) { item.deletedDate = Date() } }
                try? modelContext.save()
                selectedItems.removeAll()
            }.tint(.red)
        }
        .padding().background(.bar)
    }
    
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: language.id)
        f.dateFormat = isEnglish ? "MMM d" : "M月d日"
        return f.string(from: date)
    }
}
