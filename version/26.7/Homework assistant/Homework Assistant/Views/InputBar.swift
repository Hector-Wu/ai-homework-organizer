// Filename: InputBar.swift
// 用途: AI输入栏 — 保留原版胶囊角标外观，点击向【左上方】在软件窗口框内弹出 macOS 原生菜单

import SwiftUI
import Combine
import AppKit

private final class MenuActionTarget: NSObject {
    let action: () -> Void
    init(_ action: @escaping () -> Void) {
        self.action = action
    }
    @objc func performAction() {
        action()
    }
}

struct InputBar: View {
    var isProcessing: Bool
    var isEnglish: Bool
    var hasApiKey: Bool
    var onSubmitText: (String, @escaping () -> Void) -> Void
    var onMissingKeyTap: () -> Void
    var onManualAddTap: () -> Void
    var onOpenEngineSettings: () -> Void

    @State private var draftText: String = ""
    @ObservedObject private var aiConfig = AIConfigManager.shared

    private var isEngineReady: Bool {
        hasApiKey || aiConfig.hasAnyReadyProvider
    }

    private var activeProvider: APIProvider? {
        aiConfig.resolveActiveProvider()
    }

    private var engineBadgeText: String {
        guard isEngineReady, let provider = activeProvider else { return "" }
        return prettyModelBadgeName(for: provider)
    }

    private var engineBadgeColor: Color {
        guard let provider = activeProvider else { return .gray }
        return provider.brandColor
    }

    private var isFallback: Bool {
        guard isEngineReady, let provider = activeProvider else { return false }
        return provider != aiConfig.preferredProvider
    }

    private var helpText: String {
        guard let provider = activeProvider else { return "" }
        let preferred = aiConfig.preferredProvider
        let modelName = aiConfig.effectiveModel(for: provider)

        if isFallback {
            let preferredName = preferred.displayName(isEnglish: isEnglish)
            let actualName = provider.displayName(isEnglish: isEnglish)
            return isEnglish
                ? "Preferred: \(preferredName) (no key). Using: \(actualName) [\(modelName)] · Click to switch"
                : "首选: \(preferredName) (未配置), 已切换至: \(actualName) [\(modelName)] · 点击切换"
        } else {
            let actualName = provider.displayName(isEnglish: isEnglish)
            return isEnglish
                ? "Using \(actualName) [\(modelName)] · Click to switch"
                : "当前使用 \(actualName) [\(modelName)] · 点击切换引擎或模型"
        }
    }

    private var canSubmit: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing
    }

    private func triggerSubmit() {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isProcessing else { return }
        onSubmitText(trimmed) {
            draftText = ""
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

            if isEngineReady {
                TextField(
                    isEnglish ? "Enter homework..." : "输入作业...",
                    text: $draftText,
                    axis: .vertical
                )
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .onSubmit { triggerSubmit() }
                .disabled(isProcessing)

                if !engineBadgeText.isEmpty {
                    Button(action: popUpNativeEngineMenuTopLeft) {
                        engineBadge
                    }
                    .buttonStyle(.plain)
                }

                Button(action: triggerSubmit) {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "paperplane.circle.fill")
                            .font(.title2)
                            .foregroundStyle(canSubmit ? .blue : .gray.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)

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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isEngineReady ? Color.gray.opacity(0.2) : Color.red.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    // MARK: - 100% 原版胶囊角标样式
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
        .background(
            engineBadgeColor.opacity(isFallback ? 0.75 : 0.88),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .help(helpText)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(isFallback ? 0.4 : 0), lineWidth: 1)
        )
    }

    // MARK: - 向左上方展开，并严格钳制在主窗口内部区域
    private func popUpNativeEngineMenuTopLeft() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(.sectionHeader(title: isEnglish ? "Switch AI Engine" : "切换已就绪引擎"))
        for provider in aiConfig.readyProviders {
            let label = "\(provider.displayName(isEnglish: isEnglish))  (\(prettyModelBadgeName(for: provider)))"
            let item = makeMenuItem(title: label, isChecked: activeProvider == provider) {
                aiConfig.preferredProvider = provider
            }
            menu.addItem(item)
        }

        if let current = activeProvider {
            menu.addItem(.separator())
            menu.addItem(.sectionHeader(title: isEnglish ? "Model (\(current.shortName))" : "\(current.shortName) 模型选择"))

            let activeModel = aiConfig.effectiveModel(for: current)
            for preset in current.presetModels {
                let item = makeMenuItem(title: preset, isChecked: activeModel == preset) {
                    if preset == current.defaultModel {
                        aiConfig.resetModelToDefault(for: current)
                    } else {
                        aiConfig.setCustomModel(preset, for: current)
                    }
                }
                menu.addItem(item)
            }

            if !current.presetModels.contains(activeModel) {
                let customTitle = isEnglish ? "\(activeModel) (Custom)" : "\(activeModel) (自定义)"
                let customItem = makeMenuItem(title: customTitle, isChecked: true) {}
                menu.addItem(customItem)
            }
        }

        menu.addItem(.separator())
        let configItem = makeMenuItem(
            title: isEnglish ? "Manage Engines & Custom Models..." : "管理 AI 引擎与自定义模型...",
            symbolName: "slider.horizontal.3"
        ) {
            onOpenEngineSettings()
        }
        menu.addItem(configItem)

        // 先测量菜单实际尺寸；macOS 屏幕坐标系原点在左下角 (+Y 向上)，popUp 的 at 参数是菜单左上角坐标
        menu.update()
        let menuSize = menu.size
        let mouse = NSEvent.mouseLocation

        // 让菜单右下角对齐点击位置上方 12pt，从而整体向【左上方】展开
        var topLeftX = mouse.x - menuSize.width
        var topLeftY = mouse.y + menuSize.height + 12

        // 严格限制在当前软件窗口框内部（留出内边距，绝不越界）
        if let winFrame = NSApp.keyWindow?.frame {
            let inset: CGFloat = 14
            topLeftX = max(winFrame.minX + inset, min(topLeftX, winFrame.maxX - menuSize.width - inset))
            topLeftY = min(winFrame.maxY - 36, max(topLeftY, winFrame.minY + menuSize.height + inset))
        }

        menu.popUp(positioning: nil, at: NSPoint(x: topLeftX, y: topLeftY), in: nil)
    }

    private func makeMenuItem(
        title: String,
        isChecked: Bool = false,
        symbolName: String? = nil,
        action: @escaping () -> Void
    ) -> NSMenuItem {
        let target = MenuActionTarget(action)
        let item = NSMenuItem(
            title: title,
            action: #selector(MenuActionTarget.performAction),
            keyEquivalent: ""
        )
        item.target = target
        item.representedObject = target
        item.state = isChecked ? .on : .off
        if let symbolName {
            item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        }
        return item
    }

    private func prettyModelBadgeName(for provider: APIProvider) -> String {
        let raw = aiConfig.effectiveModel(for: provider)
        let lower = raw.lowercased()

        if lower.contains("llama-3.3") || lower.contains("llama3.3") { return "Llama 3.3" }
        if lower.contains("llama-3.1") || lower.contains("llama3.1") { return "Llama 3.1" }
        if lower.contains("llama3.2") || lower.contains("llama-3.2") { return "Llama 3.2" }
        if lower.contains("glm-4.5-flash") { return "GLM-4.5 Flash" }
        if lower.contains("glm-4-flash") { return "GLM-4 Flash" }
        if lower.contains("glm-4-9b") { return "GLM-4 9B" }
        if lower.contains("gemini-2.5-flash-lite") { return "Gemini 2.5 Lite" }
        if lower.contains("gemini-2.5") { return "Gemini 2.5" }
        if lower.contains("gemini-2.0") { return "Gemini 2.0" }
        if lower.contains("gemma-3") || lower.contains("gemma3") { return "Gemma 3" }
        if lower.contains("qwen2.5") || lower.contains("qwen-2.5") { return "Qwen 2.5" }
        if lower.contains("qwen3") { return "Qwen 3" }
        if lower.contains("qwen-turbo") { return "Qwen Turbo" }
        if lower.contains("qwen-plus") { return "Qwen Plus" }
        if lower.contains("deepseek-r1") || lower.contains("reasoner") { return "DeepSeek R1" }
        if lower.contains("deepseek") { return "DeepSeek V3" }
        if lower.contains("gpt-4o-mini") { return "GPT-4o mini" }
        if lower.contains("gpt-4.1-mini") { return "GPT-4.1 mini" }
        if lower.contains("gpt-4.1-nano") { return "GPT-4.1 nano" }
        if lower.contains("hunyuan-lite") { return "Hunyuan Lite" }
        if lower.contains("moonshot") { return "Kimi" }

        let afterSlash = raw.split(separator: "/").last.map(String.init) ?? raw
        let clean = afterSlash.replacingOccurrences(of: ":free", with: "")
        return clean.count > 14 ? String(clean.prefix(13)) + "…" : clean
    }
}
