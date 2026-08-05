// Filename: Sheets/ManualAddSheet.swift

import SwiftUI
import SwiftData

struct ManualAddSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var isEnglish: Bool
    var contextDate: Date
    var contextSubject: String?
    var allSubjects: [String]
    @ObservedObject var subjectManager: SubjectManager

    // MARK: - 表单状态
    @State private var selectedDate: Date = Date()
    @State private var subjectSearch: String = ""
    @State private var contentText: String = ""
    @State private var notesText: String = ""

    // MARK: - UI 控制状态
    @State private var isSubjectDropdownOpen: Bool = false
    @State private var showNewSubjectSheet: Bool = false
    @State private var duplicateWarning: Bool = false
    @State private var showLengthWarning: Bool = false
    
    // MARK: - 计算属性
    var filteredSubjects: [String] {
        if subjectSearch.isEmpty { return allSubjects }
        return allSubjects.filter { $0.localizedCaseInsensitiveContains(subjectSearch) }
    }
    
    var canSave: Bool {
        !contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !subjectSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        allSubjects.contains(subjectSearch)
    }
    
    var isPastDate: Bool {
        Calendar.current.startOfDay(for: selectedDate) < Calendar.current.startOfDay(for: Date())
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            HStack(alignment: .top, spacing: 20) {
                leftPanel
                Divider()
                rightPanel
            }
            .padding(20)
            Divider()
            bottomBar
        }
        .frame(width: 720, height: 500)
        .onAppear {
            selectedDate = contextDate
            if let sub = contextSubject, allSubjects.contains(sub) {
                subjectSearch = sub
            } else if let lastUsed = UserDefaults.standard.string(forKey: "last_used_subject"), allSubjects.contains(lastUsed) {
                subjectSearch = lastUsed
            }
        }
        .sheet(isPresented: $showNewSubjectSheet) {
            // 现在可以正常调用了
            AddSubjectSheet(isEnglish: isEnglish, initialZh: subjectSearch) { en, zh in
                let name = "\(zh) \(en)".trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    subjectManager.addSubject(name)
                    DispatchQueue.main.async { // 延迟到下一个 runloop 避免警告
                        subjectSearch = name
                        isSubjectDropdownOpen = false
                    }
                }
            }
        }
    }
    
    @ViewBuilder private var headerBar: some View {
        HStack {
            Text(isEnglish ? "Manual Add" : "手动添加作业").scaledFont(size: 18, weight: .bold)
            Spacer()
            Button(action: { dismiss() }) { Image(systemName: "xmark.circle.fill").foregroundStyle(.gray).font(.title2) }.buttonStyle(.plain)
        }.padding(20).background(Color(nsColor: .windowBackgroundColor))
    }
    
    @ViewBuilder private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            subjectSearchField
            contentField
            notesField
            Spacer()
        }.frame(width: 340)
    }

    @ViewBuilder private var subjectSearchField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(isEnglish ? "Subject" : "科目").scaledFont(size: 14, weight: .bold)
            TextField(isEnglish ? "Search or select subject..." : "输入搜索或选择科目...", text: $subjectSearch)
                .textFieldStyle(.roundedBorder)
                .popover(isPresented: $isSubjectDropdownOpen, arrowEdge: .bottom) { subjectDropdown }
                .onChange(of: subjectSearch) { DispatchQueue.main.async { isSubjectDropdownOpen = true; duplicateWarning = false } }
                .onTapGesture { DispatchQueue.main.async { isSubjectDropdownOpen = true } }
        }
    }
    
    @ViewBuilder private var subjectDropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredSubjects, id: \.self) { sub in
                        Button(action: { DispatchQueue.main.async { subjectSearch = sub; isSubjectDropdownOpen = false } }) {
                            HStack {
                                Circle().fill(subjectManager.getColor(for: sub)).frame(width: 10, height: 10)
                                Text(sub).scaledFont(size: 13)
                                Spacer()
                            }.padding(8).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }
            }
            if !allSubjects.contains(subjectSearch) && !subjectSearch.isEmpty {
                Divider().padding(.vertical, 4)
                Button(action: { DispatchQueue.main.async { isSubjectDropdownOpen = false; showNewSubjectSheet = true } }) {
                    HStack {
                        Image(systemName: "plus.circle.fill").foregroundStyle(.blue)
                        Text(isEnglish ? "Add: \(subjectSearch)" : "新建科目: \(subjectSearch)").scaledFont(size: 13).foregroundStyle(.blue)
                        Spacer()
                    }.padding(8).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }.frame(width: 250).frame(maxHeight: 200).padding(4)
    }

    @ViewBuilder private var contentField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(isEnglish ? "Content (Required)" : "作业内容 (必填)").scaledFont(size: 14, weight: .bold)
                Spacer()
                Text("\(contentText.count)/2000").scaledFont(size: 12).foregroundStyle(showLengthWarning ? .red : .secondary)
            }
            TextEditor(text: $contentText)
                .font(.system(size: 14)).frame(height: 130)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                .onChange(of: contentText) {
                    DispatchQueue.main.async {
                        duplicateWarning = false
                        if contentText.count > 2000 {
                            contentText = String(contentText.prefix(2000))
                            showLengthWarning = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showLengthWarning = false }
                        }
                    }
                }
        }
    }
    
    @ViewBuilder private var notesField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(isEnglish ? "Notes (Optional)" : "特殊备注 (选填)").scaledFont(size: 14, weight: .bold)
            TextField(isEnglish ? "E.g. Bring compass, print out..." : "例如: 带圆规、需打印...", text: $notesText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: notesText) {
                    DispatchQueue.main.async { if notesText.count > 500 { notesText = String(notesText.prefix(500)) } }
                }
        }
    }
    
    @ViewBuilder private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isEnglish ? "Due Date" : "截止日期").scaledFont(size: 14, weight: .bold)
            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical).labelsHidden().frame(width: 280)
                .padding(10).background(Color(nsColor: .controlBackgroundColor)).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2), lineWidth: 1))
            if isPastDate {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(isEnglish ? "Warning: Date is in the past." : "注意：该截止日期已过去。").scaledFont(size: 12, weight: .bold).foregroundStyle(.orange)
                }.transition(.opacity)
            }
            Spacer()
        }
    }
    
    @ViewBuilder private var bottomBar: some View {
        HStack {
            if duplicateWarning {
                Text(isEnglish ? "Error: Same task already exists!" : "错误：相同内容的作业已存在!").scaledFont(size: 13, weight: .bold).foregroundStyle(.red)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            Spacer()
            Button(isEnglish ? "Cancel" : "取消") { dismiss() }
            Button(action: saveTask) {
                Text(isEnglish ? "Save Task" : "保存作业").scaledFont(size: 14, weight: .bold).frame(minWidth: 80)
            }
            .buttonStyle(.borderedProminent).disabled(!canSave)
            .keyboardShortcut(.return, modifiers: .command)
            .help(isEnglish ? "Cmd + Enter to save" : "按 Cmd + Enter 快速保存")
        }.padding(20).background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func saveTask() {
        let cal = Calendar.current
        let targetEnd = cal.startOfDay(for: selectedDate)
        let targetStart = cal.startOfDay(for: Date())

        let desc = FetchDescriptor<HomeworkItem>(predicate: #Predicate {
            $0.subject == subjectSearch && $0.content == contentText && $0.endDate == targetEnd && $0.deletedDate == nil
        })
        if (try? modelContext.fetch(desc).count) ?? 0 > 0 {
            withAnimation { duplicateWarning = true }
            return
        }

        let newItem = HomeworkItem(
            subject: subjectSearch, content: contentText,
            specialNotes: notesText.isEmpty ? nil : notesText,
            startDate: targetStart, endDate: targetEnd
        )
        modelContext.insert(newItem)
        try? modelContext.save()
        
        UserDefaults.standard.set(subjectSearch, forKey: "last_used_subject")
        dismiss()
    }
}
