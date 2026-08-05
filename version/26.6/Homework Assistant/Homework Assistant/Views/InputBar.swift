//
//  InputBar.swift
//  Homework Assistant
//
//  Created by Hector Wu on 26/4/2026.
//


// Filename: InputBar.swift
// 用途: AI输入栏，集成引擎状态显示、发送按钮、手动添加按钮

import SwiftUI

struct InputBar: View {
    @Binding var text: String
    var isProcessing: Bool
    var isEnglish: Bool
    var hasApiKey: Bool
    var submitAction: () -> Void
    var onMissingKeyTap: () -> Void
    var onManualAddTap: () -> Void

    @AppStorage("user_groq_api_key") private var groqKey: String = ""
    @AppStorage("user_zhipu_api_key") private var zhipuKey: String = ""
    @AppStorage("preferred_api_provider") private var providerRaw: String = "Groq (Llama 3)"

    private var activeProvider: APIProvider? {
        let preferred = APIProvider(rawValue: providerRaw) ?? .groq
        return HomeworkManager.resolveActiveProvider(
            preferred: preferred,
            groqKey: groqKey.isEmpty ? nil : groqKey,
            zhipuKey: zhipuKey.isEmpty ? nil : zhipuKey
        )
    }

    private var engineBadgeText: String {
        guard hasApiKey else { return "" }
        guard let provider = activeProvider else { return "" }
        switch provider {
        case .groq: return "Llama 3"
        case .glm: return "GLM-4 Flash"
        }
    }

    private var engineBadgeColor: Color {
        guard let provider = activeProvider else { return .gray }
        switch provider {
        case .groq: return Color(red: 0.96, green: 0.51, blue: 0.19) // Groq orange
        case .glm: return Color(red: 0.2, green: 0.45, blue: 0.9) // Zhipu blue
        }
    }

    private var isFallback: Bool {
        guard hasApiKey, let provider = activeProvider else { return false }
        let preferred = APIProvider(rawValue: providerRaw) ?? .groq
        return provider != preferred
    }
    
    private var helpText: String {
        guard let provider = activeProvider else { return "" }
        let preferred = APIProvider(rawValue: providerRaw) ?? .groq
        
        if isFallback {
            let preferredName = preferred == .groq ? "Groq (Llama 3)" : "Zhipu (GLM-4 Flash)"
            let actualName = provider == .groq ? "Groq (Llama 3)" : "Zhipu (GLM-4 Flash)"
            return isEnglish
                ? "Preferred: \(preferredName) (no key). Using: \(actualName)"
                : "首选: \(preferredName) (未填写密钥), 已自动切换至: \(actualName)"
        } else {
            switch provider {
            case .groq:
                return isEnglish ? "Using Groq (Llama 3)" : "当前使用 Groq (Llama 3)"
            case .glm:
                return isEnglish ? "Using Zhipu (GLM-4 Flash)" : "当前使用 Zhipu (GLM-4 Flash)"
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onManualAddTap) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help(isEnglish ? "Manual Add" : "手动添加")

            Divider().frame(height: 20)

            if hasApiKey {
                TextField(isEnglish ? "Enter homework..." : "输入作业...", text: $text)
                    .textFieldStyle(.plain)
                    .onSubmit { if !isProcessing { submitAction() } }
                    .disabled(isProcessing)
                
                if !engineBadgeText.isEmpty {
                    engineBadge
                }
                
                Button(action: submitAction) {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "paperplane.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                }
                .buttonStyle(.plain)
                .disabled(text.isEmpty || isProcessing)
                
            } else {
                Button(action: onMissingKeyTap) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(isEnglish ? "API Key Missing (Click to set)" : "未填写 API Key (点击跳转)")
                            .foregroundStyle(.red)
                            .font(.caption)
                            .underline()
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(hasApiKey ? Color.gray.opacity(0.2) : Color.red.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    @ViewBuilder var engineBadge: some View {
        HStack(spacing: 4) {
            if isFallback {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            Text(engineBadgeText)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(engineBadgeColor.opacity(isFallback ? 0.75 : 0.88))
        .cornerRadius(6)
        .help(helpText)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(isFallback ? 0.4 : 0), lineWidth: 1)
        )
    }
}