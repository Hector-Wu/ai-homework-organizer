// Filename: SettingsView.swift
// 用途: 设置视图 — 外观模式(系统/浅色/暗色)、偏好设置、状态栏实时联动、多AI引擎展示、学科颜色管理、重置与双语Prompt编辑

import SwiftUI
import SwiftData
import Combine

struct SettingsView: View {
    @Binding var appLang: AppLanguage
    @Binding var outputLang: OutputLanguage
    @Binding var developerMode: Bool
    @Binding var groqKey: String
    @Binding var zhipuKey: String
    @Binding var preferredProviderRaw: String
    @Binding var closeToMenuBar: Bool
    @ObservedObject var subjectManager: SubjectManager
    @Binding var showAPISheet: Bool
    @Binding var showPrivacySheet: Bool
    var allSubjects: [String]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var aiConfig = AIConfigManager.shared

    @AppStorage("appAppearance") private var appAppearance: AppAppearance = .system
    @AppStorage("appFontSize") private var appFontSize: AppFontSize = .medium
    @AppStorage("widgetFilter") private var widgetFilter: WidgetFilterType = .allToday

    @State private var showPromptSheet: Bool = false
    @State private var showResetDialog: Bool = false
    @State private var showConfirmClearData: Bool = false
    @State private var showConfirmFactoryReset: Bool = false

    var isEnglish: Bool { appLang == .english }
    private var isDark: Bool { colorScheme == .dark }

    var currentProviderDisplay: String {
        aiConfig.preferredProvider.displayName(isEnglish: isEnglish)
    }

    var currentModelDisplay: String {
        aiConfig.effectiveModel(for: aiConfig.preferredProvider)
    }

    var body: some View {
        Form {
            aboutSection
            preferencesSection
            aiEngineSection
            subjectColorsSection
            if developerMode { advancedSection }
            resetSection
            privacySection
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            aiConfig.syncLegacyIfNeeded(
                groqKey: groqKey,
                zhipuKey: zhipuKey,
                preferredRaw: preferredProviderRaw
            )
            if !groqKey.isEmpty { groqKey = "" }
            if !zhipuKey.isEmpty { zhipuKey = "" }
        }
        .onChange(of: appAppearance) { _, newValue in
            NotificationCenter.default.post(
                name: .appAppearanceDidChange,
                object: newValue.rawValue
            )
        }
        .onChange(of: closeToMenuBar) {
            NotificationCenter.default.post(name: .closeToMenuBarDidChange, object: nil)
        }
        .sheet(isPresented: $showPromptSheet) {
            PromptEditView(isEnglish: isEnglish)
        }
        .confirmationDialog(isEnglish ? "Restore Options" : "恢复选项", isPresented: $showResetDialog, titleVisibility: .visible) {
            Button(isEnglish ? "Clear All Homework Data" : "仅清空所有作业数据", role: .destructive) {
                showConfirmClearData = true
            }
            Button(isEnglish ? "Factory Reset (Wipe All)" : "恢复出厂设置 (抹掉所有)", role: .destructive) {
                showConfirmFactoryReset = true
            }
            Button(isEnglish ? "Cancel" : "取消", role: .cancel) {}
        }
        .alert(isEnglish ? "Clear All Data?" : "确认清空所有数据？", isPresented: $showConfirmClearData) {
            Button(isEnglish ? "Cancel" : "取消", role: .cancel) {}
            Button(isEnglish ? "Clear" : "清空", role: .destructive) {
                try? modelContext.delete(model: HomeworkItem.self)
            }
        } message: {
            Text(isEnglish ? "This will erase all your assignments. Cannot be undone." : "此操作将永久删除所有的作业日程，无法恢复。")
        }
        .alert(isEnglish ? "Factory Reset?" : "确认恢复出厂设置？", isPresented: $showConfirmFactoryReset) {
            Button(isEnglish ? "Cancel" : "取消", role: .cancel) {}
            Button(isEnglish ? "Reset" : "恢复出厂", role: .destructive) {
                try? modelContext.delete(model: HomeworkItem.self)
                groqKey = ""
                zhipuKey = ""
                preferredProviderRaw = APIProvider.groq.rawValue
                appAppearance = .system
                aiConfig.resetAllAIConfigs()
                PromptManager.shared.resetToDefault()
                subjectManager.clearAll()
                NotificationCenter.default.post(
                    name: .appAppearanceDidChange,
                    object: AppAppearance.system.rawValue
                )
            }
        } message: {
            Text(
                isEnglish
                    ? "This will erase ALL data, subject settings, and Keychain API keys."
                    : "此操作将抹除所有作业数据、学科配置以及钥匙串中的全部 API 密钥，相当于重新安装本软件。"
            )
        }
    }

    @ViewBuilder var aboutSection: some View {
        Section {
            VStack(spacing: 10) {
                Text("📚").font(.system(size: 60))
                Text("作业助手 Homework Assistant").font(.largeTitle).bold()
                Text("Made by Hector").font(.body).foregroundStyle(.primary)
                Text("ver 26.7").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder var preferencesSection: some View {
        Section(header: Label(isEnglish ? "Preferences" : "偏好设置", systemImage: "gearshape")) {
            Picker(isEnglish ? "Appearance" : "外观模式", selection: $appAppearance) {
                ForEach(AppAppearance.allCases) { mode in
                    Text(mode.displayName(isEnglish: isEnglish)).tag(mode)
                }
            }
            Picker(isEnglish ? "App Language" : "软件语言", selection: $appLang) {
                ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
            }
            Picker(isEnglish ? "Output Language" : "输出语言", selection: $outputLang) {
                ForEach(OutputLanguage.allCases) { Text($0.displayName).tag($0) }
            }
            Picker(isEnglish ? "Font Size" : "全局字体大小", selection: $appFontSize) {
                ForEach(AppFontSize.allCases) { Text($0.displayName(isEnglish: isEnglish)).tag($0) }
            }
            Picker(isEnglish ? "Widget Tasks" : "悬浮窗/状态栏作业", selection: $widgetFilter) {
                ForEach(WidgetFilterType.allCases) { Text($0.displayName(isEnglish: isEnglish)).tag($0) }
            }
            Toggle(isEnglish ? "Minimize to Menu Bar on Close" : "关闭主窗口时退至菜单栏", isOn: $closeToMenuBar)
            Toggle(isEnglish ? "Developer Mode" : "开发者模式", isOn: $developerMode)
        }
    }

    @ViewBuilder var aiEngineSection: some View {
        Section(header: Label(isEnglish ? "AI Engine" : "AI 引擎", systemImage: "cpu")) {
            HStack {
                Text(isEnglish ? "Preferred Engine" : "当前首选引擎")
                Spacer()
                Text(currentProviderDisplay).foregroundStyle(.secondary)
            }
            HStack {
                Text(isEnglish ? "Active Model" : "当前模型 ID")
                Spacer()
                Text(currentModelDisplay)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(isEnglish ? "Configured Engines" : "已就绪引擎数")
                Spacer()
                Text("\(aiConfig.readyProviders.count) / \(APIProvider.allCases.count)")
                    .foregroundStyle(aiConfig.hasAnyReadyProvider ? .green : .red)
            }
            Button(isEnglish ? "Manage AI Engines & Custom Models..." : "管理 AI 引擎与自定义模型...") {
                showAPISheet = true
            }
            .buttonStyle(.plain)
            .foregroundStyle(isDark ? Color(red: 0.38, green: 0.68, blue: 1.0) : .blue)
        }
    }

    @ViewBuilder var subjectColorsSection: some View {
        Section(header: Label(isEnglish ? "Subject Colors" : "学科颜色管理", systemImage: "paintpalette")) {
            if allSubjects.isEmpty {
                Text(isEnglish ? "No subjects" : "暂无学科").foregroundStyle(.secondary)
            }
            ForEach(allSubjects, id: \.self) { sub in
                HStack {
                    Text(sub)
                    Spacer()
                    ColorPicker("", selection: Binding(
                        get: { subjectManager.getColor(for: sub) },
                        set: { subjectManager.setColor(for: sub, color: $0) }
                    ))
                }
            }
        }
    }

    @ViewBuilder var advancedSection: some View {
        Section(header: Label(isEnglish ? "Advanced" : "高级", systemImage: "terminal")) {
            Button(isEnglish ? "Edit System Prompt" : "自定义 AI 提示词") {
                showPromptSheet = true
            }
        }
    }

    @ViewBuilder var resetSection: some View {
        Section(header: Label(isEnglish ? "Reset" : "恢复", systemImage: "arrow.counterclockwise")) {
            Button(isEnglish ? "Restore..." : "恢复...") {
                showResetDialog = true
            }
            .foregroundStyle(.red)
        }
    }

    @ViewBuilder var privacySection: some View {
        Section {
            Button(action: { showPrivacySheet = true }) {
                Label(isEnglish ? "Privacy Policy" : "隐私政策与用户协议", systemImage: "hand.raised")
            }
        }
    }
}

// MARK: - Prompt 编辑视图（自动继承 NSApp.appearance）

struct PromptEditView: View {
    var isEnglish: Bool = false
    @ObservedObject var mgr = PromptManager.shared
    @State private var text: String = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isEnglish ? "System Prompt" : "自定义系统提示词 (System Prompt)")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 14)

            Text(isEnglish ? "Placeholders: {{LANG}}, {{DATE}}" : "可用动态占位符: {{LANG}} (输出语言), {{DATE}} (当天日期)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isDark ? Color.white.opacity(0.06) : Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.12), lineWidth: 1)
                )
                .padding(.horizontal)

            HStack {
                Button(isEnglish ? "Restore Default" : "恢复默认提示词") {
                    mgr.resetToDefault()
                    text = mgr.customPrompt
                }
                .foregroundStyle(.red)

                Spacer()

                Button(isEnglish ? "Cancel" : "取消") {
                    dismiss()
                }

                Button(isEnglish ? "Save" : "保存") {
                    mgr.customPrompt = text
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .onAppear { text = mgr.customPrompt }
        .frame(minWidth: 520, minHeight: 420)
    }
}
