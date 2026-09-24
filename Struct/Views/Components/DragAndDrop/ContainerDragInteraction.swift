//
//  ContainerDragInteraction.swift
//  Struct
//
//  Created by Otto Kiefer on 28.06.2026.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Drag Payload Router

/// Routes drag payloads synchronously from source to target within the app.
///
/// The drag source (`onDrag`) stores its payload here. The `UIDropInteraction`
/// target reads it synchronously — no `NSItemProvider` callback latency.
enum DragPayloadRouter {
    static var spaceDrag: SpaceDragData? = nil
    static var containerDrag: ContainerDragData? = nil
    static func clear() { spaceDrag = nil; containerDrag = nil }
}

// MARK: - Drop Interaction ViewModifier

extension View {

    /// Attaches a UIKit `UIDropInteraction` to this view for synchronous in-app drops.
    ///
    /// The interaction only activates during drag sessions, so non-drag touches
    /// pass through freely. Uses `DragPayloadRouter` for zero-latency payload
    /// delivery.
    ///
    /// - Parameters:
    ///   - acceptedTypes: UTIs this drop zone accepts.
    ///   - insertionLineY: Binding for the green insertion line overlay.
    ///   - onUpdate: Called with the drop location on `sessionDidUpdate`.
    ///   - performDrop: Called with the decoded payload on drop.
    func onInAppDrop<Payload: Codable>(
        of acceptedTypes: [UTType],
        insertionLineY: Binding<CGFloat?>,
        onUpdate: @escaping (CGPoint) -> Void = { _ in },
        performDrop: @escaping (Payload) -> Bool
    ) -> some View {
        modifier(InAppDropModifier<Payload>(
            acceptedTypes: acceptedTypes,
            insertionLineY: insertionLineY,
            onUpdate: onUpdate,
            performDrop: performDrop
        ))
    }
}

// MARK: - InAppDropModifier

private struct InAppDropModifier<Payload: Codable>: ViewModifier {

    let acceptedTypes: [UTType]
    let insertionLineY: Binding<CGFloat?>
    let onUpdate: (CGPoint) -> Void
    let performDrop: (Payload) -> Bool

    func body(content: Content) -> some View {
        content.overlay(alignment: .topLeading) {
            DropTargetView(
                acceptedTypes: acceptedTypes,
                insertionLineY: insertionLineY,
                onUpdate: onUpdate,
                performDrop: performDrop
            )
            .allowsHitTesting(false) // never blocks touches — only listens to drag sessions
        }
    }
}

// MARK: - DropTargetView (UIViewRepresentable)

private struct DropTargetView<Payload: Codable>: UIViewRepresentable {

    let acceptedTypes: [UTType]
    let insertionLineY: Binding<CGFloat?>
    let onUpdate: (CGPoint) -> Void
    let performDrop: (Payload) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
        let v = PassThroughView()
        let interaction = UIDropInteraction(delegate: context.coordinator)
        v.addInteraction(interaction)
        return v
    }

    func updateUIView(_: UIView, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, UIDropInteractionDelegate {

        var parent: DropTargetView

        init(parent: DropTargetView) { self.parent = parent }

        func dropInteraction(_: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
            session.hasItemsConforming(toTypeIdentifiers: parent.acceptedTypes.map(\.identifier))
        }

        func dropInteraction(_ interaction: UIDropInteraction,
                             sessionDidEnter session: UIDropSession) {
            guard let v = interaction.view else { return }
            parent.onUpdate(session.location(in: v))
        }

        func dropInteraction(_ interaction: UIDropInteraction,
                             sessionDidUpdate session: UIDropSession) -> UIDropProposal {
            guard let v = interaction.view else { return UIDropProposal(operation: .forbidden) }
            parent.onUpdate(session.location(in: v))
            return UIDropProposal(operation: .move)
        }

        func dropInteraction(_: UIDropInteraction, sessionDidExit _: UIDropSession) {
            parent.insertionLineY.wrappedValue = nil
        }

        func dropInteraction(_: UIDropInteraction, performDrop _: UIDropSession) {
            parent.insertionLineY.wrappedValue = nil

            // Synchronous in-app delivery via DragPayloadRouter
            if let p = DragPayloadRouter.spaceDrag as? Payload {
                _ = parent.performDrop(p)
                DragPayloadRouter.clear()
                return
            }
            if let p = DragPayloadRouter.containerDrag as? Payload {
                _ = parent.performDrop(p)
                DragPayloadRouter.clear()
                return
            }
        }
    }
}

// MARK: - PassThroughView

/// UIView that never claims touches — passes everything through to siblings.
/// `UIDropInteraction` still fires because drag sessions are tracked by the
/// system independently of hit testing.
private final class PassThroughView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = true
    }
    required init?(coder: NSCoder) { nil }
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
}