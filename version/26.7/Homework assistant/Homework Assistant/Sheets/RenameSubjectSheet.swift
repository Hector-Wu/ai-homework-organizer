// Filename: Sheets/RenameSubjectSheet.swift

import SwiftUI

struct RenameSubjectSheet: View {
    var oldName: String
    var isEnglish: Bool
    var onRename: (String, String) -> Void
    var onDelete: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var enName = ""
    @State private var zhName = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text(isEnglish ? "Rename / Edit" : "修改学科名").font(.headline)
            Text(oldName).font(.caption).foregroundStyle(.secondary)
            Form {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isEnglish ? "Chinese Name:" : "中文名:")
                    TextField("", text: $zhName).textFieldStyle(.roundedBorder).onChange(of: zhName) { if zhName.count > 20 { zhName = String(zhName.prefix(20)) } }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(isEnglish ? "English Name:" : "英文名:")
                    TextField("", text: $enName).textFieldStyle(.roundedBorder).onChange(of: enName) { if enName.count > 75 { enName = String(enName.prefix(75)) } }
                }
            }.formStyle(.grouped)
            HStack {
                Button(role: .destructive) { onDelete(); dismiss() } label: { Text(isEnglish ? "Delete" : "删除") }
                Spacer()
                Button(isEnglish ? "Cancel" : "取消") { dismiss() }
                Button(isEnglish ? "Save" : "保存") { onRename(enName, zhName); dismiss() }.buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 350, height: 300)
        // 强迫 SwiftUI 在 oldName 更新时彻底刷新整个视图状态
        .id(oldName)
        .onAppear {
            let components = oldName.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            if components.count >= 2 {
                zhName = String(components[0]); enName = String(components[1])
            } else if oldName.contains(" ") {
                zhName = oldName.trimmingCharacters(in: .whitespacesAndNewlines); enName = ""
            } else if oldName.first?.isASCII ?? false {
                zhName = ""; enName = oldName
            } else {
                zhName = oldName; enName = ""
            }
        }
    }
}
