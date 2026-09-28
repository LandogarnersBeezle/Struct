//
//  SampleContainers.swift
//  Struct
//
//  Created by Otto Kiefer on 24.09.2026.
//

import Foundation

/// Sample containers with stable identifiers, so previews, seeding, and the reorder
/// scenarios always describe the same data.
///
/// In the hybrid architecture, parentage and sibling sort orders are explicit.
enum SampleContainers {
    // Deterministic Space IDs
    static let workID = sampleID(10)
    static let personalID = sampleID(20)
    static let readingID = sampleID(30)

    /// Factory method returning freshly instantiated sample containers with `isSample: true`.
    static func createSamples() -> [ContainerItem] {
        [
            // Sole lists and projects: autonomous (parentID == nil)
            ContainerItem(id: sampleID(1), kind: .list, name: "Inbox", parentID: nil, sortOrder: 100, isSample: true),
            ContainerItem(id: sampleID(2), kind: .project, name: "Portfolio Site", parentID: nil, sortOrder: 200, isSample: true),

            // Work space & children
            ContainerItem(id: workID, kind: .space, name: "Work", parentID: nil, sortOrder: 300, isSample: true),
            ContainerItem(id: sampleID(11), kind: .list, name: "Sprint Backlog", parentID: workID, sortOrder: 100, isSample: true),
            ContainerItem(id: sampleID(12), kind: .list, name: "Meeting Notes", parentID: workID, sortOrder: 200, isSample: true),
            ContainerItem(id: sampleID(13), kind: .project, name: "Q3 Roadmap", parentID: workID, sortOrder: 300, isSample: true),

            // Personal space & children
            ContainerItem(id: personalID, kind: .space, name: "Personal", parentID: nil, sortOrder: 400, isSample: true),
            ContainerItem(id: sampleID(21), kind: .list, name: "Groceries", parentID: personalID, sortOrder: 100, isSample: true),
            ContainerItem(id: sampleID(22), kind: .project, name: "Home Studio", parentID: personalID, sortOrder: 200, isSample: true),

            // Reading space & children
            ContainerItem(id: readingID, kind: .space, name: "Reading", parentID: nil, sortOrder: 500, isSample: true),
            ContainerItem(id: sampleID(31), kind: .list, name: "Want to Read", parentID: readingID, sortOrder: 100, isSample: true),
            ContainerItem(id: sampleID(32), kind: .project, name: "Book Notes", parentID: readingID, sortOrder: 200, isSample: true)
        ]
    }

    /// Single instance samples for row previews.
    static var sampleInbox: ContainerItem {
        ContainerItem(id: sampleID(1), kind: .list, name: "Inbox", parentID: nil, sortOrder: 100, isSample: true)
    }

    static var sampleWork: ContainerItem {
        ContainerItem(id: workID, kind: .space, name: "Work", parentID: nil, sortOrder: 300, isSample: true)
    }

    static var sampleSprintBacklog: ContainerItem {
        ContainerItem(id: sampleID(11), kind: .list, name: "Sprint Backlog", parentID: workID, sortOrder: 100, isSample: true)
    }
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


