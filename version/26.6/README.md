# Homework Assistant (作业助手)

Homework Assistant is a native macOS application designed to parse unstructured, natural language homework descriptions into a structured schedule using AI.

> **Note:** This project contains code generated with the assistance of AI tools. All logic and architecture have been reviewed and tested by the author.

---

## System Requirements
* **OS:** macOS 14.0 or later
* **IDE:** Xcode 15.0 or later

## API Configuration 

This application operates locally and does not include built-in API keys. You must supply your own free API key to use the AI parsing feature:

1. **Groq:** Uses `llama-3.3-70b` (Recommended for speed). [Get Key](https://console.groq.com/keys)
2. **Google AI Studio:** Uses the `gemma-3` / `gemma-4` series. [Get Key](https://aistudio.google.com/app/apikey)

Keys are stored locally on your device. Your data is not uploaded to third-party servers other than the direct prompt sent to your selected AI provider.

---

## English

### What's New in v26.6
The codebase has been completely refactored from v26.3 to improve application architecture, window management, and background execution.

* **MenuBar Integration:** Native MenuBar item supporting left-click popover view and right-click context menu to show the main window or quit the app.
* **MiniWidget Mode:** A floating mini view for quickly checking and completing tasks without opening the main window.
* **Background Execution:** Closing the main window keeps the application running in the MenuBar when configured, allowing instant access from the status bar.
* **Architecture & Stability:** Updated AppKit and SwiftUI integration with shared ModelContainer management and improved window state handling.

### Features
* **Natural Language Input:** Type naturally, and the AI extracts the subject, task description, and deadlines.
* **Day View & DUE Highlights:** View daily schedules with highlight indicators for incomplete tasks due within 24 hours.
* **Bilingual Support:** Interface supports English and Chinese, with automated bilingual subject tagging.
* **Subject Customization:** Assign custom colors to different subjects for visual distinction.
* **AI Fallback & Prompts:** Configurable System Prompts with fallback mechanisms when API rate limits occur.
* **Recycle Bin & Data Management:** SwiftData-powered local storage with a 7-day recycle bin for recovering deleted items.

---

## 中文

### 项目简介
作业助手 (Homework Assistant) 是一款 macOS 原生应用。你可以输入自然语言描述，AI 会自动提取学科、任务内容和截止日期，转化为结构化的日程管理视图。

> **注意：** 本项目包含 AI 辅助生成的代码，所有逻辑与架构均经过作者审查与测试。

---

## 系统要求
* **操作系统:** macOS 14.0 或更高版本
* **开发环境:** Xcode 15.0 或更高版本

## API 配置

应用完全在本地运行，不内置 API Key。使用 AI 解析功能前，需自行配置免费的 API Key：

1. **Groq:** 使用 `llama-3.3-70b` (推荐，响应速度快)。[获取 Key](https://console.groq.com/keys)
2. **Google AI Studio:** 使用 `gemma-3` / `gemma-4` 系列。[获取 Key](https://aistudio.google.com/app/apikey)

API Key 仅加密存储于本地设备。除直接发送至选定 AI 服务商的文本 Prompt 外，你的数据不会上传至任何第三方服务器。

---

### v26.6 更新内容
相比于 v26.3，v26.6 对全部底层代码进行了重构，优化了应用架构、窗口生命周期管理与后台运行机制。

* **菜单栏常驻:** 原生 MenuBar 支持，左键点击弹出快捷面板，右键点击显示上下文菜单（打开主界面或退出软件）。
* **MiniWidget 模式:** 提供悬浮的桌面迷你组件，无需打开主窗口即可快速查看并勾选完成作业。
* **后台驻留机制:** 开启相关选项后，关闭主窗口应用会自动隐藏并保留在菜单栏后台运行，随时唤醒。
* **架构与稳定性重构:** 重新设计了 AppKit 与 SwiftUI 的结合逻辑，优化了 ModelContainer 共享与窗口状态控制。

### 核心功能
* **自然语言解析:** 输入日常口语化内容，AI 自动提取学科、任务详情与具体截止日期。
* **日视图与过期提醒:** 提供按日查看的日程视图，对 24 小时内即将截止且未完成的作业提供高亮提示。
* **双语支持:** 界面支持中英文切换，AI 自动生成双语学科标签。
* **学科个性化:** 支持为不同学科自定义颜色，便于直观区分。
* **提示词与降级策略:** 支持自定义系统 Prompt，并在遇到 API 限流时提供模型降级切换选项。
* **数据管理与回收站:** 基于 SwiftData 实现纯本地存储，并提供保留 7 天的回收站机制。

---

## Compilation and Running / 编译与运行
1. Clone this repository. / 克隆本仓库。
2. Open the project with Xcode. / 使用 Xcode 打开项目。
3. Press `Cmd + R` to build and run. / 按 `Cmd + R` 编译运行。

---

**Author:** Hector Wu  
**Version:** 26.6
