// Filename: SubjectManager.swift
// 用途：学科管理器 —— 颜色分配、持久化、增删改清

import SwiftUI
import Combine

class SubjectManager: ObservableObject {
    @Published var subjectColors:         [String: String] = [:]
    @Published var manuallyAddedSubjects: Set<String>      = []

    private let palette: [Color] = [
        .blue, .orange, .green, .purple, .pink,
        .teal, .indigo, .mint, .cyan, .brown
    ]

    init() { load() }

    func load() {
        if let data    = UserDefaults.standard.data(forKey: "subjectColors"),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            self.subjectColors = decoded
        } else {
            self.subjectColors = [:]
        }
        if let data    = UserDefaults.standard.data(forKey: "manualSubjects"),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            self.manuallyAddedSubjects = decoded
        } else {
            self.manuallyAddedSubjects = []
        }
    }

    func getColor(for subject: String) -> Color {
        if let hex = subjectColors[subject] { return Color(hex: hex) }
        let usedHexes = Set(subjectColors.values)
        var newColor  = palette.randomElement()!
        for color in palette {
            if !(usedHexes.contains(color.toHex() ?? "")) {
                newColor = color
                break
            }
        }
        let hex = newColor.toHex() ?? "0000FF"
        subjectColors[subject] = hex
        save()
        return newColor
    }

    func setColor(for subject: String, color: Color) {
        subjectColors[subject] = color.toHex()
        save()
    }

    func addSubject(_ name: String) {
        manuallyAddedSubjects.insert(name)
        save()
    }

    func removeSubject(_ name: String) {
        manuallyAddedSubjects.remove(name)
        save()
    }

    func renameSubject(from old: String, to new: String) {
        if let colorHex = subjectColors[old] {
            subjectColors[new] = colorHex
            subjectColors.removeValue(forKey: old)
        }
        if manuallyAddedSubjects.contains(old) {
            manuallyAddedSubjects.remove(old)
            manuallyAddedSubjects.insert(new)
        }
        save()
    }

    func clearAll() {
        subjectColors         = [:]
        manuallyAddedSubjects = []
        UserDefaults.standard.removeObject(forKey: "subjectColors")
        UserDefaults.standard.removeObject(forKey: "manualSubjects")
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(subjectColors) {
            UserDefaults.standard.set(encoded, forKey: "subjectColors")
        }
        if let encoded = try? JSONEncoder().encode(manuallyAddedSubjects) {
            UserDefaults.standard.set(encoded, forKey: "manualSubjects")
        }
    }
}
