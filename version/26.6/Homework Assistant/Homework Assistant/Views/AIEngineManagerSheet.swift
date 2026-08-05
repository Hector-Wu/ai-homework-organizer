//
//  AIEngineManagerSheet.swift
//  Homework Assistant
//
//  Created by Hector Wu on 26/4/2026.
//


// Filename: AIEngineManagerSheet.swift
// 用途: AI引擎配置Sheet, 用于设置默认引擎和填写API Keys

import SwiftUI

struct AIEngineManagerSheet: View {
    @Binding var preferredProviderRaw: String
    @Binding var groqKey: String
    @Binding var zhipuKey: String
    var isEnglish: Bool
    @Environment(\.dismiss) var dismiss

    @State private var showGroqKey: Bool = false
    @State private var showZhipuKey: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Text(isEnglish ? "AI Engines Configuration" : "AI 引擎配置")
                .font(.headline)
                .padding()
            
            Form {
                // Groq (Llama 3)
                Section(header: Text("Groq (Llama 3)").font(.headline)) {
                    Button(action: { preferredProviderRaw = APIProvider.groq.rawValue }) {
                        HStack {
                            Image(systemName: preferredProviderRaw == APIProvider.groq.rawValue ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(preferredProviderRaw == APIProvider.groq.rawValue ? .blue : .gray)
                            Text(isEnglish ? "Set as Default" : "设为默认引擎")
                        }
                    }
                    .buttonStyle(.plain)
                    
                    HStack {
                        if showGroqKey {
                            TextField("gsk_...", text: $groqKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("gsk_...", text: $groqKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        Button(action: { showGroqKey.toggle() }) {
                            Image(systemName: showGroqKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)
                    }
                    if !groqKey.isEmpty && !groqKey.hasPrefix("gsk_") {
                        Text(isEnglish ? "Invalid Key Format" : "密钥格式可能不正确")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Zhipu (GLM-4 Flash)
                Section(header: Text("Zhipu (GLM-4 Flash)").font(.headline)) {
                    Button(action: { preferredProviderRaw = APIProvider.glm.rawValue }) {
                        HStack {
                            Image(systemName: preferredProviderRaw == APIProvider.glm.rawValue ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(preferredProviderRaw == APIProvider.glm.rawValue ? .blue : .gray)
                            Text(isEnglish ? "Set as Default" : "设为默认引擎")
                        }
                    }
                    .buttonStyle(.plain)

                    HStack {
                        if showZhipuKey {
                            TextField(isEnglish ? "Paste Zhipu API Key..." : "粘贴智谱 API Key...", text: $zhipuKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField(isEnglish ? "Paste Zhipu API Key..." : "粘贴智谱 API Key...", text: $zhipuKey)
                                .textFieldStyle(.roundedBorder)
                        }
                        Button(action: { showZhipuKey.toggle() }) {
                            Image(systemName: showZhipuKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // 即将支持
                Section(header: Text(isEnglish ? "Coming Soon" : "即将支持")) {
                    Text("OpenAI (ChatGPT), DeepSeek, Anthropic (Claude)...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
            
            Button(isEnglish ? "Done" : "完成") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding()
        }
        .frame(width: 500, height: 500)
    }
}