// Filename: AIEngineManagerSheet.swift
// 用途: 多 AI 引擎与自定义模型配置面板 — Keychain 加密存储、预设与自定义模型 ID、快捷模板及连通性测试

import SwiftUI
import Combine

struct AIEngineManagerSheet: View {
    @Binding var preferredProviderRaw: String
    @Binding var groqKey: String
    @Binding var zhipuKey: String
    var isEnglish: Bool

    @Environment(\.dismiss) var dismiss
    @ObservedObject private var config = AIConfigManager.shared

    @State private var selectedProvider: APIProvider = .groq
    @State private var showKey: Bool = false
    @State private var showProxyOverride: Bool = false
    @State private var isTesting: Bool = false
    @State private var testResultText: String? = nil
    @State private var testSucceeded: Bool = false

    private let testService = UnifiedLLMService()

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            HStack(spacing: 0) {
                providerSidebar
                Divider()
                providerDetailPane
            }
            Divider()
            footerBar
        }
        .frame(width: 760, height: 560)
        .onAppear {
            config.syncLegacyIfNeeded(
                groqKey: groqKey,
                zhipuKey: zhipuKey,
                preferredRaw: preferredProviderRaw
            )
            // 旧明文迁移进 Keychain 后清空 AppStorage 里的旧值
            if !groqKey.isEmpty { groqKey = "" }
            if !zhipuKey.isEmpty { zhipuKey = "" }
            selectedProvider = config.preferredProvider
            showProxyOverride = !config.customEndpoint(for: selectedProvider).isEmpty
        }
        .onChange(of: selectedProvider) {
            showKey = false
            testResultText = nil
            showProxyOverride = !config.customEndpoint(for: selectedProvider).isEmpty
        }
    }

    // MARK: - 顶部栏
    @ViewBuilder private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(isEnglish ? "AI Engines & Custom Models" : "AI 引擎与自定义模型配置")
                    .font(.headline)
                Text(isEnglish
                     ? "Keys encrypted in macOS Keychain · Supports free providers & custom models"
                     : "密钥加密存储于系统钥匙串 · 支持免费平台、自定义模型及本地 Ollama")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle(
                isEnglish ? "Auto-Fallback on 429/Error" : "限流或故障时自动切换备用引擎",
                isOn: $config.autoFallbackOnError
            )
            .toggleStyle(.switch)
            .font(.caption)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - 左侧引擎列表
    @ViewBuilder private var providerSidebar: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(APIProvider.allCases) { provider in
                    providerRow(provider)
                }
            }
            .padding(10)
        }
        .frame(width: 245)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    @ViewBuilder private func providerRow(_ provider: APIProvider) -> some View {
        let isSelected = selectedProvider == provider
        let isDefault = config.preferredProvider == provider
        let isReady = config.isProviderReady(provider)

        Button(action: { selectedProvider = provider }) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isReady ? Color.green : Color.gray.opacity(0.35))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(provider.displayName(isEnglish: isEnglish))
                            .font(.system(size: 12.5, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if isDefault {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.yellow)
                        }
                    }

                    if let tag = provider.badgeTag(isEnglish: isEnglish) {
                        Text(tag)
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(provider.brandColor)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? provider.brandColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? provider.brandColor.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 右侧详情配置区
    @ViewBuilder private var providerDetailPane: some View {
        let provider = selectedProvider
        let keyBinding = Binding<String>(
            get: { config.apiKey(for: provider) },
            set: { newVal in
                config.setAPIKey(newVal, for: provider)
            }
        )
        let modelBinding = Binding<String>(
            get: {
                let custom = config.customModel(for: provider)
                return custom.isEmpty ? provider.defaultModel : custom
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty || trimmed == provider.defaultModel {
                    config.resetModelToDefault(for: provider)
                } else {
                    config.setCustomModel(trimmed, for: provider)
                }
            }
        )
        let endpointBinding = Binding<String>(
            get: {
                if provider == .custom {
                    let saved = config.customEndpoint(for: .custom)
                    return saved.isEmpty ? provider.defaultEndpoint : saved
                }
                return config.customEndpoint(for: provider)
            },
            set: { config.setCustomEndpoint($0, for: provider) }
        )

        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(provider.displayName(isEnglish: isEnglish))
                                .font(.title3.bold())
                            if config.preferredProvider == provider {
                                Text(isEnglish ? "DEFAULT" : "当前首选")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(provider.brandColor)
                                    .cornerRadius(5)
                            }
                        }
                        Text(provider.subtitle(isEnglish: isEnglish))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if config.preferredProvider != provider {
                        Button(isEnglish ? "Set as Default" : "设为首选引擎") {
                            config.preferredProvider = provider
                            preferredProviderRaw = provider.rawValue
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(provider.brandColor)
                    }
                }
            }

            if provider == .custom {
                Section(header: Text(isEnglish ? "Endpoint & Quick Templates" : "接口地址与快捷模板")) {
                    Menu {
                        ForEach(CustomEndpointTemplate.all) { tpl in
                            Button(isEnglish ? tpl.nameEn : tpl.nameZh) {
                                config.applyCustomTemplate(tpl)
                                testResultText = nil
                            }
                        }
                    } label: {
                        Label(
                            isEnglish ? "Apply Quick Preset (Ollama / Hunyuan / Kimi...)" : "一键填入常用模板 (Ollama本地 / 腾讯混元免费版 / Kimi / 豆包)",
                            systemImage: "sparkles"
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(isEnglish ? "OpenAI-Compatible Endpoint / Base URL:" : "OpenAI 兼容接口地址 (Base URL):")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("http://localhost:11434/v1/chat/completions", text: endpointBinding)
                            .textFieldStyle(.roundedBorder)
                    }

                    Toggle(
                        isEnglish ? "No API Key Required (Local Ollama / LM Studio)" : "免 API Key 模式（适用于本地 Ollama / LM Studio）",
                        isOn: $config.customAllowEmptyKey
                    )
                }
            }

            Section(header: HStack {
                Label("API Key", systemImage: "lock.shield")
                Spacer()
                if let url = provider.keyPortalURL {
                    Link(isEnglish ? "Get Free / Official Key ↗" : "前往官网获取 Key ↗", destination: url)
                        .font(.caption)
                }
            }) {
                HStack {
                    if showKey {
                        TextField(provider.keyPlaceholder(isEnglish: isEnglish), text: keyBinding)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField(provider.keyPlaceholder(isEnglish: isEnglish), text: keyBinding)
                            .textFieldStyle(.roundedBorder)
                    }
                    Button(action: { showKey.toggle() }) {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                    if !keyBinding.wrappedValue.isEmpty {
                        Button(isEnglish ? "Clear" : "清空") {
                            config.setAPIKey("", for: provider)
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                        .buttonStyle(.plain)
                    }
                }

                if provider == .groq && !keyBinding.wrappedValue.isEmpty && !keyBinding.wrappedValue.hasPrefix("gsk_") {
                    Text(isEnglish ? "Tip: Groq keys usually start with gsk_" : "提示：Groq 密钥通常以 gsk_ 开头")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if provider == .gemini && !keyBinding.wrappedValue.isEmpty && !keyBinding.wrappedValue.hasPrefix("AIza") {
                    Text(isEnglish ? "Tip: Google AI Studio keys usually start with AIza" : "提示：Google AI Studio 密钥通常以 AIza 开头")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section(header: Text(isEnglish ? "Model (Preset & Custom Model ID)" : "模型选择与自定义模型")) {
                HStack {
                    Text(isEnglish ? "Recommended Presets:" : "预设够用/免费模型:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        ForEach(provider.presetModels, id: \.self) { preset in
                            Button(action: {
                                if preset == provider.defaultModel {
                                    config.resetModelToDefault(for: provider)
                                } else {
                                    config.setCustomModel(preset, for: provider)
                                }
                            }) {
                                HStack {
                                    Text(preset)
                                    if config.effectiveModel(for: provider) == preset {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Text(isEnglish ? "Select Preset Model" : "点此快速选择预设模型")
                            .font(.caption)
                    }
                    .frame(maxWidth: 210)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(isEnglish ? "Effective / Custom Model ID:" : "当前模型 ID（可直接手动输入任意模型名）:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if config.isUsingCustomModel(for: provider) {
                            Button(isEnglish ? "Reset Default" : "恢复默认模型") {
                                config.resetModelToDefault(for: provider)
                            }
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .buttonStyle(.plain)
                        }
                    }

                    TextField(provider.defaultModel, text: modelBinding)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }
            }

            if provider != .custom {
                Section {
                    DisclosureGroup(
                        isEnglish ? "Advanced: Custom Proxy Endpoint (Optional)" : "高级：自定义接口代理地址（选填，留空则用官方地址）",
                        isExpanded: $showProxyOverride
                    ) {
                        VStack(alignment: .leading, spacing: 6) {
                            TextField(provider.defaultEndpoint, text: endpointBinding)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.caption, design: .monospaced))
                            if !endpointBinding.wrappedValue.isEmpty {
                                Button(isEnglish ? "Restore Official Endpoint" : "恢复官方默认地址") {
                                    config.setCustomEndpoint("", for: provider)
                                }
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - 底部测试与完成栏
    @ViewBuilder private var footerBar: some View {
        HStack(spacing: 12) {
            Button(action: runConnectionTest) {
                HStack(spacing: 6) {
                    if isTesting {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "bolt.horizontal.circle")
                    }
                    Text(isEnglish ? "Test Connection" : "测试当前引擎连接")
                }
            }
            .disabled(isTesting || !config.isProviderReady(selectedProvider))

            if let result = testResultText {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(testSucceeded ? .green : .red)
                    .lineLimit(2)
            } else if !config.isProviderReady(selectedProvider) {
                Text(isEnglish ? "Enter API Key to enable this engine" : "填写 API Key 后即可启用该引擎")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(isEnglish ? "Done" : "完成") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func runConnectionTest() {
        let target = selectedProvider
        isTesting = true
        testResultText = nil
        Task {
            do {
                let res = try await testService.testConnection(provider: target, config: config)
                testSucceeded = true
                testResultText = isEnglish
                    ? "Connected (\(res.latencyMs)ms) · \(config.effectiveModel(for: target))"
                    : "连接成功 (\(res.latencyMs)ms) · 模型可用"
            } catch {
                testSucceeded = false
                testResultText = error.localizedDescription
            }
            isTesting = false
        }
    }
}
