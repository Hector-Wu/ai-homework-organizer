//
//  AddSubjectSheet.swift
//  Homework Assistant
//
//  Created by Hector Wu on 26/4/2026.
//


// Filename: Sheets/AddSubjectSheet.swift

import SwiftUI

struct AddSubjectSheet: View {
    var isEnglish: Bool
    var initialZh: String
    var onAdd: (String, String) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var enName = ""
    @State private var zhName = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text(isEnglish ? "Add Subject" : "新建学科").font(.headline)
            Form {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isEnglish ? "Chinese Name (Max 20):" : "中文名 (最多20):")
                    TextField("", text: $zhName).textFieldStyle(.roundedBorder).onChange(of: zhName) {
                        if zhName.count > 20 { zhName = String(zhName.prefix(20)) }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(isEnglish ? "English Name (Max 75):" : "英文名 (最多75):")
                    TextField("", text: $enName).textFieldStyle(.roundedBorder).onChange(of: enName) {
                        if enName.count > 75 { enName = String(enName.prefix(75)) }
                    }
                }
            }.formStyle(.grouped)
            HStack {
                Button(isEnglish ? "Cancel" : "取消") { dismiss() }; Spacer()
                Button(isEnglish ? "Add" : "添加") {
                    if !enName.isEmpty || !zhName.isEmpty {
                        onAdd(enName, zhName)
                        dismiss()
                    }
                }.buttonStyle(.borderedProminent)
            }
        }.padding().frame(width: 350, height: 280).onAppear { zhName = initialZh; enName = "" }
    }
}