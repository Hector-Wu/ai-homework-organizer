//
//  HomeworkRowCard.swift
//  Homework Assistant
//
//  Created by Hector Wu on 26/4/2026.
//


// Filename: HomeworkRowCard.swift
// 用途: 作业卡片视图, 用于DayView和CalendarListView, 包含打勾、状态、上下文菜单等功能

import SwiftUI
import SwiftData

struct HomeworkRowCard: View {
    @Bindable var task: HomeworkItem
    @ObservedObject var subjectManager: SubjectManager
    var onEdit: (HomeworkItem) -> Void
    var viewedDate: Date
    var isEnglish: Bool

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let stat = task.getSCRStatus(viewedDate: viewedDate, isEnglish: isEnglish)

        HStack {
            // 打勾按钮
            Button(action: {
                withAnimation { task.isCompleted.toggle() }
                try? modelContext.save()
            }) {
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(task.isCompleted ? .gray : .blue)
            }
            .buttonStyle(.plain)

            // 科目颜色左边条
            Rectangle()
                .fill(task.isCompleted ? .gray : subjectManager.getColor(for: task.subject))
                .frame(width: 4)

            // 内容区
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // 科目徽章
                    Text(task.subject)
                        .scaledFont(size: 12, weight: .bold)
                        .padding(2)
                        .background(
                            task.isCompleted
                                ? Color.gray.opacity(0.1)
                                : subjectManager.getColor(for: task.subject).opacity(0.1)
                        )
                        .cornerRadius(4)
                        .foregroundStyle(task.isCompleted ? .gray : .primary)

                    // 特殊备注标签
                    if let notes = task.specialNotes, !notes.isEmpty {
                        Text(notes)
                            .scaledFont(size: 10)
                            .foregroundStyle(task.isCompleted ? .gray : .red)
                            .padding(2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(task.isCompleted ? Color.gray : Color.red, lineWidth: 1)
                            )
                    }
                }

                // 作业内容
                Text(task.content)
                    .scaledFont(size: 15)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .gray : .primary)
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
                    .cornerRadius(6)
            }
        }
        .padding(.horizontal, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    stat.isUrgent && !task.isCompleted ? stat.color.opacity(0.6) : Color.gray.opacity(0.1),
                    lineWidth: stat.isUrgent && !task.isCompleted ? 2 : 1
                )
        )
        .opacity(task.isCompleted ? 0.6 : 1.0)
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
            
            // 删除 (移入回收站)
            Button(role: .destructive, action: {
                task.deletedDate = Date()
                try? modelContext.save()
            }) {
                Label(isEnglish ? "Delete" : "删除", systemImage: "trash")
            }
        }
    }
}
