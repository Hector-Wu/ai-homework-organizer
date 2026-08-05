// Filename: Views/RecycleBinView.swift

import SwiftUI
import SwiftData

struct RecycleBinView: View {
    @Environment(\.modelContext) private var modelContext
    var items: [HomeworkItem]
    var isEnglish: Bool
    var language: AppLanguage
    var allSubjects: [String]
    
    @State private var selectedItems: Set<HomeworkItem.ID> = []
    @State private var showMoveSheet: Bool = false
    @State private var moveInitialSubject: String = ""
    @State private var showEmptyTrashAlert: Bool = false
    @State private var showDeleteConfirm: Bool = false
    
    private var trashItems: [HomeworkItem] {
        items
            .filter { $0.deletedDate != nil }
            .sorted { ($0.deletedDate ?? Date()) > ($1.deletedDate ?? Date()) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            toolbarBar
            Divider()
            listContent
            if !selectedItems.isEmpty { selectionActionBar }
        }
        .onAppear { selectedItems.removeAll() }
        .sheet(isPresented: $showMoveSheet) {
            MoveToSubjectSheet(
                isEnglish: isEnglish,
                allSubjects: allSubjects,
                initialSubject: moveInitialSubject,
                isRestoring: true,
                onMove: { targetSubject in
                    for id in selectedItems {
                        if let item = items.first(where: { $0.id == id }) {
                            item.subject = targetSubject
                            item.deletedDate = nil
                        }
                    }
                    try? modelContext.save()
                    selectedItems.removeAll()
                    showMoveSheet = false
                },
                onCancel: { showMoveSheet = false }
            )
        }
        .alert(isEnglish ? "Empty Trash?" : "清空回收站?", isPresented: $showEmptyTrashAlert) {
            Button("Cancel", role: .cancel) {}
            Button(isEnglish ? "Empty Trash" : "清空", role: .destructive) {
                for item in trashItems { modelContext.delete(item) }
                try? modelContext.save()
            }
        } message: { Text(isEnglish ? "This action cannot be undone." : "此操作不可撤销，所有项目将永久删除。") }
        .alert(isEnglish ? "Permanently Delete?" : "确认彻底删除?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button(isEnglish ? "Delete" : "删除", role: .destructive) {
                for id in selectedItems {
                    if let item = items.first(where: { $0.id == id }) {
                        modelContext.delete(item)
                    }
                }
                try? modelContext.save()
                selectedItems.removeAll()
            }
        } message: { Text(isEnglish ? "These items will be erased forever." : "选中的作业将被永久抹除且不可恢复。") }
    }
    
    @ViewBuilder private var toolbarBar: some View {
        HStack {
            Text(isEnglish ? "Recycle Bin (Auto-delete in 7 days)" : "回收站 (7天后自动删除)").scaledFont(size: 16, weight: .bold)
            Spacer()
            Text(isEnglish ? "Tip: Hold Shift/Cmd to multi-select" : "💡 提示：按住 Shift 或 Cmd 键进行多选").scaledFont(size: 12).foregroundStyle(.secondary)
            Button(isEnglish ? "Empty Trash" : "清空回收站") { showEmptyTrashAlert = true }
                .buttonStyle(.bordered).tint(.red).disabled(trashItems.isEmpty)
        }
        .padding().background(Color(nsColor: .controlBackgroundColor))
    }
    
    @ViewBuilder private var listContent: some View {
        if trashItems.isEmpty {
            Spacer()
            Text(isEnglish ? "Trash is empty" : "回收站是空的").foregroundStyle(.secondary)
            Spacer()
        } else {
            List(selection: $selectedItems) {
                ForEach(trashItems) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.subject).scaledFont(size: 12, weight: .bold)
                            Text(item.content).scaledFont(size: 14)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(formatDate(item.endDate)).scaledFont(size: 12)
                            if let del = item.deletedDate {
                                Text((isEnglish ? "Deleted: " : "删除于: ") + formatDate(del))
                                    .scaledFont(size: 10).foregroundStyle(.red)
                            }
                        }
                    }
                    .tag(item.id)
                }
            }
            .listStyle(.inset)
        }
    }
    
    @ViewBuilder private var selectionActionBar: some View {
        HStack {
            Text(isEnglish ? "\(selectedItems.count) Selected" : "已选 \(selectedItems.count) 项")
            Spacer()
            Button(isEnglish ? "Select All" : "全选") { selectedItems = Set(trashItems.map { $0.id }) }
            Button(isEnglish ? "Restore" : "复位") {
                for id in selectedItems { if let item = items.first(where: { $0.id == id }) { item.deletedDate = nil } }
                try? modelContext.save()
                selectedItems.removeAll()
            }
            Button(isEnglish ? "Move to..." : "移动到...") {
                if let firstId = selectedItems.first, let firstItem = items.first(where: { $0.id == firstId }) {
                    moveInitialSubject = firstItem.subject
                    showMoveSheet = true
                }
            }
            Button(isEnglish ? "Delete Permanently" : "彻底删除") { showDeleteConfirm = true }.tint(.red)
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
