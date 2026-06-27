//
//  ContainerDragData.swift
//  Struct
//
//  Created by Otto Kiefer on 24.06.2026.
//

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Container Drag Data

/// Lightweight payload transferred during a container drag-and-drop operation.
///
/// Carries enough information to look up the model object on the receiving
/// side and determine whether the move crosses space boundaries.
///
/// `PersistentIdentifier` is `Codable` as of iOS 18+, so we encode it directly.
struct ContainerDragData: Codable, Transferable {

    let containerID: PersistentIdentifier
    let isList:      Bool
    let sourceSpaceID: PersistentIdentifier

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .containerDrag)
    }
}

// MARK: - Space Drag Data

/// Payload transferred during a space reorder drag-and-drop operation.
struct SpaceDragData: Codable, Transferable {
    let spaceID: PersistentIdentifier
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .spaceDrag)
    }
}

// MARK: - Custom UTType

extension UTType {
    static let containerDrag = UTType(exportedAs: "com.struct.containerDrag")
    static let spaceDrag = UTType(exportedAs: "com.struct.spaceDrag")
}