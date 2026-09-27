//
//  ContainerRowView.swift
//  Struct
//
//  Created by Otto Kiefer on 24.09.2026.
//

import SwiftUI

/// One row of the container list.
struct ContainerRowView: View {
    let item: ContainerItem
    let presentation: ContainerRowPresentation

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.kind.symbolName)
                .font(.system(size: item.isSpace ? 16 : 14, weight: item.isSpace ? .semibold : .regular))
                .foregroundStyle(item.kind.tint)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(item.isSpace ? .headline : .body)
                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, CGFloat(presentation.depth) * 22)
        .padding(.vertical, 2)
        .contentShape(.rect)
    }

    private var caption: String? {
        if item.isSpace {
            return "\(presentation.childCount) container\(presentation.childCount == 1 ? "" : "s")"
        }
        return presentation.isAutonomous ? "Sole" : nil
    }
}

extension ContainerKind {
    var tint: Color {
        switch self {
        case .space: .indigo
        case .list: .blue
        case .project: .orange
        }
    }
}

#Preview("Rows") {
    List {
        ContainerRowView(item: SampleContainers.inbox, presentation: ContainerRowPresentation(isAutonomous: true))
        ContainerRowView(item: SampleContainers.work, presentation: ContainerRowPresentation(childCount: 3))
        ContainerRowView(item: SampleContainers.sprintBacklog, presentation: ContainerRowPresentation(depth: 1))
    }
}
