//
//  Space.swift
//  Struct
//
//  Created by Otto Kiefer on 04.05.2026.
//

import Foundation
import SwiftData

@Model
final class Space {
    var name: String
    var symbolName: String
    var colorHex: String?
    var sortIndex: Int
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Project.space)
    var projects: [Project] = []

    @Relationship(deleteRule: .nullify, inverse: \List.space)
    var lists: [List] = []

    @Relationship(deleteRule: .nullify, inverse: \Item.space)
    var items: [Item] = []

    init(name: String,
         symbolName: String = "square.grid.2x2",
         colorHex: String? = nil,
         sortIndex: Int = 0) {
        self.name = name
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.sortIndex = sortIndex
        self.createdAt = .now
        self.updatedAt = .now
    }

    func touch() {
        updatedAt = .now
    }
}
