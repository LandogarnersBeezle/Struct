//
//  TodoItem.swift
//  Struct
//
//  Created by Otto Kiefer on 01.05.2026.
//

import Foundation
import SwiftData

@Model
final class TodoItem {
    var timestamp: Date
    var title: String
    var isCompleted: Bool

    init(timestamp: Date = .now, title: String, isCompleted: Bool = false) {
        self.timestamp = timestamp
        self.title = title
        self.isCompleted = isCompleted
    }
}
