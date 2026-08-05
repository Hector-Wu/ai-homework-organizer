// Filename: SharedComponents.swift
// 用途：全局共享 UI 组件 ——
// SidebarRow、DateHeader、DeveloperConsoleView、MoveToSubjectSheet

import SwiftUI
import SwiftData

// MARK: - 侧边栏行组件

struct SidebarRow: View {
    let title:      String
    let icon:       String
    var color:      Color = .primary
    let isSelected: Bool
    let action:     () -> Void

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20, alignment: .center)
            Text(title).scaledFont(size: 14)
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture { action() }
        .listRowBackground(isSelected ? Color.blue.opacity(0.1) : Color.clear)
    }
}

// MARK: - 日历列表日期标题

struct DateHeader: View {
    let date:     Date
    let language: AppLanguage

    var isToday: Bool { Calendar.current.isDateInToday(date) }

    var dateString: String {
        let f = DateFormatter()
        f.locale     = Locale(identifier: language.id)
        f.dateFormat = language == .english ? "MMM d, EEE" : "M月d日 EEEE"
        return f.string(from: date)
    }

    var body: some View {
        HStack {
            Text(dateString)
                .scaledFont(size: 15, weight: .bold)
                .foregroundStyle(isToday ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isToday ? Color.blue : Color(nsColor: .windowBackgroundColor))
                .cornerRadius(8)
            Spacer()
        }
        .padding(.vertical, 4)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
    }
}

// MARK: - 开发者控制台

struct DeveloperConsoleView: View {
    var logs:        [AppLog]
    var clearAction: () -> Void

    private func copyLogs() {
        let text = logs.map { "[\($0.type)] \($0.message)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Console")
                    .foregroundStyle(.green)
                    .font(.caption.bold())
                Spacer()
                Button("Copy")  { copyLogs()    }
                Button("Clear") { clearAction() }
            }
            .padding(5)
            .background(Color.black)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(logs) { log in
                        Text(log.message)
                            .font(.caption)
                            .foregroundStyle(logColor(for: log.type))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(4)
            }
        }
        .background(Color.black)
    }

    private func logColor(for type: AppLog.LogType) -> Color {
        switch type {
        case .info:    return .green
        case .success: return .cyan
        case .error:   return .red
        case .aiRaw:   return .yellow
        }
    }
}

// MARK: - 通用"移动到学科" Sheet（RecycleBinView 和 TaskManagementView 共用）

struct MoveToSubjectSheet: View {
    var isEnglish:   Bool
    var allSubjects: [String]
    /// 是否同时恢复（从回收站移动时为 true，普通移动为 false）
    var isRestoring: Bool
    var onMove:      (String) -> Void
    var onCancel:    () -> Void

    @State private var targetSubject: String

    init(
        isEnglish:      Bool,
        allSubjects:    [String],
        initialSubject: String,
        isRestoring:    Bool,
        onMove:         @escaping (String) -> Void,
        onCancel:       @escaping () -> Void
    ) {
        self.isEnglish   = isEnglish
        self.allSubjects = allSubjects
        self.isRestoring = isRestoring
        self.onMove      = onMove
        self.onCancel    = onCancel
        _targetSubject   = State(initialValue: initialSubject)
    }

    var title: String {
        if isRestoring {
            return isEnglish ? "Restore & Move to" : "恢复并移动到"
        } else {
            return isEnglish ? "Move to Subject"   : "移动到学科"
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .scaledFont(size: 16, weight: .bold)

            Picker("", selection: $targetSubject) {
                ForEach(allSubjects, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            HStack {
                Button(isEnglish ? "Cancel" : "取消") { onCancel() }
                Button(isEnglish ? "Move"   : "移动") { onMove(targetSubject) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 300, height: 200)
    }
}
