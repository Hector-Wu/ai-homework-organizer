// Filename: Shared/HomeworkItemExtensions.swift
// 用途: HomeworkItem 的业务逻辑扩展 — 优先级、激活判断、剩余天数

import SwiftUI

extension HomeworkItem {
    // MARK: - SCR 优先级状态计算
    // 返回: (status: Int, text: String, color: Color, isUrgent: Bool)
    // 9 = OVERDUE (逾期, 最高优先, 红色紧急)
    // 1 = DUE (今天/明天截止, 橙/红色紧急)
    // 2 = 倒计时 (7天内, 橙/绿色提示)
    // 3 = 普通 (7天以上, 透明无标签)
    func getSCRStatus(viewedDate: Date, isEnglish: Bool) -> (status: Int, text: String, color: Color, isUrgent: Bool) {
        let cal = Calendar.current
        let vDay = cal.startOfDay(for: viewedDate)
        let sDay = cal.startOfDay(for: startDate)
        let eDay = cal.startOfDay(for: endDate)
        let realToday = cal.startOfDay(for: Date())

        let daysToDue = cal.dateComponents([.day], from: vDay, to: eDay).day ?? 0
        let isViewedToday = cal.isDateInToday(vDay)

        // 单日作业 (布置当天 == 截止当天)
        if sDay == eDay {
            if daysToDue == 0 { // 截止当天
                return (1, "DUE", isViewedToday ? .red : .orange, true)
            }
            // 昨天截止、今天查看、未完成 -> OVERDUE
            if daysToDue == -1 && vDay == realToday && !isCompleted {
                return (9, isEnglish ? "OVERDUE" : "已逾期", Color(white: 0.3), true)
            }
            return (3, "", .clear, false)
        }

        // 多日作业 (有时间跨度)
        if daysToDue < 0 && !isCompleted {
            return (9, isEnglish ? "OVERDUE" : "已逾期", Color(white: 0.3), true)
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

    // 文件路径: Shared/HomeworkItemExtensions.swift

        // MARK: - 判断作业在指定日期是否"激活" (应显示在该日的视图中)
        func isActiveOn(date: Date) -> Bool {
            let cal = Calendar.current
            let vDay = cal.startOfDay(for: date)
            let sDay = cal.startOfDay(for: startDate)
            let eDay = cal.startOfDay(for: endDate)
            let realToday = cal.startOfDay(for: Date())

            // 视图日期在作业开始之前，肯定不激活
            if vDay < sDay { return false }

            // 在正常的作业周期内 (包含开始和截止当天)
            if vDay >= sDay && vDay <= eDay {
                return true
            }

            // 逾期提醒逻辑: 如果作业已过期(vDay > eDay), 仅在真实世界的“今天”且作业未完成时显示
            if vDay > eDay && vDay == realToday && !isCompleted {
                // 计算逾期天数，超过 3 天则自动在“今天”视图中隐藏 (不再常驻)
                let daysOverdue = cal.dateComponents([.day], from: eDay, to: realToday).day ?? 0
                if daysOverdue <= 3 {
                    return true
                }
            }
            
            return false
        }

    // MARK: - 计算从指定日期到截止日的天数
    func daysToDue(from date: Date) -> Int {
        let cal = Calendar.current
        let vDay = cal.startOfDay(for: date)
        let eDay = cal.startOfDay(for: endDate)
        return cal.dateComponents([.day], from: vDay, to: eDay).day ?? 0
    }
}
