// Filename: HomeworkLogic.swift
// 用途: 业务逻辑层，处理多引擎AI请求调度、自动限流回退、JSON清洗、长短期日期解析及数据持久化

import Foundation
import SwiftData
import SwiftUI

class HomeworkManager {
    private let llmService = UnifiedLLMService()
    private var config: AIConfigManager { AIConfigManager.shared }

    private static let dueDateParsers: [DateFormatter] = {
        let formats = ["yyyy-MM-dd", "yyyy/MM/dd", "yyyy.MM.dd"]
        return formats.map { fmt in
            let f = DateFormatter()
            f.calendar = Calendar(identifier: .gregorian)
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone.current
            f.dateFormat = fmt
            return f
        }
    }()

    @MainActor
    @discardableResult
    func processInput(
        text: String,
        outputLang: String,
        modelContext: ModelContext,
        onLog: @escaping (AppLog) -> Void
    ) async throws -> [HomeworkItem] {
        guard let primaryProvider = config.resolveActiveProvider() else {
            throw LLMError.invalidKey
        }
        
        var candidates: [APIProvider] = [primaryProvider]
        if config.autoFallbackOnError {
            candidates.append(contentsOf: config.fallbackCandidates(excluding: [primaryProvider]))
        }
        
        let systemPrompt = PromptManager.shared.getEffectivePrompt(lang: outputLang)
        var lastError: Error = LLMError.invalidKey
        
        for (index, provider) in candidates.enumerated() {
            let modelName = config.effectiveModel(for: provider)
            let endpoint = config.effectiveEndpoint(for: provider)
            let key = config.apiKey(for: provider)
            
            let prefix = index == 0 ? "Engine" : "Fallback Engine #\(index)"
            onLog(AppLog(type: .info, message: "\(prefix): \(provider.displayName(isEnglish: false)) [\(modelName)]"))
            
            do {
                let jsonString = try await llmService.send(
                    provider: provider,
                    endpoint: endpoint,
                    model: modelName,
                    prompt: systemPrompt,
                    text: text,
                    apiKey: key,
                    onLog: onLog
                )
                return try parseAndSave(jsonString: jsonString, modelContext: modelContext, onLog: onLog)
            } catch let llmErr as LLMError {
                lastError = llmErr
                let hasMoreCandidates = index < (candidates.count - 1)
                if hasMoreCandidates && llmErr.isRetryableWithFallback {
                    onLog(AppLog(
                        type: .error,
                        message: "⚠️ \(provider.shortName) unavailable (\(llmErr.localizedDescription)), switching fallback..."
                    ))
                    continue
                }
                throw llmErr
            } catch {
                lastError = error
                throw error
            }
        }
        
        throw lastError
    }

    private func extractCleanJSONArrayString(from raw: String) -> String {
        var text = raw
        
        if let regex = try? NSRegularExpression(pattern: "<think>[\\s\\S]*?</think>", options: [.caseInsensitive]) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        }
        
        let fence = String(repeating: "\u{0060}", count: 3)
        text = text
            .replacingOccurrences(of: fence + "json", with: "")
            .replacingOccurrences(of: fence + "JSON", with: "")
            .replacingOccurrences(of: fence, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let startIdx = text.firstIndex(of: "["),
           let endIdx = text.lastIndex(of: "]"),
           startIdx <= endIdx {
            return String(text[startIdx...endIdx])
        }
        
        if let objStart = text.firstIndex(of: "{"),
           let objEnd = text.lastIndex(of: "}"),
           objStart <= objEnd {
            return "[\(String(text[objStart...objEnd]))]"
        }
        
        return text
    }

    @MainActor
    private func parseAndSave(
        jsonString: String,
        modelContext: ModelContext,
        onLog: @escaping (AppLog) -> Void
    ) throws -> [HomeworkItem] {
        let clean = extractCleanJSONArrayString(from: jsonString)
        
        guard let data = clean.data(using: .utf8) else {
            throw LLMError.decodingError("Data conversion failed")
        }
        
        let tasks: [AIHomeworkResponse]
        do {
            tasks = try JSONDecoder().decode([AIHomeworkResponse].self, from: data)
        } catch {
            throw LLMError.decodingError(error.localizedDescription)
        }
        
        var existing = try fetchAllSubjectNames(context: modelContext)
        var insertedItems: [HomeworkItem] = []
        
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
            if !existing.contains(normalized) {
                existing.append(normalized)
            }
            if let item = save(task: task, subject: normalized, context: modelContext) {
                insertedItems.append(item)
            }
        }
        
        try? modelContext.save()
        onLog(AppLog(type: .success, message: "Saved \(insertedItems.count) tasks"))
        return insertedItems
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

    private func resolveEndDate(for task: AIHomeworkResponse, today: Date, calendar: Calendar) -> Date {
        // 1. 若 AI 返回了明确日历日期 dueDate ("YYYY-MM-DD")，优先精确解析（完美应对跨月/两个月以上大作业）
        if let rawDue = task.dueDate?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawDue.isEmpty {
            let datePrefix = String(rawDue.prefix(10))
            for parser in Self.dueDateParsers {
                if let parsed = parser.date(from: datePrefix) {
                    return calendar.startOfDay(for: parsed)
                }
            }
        }
        
        // 2. 否则 100% 沿用原有的 daysFromToday + durationDays 计算规则
        var comp = DateComponents()
        comp.day = (task.daysFromToday ?? 0) + ((task.durationDays ?? 1) > 1 ? (task.durationDays ?? 1) - 1 : 0)
        let end = calendar.date(byAdding: comp, to: today) ?? today
        return calendar.startOfDay(for: end)
    }

    @MainActor
    private func save(
        task: AIHomeworkResponse,
        subject: String,
        context: ModelContext
    ) -> HomeworkItem? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let cleanEnd = max(today, resolveEndDate(for: task, today: today, calendar: cal))
        
        // 修复点：加上 endDate == cleanEnd 判断，只拦截同一截止日的完全重复项，避免跨周布置同名日常作业被吞掉
        let desc = FetchDescriptor<HomeworkItem>(
            predicate: #Predicate {
                $0.subject == subject &&
                $0.content == task.content &&
                $0.endDate == cleanEnd &&
                $0.deletedDate == nil
            }
        )
        
        if ((try? context.fetch(desc).count) ?? 0) > 0 { return nil }
        
        let newItem = HomeworkItem(
            subject: subject,
            content: task.content,
            specialNotes: task.notes,
            startDate: today,
            endDate: cleanEnd
        )
        context.insert(newItem)
        return newItem
    }
}
