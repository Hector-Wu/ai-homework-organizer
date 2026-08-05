// Filename: WidgetModels.swift
// 用途：全局配置枚举 —— 字体大小、组件筛选类型
// 注：ScaledFont 和 View.scaledFont 已移至 Extensions.swift

import SwiftUI

// MARK: - 应用语言枚举

enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh-Hans"
    case english = "en"
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .chinese: return "中文 (Chinese)"
        case .english: return "English"
        }
    }
}

// MARK: - AI 输出语言枚举

enum OutputLanguage: String, CaseIterable, Identifiable {
    case chinese = "Chinese"
    case english = "English"
    var id: String { self.rawValue }
    var displayName: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        }
    }
}

// MARK: - 全局字体大小枚举（绝对比例缩放，不受系统无障碍影响）

enum AppFontSize: String, CaseIterable, Identifiable {
    case small  = "Small"
    case medium = "Medium"
    case large  = "Large"

    var id: String { self.rawValue }

    /// 相对于基准字号的缩放比例
    var scale: CGFloat {
        switch self {
        case .small:  return 0.85
        case .medium: return 1.0
        case .large:  return 1.15
        }
    }

    func displayName(isEnglish: Bool) -> String {
        switch self {
        case .small:  return isEnglish ? "Small"  : "小"
        case .medium: return isEnglish ? "Medium" : "中 (默认)"
        case .large:  return isEnglish ? "Large"  : "大"
        }
    }
}

// MARK: - 悬浮窗/状态栏作业筛选类型

enum WidgetFilterType: String, CaseIterable, Identifiable {
    case allToday = "AllToday"
    case onlyDue  = "OnlyDue"

    var id: String { self.rawValue }

    func displayName(isEnglish: Bool) -> String {
        switch self {
        case .allToday: return isEnglish ? "All Today's Tasks"   : "今日全部作业"
        case .onlyDue:  return isEnglish ? "Only Urgent / Due"   : "仅限紧急 / 即将截止"
        }
    }
}
