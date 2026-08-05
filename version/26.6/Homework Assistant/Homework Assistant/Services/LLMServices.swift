// Filename: LLMServices.swift
// 用途: 网络/AI层

import Foundation
import SwiftUI

enum LLMError: Error, LocalizedError {
    case invalidKey
    case quotaExceeded
    case accessDenied
    case serverError(Int)
    case networkError(Error)
    case decodingError(String)
    case emptyResponse
    case userCancelled
    
    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "API Key 无效 (401)"
        case .quotaExceeded:
            return "配额超限/请求过快 (429)"
        case .accessDenied:
            return "访问被拒绝 (403)"
        case .serverError(let code):
            return "服务器错误 (\(code))"
        case .networkError(let err):
            return "网络连接失败: \(err.localizedDescription)"
        case .decodingError(let msg):
            return "解析失败: \(msg)"
        case .emptyResponse:
            return "AI 返回内容为空"
        case .userCancelled:
            return "已取消: 拒绝使用低精度模型"
        }
    }
}

protocol LLMClient {
    func send(prompt: String, text: String, apiKey: String, onLog: @escaping (AppLog) -> Void) async throws -> String
}

class GroqClient: LLMClient {
    func send(prompt: String, text: String, apiKey: String, onLog: @escaping (AppLog) -> Void) async throws -> String {
        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "llama3-70b-8192",
            "messages": [
                ["role": "system", "content": prompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.1
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await performRequest(request, onLog: onLog)
    }
}

class ZhipuClient: LLMClient {
    func send(prompt: String, text: String, apiKey: String, onLog: @escaping (AppLog) -> Void) async throws -> String {
        let url = URL(string: "https://open.bigmodel.cn/api/paas/v4/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "glm-4-flash-250414",
            "messages": [
                ["role": "system", "content": prompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.1
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await performRequest(request, onLog: onLog)
    }
}

// MARK: - 通用网络请求
private func performRequest(
    _ request: URLRequest,
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
            case 400:
                throw LLMError.serverError(400)
            case 401:
                throw LLMError.invalidKey
            case 403:
                throw LLMError.accessDenied
            case 429:
                throw LLMError.quotaExceeded
            default:
                throw LLMError.serverError(httpResponse.statusCode)
            }
        }
        
        let res = try JSONDecoder().decode(OpenAIStyleAPIResponse.self, from: data)
        guard let txt = res.choices.first?.message.content else {
            throw LLMError.emptyResponse
        }
        return txt
        
    } catch let error as LLMError {
        throw error
    } catch {
        throw LLMError.networkError(error)
    }
}

// MARK: - 响应解码结构
struct OpenAIStyleAPIResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message
    }
    let choices: [Choice]
}
