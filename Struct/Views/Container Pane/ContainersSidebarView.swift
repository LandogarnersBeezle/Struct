//
//  ContainersSidebarView.swift
//  Struct
//
//  Created by Otto Kiefer on 01.05.2026.
//

import SwiftUI
import SwiftData

// MARK: - ContainersSidebarView

/// Layout host for the leading sidebar pane.
///
/// Owns the shared `SidebarDragState` and injects it into the view hierarchy
/// via `.environment`.  Collects per-row frames through `RowFrameKey` and
/// routes them into `drag.rowFrames` so drop-target computation (which runs
/// entirely inside `SidebarDragState`) has up-to-date geometry.
///
/// The floating drag card and the dashed drop-zone gap together produce the
/// smooth "push-aside" animation: the gap is rendered by `SpaceSectionView`
/// in the normal layout flow (so other rows spring apart naturally), while
/// the card floats above everything in a `ZStack` overlay.
struct ContainersSidebarView: View {

    let inbox:  List?
    let spaces: [Space]

    /// Called whenever the user taps a container row or space header.
    let onSelect: (ContainerTarget) -> Void

    /// Drives the "create container" sheet; owned by the parent so the sheet
    /// survives sidebar hide/show transitions.
    @Binding var pendingCreate: CreateKind?

    // MARK: Drag state

    @State private var drag = SidebarDragState()

    // MARK: Body

    var body: some View {
        // Inbox row — sits above the drag-enabled scroll area
        if let inbox {
            Button { onSelect(.list(inbox)) } label: {
                ContainerRowView(symbol: "tray", title: inbox.title,
                                 openTaskCount: inbox.items.filter { !$0.isCompleted }.count,
                                 color: List.containerColor)
            }
            .buttonStyle(ContainerRowButtonStyle())
            .padding(5)
        }

        // ZStack: scroll content behind + floating drag card on top
        ZStack(alignment: .top) {
            scrollContent
            floatingCardOverlay
        }
        .environment(drag)
    }

    // MARK: - Scroll content

    private var scrollContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(spaces) { space in
                    Section {
                        SpaceSectionView(space: space, allSpaces: spaces, onSelect: onSelect)
                            .padding(.horizontal, 5)
                            .padding(.bottom, 8)
                    } header: {
                        spaceHeader(for: space)
                    }
                }
            }
        }
        // Name the coordinate space so DragGesture and GeometryReader in
        // child rows all share the same reference frame.
        .coordinateSpace(.named("sidebar"))
        // Route preference-key frames into drag state
        .onPreferenceChange(RowFrameKey.self) { frames in
            drag.rowFrames = frames
        }
        .onPreferenceChange(SpaceHeaderFrameKey.self) { frames in
            drag.spaceHeaderFrames = frames
        }
        .safeAreaInset(edge: .bottom) { addMenu.padding() }
        .sheet(item: $pendingCreate) { CreateContainerView(kind: $0) }
    }

    // MARK: - Floating drag card

    @ViewBuilder
    private var floatingCardOverlay: some View {
        if drag.isDragging, let child = drag.dragging {
            GeometryReader { proxy in
                ContainerRowView(
                    symbol:        child.symbol,
                    title:         child.title,
                    openTaskCount: child.openTaskCount,
                    color:         child.containerColor
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.background)
                        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                        .opacity(0.5)
                )
                .scaleEffect(1)
                // Center horizontally in the sidebar; follow finger vertically
                .position(x: proxy.size.width / 2,
                          y: drag.location.y)
            }
            .allowsHitTesting(false)
            .transition(.opacity.combined(with: .scale(scale: 0.92)))
            .animation(.spring(duration: 0.2, bounce: 0.3), value: drag.isDragging)
            .zIndex(999)
        }
    }

    // MARK: - Space header

    private func spaceHeader(for space: Space) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            // Report the header's frame so empty spaces are valid drop targets.
            // The invisible GeometryReader sits behind the Divider/button content
            // and has no visual effect.
            Button { onSelect(.space(space)) } label: {
                HStack {
                    Image(systemName: space.symbolName)
                        .foregroundStyle(Space.containerColor)
                        .frame(width: 24)
                    Text(space.name)
                        .lineLimit(1)
                    Spacer()
                    let openCount = space.items.filter { !$0.isCompleted }.count
                    if openCount > 0 {
                        Text("\(openCount)")
                            .foregroundStyle(.secondary)
                            .padding(5)
                            .background {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.secondary.opacity(0.1))
                            }
                            .padding(.trailing, 5)
                    }
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 4)
                .padding(.bottom, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(ContainerRowButtonStyle())
        }
        .background {
            GeometryReader { geo in
                let spaceID = space.persistentModelID
                Color.clear.preference(
                    key: SpaceHeaderFrameKey.self,
                    value: [spaceID: geo.frame(in: .named("sidebar"))]
                )
            }
        }
        .background(.background)
    }

    // MARK: - Add menu

    private var addMenu: some View {
        Menu {
            Button("New Space",   systemImage: "square.grid.2x2") { pendingCreate = .space }
            Button("New List",    systemImage: "list.bullet")     { pendingCreate = .list }
            Button("New Project", systemImage: "folder")          { pendingCreate = .project }
        } label: {
            Image(systemName: "plus")
                .frame(width: 56, height: 56)
                .background(.tint, in: Circle())
                .foregroundStyle(.white)
                .shadow(radius: 4, y: 2)
        }
    }
}
