// Filename: Extensions.swift
// 用途：全局工具扩展 —— Color十六进制互转、View字体缩放

import SwiftUI

// MARK: - Color 十六进制互转

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 255)
        }
        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }

    func toHex() -> String? {
        guard let components = NSColor(self).cgColor.components,
              components.count >= 3 else { return nil }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "%02lX%02lX%02lX",
                      lroundf(r * 255),
                      lroundf(g * 255),
                      lroundf(b * 255))
    }
}

// MARK: - 绝对字号缩放（视系统动态字体设置无效，强制按比例）

struct ScaledFont: ViewModifier {
    var baseSize: CGFloat
    var weight: Font.Weight
    @AppStorage("appFontSize") private var fontSize: AppFontSize = .medium

    func body(content: Content) -> some View {
        content.font(.system(size: baseSize * fontSize.scale, weight: weight))
    }
}

extension View {
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.modifier(ScaledFont(baseSize: size, weight: weight))
    }
}

// 9(逾期)>1(DUE今天截止)>2(倒计时)>3(普通)

extension Array where Element == HomeworkItem {
    /// 未完成优先，逾期>DUE>倒计时>普通，同级按剩余天数和科目名排
    func scrSorted(for date: Date, isEnglish: Bool) -> [HomeworkItem] {
        return self.sorted { a, b in
            // 第一级：未完成的排在完成的前面
            if a.isCompleted != b.isCompleted { return !a.isCompleted }
            
            // 第二级：9号最紧急，等价于0级优先
            let statA = a.getSCRStatus(viewedDate: date, isEnglish: isEnglish).status
            let statB = b.getSCRStatus(viewedDate: date, isEnglish: isEnglish).status
            
            // status==9(逾期/OVERDUE)等同于最高优先级0
            let rankA = statA == 9 ? 0 : statA
            let rankB = statB == 9 ? 0 : statB
            if rankA != rankB { return rankA < rankB }
            
            // 第三级：剩余天数越少越靠前
            let aDays = a.daysToDue(from: date)
            let bDays = b.daysToDue(from: date)
            if aDays != bDays { return aDays < bDays }

            // 第四级：科目名字母顺序
            return a.subject < b.subject
        }
    }
}
