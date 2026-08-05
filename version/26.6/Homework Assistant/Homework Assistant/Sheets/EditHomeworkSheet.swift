//
//  EditHomeworkSheet.swift
//  Homework Assistant
//
//  Created by Hector Wu on 26/4/2026.
//


// Filename: Sheets/EditHomeworkSheet.swift

import SwiftUI
import SwiftData

struct EditHomeworkSheet: View {
    @Bindable var item: HomeworkItem
    var allSubjects: [String]
    var isEnglish: Bool
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Form {
            Section(isEnglish ? "Edit" : "修改") {
                Picker(isEnglish ? "Subject" : "科目", selection: $item.subject) { ForEach(allSubjects, id: \.self) { Text($0).tag($0) } }
                TextEditor(text: $item.content).frame(height: 100)
                    .onChange(of: item.content) { if item.content.count > 2000 { item.content = String(item.content.prefix(2000)) } }
                TextField(isEnglish ? "Notes" : "备注", text: Binding(get: { item.specialNotes ?? "" }, set: { item.specialNotes = $0.isEmpty ? nil : $0 }))
                DatePicker(isEnglish ? "Due" : "截止", selection: $item.endDate, displayedComponents: .date).datePickerStyle(.compact)
            }
            HStack {
                Spacer()
                Button(isEnglish ? "Save" : "保存") { try? modelContext.save(); dismiss() }.buttonStyle(.borderedProminent)
            }
        }
        .padding().frame(width: 400, height: 450)
    }
}