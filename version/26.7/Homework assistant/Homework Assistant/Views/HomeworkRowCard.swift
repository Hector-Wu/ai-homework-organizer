//
//  HomeworkRowCard.swift
//  Homework Assistant
//
//  Created by Hector Wu on 26/4/2026.
//

// Filename: HomeworkRowCard.swift
// 用途: 作业卡片视图, 用于DayView和CalendarListView, 包含打勾、状态、上下文菜单、删除撤销回调及暗色适配

import SwiftUI
import SwiftData

struct HomeworkRowCard: View {
    @Bindable var task: HomeworkItem
    @ObservedObject var subjectManager: SubjectManager
    var onEdit: (HomeworkItem) -> Void
    var viewedDate: Date
    var isEnglish: Bool
    var onDelete: ((HomeworkItem) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        let stat = task.getSCRStatus(viewedDate: viewedDate, isEnglish: isEnglish)
        let subjectColor = subjectManager.getColor(for: task.subject)
        let noteColor: Color = isDark ? Color(red: 1.0, green: 0.45, blue: 0.42) : .red

        HStack {
            // 打勾按钮
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                    task.isCompleted.toggle()
                }
                try? modelContext.save()
            }) {
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(
                        task.isCompleted
                            ? Color.secondary
                            : (isDark ? Color(red: 0.38, green: 0.68, blue: 1.0) : .blue)
                    )
            }
            .buttonStyle(.plain)

            // 科目颜色左边条
            RoundedRectangle(cornerRadius: 2)
                .fill(task.isCompleted ? Color.secondary.opacity(0.5) : subjectColor)
                .frame(width: 4)
                .padding(.vertical, 4)

            // 内容区
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    // 科目徽章
                    Text(task.subject)
                        .scaledFont(size: 12, weight: .bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            task.isCompleted
                                ? Color.secondary.opacity(isDark ? 0.18 : 0.12)
                                : subjectColor.opacity(isDark ? 0.24 : 0.12)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)

                    // 特殊备注标签
                    if let notes = task.specialNotes, !notes.isEmpty {
                        Text(notes)
                            .scaledFont(size: 10, weight: .medium)
                            .foregroundStyle(task.isCompleted ? .secondary : noteColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(task.isCompleted ? Color.clear : noteColor.opacity(isDark ? 0.12 : 0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(task.isCompleted ? Color.secondary.opacity(0.5) : noteColor.opacity(0.85), lineWidth: 1)
                            )
                    }
                }

                // 作业内容
                Text(task.content)
                    .scaledFont(size: 15)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
            }
            .padding(.vertical, 8)

            Spacer()

            // 状态标签 (逾期/DUE/倒计时)
            if !stat.text.isEmpty && !task.isCompleted {
                Text(stat.text)
                    .scaledFont(size: 11, weight: .bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(stat.color)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isDark ? Color.white.opacity(0.065) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    stat.isUrgent && !task.isCompleted
                        ? stat.color.opacity(isDark ? 0.8 : 0.6)
                        : (isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)),
                    lineWidth: stat.isUrgent && !task.isCompleted ? 1.5 : 1
                )
        )
        .shadow(
            color: Color.black.opacity(isDark ? 0 : 0.03),
            radius: 3,
            x: 0,
            y: 1
        )
        .opacity(task.isCompleted ? (isDark ? 0.55 : 0.6) : 1.0)
        .contextMenu {
            // 推迟一天
            Button(action: {
                task.endDate = Calendar.current.date(byAdding: .day, value: 1, to: task.endDate) ?? task.endDate
                try? modelContext.save()
            }) {
                Label(isEnglish ? "Push back 1 day" : "推迟一天", systemImage: "arrow.right.circle")
            }

            // 设为今天截止
            Button(action: {
                let today = Calendar.current.startOfDay(for: Date())
                task.endDate = today
                task.startDate = today
                try? modelContext.save()
            }) {
                Label(isEnglish ? "Set Due to Today" : "设为今天截止", systemImage: "clock.badge.exclamationmark")
            }

            Divider()

            // 编辑
            Button(action: { onEdit(task) }) {
                Label(isEnglish ? "Edit Details" : "详细修改", systemImage: "pencil")
            }

            // 删除 (移入回收站并支持主页反色胶囊撤销)
            Button(role: .destructive, action: {
                if let onDelete {
                    onDelete(task)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                        task.deletedDate = Date()
                    }
                    try? modelContext.save()
                }
            }) {
                Label(isEnglish ? "Delete" : "删除", systemImage: "trash")
            }
        }
    }
}
