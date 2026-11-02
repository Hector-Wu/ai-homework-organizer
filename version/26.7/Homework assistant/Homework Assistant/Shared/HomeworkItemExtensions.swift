// Filename: Shared/HomeworkItemExtensions.swift
// 用途: HomeworkItem 的业务逻辑扩展 — 优先级、暗色适配逾期颜色、激活判断、剩余天数

import SwiftUI
import AppKit

extension HomeworkItem {
    // 浅色下保持沉稳深灰，暗色下自动提亮为醒目酒红紫，避免深灰融入暗色背景看不清
    private static var adaptiveOverdueColor: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark
                ? NSColor(srgbRed: 0.78, green: 0.24, blue: 0.38, alpha: 1.0)
                : NSColor(calibratedWhite: 0.28, alpha: 1.0)
        })
    }

    func getSCRStatus(viewedDate: Date, isEnglish: Bool) -> (status: Int, text: String, color: Color, isUrgent: Bool) {
        let cal = Calendar.current
        let vDay = cal.startOfDay(for: viewedDate)
        let sDay = cal.startOfDay(for: startDate)
        let eDay = cal.startOfDay(for: endDate)
        let realToday = cal.startOfDay(for: Date())

        let daysToDue = cal.dateComponents([.day], from: vDay, to: eDay).day ?? 0
        let isViewedToday = cal.isDateInToday(vDay)

        if sDay == eDay {
            if daysToDue == 0 {
                return (1, "DUE", isViewedToday ? .red : .orange, true)
            }
            if daysToDue == -1 && vDay == realToday && !isCompleted {
                return (9, isEnglish ? "OVERDUE" : "已逾期", Self.adaptiveOverdueColor, true)
            }
            return (3, "", .clear, false)
        }

        if daysToDue < 0 && !isCompleted {
            return (9, isEnglish ? "OVERDUE" : "已逾期", Self.adaptiveOverdueColor, true)
        }
        if daysToDue == 0 {
            return (1, "DUE", isViewedToday ? .red : .orange, true)
        }
        if daysToDue == 1 {
            return (1, "DUE", isViewedToday ? .red : .orange, true)
        }
        if daysToDue > 1 {
            let left = daysToDue
            if left > 7 { return (3, "", .clear, false) }
            if left > 3 { return (2, isEnglish ? "\(left) Days Left" : "倒计时 \(left)天", .green, false) }
            return (2, isEnglish ? "\(left) Days Left" : "倒计时 \(left) 天", .orange, false)
        }
        
        return (3, "", .clear, false)
    }

    func isActiveOn(date: Date) -> Bool {
        let cal = Calendar.current
        let vDay = cal.startOfDay(for: date)
        let sDay = cal.startOfDay(for: startDate)
        let eDay = cal.startOfDay(for: endDate)
        let realToday = cal.startOfDay(for: Date())

        if vDay < sDay { return false }

        if vDay >= sDay && vDay <= eDay {
            return true
        }

        if vDay > eDay && vDay == realToday && !isCompleted {
            let daysOverdue = cal.dateComponents([.day], from: eDay, to: realToday).day ?? 0
            if daysOverdue <= 3 {
                return true
            }
        }
        
        return false
    }

    func daysToDue(from date: Date) -> Int {
        let cal = Calendar.current
        let vDay = cal.startOfDay(for: date)
        let eDay = cal.startOfDay(for: endDate)
        return cal.dateComponents([.day], from: vDay, to: eDay).day ?? 0
    }
}
