//
//  ContainerFocusListView.swift
//  Struct
//
//  Created by Otto Kiefer on 06.05.2026.
//

import SwiftUI
import SwiftData

// MARK: - Main Content View

struct ContainerFocusListView: View {
    let target: ContainerTarget
    @ObservedObject var viewModel: ContainerFocusViewModel
    let modelContext: ModelContext

    private var groupedContent: (directItems: ContainerFocusViewModel.GroupedItems, sectionGroups: [ContainerFocusViewModel.SectionGroup]) {
        viewModel.groupedContent(for: target)
    }

    private var childContainerGroups: [ContainerFocusViewModel.ChildContainerGroup] {
        guard case .space(let space) = target else { return [] }
        return viewModel.childContainerGroups(for: space)
    }

    private let layoutMetrics = LayoutMetrics.focusView

    init(target: ContainerTarget, viewModel: ContainerFocusViewModel, modelContext: ModelContext) {
        self.target = target
        self.viewModel = viewModel
        self.modelContext = modelContext
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                // Direct items - Unscheduled
                if !groupedContent.directItems.unscheduled.isEmpty {
                    Section(header: sectionHeader("Unscheduled")) {
                        ForEach(groupedContent.directItems.unscheduled) { item in
                            ItemRowView(item: item)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    }
                }

                // Direct items - Scheduled
                if !groupedContent.directItems.scheduled.isEmpty {
                    Section(header: sectionHeader("Scheduled")) {
                        ForEach(groupedContent.directItems.scheduled) { item in
                            ItemRowView(item: item)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    }
                }

                // Task Sections
                ForEach(groupedContent.sectionGroups) { sectionGroup in
                    Section(header: sectionHeader(sectionGroup.title)) {
                        if sectionGroup.groupedItems.isEmpty {
                            NoContentRow()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                        } else {
                            ForEach(sectionGroup.groupedItems.unscheduled) { item in
                                ItemRowView(item: item)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            ForEach(sectionGroup.groupedItems.scheduled) { item in
                                ItemRowView(item: item)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                }

                // Child Containers (for Space view)
                ForEach(childContainerGroups) { childGroup in
                    Section(header: childContainerHeader(childGroup)) {
                        if viewModel.isChildContainerExpanded(childGroup.child) {
                            // Child container's direct items - Unscheduled
                            if !childGroup.directItems.unscheduled.isEmpty {
                                ForEach(childGroup.directItems.unscheduled) { item in
                                    ItemRowView(item: item)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                }
                            }

                            // Child container's direct items - Scheduled
                            if !childGroup.directItems.scheduled.isEmpty {
                                ForEach(childGroup.directItems.scheduled) { item in
                                    ItemRowView(item: item)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                }
                            }

                            // Child container's task sections
                            ForEach(childGroup.sectionGroups) { sectionGroup in
                                Section(header: sectionHeader(sectionGroup.title)) {
                                    if sectionGroup.groupedItems.isEmpty {
                                        NoContentRow()
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 4)
                                    } else {
                                        ForEach(sectionGroup.groupedItems.unscheduled) { item in
                                            ItemRowView(item: item)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                        }
                                        ForEach(sectionGroup.groupedItems.scheduled) { item in
                                            ItemRowView(item: item)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 80)
        }
        .onPreferenceChange(SectionPositionPreferenceKey.self) { positions in
            updateActiveNestedSections(from: positions)
        }
    }

    // MARK: - Section Headers

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        if let childGroup = findChildContainerGroup(title: title) {
            CollapsibleHeaderLabel(
                title: childGroup.title,
                subtitle: viewModel.activeNestedSections[childGroup.child.id],
                symbol: childGroup.symbol,
                color: childGroup.color,
                itemCount: childGroup.directItems.unscheduled.count + childGroup.directItems.scheduled.count + childGroup.sectionGroups.reduce(0) { $0 + $1.groupedItems.unscheduled.count + $1.groupedItems.scheduled.count },
                isExpanded: viewModel.isChildContainerExpanded(childGroup.child)
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.toggleChildContainer(childGroup.child)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.04))
            .cornerRadius(6)
        } else {
            SectionTitleLabel(title: title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.06))
                .cornerRadius(6)
        }
    }

    @ViewBuilder
    private func childContainerHeader(_ childGroup: ContainerFocusViewModel.ChildContainerGroup) -> some View {
        CollapsibleHeaderLabel(
            title: childGroup.title,
            subtitle: viewModel.activeNestedSections[childGroup.child.id],
            symbol: childGroup.symbol,
            color: childGroup.color,
            itemCount: childGroup.directItems.unscheduled.count + childGroup.directItems.scheduled.count + childGroup.sectionGroups.reduce(0) { $0 + $1.groupedItems.unscheduled.count + $1.groupedItems.scheduled.count },
            isExpanded: viewModel.isChildContainerExpanded(childGroup.child)
        ) {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.toggleChildContainer(childGroup.child)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(6)
    }

    // MARK: - Helper Methods

    private func findChildContainerGroup(title: String) -> ContainerFocusViewModel.ChildContainerGroup? {
        return childContainerGroups.first { $0.title == title }
    }

    private func updateActiveNestedSections(from positions: [SectionPositionInfo]) {
        guard case .space = target else { return }

        var newActiveSections: [ContainerChild.ID: String] = [:]
        let positionsByContainer = Dictionary(grouping: positions) { $0.childContainerID }

        for (childContainerID, containerPositions) in positionsByContainer {
            guard viewModel.expandedChildContainers.contains(childContainerID) else { continue }

            if let topmostSection = containerPositions.min(by: { $0.yPosition < $1.yPosition }) {
                newActiveSections[childContainerID] = topmostSection.title
            }
        }

        if newActiveSections != viewModel.activeNestedSections {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.activeNestedSections = newActiveSections
            }
        }
    }
}

// MARK: - Helper Views

struct SectionTitleLabel: View {
    let title: String
    var titleColor: Color = .secondary

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(titleColor)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

struct CollapsibleHeaderLabel: View {
    let title: String
    let subtitle: String?
    let symbol: String
    let color: Color
    var itemCount: Int = 0
    let isExpanded: Bool
    let onToggle: () -> Void

    private var isEmpty: Bool { itemCount == 0 }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 0) {
                if let subtitle = subtitle {
                    HStack(spacing: 4) {
                        Text(title)
                            .fontWeight(.semibold)
                            .foregroundStyle(color)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text("›")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Text(subtitle)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .opacity(isEmpty ? 0.5 : 1.0)
                } else {
                    Text(title)
                        .fontWeight(.semibold)
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .opacity(isEmpty ? 0.5 : 1.0)
                }
            }

            Spacer()

            if !isEmpty {
                Text("\(itemCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.down")
                .font(.caption)
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isExpanded ? 0 : -90))
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}

struct NoContentRow: View {
    var body: some View {
        Text("No content")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .italic()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .padding(.horizontal, 12)
            .background(Color.secondary.opacity(0.03))
            .cornerRadius(6)
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    EmptyView()
        .modelContainer(for: [Space.self, Project.self, List.self, Item.self, TaskSection.self], inMemory: true)
}