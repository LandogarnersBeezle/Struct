//
//  Project.swift
//  Struct
//
//  Created by Otto Kiefer on 04.05.2026.
//

import Foundation
import SwiftData

@Model
final class Project {
    var title: String
    var notes: String
    var isCompleted: Bool {
        didSet {
            completedAt = isCompleted ? (completedAt ?? .now) : nil
        }
    }
    var completedAt: Date?
    var sortIndex: Int
    var createdAt: Date
    var updatedAt: Date

    var space: Space?

    @Relationship(deleteRule: .cascade, inverse: \Item.project)
    var items: [Item] = []

    init(title: String,
         notes: String = "",
         space: Space? = nil,
         sortIndex: Int = 0) {
        self.title = title
        self.notes = notes
        self.isCompleted = false
        self.completedAt = nil
        self.sortIndex = sortIndex
        self.createdAt = .now
        self.updatedAt = .now
        self.space = space
    }

    func touch() {
        updatedAt = .now
    }
}
