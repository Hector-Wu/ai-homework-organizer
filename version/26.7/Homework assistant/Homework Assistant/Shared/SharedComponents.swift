// Filename: SharedComponents.swift
// 用途：全局共享 UI 组件 —— 反色撤销胶囊、SidebarRow、暗色适配 DateHeader、DeveloperConsoleView、MoveToSubjectSheet

import SwiftUI
import SwiftData

// MARK: - 全局统一反色提示/撤销胶囊（浅色页深色底，暗色页纯白底）

struct InvertedToastCapsule: View {
    var message: String
    var undoTitle: String? = nil
    var isError: Bool = false
    var fillWidth: Bool = false
    var onUndo: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var isDarkPage: Bool { colorScheme == .dark }

    private var capsuleBackground: Color {
        isDarkPage
            ? Color(red: 0.95, green: 0.96, blue: 0.98).opacity(0.96)
            : Color(red: 0.13, green: 0.14, blue: 0.16).opacity(0.92)
    }

    private var textColor: Color {
        if isError {
            return isDarkPage
                ? Color(red: 0.82, green: 0.14, blue: 0.18)
                : Color(red: 1.0, green: 0.45, blue: 0.45)
        }
        return isDarkPage
            ? Color(red: 0.10, green: 0.11, blue: 0.13)
            : Color.white
    }

    private var undoButtonColor: Color {
        isDarkPage
            ? Color(red: 0.04, green: 0.40, blue: 0.94)
            : Color(red: 1.0, green: 0.82, blue: 0.20)
    }

    var body: some View {
        HStack(spacing: 16) {
            if isError {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(textColor)
            }

            Text(message)
                .scaledFont(size: 12.5, weight: .medium)
                .foregroundStyle(textColor)
                .lineLimit(2)

            if fillWidth {
                Spacer(minLength: 8)
            }

            if let undoTitle, let onUndo {
                Button(action: onUndo) {
                    Text(undoTitle)
                        .scaledFont(size: 12.5, weight: .bold)
                        .foregroundStyle(undoButtonColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(capsuleBackground, in: Capsule())
        .overlay(
            Capsule()
                .stroke(
                    isDarkPage ? Color.black.opacity(0.08) : Color.white.opacity(0.12),
                    lineWidth: 1
                )
        )
        .shadow(
            color: Color.black.opacity(isDarkPage ? 0.35 : 0.18),
            radius: 10,
            x: 0,
            y: 4
        )
    }
}

// MARK: - 侧边栏行组件

struct SidebarRow: View {
    let title:      String
    let icon:       String
    var color:      Color = .primary
    let isSelected: Bool
    let action:     () -> Void

    @Environment(\.colorScheme) private var colorScheme

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
        .listRowBackground(
            isSelected
                ? Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.12)
                : Color.clear
        )
    }
}

// MARK: - 日历列表日期标题（适配深浅色置顶背景与标签对比度）

struct DateHeader: View {
    let date:     Date
    let language: AppLanguage

    @Environment(\.colorScheme) private var colorScheme

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
                .background(
                    isToday
                        ? Color.blue
                        : (colorScheme == .dark ? Color.white.opacity(0.09) : Color.black.opacity(0.05)),
                    in: RoundedRectangle(cornerRadius: 8)
                )
            Spacer()
        }
        .padding(.vertical, 4)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.95))
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
            .background(Color(white: 0.08))

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
        .background(Color(white: 0.05))
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

// MARK: - 通用"移动到学科" Sheet

struct MoveToSubjectSheet: View {
    var isEnglish:   Bool
    var allSubjects: [String]
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
