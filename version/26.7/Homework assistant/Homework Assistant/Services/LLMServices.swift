// Filename: LLMServices.swift
// 用途: 网络/AI通信层 — 支持全部主流 OpenAI 兼容平台、Google Gemini/Gemma 原生协议、本地 Ollama 及双语错误提示

import Foundation
import SwiftUI

enum LLMError: Error, LocalizedError {
    case invalidKey
    case quotaExceeded
    case accessDenied(String?)
    case invalidEndpoint(String)
    case serverError(Int, String?)
    case networkError(Error)
    case decodingError(String)
    case emptyResponse
    case userCancelled
    
    private var isEnglishUI: Bool {
        UserDefaults.standard.string(forKey: "appLanguage") == AppLanguage.english.rawValue
    }
    
    var errorDescription: String? {
        let isEn = isEnglishUI
        switch self {
        case .invalidKey:
            return isEn
                ? "Invalid or Missing API Key (401)"
                : "API Key 无效或未填写 (401)"
        case .quotaExceeded:
            return isEn
                ? "Quota Exceeded / Rate Limited (429)"
                : "配额超限/请求过快 (429)"
        case .accessDenied(let detail):
            let base = isEn
                ? "Access Denied / Region Restricted (403)"
                : "访问被拒绝/地区受限 (403)"
            if let detail = detail, !detail.isEmpty {
                return "\(base): \(detail)"
            }
            return base
        case .invalidEndpoint(let raw):
            return isEn
                ? "Invalid Endpoint URL: \(raw)"
                : "接口地址格式无效: \(raw)"
        case .serverError(let code, let detail):
            if let detail = detail, !detail.isEmpty {
                return isEn
                    ? "Request Error (\(code)): \(detail)"
                    : "请求错误 (\(code)): \(detail)"
            }
            return isEn
                ? "Server Error (\(code))"
                : "服务器错误 (\(code))"
        case .networkError(let err):
            return isEn
                ? "Network Error: \(err.localizedDescription)"
                : "网络连接失败: \(err.localizedDescription)"
        case .decodingError(let msg):
            return isEn
                ? "Parse Failed: \(msg)"
                : "解析失败: \(msg)"
        case .emptyResponse:
            return isEn
                ? "Empty Response from AI"
                : "AI 返回内容为空"
        case .userCancelled:
            return isEn
                ? "Operation Cancelled"
                : "操作已取消"
        }
    }
    
    var isRetryableWithFallback: Bool {
        switch self {
        case .quotaExceeded, .serverError, .networkError, .emptyResponse, .accessDenied:
            return true
        case .invalidKey, .invalidEndpoint, .decodingError, .userCancelled:
            return false
        }
    }
}

protocol LLMClient {
    func send(
        provider: APIProvider,
        endpoint: String,
        model: String,
        prompt: String,
        text: String,
        apiKey: String,
        timeout: TimeInterval,
        onLog: @escaping (AppLog) -> Void
    ) async throws -> String
}

// MARK: - 通用 OpenAI 兼容客户端（Groq / 智谱 / 硅基流动 / OpenRouter / GitHub Models / 通义千问 / DeepSeek / OpenAI / 自定义 & Ollama）
class OpenAICompatibleClient: LLMClient {
    
    static func resolveChatCompletionsURL(from rawEndpoint: String) -> URL? {
        var trimmed = rawEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        
        let lower = trimmed.lowercased()
        if lower.hasSuffix("/chat/completions") {
            return URL(string: trimmed)
        }
        
        let versionSuffixes = ["/v1", "/v2", "/v3", "/v4", "/api/paas/v4", "/compatible-mode/v1", "/openai/v1", "/inference"]
        if versionSuffixes.contains(where: { lower.hasSuffix($0) }) {
            return URL(string: trimmed + "/chat/completions")
        }
        
        if let parsed = URL(string: trimmed), (parsed.path.isEmpty || parsed.path == "/") {
            return URL(string: trimmed + "/v1/chat/completions")
        }
        
        return URL(string: trimmed)
    }
    
    private static func omitsTemperature(for model: String) -> Bool {
        let lower = model.lowercased()
        return lower.contains("reasoner")
            || lower.hasPrefix("o1")
            || lower.hasPrefix("o3")
            || lower.hasPrefix("o4")
            || lower.hasPrefix("gpt-5")
    }
    
    func send(
        provider: APIProvider,
        endpoint: String,
        model: String,
        prompt: String,
        text: String,
        apiKey: String,
        timeout: TimeInterval = 35,
        onLog: @escaping (AppLog) -> Void
    ) async throws -> String {
        guard let url = Self.resolveChatCompletionsURL(from: endpoint) else {
            throw LLMError.invalidEndpoint(endpoint)
        }
        
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if !cleanKey.isEmpty {
            request.addValue("Bearer \(cleanKey)", forHTTPHeaderField: "Authorization")
        }
        
        if provider == .openRouter {
            request.addValue("https://github.com/Hector-Wu/ai-homework-organizer", forHTTPHeaderField: "HTTP-Referer")
            request.addValue("Homework Assistant", forHTTPHeaderField: "X-Title")
        }
        
        var body: [String: Any] = [
            "model": cleanModel,
            "messages": [
                ["role": "system", "content": prompt],
                ["role": "user", "content": text]
            ]
        ]
        
        if !Self.omitsTemperature(for: cleanModel) {
            body["temperature"] = 0.1
        }
        
        if provider == .qwen && cleanModel.lowercased().contains("qwen3") {
            body["enable_thinking"] = false
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await performHTTPRequest(request, isGoogleNative: false, onLog: onLog)
    }
}

// MARK: - Google AI Studio 原生客户端（Gemini 2.5 / 2.0 及 Gemma 3 全系列免费模型）
class GoogleGeminiClient: LLMClient {
    func send(
        provider: APIProvider,
        endpoint: String,
        model: String,
        prompt: String,
        text: String,
        apiKey: String,
        timeout: TimeInterval = 35,
        onLog: @escaping (AppLog) -> Void
    ) async throws -> String {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else { throw LLMError.invalidKey }
        
        var cleanModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanModel.hasPrefix("models/") {
            cleanModel = String(cleanModel.dropFirst("models/".count))
        }
        
        var base = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        if base.isEmpty { base = APIProvider.gemini.defaultEndpoint }
        
        guard let encodedModel = cleanModel.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let encodedKey = cleanKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(base)/models/\(encodedModel):generateContent?key=\(encodedKey)") else {
            throw LLMError.invalidEndpoint(endpoint)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any]
        if cleanModel.lowercased().hasPrefix("gemma") {
            let mergedText = "\(prompt)\n\nUser Input:\n\(text)"
            body = [
                "contents": [
                    ["role": "user", "parts": [["text": mergedText]]]
                ],
                "generationConfig": ["temperature": 0.1]
            ]
        } else {
            body = [
                "systemInstruction": [
                    "parts": [["text": prompt]]
                ],
                "contents": [
                    ["role": "user", "parts": [["text": text]]]
                ],
                "generationConfig": ["temperature": 0.1]
            ]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await performHTTPRequest(request, isGoogleNative: true, onLog: onLog)
    }
}

// MARK: - 统一 AI 调度与连接测试服务
class UnifiedLLMService {
    private let openAIClient = OpenAICompatibleClient()
    private let googleClient = GoogleGeminiClient()
    
    func send(
        provider: APIProvider,
        endpoint: String,
        model: String,
        prompt: String,
        text: String,
        apiKey: String,
        timeout: TimeInterval = 35,
        onLog: @escaping (AppLog) -> Void
    ) async throws -> String {
        if provider.usesGoogleNativeProtocol {
            return try await googleClient.send(
                provider: provider,
                endpoint: endpoint,
                model: model,
                prompt: prompt,
                text: text,
                apiKey: apiKey,
                timeout: timeout,
                onLog: onLog
            )
        } else {
            return try await openAIClient.send(
                provider: provider,
                endpoint: endpoint,
                model: model,
                prompt: prompt,
                text: text,
                apiKey: apiKey,
                timeout: timeout,
                onLog: onLog
            )
        }
    }
    
    func testConnection(provider: APIProvider, config: AIConfigManager) async throws -> (latencyMs: Int, reply: String) {
        guard config.isProviderReady(provider) else {
            throw LLMError.invalidKey
        }
        let start = Date()
        let reply = try await send(
            provider: provider,
            endpoint: config.effectiveEndpoint(for: provider),
            model: config.effectiveModel(for: provider),
            prompt: "You are a connectivity checker. Reply with OK only.",
            text: "ping",
            apiKey: config.apiKey(for: provider),
            timeout: 18,
            onLog: { _ in }
        )
        let ms = max(1, Int(Date().timeIntervalSince(start) * 1000))
        let preview = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        return (ms, String(preview.prefix(40)))
    }
}

// MARK: - 底层网络请求与状态码映射
private func performHTTPRequest(
    _ request: URLRequest,
    isGoogleNative: Bool,
    onLog: @escaping (AppLog) -> Void
) async throws -> String {
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let raw = String(data: data, encoding: .utf8) {
            onLog(AppLog(type: .aiRaw, message: raw))
        }

        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200...299:
                break
            case 401:
                throw LLMError.invalidKey
            case 403:
                let errDetail = extractServerErrorMessage(from: data)
                throw LLMError.accessDenied(errDetail)
            case 429:
                throw LLMError.quotaExceeded
            default:
                let errDetail = extractServerErrorMessage(from: data)
                throw LLMError.serverError(httpResponse.statusCode, errDetail)
            }
        }
        
        if isGoogleNative {
            let res = try JSONDecoder().decode(GoogleGenerateContentResponse.self, from: data)
            let parts = res.candidates?.first?.content?.parts ?? []
            let nonThoughtText = parts
                .filter { $0.thought != true }
                .compactMap { $0.text }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !nonThoughtText.isEmpty {
                return nonThoughtText
            }
            if let fallbackText = parts.compactMap({ $0.text }).last, !fallbackText.isEmpty {
                return fallbackText
            }
            throw LLMError.emptyResponse
        } else {
            let res = try JSONDecoder().decode(OpenAIStyleAPIResponse.self, from: data)
            guard let txt = res.choices.first?.message.content,
                  !txt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LLMError.emptyResponse
            }
            return txt
        }
        
    } catch let error as LLMError {
        throw error
    } catch let error as DecodingError {
        throw LLMError.decodingError(error.localizedDescription)
    } catch {
        throw LLMError.networkError(error)
    }
}

private func extractServerErrorMessage(from data: Data) -> String? {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
    }
    if let errDict = json["error"] as? [String: Any],
       let msg = errDict["message"] as? String {
        return String(msg.prefix(120))
    }
    if let errStr = json["error"] as? String {
        return String(errStr.prefix(120))
    }
    if let msg = json["message"] as? String {
        return String(msg.prefix(120))
    }
    return nil
}

// MARK: - 响应解码结构
struct OpenAIStyleAPIResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }
        let message: Message
    }
    let choices: [Choice]
}

struct GoogleGenerateContentResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable {
                let text: String?
                let thought: Bool?
            }
            let parts: [Part]?
        }
        let content: Content?
    }
    let candidates: [Candidate]?
}
