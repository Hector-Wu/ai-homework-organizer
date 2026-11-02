// Filename: HomeworkModels.swift
// 用途: 定义所有数据结构 — 数据库模型、兼容旧版与长周期日期的AI响应模型、Keychain加密配置管理器、Prompt管理器

import Foundation
import SwiftData
import SwiftUI
import Combine
import Security

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

// 100% 兼容旧版 JSON 结构；额外可选支持 dueDate ("YYYY-MM-DD") 以精准处理跨月/超长周期作业
struct AIHomeworkResponse: Codable {
    let subject_en: String?
    let subject_zh: String?
    let content: String
    let notes: String?
    let daysFromToday: Int?
    let durationDays: Int?
    let dueDate: String?
}

struct AppLog: Identifiable {
    let id = UUID()
    let timestamp = Date()
    let type: LogType
    let message: String
    
    enum LogType { case info, success, error, aiRaw }
}

// MARK: - macOS 原生系统钥匙串加密工具（替代 UserDefaults 明文存储 API Key）
enum KeychainHelper {
    private static let service = "hector0922.Homework-assistant.apikeys"
    
    static func save(_ value: String, account: String) {
        let queryBase: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(queryBase as CFDictionary)
        
        guard !value.isEmpty, let data = value.data(using: .utf8) else { return }
        
        var addQuery = queryBase
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(addQuery as CFDictionary, nil)
    }
    
    static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }
    
    static func deleteAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - 主流 AI 引擎枚举（不含 Claude，优先免费够用模型，支持自定义模型与本地接口）
enum APIProvider: String, CaseIterable, Identifiable, Codable {
    case groq         = "Groq (Llama 3)"
    case glm          = "Zhipu (GLM-4 Flash)"
    case gemini       = "Google (Gemini / Gemma)"
    case siliconFlow  = "SiliconFlow"
    case openRouter   = "OpenRouter"
    case githubModels = "GitHub Models"
    case qwen         = "Alibaba Qwen"
    case deepseek     = "DeepSeek"
    case openai       = "OpenAI (ChatGPT)"
    case custom       = "Custom (OpenAI / Ollama)"
    
    var id: String { self.rawValue }
    
    func displayName(isEnglish: Bool) -> String {
        switch self {
        case .groq:         return "Groq"
        case .glm:          return isEnglish ? "Zhipu AI (GLM)" : "智谱 AI (GLM)"
        case .gemini:       return "Google AI Studio (Gemini)"
        case .siliconFlow:  return isEnglish ? "SiliconFlow" : "硅基流动 (SiliconFlow)"
        case .openRouter:   return "OpenRouter"
        case .githubModels: return "GitHub Models"
        case .qwen:         return isEnglish ? "Alibaba Qwen (DashScope)" : "通义千问 (阿里云百炼)"
        case .deepseek:     return isEnglish ? "DeepSeek" : "DeepSeek (深度求索)"
        case .openai:       return "OpenAI (ChatGPT)"
        case .custom:       return isEnglish ? "Custom / Local (Ollama)" : "自定义接口 / 本地模型"
        }
    }
    
    var shortName: String {
        switch self {
        case .groq:         return "Groq"
        case .glm:          return "Zhipu"
        case .gemini:       return "Gemini"
        case .siliconFlow:  return "SiliconFlow"
        case .openRouter:   return "OpenRouter"
        case .githubModels: return "GitHub"
        case .qwen:         return "Qwen"
        case .deepseek:     return "DeepSeek"
        case .openai:       return "OpenAI"
        case .custom:       return "Custom"
        }
    }
    
    func subtitle(isEnglish: Bool) -> String {
        switch self {
        case .groq:
            return isEnglish ? "Ultra-fast inference · Free tier (Llama 3.3)" : "超高速推理 · 提供免费额度 (Llama 3.3)"
        case .glm:
            return isEnglish ? "Direct in China · Official free GLM-4-Flash" : "国内直连 · 官方提供永久免费 Flash 模型"
        case .gemini:
            return isEnglish ? "Official free tier · Gemini 2.5 Flash & Gemma 3" : "官方免费 API 额度 · 支持 Gemini 2.5 Flash 与 Gemma 3"
        case .siliconFlow:
            return isEnglish ? "Multiple permanent free 7B/8B/9B models" : "国内直连 · 多款 7B/8B/9B 开源模型永久免费"
        case .openRouter:
            return isEnglish ? "Aggregates dozens of :free mainstream models" : "聚合数十款带 :free 后缀的免费主流大模型"
        case .githubModels:
            return isEnglish ? "Free GPT-4o-mini & Llama 3.3 with GitHub PAT" : "使用 GitHub Token 免费调用 GPT-4o-mini / Llama"
        case .qwen:
            return isEnglish ? "Direct in China · Free trial quota & Qwen-Turbo" : "国内直连 · 百炼新人免费额度与轻量 Qwen-Turbo"
        case .deepseek:
            return isEnglish ? "Direct in China · High-value DeepSeek-V3" : "国内直连 · 高性价比主力模型 DeepSeek-V3"
        case .openai:
            return isEnglish ? "Official ChatGPT API · Lightweight GPT-4o-mini" : "官方接口 · 轻量够用的 GPT-4o-mini / 4.1-nano"
        case .custom:
            return isEnglish ? "Ollama, LM Studio, Hunyuan, Kimi, or any OpenAI API" : "支持本地 Ollama/LM Studio、腾讯混元免费版、Kimi、中转站等"
        }
    }
    
    func badgeTag(isEnglish: Bool) -> String? {
        switch self {
        case .groq:         return isEnglish ? "Free Tier" : "免费额度"
        case .glm:          return isEnglish ? "Free" : "永久免费"
        case .gemini:       return isEnglish ? "Free Tier" : "免费额度"
        case .siliconFlow:  return isEnglish ? "Free Models" : "多款免费"
        case .openRouter:   return isEnglish ? ":free" : "含免费"
        case .githubModels: return isEnglish ? "Free" : "免费"
        case .qwen:         return isEnglish ? "Trial Free" : "送额度"
        case .deepseek:     return isEnglish ? "Low Cost" : "低成本"
        case .openai:       return nil
        case .custom:       return isEnglish ? "DIY / Local" : "自定义"
        }
    }
    
    var brandColor: Color {
        switch self {
        case .groq:         return Color(red: 0.96, green: 0.51, blue: 0.19)
        case .glm:          return Color(red: 0.20, green: 0.45, blue: 0.90)
        case .gemini:       return Color(red: 0.26, green: 0.52, blue: 0.96)
        case .siliconFlow:  return Color(red: 0.45, green: 0.32, blue: 0.92)
        case .openRouter:   return Color(red: 0.16, green: 0.65, blue: 0.55)
        case .githubModels: return Color(red: 0.28, green: 0.32, blue: 0.38)
        case .qwen:         return Color(red: 0.38, green: 0.28, blue: 0.88)
        case .deepseek:     return Color(red: 0.18, green: 0.42, blue: 0.85)
        case .openai:       return Color(red: 0.06, green: 0.64, blue: 0.50)
        case .custom:       return Color(red: 0.55, green: 0.38, blue: 0.78)
        }
    }
    
    var defaultEndpoint: String {
        switch self {
        case .groq:         return "https://api.groq.com/openai/v1/chat/completions"
        case .glm:          return "https://open.bigmodel.cn/api/paas/v4/chat/completions"
        case .gemini:       return "https://generativelanguage.googleapis.com/v1beta"
        case .siliconFlow:  return "https://api.siliconflow.cn/v1/chat/completions"
        case .openRouter:   return "https://openrouter.ai/api/v1/chat/completions"
        case .githubModels: return "https://models.inference.ai.azure.com/chat/completions"
        case .qwen:         return "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
        case .deepseek:     return "https://api.deepseek.com/chat/completions"
        case .openai:       return "https://api.openai.com/v1/chat/completions"
        case .custom:       return "http://localhost:11434/v1/chat/completions"
        }
    }
    
    var defaultModel: String {
        switch self {
        case .groq:         return "llama-3.3-70b-versatile"
        case .glm:          return "glm-4-flash-250414"
        case .gemini:       return "gemini-2.5-flash"
        case .siliconFlow:  return "Qwen/Qwen2.5-7B-Instruct"
        case .openRouter:   return "meta-llama/llama-3.3-70b-instruct:free"
        case .githubModels: return "gpt-4o-mini"
        case .qwen:         return "qwen-turbo"
        case .deepseek:     return "deepseek-chat"
        case .openai:       return "gpt-4o-mini"
        case .custom:       return "qwen2.5:7b"
        }
    }
    
    var presetModels: [String] {
        switch self {
        case .groq:
            return ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "qwen/qwen3-32b"]
        case .glm:
            return ["glm-4-flash-250414", "glm-4.5-flash", "glm-4-flash"]
        case .gemini:
            return ["gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-2.0-flash", "gemma-3-27b-it", "gemma-3-12b-it"]
        case .siliconFlow:
            return ["Qwen/Qwen2.5-7B-Instruct", "Qwen/Qwen3-8B", "THUDM/GLM-4-9B-0414", "deepseek-ai/DeepSeek-R1-Distill-Qwen-7B"]
        case .openRouter:
            return ["meta-llama/llama-3.3-70b-instruct:free", "google/gemma-3-27b-it:free", "qwen/qwen-2.5-72b-instruct:free", "deepseek/deepseek-chat-v3-0324:free"]
        case .githubModels:
            return ["gpt-4o-mini", "Llama-3.3-70B-Instruct", "Mistral-small"]
        case .qwen:
            return ["qwen-turbo", "qwen-plus", "qwen2.5-72b-instruct", "qwen2.5-7b-instruct"]
        case .deepseek:
            return ["deepseek-chat", "deepseek-reasoner"]
        case .openai:
            return ["gpt-4o-mini", "gpt-4.1-mini", "gpt-4.1-nano"]
        case .custom:
            return ["qwen2.5:7b", "llama3.2:3b", "gemma3:4b", "hunyuan-lite", "moonshot-v1-8k"]
        }
    }
    
    func keyPlaceholder(isEnglish: Bool) -> String {
        switch self {
        case .groq:         return "gsk_..."
        case .glm:          return isEnglish ? "Paste Zhipu API Key..." : "粘贴智谱 API Key..."
        case .gemini:       return "AIzaSy..."
        case .siliconFlow:  return "sk-..."
        case .openRouter:   return "sk-or-v1-..."
        case .githubModels: return "ghp_... / github_pat_..."
        case .qwen:         return "sk-..."
        case .deepseek:     return "sk-..."
        case .openai:       return "sk-..."
        case .custom:       return isEnglish ? "Optional for local Ollama; sk-... for cloud" : "本地 Ollama 可留空；云端接口填 sk-..."
        }
    }
    
    var keyPortalURL: URL? {
        switch self {
        case .groq:         return URL(string: "https://console.groq.com/keys")
        case .glm:          return URL(string: "https://open.bigmodel.cn/usercenter/apikeys")
        case .gemini:       return URL(string: "https://aistudio.google.com/app/apikey")
        case .siliconFlow:  return URL(string: "https://cloud.siliconflow.cn/account/ak")
        case .openRouter:   return URL(string: "https://openrouter.ai/keys")
        case .githubModels: return URL(string: "https://github.com/settings/tokens")
        case .qwen:         return URL(string: "https://bailian.console.aliyun.com/?apiKey=1")
        case .deepseek:     return URL(string: "https://platform.deepseek.com/api_keys")
        case .openai:       return URL(string: "https://platform.openai.com/api-keys")
        case .custom:       return nil
        }
    }
    
    var usesGoogleNativeProtocol: Bool {
        self == .gemini
    }
    
    var legacyUserDefaultsKey: String? {
        switch self {
        case .groq:   return "user_groq_api_key"
        case .glm:    return "user_zhipu_api_key"
        case .gemini: return "user_google_api_key"
        default:      return nil
        }
    }
}

// MARK: - 自定义接口快捷模板
struct CustomEndpointTemplate: Identifiable {
    let id: String
    let nameZh: String
    let nameEn: String
    let endpoint: String
    let defaultModel: String
    let allowEmptyKey: Bool
    
    static let all: [CustomEndpointTemplate] = [
        CustomEndpointTemplate(
            id: "ollama",
            nameZh: "Ollama 本地模型 (完全免费·免 Key)",
            nameEn: "Ollama Local (Free · No Key)",
            endpoint: "http://localhost:11434/v1/chat/completions",
            defaultModel: "qwen2.5:7b",
            allowEmptyKey: true
        ),
        CustomEndpointTemplate(
            id: "lmstudio",
            nameZh: "LM Studio 本地服务 (完全免费·免 Key)",
            nameEn: "LM Studio Local (Free · No Key)",
            endpoint: "http://localhost:1234/v1/chat/completions",
            defaultModel: "local-model",
            allowEmptyKey: true
        ),
        CustomEndpointTemplate(
            id: "hunyuan",
            nameZh: "腾讯混元 (hunyuan-lite 官方免费)",
            nameEn: "Tencent Hunyuan (hunyuan-lite Free)",
            endpoint: "https://api.hunyuan.cloud.tencent.com/v1/chat/completions",
            defaultModel: "hunyuan-lite",
            allowEmptyKey: false
        ),
        CustomEndpointTemplate(
            id: "kimi",
            nameZh: "月之暗面 Kimi (Moonshot)",
            nameEn: "Moonshot Kimi",
            endpoint: "https://api.moonshot.cn/v1/chat/completions",
            defaultModel: "moonshot-v1-8k",
            allowEmptyKey: false
        ),
        CustomEndpointTemplate(
            id: "doubao",
            nameZh: "火山引擎豆包 (Ark)",
            nameEn: "Volcengine Doubao (Ark)",
            endpoint: "https://ark.cn-beijing.volces.com/api/v3/chat/completions",
            defaultModel: "doubao-1-5-lite-32k-250115",
            allowEmptyKey: false
        )
    ]
}

// MARK: - AI 引擎与自定义模型全局配置管理器（API Key 加密存储于 macOS Keychain）
class AIConfigManager: ObservableObject {
    static let shared = AIConfigManager()
    
    private let legacyKeysDictStorageKey = "ai_provider_api_keys_v2"
    private let modelsStorageKey = "ai_provider_custom_models_v2"
    private let endpointsStorageKey = "ai_provider_custom_endpoints_v2"
    private let preferredStorageKey = "preferred_api_provider"
    private let fallbackStorageKey = "ai_auto_fallback_on_error"
    private let customAllowEmptyKeyStorageKey = "ai_custom_allow_empty_key"
    
    @Published var preferredProvider: APIProvider {
        didSet {
            UserDefaults.standard.set(preferredProvider.rawValue, forKey: preferredStorageKey)
        }
    }
    
    @Published var autoFallbackOnError: Bool {
        didSet {
            UserDefaults.standard.set(autoFallbackOnError, forKey: fallbackStorageKey)
        }
    }
    
    @Published var customAllowEmptyKey: Bool {
        didSet {
            UserDefaults.standard.set(customAllowEmptyKey, forKey: customAllowEmptyKeyStorageKey)
        }
    }
    
    @Published private var apiKeysCache: [String: String] = [:]
    @Published private var customModels: [String: String] = [:]
    @Published private var customEndpoints: [String: String] = [:]
    
    private init() {
        let defaults = UserDefaults.standard
        
        if let raw = defaults.string(forKey: preferredStorageKey),
           let provider = APIProvider(rawValue: raw) {
            self.preferredProvider = provider
        } else {
            self.preferredProvider = .groq
        }
        
        if defaults.object(forKey: fallbackStorageKey) != nil {
            self.autoFallbackOnError = defaults.bool(forKey: fallbackStorageKey)
        } else {
            self.autoFallbackOnError = true
        }
        
        if defaults.object(forKey: customAllowEmptyKeyStorageKey) != nil {
            self.customAllowEmptyKey = defaults.bool(forKey: customAllowEmptyKeyStorageKey)
        } else {
            self.customAllowEmptyKey = false
        }
        
        // 1. 先从 Keychain 读取已加密保存的密钥
        for provider in APIProvider.allCases {
            if let kcVal = KeychainHelper.read(account: provider.rawValue), !kcVal.isEmpty {
                self.apiKeysCache[provider.rawValue] = kcVal
            }
        }
        
        // 2. 自动迁移此前存在 UserDefaults 中的旧版明文密钥至 Keychain，随后擦除明文
        if let oldDictData = defaults.data(forKey: legacyKeysDictStorageKey),
           let oldDict = try? JSONDecoder().decode([String: String].self, from: oldDictData) {
            for (rawKey, val) in oldDict where !val.isEmpty {
                if (self.apiKeysCache[rawKey] ?? "").isEmpty {
                    self.apiKeysCache[rawKey] = val
                    KeychainHelper.save(val, account: rawKey)
                }
            }
            defaults.removeObject(forKey: legacyKeysDictStorageKey)
        }
        
        for provider in APIProvider.allCases {
            if let legacyKeyName = provider.legacyUserDefaultsKey,
               let legacyVal = defaults.string(forKey: legacyKeyName),
               !legacyVal.isEmpty {
                if (self.apiKeysCache[provider.rawValue] ?? "").isEmpty {
                    self.apiKeysCache[provider.rawValue] = legacyVal
                    KeychainHelper.save(legacyVal, account: provider.rawValue)
                }
                defaults.removeObject(forKey: legacyKeyName)
            }
        }
        
        if let data = defaults.data(forKey: modelsStorageKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            self.customModels = decoded
        }
        
        if let data = defaults.data(forKey: endpointsStorageKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            self.customEndpoints = decoded
        }
    }
    
    func syncLegacyIfNeeded(groqKey: String, zhipuKey: String, preferredRaw: String) {
        if !groqKey.isEmpty && (apiKeysCache[APIProvider.groq.rawValue] ?? "").isEmpty {
            setAPIKey(groqKey, for: .groq)
        }
        if !zhipuKey.isEmpty && (apiKeysCache[APIProvider.glm.rawValue] ?? "").isEmpty {
            setAPIKey(zhipuKey, for: .glm)
        }
        if let p = APIProvider(rawValue: preferredRaw), preferredProvider != p {
            preferredProvider = p
        }
    }
    
    func apiKey(for provider: APIProvider) -> String {
        apiKeysCache[provider.rawValue] ?? ""
    }
    
    func setAPIKey(_ key: String, for provider: APIProvider) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        apiKeysCache[provider.rawValue] = trimmed
        KeychainHelper.save(trimmed, account: provider.rawValue)
        if let legacyKeyName = provider.legacyUserDefaultsKey {
            UserDefaults.standard.removeObject(forKey: legacyKeyName)
        }
    }
    
    func customModel(for provider: APIProvider) -> String {
        customModels[provider.rawValue] ?? ""
    }
    
    func setCustomModel(_ model: String, for provider: APIProvider) {
        customModels[provider.rawValue] = model.trimmingCharacters(in: .whitespacesAndNewlines)
        persistMetadata()
    }
    
    func effectiveModel(for provider: APIProvider) -> String {
        let custom = (customModels[provider.rawValue] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return custom.isEmpty ? provider.defaultModel : custom
    }
    
    func isUsingCustomModel(for provider: APIProvider) -> Bool {
        let custom = (customModels[provider.rawValue] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !custom.isEmpty && custom != provider.defaultModel
    }
    
    func resetModelToDefault(for provider: APIProvider) {
        customModels.removeValue(forKey: provider.rawValue)
        persistMetadata()
    }
    
    func customEndpoint(for provider: APIProvider) -> String {
        customEndpoints[provider.rawValue] ?? ""
    }
    
    func setCustomEndpoint(_ url: String, for provider: APIProvider) {
        customEndpoints[provider.rawValue] = url.trimmingCharacters(in: .whitespacesAndNewlines)
        persistMetadata()
    }
    
    func effectiveEndpoint(for provider: APIProvider) -> String {
        let custom = (customEndpoints[provider.rawValue] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return custom.isEmpty ? provider.defaultEndpoint : custom
    }
    
    func applyCustomTemplate(_ template: CustomEndpointTemplate) {
        setCustomEndpoint(template.endpoint, for: .custom)
        setCustomModel(template.defaultModel, for: .custom)
        customAllowEmptyKey = template.allowEmptyKey
    }
    
    func isProviderReady(_ provider: APIProvider) -> Bool {
        let hasKey = !apiKey(for: provider).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if provider == .custom {
            let endpoint = effectiveEndpoint(for: .custom)
            let model = effectiveModel(for: .custom)
            guard !endpoint.isEmpty && !model.isEmpty else { return false }
            return hasKey || customAllowEmptyKey
        }
        return hasKey
    }
    
    var readyProviders: [APIProvider] {
        APIProvider.allCases.filter { isProviderReady($0) }
    }
    
    var hasAnyReadyProvider: Bool {
        !readyProviders.isEmpty
    }
    
    func resolveActiveProvider() -> APIProvider? {
        if isProviderReady(preferredProvider) {
            return preferredProvider
        }
        return readyProviders.first
    }
    
    func fallbackCandidates(excluding tried: Set<APIProvider>) -> [APIProvider] {
        readyProviders.filter { !tried.contains($0) }
    }
    
    func shortModelLabel(for provider: APIProvider) -> String {
        let full = effectiveModel(for: provider)
        let afterSlash = full.split(separator: "/").last.map(String.init) ?? full
        let clean = afterSlash.replacingOccurrences(of: ":free", with: "")
        if clean.count > 18 {
            return String(clean.prefix(16)) + "…"
        }
        return clean
    }
    
    func resetAllAIConfigs() {
        apiKeysCache = [:]
        customModels = [:]
        customEndpoints = [:]
        customAllowEmptyKey = false
        autoFallbackOnError = true
        preferredProvider = .groq
        
        KeychainHelper.deleteAll()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: legacyKeysDictStorageKey)
        defaults.removeObject(forKey: modelsStorageKey)
        defaults.removeObject(forKey: endpointsStorageKey)
        for p in APIProvider.allCases {
            if let legacy = p.legacyUserDefaultsKey {
                defaults.removeObject(forKey: legacy)
            }
        }
    }
    
    private func persistMetadata() {
        let defaults = UserDefaults.standard
        if let encodedModels = try? JSONEncoder().encode(customModels) {
            defaults.set(encodedModels, forKey: modelsStorageKey)
        }
        if let encodedEndpoints = try? JSONEncoder().encode(customEndpoints) {
            defaults.set(encodedEndpoints, forKey: endpointsStorageKey)
        }
    }
}

// MARK: - 系统提示词管理器（固定 ISO 日期消除地区歧义，同时兼容短期相对天数与远期绝对日期）
class PromptManager: ObservableObject {
    static let shared = PromptManager()

    static let defaultPromptText = """
    Role: Homework Parser.
    Task: Extract homework.
    Output Language: {{LANG}}.
    Context: Today is {{DATE}}.
    Rules:
    1. SPLIT: Separate multiple items.
    2. SUBJECT: Return 'subject_en' AND 'subject_zh'. Do NOT treat books/objects as subjects. If unknown, use "General"/"综合".
    3. DATE: Near-term: set 'daysFromToday' (0=Today, 1=Tomorrow) and optional 'durationDays'. Long-term/specific calendar date: set 'dueDate' ("YYYY-MM-DD").
    4. NOISE: Ignore administrative notes.

    Output: JSON Array ONLY.
    JSON: [{"subject_en":String,"subject_zh":String,"content":String,"notes":String?,"daysFromToday":Int?,"durationDays":Int?,"dueDate":String?}]
    """
    
    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd (EEEE)"
        return f
    }()
    
    @Published var customPrompt: String {
        didSet { UserDefaults.standard.set(customPrompt, forKey: "custom_system_prompt") }
    }
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: "custom_system_prompt") ?? ""
        self.customPrompt = saved.isEmpty ? Self.defaultPromptText : saved
    }
    
    func getEffectivePrompt(lang: String) -> String {
        let dateStr = Self.isoFormatter.string(from: Date())
        return customPrompt
            .replacingOccurrences(of: "{{LANG}}", with: lang)
            .replacingOccurrences(of: "{{DATE}}", with: dateStr)
    }
    
    func resetToDefault() {
        self.customPrompt = Self.defaultPromptText
    }
}
