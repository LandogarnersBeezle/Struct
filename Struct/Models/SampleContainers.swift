//
//  SampleContainers.swift
//  Struct
//
//  Created by Otto Kiefer on 24.09.2026.
//

import Foundation

/// Sample containers with stable identifiers, so previews and the reorder
/// scenarios always describe the same data.
enum SampleContainers {
    // Sole lists and projects: they sit above the first space.
    static let inbox = ContainerItem(id: sampleID(1), kind: .list, name: "Inbox")
    static let portfolio = ContainerItem(id: sampleID(2), kind: .project, name: "Portfolio Site")

    static let work = ContainerItem(id: sampleID(10), kind: .space, name: "Work")
    static let sprintBacklog = ContainerItem(id: sampleID(11), kind: .list, name: "Sprint Backlog")
    static let meetingNotes = ContainerItem(id: sampleID(12), kind: .list, name: "Meeting Notes")
    static let roadmap = ContainerItem(id: sampleID(13), kind: .project, name: "Q3 Roadmap")

    static let personal = ContainerItem(id: sampleID(20), kind: .space, name: "Personal")
    static let groceries = ContainerItem(id: sampleID(21), kind: .list, name: "Groceries")
    static let homeStudio = ContainerItem(id: sampleID(22), kind: .project, name: "Home Studio")

    static let reading = ContainerItem(id: sampleID(30), kind: .space, name: "Reading")
    static let wantToRead = ContainerItem(id: sampleID(31), kind: .list, name: "Want to Read")
    static let bookNotes = ContainerItem(id: sampleID(32), kind: .project, name: "Book Notes")

    /// The order the list starts with.
    static let all: [ContainerItem] = [
        inbox, portfolio,
        work, sprintBacklog, meetingNotes, roadmap,
        personal, groceries, homeStudio,
        reading, wantToRead, bookNotes
    ]
}

/// Deterministic identifiers for the sample data.
private func sampleID(_ value: Int) -> UUID {
    let suffix = String(value)
    let padding = String(repeating: "0", count: max(0, 12 - suffix.count))
    guard let id = UUID(uuidString: "00000000-0000-4000-8000-\(padding)\(suffix)") else {
        preconditionFailure("Invalid sample identifier for \(value)")
    }
    return id
}
