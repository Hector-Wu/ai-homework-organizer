# Homework Assistant (作业助手)

Homework Assistant is a native macOS application designed to parse unstructured, natural language homework descriptions into a structured schedule using AI.

> **Note:** This project contains code generated with the assistance of AI tools. All logic and architecture have been reviewed and tested by the author.

---

## System Requirements
* **OS:** macOS 15.6 or later
* **IDE:** Xcode 16.0 or later

## API Configuration

This application operates locally and does not include built-in API keys. You must configure an API key from a supported provider or connect to a local endpoint to use the AI parsing feature:

1. **Groq:** Default model `llama-3.3-70b-versatile`. [Get Key](https://console.groq.com/keys)
2. **Zhipu AI (智谱 AI):** Default model `glm-4-flash`. [Get Key](https://open.bigmodel.cn/)
3. **Google Gemini:** Uses Gemini / Gemma models via Google AI Studio. [Get Key](https://aistudio.google.com/app/apikey)
4. **Other Providers:** Built-in presets for SiliconFlow, OpenRouter, Cerebras, Mistral, DeepSeek, and OpenAI, with support for custom Model IDs.
5. **Custom & Local Endpoints:** Supports OpenAI-compatible Base URLs and local Ollama instances (e.g., `http://localhost:11434/v1`).

API keys are stored locally in the macOS Keychain. Your data is not uploaded to third-party servers other than the direct prompt sent to your selected AI provider.

---

## English

### What's New in v26.7
v26.7 expands AI provider compatibility, upgrades credential storage, adds Dark Mode support, and refines window and undo interactions.

* **Multi-Provider AI & Custom Models:** Added support for 10 AI providers, per-provider custom Model IDs, custom OpenAI-compatible / Ollama endpoints, connection testing, automatic provider fallback, and an input-bar menu for switching active engines.
* **Keychain Storage:** Migrated API key storage from `UserDefaults` to the macOS Keychain, with automatic migration for existing keys.
* **Dark Mode Support:** Added System, Light, and Dark appearance options in Settings, with synchronized `NSAppearance` updates across the main window, sheets, menus, MenuBar popover, and MiniWidget.
* **Unified Undo Toast:** Unified the undo feedback component across the main window, MenuBar popover, and MiniWidget using an inverted-color capsule, adding undo support for AI task imports, single or batch task deletions, and subject deletions.
* **Long-Term Date Parsing & Deduplication:** Added `dueDate` (`YYYY-MM-DD`) parsing for multi-month assignments while maintaining backward compatibility with `daysFromToday` and `durationDays`, and included `endDate` in task deduplication checks.
* **UI & Window Lifecycle Fixes:** Fixed initial scroll jumping in List View, isolated input-bar text state to prevent unnecessary view re-renders, added dynamic MenuBar status item toggling, and updated MiniWidget close behavior to automatically restore the main window.

### Features
* **Natural Language Input:** Type naturally, and the AI extracts the subject, task description, notes, and deadlines.
* **Day View, List View & DUE Highlights:** View daily or chronological schedules with highlight indicators for overdue tasks and incomplete tasks due within 24 hours.
* **MenuBar & MiniWidget Modes:** Native MenuBar popover and floating MiniWidget for checking and completing tasks.
* **Bilingual Support:** Interface supports English and Simplified Chinese, with automated bilingual subject tagging.
* **Subject Customization:** Assign custom colors to different subjects for visual distinction.
* **Recycle Bin & Data Management:** SwiftData-powered local storage with batch task management and a 7-day recycle bin for recovering deleted items.

---

## 中文

### 项目简介
作业助手 (Homework Assistant) 是一款 macOS 原生应用。你可以输入自然语言描述，AI 会自动提取学科、任务内容和截止日期，转化为结构化的日程管理视图。

> **注意：** 本项目包含 AI 辅助生成的代码，所有逻辑与架构均经过作者审查与测试。

---

## 系统要求
* **操作系统:** macOS 15.6 或更高版本
* **开发环境:** Xcode 16.0 或更高版本

## API 配置

应用完全在本地运行，不内置 API Key。使用 AI 解析功能前，需自行配置任一受支持服务商的 API Key 或本地模型端点：

1. **Groq:** 默认使用 `llama-3.3-70b-versatile`。[获取 Key](https://console.groq.com/keys)
2. **智谱 AI:** 默认使用 `glm-4-flash`。[获取 Key](https://open.bigmodel.cn/)
3. **Google Gemini:** 通过 Google AI Studio 调用 Gemini / Gemma 系列模型。[获取 Key](https://aistudio.google.com/app/apikey)
4. **其他服务商:** 内置 SiliconFlow、OpenRouter、Cerebras、Mistral、DeepSeek 与 OpenAI 预设，支持自定义模型 ID。
5. **自定义接口与本地模型:** 支持自定义 OpenAI 兼容 Base URL 及本地 Ollama 接口（如 `http://localhost:11434/v1`）。

API Key 存储于本地 macOS 钥匙串 (Keychain) 中。除直接发送至选定 AI 服务商的文本 Prompt 外，你的数据不会上传至任何第三方服务器。

---

### v26.7 更新内容
相比于 v26.6，v26.7 扩展了多模型接口支持，升级了密钥存储方式，新增全局暗色模式，并完善了撤销机制与窗口管理逻辑。

* **多 AI 引擎与自定义模型:** 支持 10 种 AI 服务渠道、单平台自定义模型 ID 以及自定义 OpenAI 兼容接口 / 本地 Ollama，提供接口连通性测试、无密钥自动回退及输入栏模型快捷切换菜单。
* **钥匙串密钥存储:** API Key 由 `UserDefaults` 迁移至 macOS Keychain 保存，兼容旧版配置自动迁移与恢复出厂清理。
* **暗色模式支持:** 设置中新增跟随系统、浅色与暗色三种外观选项，适配各视图组件配色，并统一同步主窗口、弹窗、菜单、状态栏面板与悬浮窗外观。
* **统一撤销交互:** 调整状态栏面板撤销提示位置，并在主界面统一采用反色胶囊提示组件，支持对 AI 导入任务、单条或批量删除作业以及删除学科执行撤销恢复。
* **长周期日期解析与去重修正:** 新增 `dueDate` (`YYYY-MM-DD`) 字段解析以支持跨月长周期作业（向下兼容原有的 `daysFromToday` 与 `durationDays` 字段），并在去重逻辑中纳入截止日期判定。
* **列表渲染与窗口状态修复:** 修复列表视图首次加载滚动时的画面跳动问题，隔离输入栏文本状态以提升列表刷新性能，支持状态栏图标动态启停，并在关闭悬浮小窗时自动恢复主窗口。

### 核心功能
* **自然语言解析:** 输入日常口语化内容，AI 自动提取学科、任务详情、备注与具体截止日期。
* **日视图、列表视图与到期提醒:** 提供按日与按时间轴查看的日程视图，对已逾期及 24 小时内即将截止的未完成作业提供高亮标识。
* **菜单栏与悬浮窗模式:** 支持顶部菜单栏快捷面板与桌面置顶悬浮窗，便于快速查看并勾选完成作业。
* **双语支持:** 界面支持中英文切换，AI 自动生成并归并双语学科标签。
* **学科个性化:** 支持为不同学科自定义颜色。
* **数据管理与回收站:** 基于 SwiftData 实现纯本地存储，支持多选批量操作，并提供保留 7 天的回收站机制。

---

## Compilation and Running / 编译与运行
1. Clone this repository. / 克隆本仓库。
2. Open the project with Xcode. / 使用 Xcode 打开项目。
3. Press `Cmd + R` to build and run. / 按 `Cmd + R` 编译运行。

---

**Author:** Hector Wu  
**Version:** 26.7