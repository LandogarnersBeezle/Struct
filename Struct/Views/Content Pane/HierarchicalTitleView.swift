//
//  HierarchicalTitleView.swift
//  Struct
//
//  Created by Otto Kiefer on 05.05.2026.
//

import SwiftUI

/// Displays the hierarchical title for a container, showing the full path
/// (e.g., "Space / List") with appropriate icons and colors.
struct HierarchicalTitleView: View {
    let target: ContainerTarget

    var body: some View {
        switch target {
        case .space(let space):
            HStack(spacing: 4) {
                Image(systemName: space.symbolName)
                    .foregroundStyle(Space.containerColor)
                Text(space.name)
            }
        case .list(let list):
            if let space = list.space {
                HStack(spacing: 4) {
                    Image(systemName: space.symbolName)
                        .foregroundStyle(Space.containerColor)
                    Text(space.name)
                    Text("/")
                        .foregroundStyle(.secondary)
                    Image(systemName: list.kind == .inbox ? "tray" : "list.bullet")
                        .foregroundStyle(List.containerColor)
                    Text(list.title)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: list.kind == .inbox ? "tray" : "list.bullet")
                        .foregroundStyle(List.containerColor)
                    Text(list.title)
                }
            }
        case .project(let project):
            HStack(spacing: 4) {
                Image(systemName: project.space.symbolName)
                    .foregroundStyle(Space.containerColor)
                Text(project.space.name)
                Text("/")
                    .foregroundStyle(.secondary)
                Image(systemName: "folder")
                    .foregroundStyle(Project.containerColor)
                Text(project.title)
            }
        }
    }
}