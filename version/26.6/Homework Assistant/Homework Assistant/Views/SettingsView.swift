// Filename: SettingsView.swift
// 用途: 设置视图 — 偏好设置、AI引擎、学科颜色管理、重置、隐私政策

import SwiftUI
import SwiftData

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
    @AppStorage("appFontSize") private var appFontSize: AppFontSize = .medium
    @AppStorage("widgetFilter") private var widgetFilter: WidgetFilterType = .allToday

    @State private var showPromptSheet: Bool = false
    @State private var showResetDialog: Bool = false
    @State private var showConfirmClearData: Bool = false
    @State private var showConfirmFactoryReset: Bool = false
    
    var isEnglish: Bool { appLang == .english }

    var currentProviderDisplay: String {
        let provider = APIProvider(rawValue: preferredProviderRaw)
        switch provider {
        case .groq:
            return "Groq (Llama 3)"
        case .glm:
            return "Zhipu (GLM-4 Flash)"
        default:
            return isEnglish ? "Not Set" : "未设置"
        }
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
        .sheet(isPresented: $showPromptSheet) { PromptEditView() }
        .confirmationDialog(isEnglish ? "Restore Options" : "恢复选项", isPresented: $showResetDialog, titleVisibility: .visible) {
            Button(isEnglish ? "Clear All Homework Data" : "仅清空所有作业数据", role: .destructive) { showConfirmClearData = true }
            Button(isEnglish ? "Factory Reset (Wipe All)" : "恢复出厂设置 (抹掉所有)", role: .destructive) { showConfirmFactoryReset = true }
        }
        .alert(isEnglish ? "Clear All Data?" : "确认清空所有数据？", isPresented: $showConfirmClearData) {
            Button("Cancel", role: .cancel) {}
            Button(isEnglish ? "Clear" : "清空", role: .destructive) {
                try? modelContext.delete(model: HomeworkItem.self)
            }
        } message: {
            Text(isEnglish ? "This will erase all your assignments. Cannot be undone." : "此操作将永久删除所有的作业日程，无法恢复。")
        }
        .alert(isEnglish ? "Factory Reset?" : "确认恢复出厂设置？", isPresented: $showConfirmFactoryReset) {
            Button("Cancel", role: .cancel) {}
            Button(isEnglish ? "Reset" : "恢复出厂", role: .destructive) {
                try? modelContext.delete(model: HomeworkItem.self)
                groqKey = ""
                zhipuKey = ""
                subjectManager.clearAll()
            }
        } message: {
            Text(isEnglish ? "This will erase ALL data and API keys." : "此操作将抹除所有作业数据、学科配置和 API 密钥，相当于重新安装本软件。")
        }
    }

    @ViewBuilder var aboutSection: some View {
        Section {
            VStack(spacing: 10) {
                Text("📚").font(.system(size: 60))
                Text("作业助手 Homework Assistant").font(.largeTitle).bold()
                Text("Made by Hector").font(.body).foregroundStyle(.primary)
                Text("ver 26.6 (Build 15)").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder var preferencesSection: some View {
        Section(header: Label(isEnglish ? "Preferences" : "偏好设置", systemImage: "gearshape")) {
            // 修复: 直接使用 displayName 属性
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
                Text(isEnglish ? "Current Engine" : "当前首选引擎")
                Spacer()
                Text(currentProviderDisplay).foregroundStyle(.secondary)
            }
            Button(isEnglish ? "Manage AI Engines..." : "管理 AI 引擎...") {
                showAPISheet = true
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)
        }
    }

    @ViewBuilder var subjectColorsSection: some View {
        Section(header: Label(isEnglish ? "Subject Colors" : "学科颜色管理", systemImage: "paintpalette")) {
            if allSubjects.isEmpty {
                Text("No subjects").foregroundStyle(.secondary)
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

// MARK: - Prompt 编辑视图
struct PromptEditView: View {
    @ObservedObject var mgr = PromptManager.shared
    @State private var text: String = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("System Prompt")
                .font(.headline)
                .padding(.horizontal)
            
            Text("Placeholders: {{LANG}}, {{DATE}}")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .padding(4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding()
            
            HStack {
                Button("Restore Default") {
                    mgr.resetToDefault()
                    text = mgr.customPrompt
                }
                .foregroundStyle(.red)
                
                Spacer()
                
                Button("Save") {
                    mgr.customPrompt = text
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .onAppear { text = mgr.customPrompt }
        .frame(minWidth: 500, minHeight: 400)
    }
}
