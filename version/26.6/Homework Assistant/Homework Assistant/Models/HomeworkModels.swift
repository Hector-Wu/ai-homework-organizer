// Filename: HomeworkModels.swift
// 用途:定义所有数据结构 — 数据库模型、AI响应模型、日志模型、枚举、Prompt管理器

import Foundation
import SwiftData
import Combine

@Model
final class HomeworkItem {
    var id: UUID
    var subject: String
    var content: String
    var specialNotes: String?
    var startDate: Date
    var endDate: Date
    var isCompleted: Bool
    var creationDate: Date
    var deletedDate: Date?
    
    init(subject: String, content: String, specialNotes: String? = nil, startDate: Date, endDate: Date) {
        self.id = UUID()
        self.subject = subject
        self.content = content
        self.specialNotes = specialNotes
        let cal = Calendar.current
        self.startDate = cal.startOfDay(for: startDate)
        self.endDate = cal.startOfDay(for: endDate)
        self.isCompleted = false
        self.creationDate = Date()
        self.deletedDate = nil
    }
}

struct AIHomeworkResponse: Codable {
    let subject_en: String?
    let subject_zh: String?
    let content: String
    let notes: String?
    let daysFromToday: Int?
    let durationDays: Int?
}

struct AppLog: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let type: LogType
    let message: String
    
    enum LogType { case info, success, error, aiRaw }
}

enum APIProvider: String, CaseIterable, Identifiable {
    case groq = "Groq (Llama 3)"
    case glm = "Zhipu (GLM-4 Flash)"
    var id: String { self.rawValue }
}

class PromptManager: ObservableObject {
    static let shared = PromptManager()

    static let defaultPromptText = """
    Role: Homework Parser.
    Task: Extract homework.
    Output Language: {{LANG}}.
    Context: Today is {{DATE}}.
    Rules:
    1. **SPLIT**: Separate multiple items.
    2. **SUBJECT**: Return 'subject_en' AND 'subject_zh'. Do NOT treat books/objects as subjects. If unknown, use "General/综合".
    3. **DATE**: 0=Today, 1=Tomorrow, etc. Calculate 'daysFromToday' relative to {{DATE}}.
    4. **NOISE**: Ignore administrative notes. Do NOT include time/hours.

    Output: JSON Array ONLY.
    JSON: [{"subject_en":String, "subject_zh":String, "content":String, "notes":String?, "daysFromToday":Int?, "durationDays":Int?}]
    """
    
    @Published var customPrompt: String {
        didSet { UserDefaults.standard.set(customPrompt, forKey: "custom_system_prompt") }
    }
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: "custom_system_prompt") ?? ""
        self.customPrompt = saved.isEmpty ? Self.defaultPromptText : saved
    }
    
    func getEffectivePrompt(lang: String) -> String {
        let weekday = Date().formatted(Date.FormatStyle().weekday(.wide))
        let dateStr = "\(Date().formatted(date: .numeric, time: .omitted)) (\(weekday))"
        return customPrompt
            .replacingOccurrences(of: "{{LANG}}", with: lang)
            .replacingOccurrences(of: "{{DATE}}", with: dateStr)
    }
    
    func resetToDefault() {
        self.customPrompt = Self.defaultPromptText
    }
}
