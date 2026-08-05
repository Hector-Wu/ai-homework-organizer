// Filename: HomeworkLogic.swift
// 用途: 业务逻辑层，处理AI请求和数据持久化

import Foundation
import SwiftData
import SwiftUI

class HomeworkManager {
    private var groqKey: String? {
        UserDefaults.standard.string(forKey: "user_groq_api_key")
    }
    private var zhipuKey: String? {
        UserDefaults.standard.string(forKey: "user_zhipu_api_key")
    }
    private var preferredProvider: APIProvider {
        if let raw = UserDefaults.standard.string(forKey: "preferred_api_provider"),
           let p = APIProvider(rawValue: raw) { return p }
        return .groq
    }

    private let groqClient = GroqClient()
    private let zhipuClient = ZhipuClient()

    // MARK: - 计算实际将使用的引擎 (考虑 Key 是否存在)
    /// 规则:
    /// 1. 优先使用用户设定的默认引擎 (前提是该引擎有 Key)
    /// 2. 默认引擎没有 Key 但另一个有, 自动回退
    /// 3. 两个都没有 Key -> 抛出 invalidKey
    static func resolveActiveProvider(
        preferred: APIProvider,
        groqKey: String?,
        zhipuKey: String?
    ) -> APIProvider? {
        let hasGroq = !(groqKey?.isEmpty ?? true)
        let hasZhipu = !(zhipuKey?.isEmpty ?? true)
        
        switch preferred {
        case .groq:
            if hasGroq { return .groq }
            if hasZhipu { return .glm }
            return nil
        case .glm:
            if hasZhipu { return .glm }
            if hasGroq { return .groq }
            return nil
        }
    }

    @MainActor
    func processInput(
        text: String,
        outputLang: String,
        modelContext: ModelContext,
        onLog: @escaping (AppLog) -> Void
    ) async throws {
        guard let provider = Self.resolveActiveProvider(
            preferred: preferredProvider,
            groqKey: groqKey,
            zhipuKey: zhipuKey
        ) else {
            throw LLMError.invalidKey
        }
        
        let key: String
        switch provider {
        case .groq: key = groqKey ?? ""
        case .glm: key = zhipuKey ?? ""
        }
        
        guard !key.isEmpty else { throw LLMError.invalidKey }

        let engineName = provider == .groq ? "Groq (Llama 3)" : "Zhipu (GLM-4 Flash)"
        onLog(AppLog(type: .info, message: "Engine: \(engineName)"))
        
        let systemPrompt = PromptManager.shared.getEffectivePrompt(lang: outputLang)
        
        let jsonString: String
        if provider == .groq {
            jsonString = try await groqClient.send(
                prompt: systemPrompt, text: text, apiKey: key, onLog: onLog
            )
        } else {
            jsonString = try await zhipuClient.send(
                prompt: systemPrompt, text: text, apiKey: key, onLog: onLog
            )
        }
        
        try parseAndSave(jsonString: jsonString, modelContext: modelContext, onLog: onLog)
    }

    @MainActor
    private func parseAndSave(
        jsonString: String,
        modelContext: ModelContext,
        onLog: @escaping (AppLog) -> Void
    ) throws {
        let clean = jsonString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = clean.data(using: .utf8) else {
            throw LLMError.decodingError("Data conversion failed")
        }
        
        let tasks = try JSONDecoder().decode([AIHomeworkResponse].self, from: data)
        let existing = try fetchAllSubjectNames(context: modelContext)
        
        var savedCount = 0
        for task in tasks {
            let en = task.subject_en ?? ""
            let zh = task.subject_zh ?? ""
            var sub = "\(zh) \(en)".trimmingCharacters(in: .whitespaces)
            if sub.isEmpty {
                if !zh.isEmpty { sub = zh }
                else if !en.isEmpty { sub = en }
                else { sub = "综合 General" }
            }
            
            let normalized = normalize(raw: sub, existing: existing)
            if save(task: task, subject: normalized, context: modelContext) {
                savedCount += 1
            }
        }
        
        onLog(AppLog(type: .success, message: "Saved \(savedCount) tasks"))
    }
    
    private func fetchAllSubjectNames(context: ModelContext) throws -> [String] {
        let items = try context.fetch(FetchDescriptor<HomeworkItem>())
        return Array(Set(items.map { $0.subject }))
    }
    
    private func normalize(raw: String, existing: [String]) -> String {
        if existing.contains(raw) { return raw }
        let keys = raw.split(separator: " ").map { String($0).lowercased() }
        for exist in existing {
            let existLower = exist.lowercased()
            for k in keys {
                if k.count > 1 && existLower.contains(k) { return exist }
            }
        }
        return raw
    }

    @MainActor
    private func save(
        task: AIHomeworkResponse,
        subject: String,
        context: ModelContext
    ) -> Bool {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        
        var comp = DateComponents()
        comp.day = (task.daysFromToday ?? 0) + ((task.durationDays ?? 1) > 1 ? (task.durationDays ?? 1) - 1 : 0)
        let end = cal.date(byAdding: comp, to: today) ?? today
        let cleanEnd = cal.startOfDay(for: end)
        
        let desc = FetchDescriptor<HomeworkItem>(
            predicate: #Predicate {
                $0.subject == subject &&
                $0.content == task.content &&
                $0.deletedDate == nil
            }
        )
        
        if (try? context.fetch(desc).count) ?? 0 > 0 { return false }
        
        context.insert(HomeworkItem(
            subject: subject,
            content: task.content,
            specialNotes: task.notes,
            startDate: today,
            endDate: cleanEnd
        ))
        try? context.save()
        return true
    }
}
