//
//  List.swift
//  Struct
//
//  Created by Otto Kiefer on 04.05.2026.
//

import Foundation
import SwiftData

enum ListKind: String, Codable {
    case user
    case inbox
}

@Model
final class List {
    var title: String
    var notes: String
    var kindRaw: String
    var sortIndex: Int
    var createdAt: Date
    var updatedAt: Date

    var space: Space?

    @Relationship(deleteRule: .cascade, inverse: \Item.list)
    var items: [Item] = []

    var kind: ListKind {
        get { ListKind(rawValue: kindRaw) ?? .user }
        set { kindRaw = newValue.rawValue }
    }

    init(title: String,
         notes: String = "",
         kind: ListKind = .user,
         space: Space? = nil,
         sortIndex: Int = 0) {
        self.title = title
        self.notes = notes
        self.kindRaw = kind.rawValue
        self.sortIndex = sortIndex
        self.createdAt = .now
        self.updatedAt = .now
        self.space = space
    }

    func touch() {
        updatedAt = .now
    }
}

extension List {
    static func ensureInbox(in context: ModelContext) {
        let inboxRaw = ListKind.inbox.rawValue
        let descriptor = FetchDescriptor<List>(
            predicate: #Predicate { $0.kindRaw == inboxRaw }
        )
        do {
            let existing = try context.fetch(descriptor)
            if existing.isEmpty == false { return }
            let inbox = List(title: "Inbox", kind: .inbox)
            context.insert(inbox)
            try context.save()
        } catch {
            assertionFailure("Inbox bootstrap failed: \(error)")
        }
    }
}
