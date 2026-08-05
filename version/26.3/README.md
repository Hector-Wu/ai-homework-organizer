# Homework Assistant (作业助手)

![License](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg)
![Swift](https://img.shields.io/badge/SwiftUI-SwiftData-orange.svg)

Homework Assistant is a native macOS application designed to parse your unstructured, natural language homework descriptions into a structured schedule using AI.

> **Note:** This project contains code generated with the assistance of AI tools. All logic and architecture have been reviewed and tested by the author.

---

## ⚙️ System Requirements
*   **OS:** macOS 14.0 or later
*   **IDE:** Xcode 15.0 or later

## 🔑 API Configuration 

This application operates purely locally and **does not** include any built-in API keys. You must supply your own free API key to use the AI parsing feature:

1.  **Groq:** Uses `llama-3.3-70b` (Recommended for speed). [Get Key](https://console.groq.com/keys)
2.  **Google AI Studio:** Uses the `gemma-3` series. [Get Key](https://aistudio.google.com/app/apikey)

*Keys are stored securely on your local device. Your data is not uploaded to any third-party servers other than the direct text prompt sent to your chosen AI provider.*

---

## 🇬🇧 English

### What's New in v26.3
*   **Day View:** The app now defaults to a "Today" view. You can use the calendar picker to jump to any date. Assignments will show up on any day between their start and end dates.
*   **DUE Highlights:** Incomplete assignments due within 24 hours will automatically be highlighted with a red "DUE" badge and border.
*   **Smart AI Fallback:** If your selected AI model fails (e.g., rate limits), the app will now pause and ask if you want to try a smaller model, rather than just failing silently.
*   **Recycle Bin:** Deleted assignments now go to a recycle bin where they can be restored. Items older than 7 days are automatically cleared.
*   **Custom AI Prompts:** You can now edit the underlying AI instructions (System Prompt) in the Settings to tweak how it reads your homework.

### Features
*   **Natural Language Input:** Just type normally, and the AI extracts the subject, task, and deadline.
*   **Bilingual:** The interface supports English and Chinese, and the AI automatically tags subjects bilingually (e.g., "Math 数学").
*   **Customization:** Assign different colors to your subjects.
*   **Data Management:** Easily move, edit, or batch-delete tasks.

---

## 🇨🇳 中文

### 项目简介
作业助手 (Homework Assistant) 是一款 macOS 原生应用。你可以直接输入一大段自然语言（比如“明天交数学卷子，下周一有个历史展示”），AI 会自动帮你把它们拆分成带学科、内容和具体截止日期的日程表。

### v26.3 更新内容
*   **全新“当天”视图**: 默认界面改为查看单日任务。你可以点击日期选择器查看任意一天。只要某个作业的持续时间包含这一天，它就会显示在列表里。
*   **DUE 紧急高亮**: 距离截止时间不足 24 小时且未打勾的作业，会自动加上红色的“DUE”标签和警示边框，防遗漏。
*   **AI 智能降级提示**: 完美支持 Groq 和最新的 Gemma 3。如果遇到网络请求失败或限流，应用会弹窗询问你是否愿意切换到较小的备用模型继续解析，而不是直接报错卡死。
*   **回收站机制**: 误删的作业会进入回收站，支持随时还原。回收站里的垃圾数据超过 7 天会自动清理。
*   **自定义提示词**: 在设置中，你可以直接修改发给 AI 的底层指令 (System Prompt)，亲自调教 AI 的解析习惯。

### 核心功能
*   **🤖 智能提取**: 自动计算相对时间（如“下周三”会自动转为具体日期）。
*   **🇨🇳/🇬🇧 双语体验**: 界面中英切换，AI 会自动帮你把学科名统一成双语标签（如“数学 Math”）。
*   **🎨 个性化**: 支持为不同学科自定义颜色。
*   **📂 批量管理**: 独立的管理页面，支持按日期筛选和批量移动/删除作业。所有数据均保存在本地 (SwiftData)。

### 编译与运行
1.  Clone 本仓库。
2.  使用 Xcode 打开项目。
3.  按 `Cmd + R` 编译运行。

---

**Author:** Hector Wu
**Version:** 26.3