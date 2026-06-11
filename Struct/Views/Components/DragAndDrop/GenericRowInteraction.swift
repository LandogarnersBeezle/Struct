//
//  GenericRowInteraction.swift
//  Struct
//
//  Created by Otto Kiefer on 10.06.2026.
//

import SwiftUI
import UIKit

// MARK: - Generic Row Interaction Modifier

extension View {
    /// Generic gesture pipeline for draggable, swipeable rows.
    ///
    /// Installs UIKit recognisers (tap, optional horizontal pan, long press)
    /// wired through a shared `UIGestureRecognizerDelegate` so the enclosing
    /// `UIScrollView`'s pan is never blocked.
    ///
    /// - Parameter supportsSwipe: When `true` (sidebar rows), a horizontal pan
    ///   recogniser is installed for swipe-to-reveal actions. When `false`
    ///   (task rows), only tap and long-press-for-drag are installed,
    ///   eliminating gesture competition during drag initiation.
    ///
    /// Drag locations are reported in **window** coordinates; convert with
    /// the drag state's `toViewport` method to match the viewport coordinate space.
    ///
    /// This modifier is reusable across different views (sidebar, focus view, etc.)
    func draggableRowInteraction(
        supportsSwipe: Bool = true,
        isHighlighted: Bool = false,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        onTap: @escaping () -> Void = {},
        onSwipeTriggered: @escaping () -> Void = {},
        onDragBegan: @escaping (CGPoint) -> Void = { _ in },
        onDragChanged: @escaping (CGPoint) -> Void = { _ in },
        onDragEnded: @escaping () -> Void = {}
    ) -> some View {
        modifier(DraggableRowInteractionModifier(
            supportsSwipe:       supportsSwipe,
            isHighlighted:       isHighlighted,
            accessibilityLabel:  accessibilityLabel,
            accessibilityHint:   accessibilityHint,
            onTap:               onTap,
            onSwipeTriggered:    onSwipeTriggered,
            onDragBegan:         onDragBegan,
            onDragChanged:       onDragChanged,
            onDragEnded:         onDragEnded
        ))
    }

    /// Backward-compatible alias for existing code.
    @available(*, deprecated, renamed: "draggableRowInteraction")
    func sidebarRowInteraction(
        isHighlighted: Bool = false,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        onTap: @escaping () -> Void = {},
        onSwipeTriggered: @escaping () -> Void = {},
        onDragBegan: @escaping (CGPoint) -> Void = { _ in },
        onDragChanged: @escaping (CGPoint) -> Void = { _ in },
        onDragEnded: @escaping () -> Void = {}
    ) -> some View {
        draggableRowInteraction(
            isHighlighted: isHighlighted,
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: accessibilityHint,
            onTap: onTap,
            onSwipeTriggered: onSwipeTriggered,
            onDragBegan: onDragBegan,
            onDragChanged: onDragChanged,
            onDragEnded: onDragEnded
        )
    }
}

// MARK: - Draggable Row Interaction Modifier

/// Owns the per-row visual state (press highlight, swipe-offset rubber-band,
/// selection background) and forwards UIKit gesture callbacks to the caller.
struct DraggableRowInteractionModifier: ViewModifier {

    let supportsSwipe:       Bool
    let isHighlighted:       Bool
    let accessibilityLabel:  String?
    let accessibilityHint:   String?
    let onTap:               () -> Void
    let onSwipeTriggered:    () -> Void
    let onDragBegan:         (CGPoint) -> Void
    let onDragChanged:       (CGPoint) -> Void
    let onDragEnded:         () -> Void

    @State private var offset:    CGFloat = 0
    @State private var isPressed: Bool    = false

    func body(content: Content) -> some View {
        let pressBackground = RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.primary.opacity(isPressed ? 0.08 : 0))
        let highlightBackground = RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.accentColor.opacity(isHighlighted ? 0.10 : 0))
            .animation(.easeOut(duration: 0.2), value: isHighlighted)

        return content
            .background(highlightBackground)
            .background(pressBackground)
            .scaleEffect(isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: isPressed)
            .offset(x: offset)
            .overlay {
                DraggableGestureOverlay(
                    supportsSwipe:    supportsSwipe,
                    isPressed:        $isPressed,
                    onTap:            onTap,
                    onSwipeChanged:   handleSwipeChanged,
                    onSwipeEnded:     { _ in handleSwipeEnded() },
                    onDragBegan:      onDragBegan,
                    onDragChanged:    onDragChanged,
                    onDragEnded:      onDragEnded,
                    accessibilityLabel: accessibilityLabel,
                    accessibilityHint:  accessibilityHint
                )
            }
            // VoiceOver hint for available gestures
            .accessibilityHint(accessibilityHint ?? NSLocalizedString(
                "Tap to open. Swipe left for options. Long press to reorder.",
                comment: "Default accessibility hint for rows"
            ))
    }

    // MARK: - Swipe rubber-band

    private func handleSwipeChanged(_ tx: CGFloat, _ ty: CGFloat) {
        guard tx < 0 else { return }
        // Rubber-band: ~35 % of finger travel, capped at 24 pt.
        offset = max(-24, tx * 0.35)
    }

    private func handleSwipeEnded() {
        guard offset < -12 else {
            withAnimation(.spring(duration: 0.25, bounce: 0)) { offset = 0 }
            return
        }
        // Snap to max excursion, then spring back with a small bounce.
        withAnimation(.spring(duration: 0.12, bounce: 0)) { offset = -20 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(duration: 0.35, bounce: 0.25)) { offset = 0 }
        }
        onSwipeTriggered()
    }
}

// MARK: - Draggable Gesture Overlay

/// Thin SwiftUI shell over a `GestureHostView`.  Lives in `.overlay` of the
/// row so it captures touches on the row's full bounds.
struct DraggableGestureOverlay: UIViewRepresentable {

    var supportsSwipe:     Bool = true
    @Binding var isPressed: Bool
    var onTap:             () -> Void
    var onSwipeChanged:    (CGFloat, CGFloat) -> Void
    var onSwipeEnded:      (CGFloat) -> Void
    var onDragBegan:       (CGPoint) -> Void
    var onDragChanged:     (CGPoint) -> Void
    var onDragEnded:       () -> Void

    /// Accessibility label for the row
    var accessibilityLabel: String?

    /// Accessibility hint describing available gestures
    var accessibilityHint: String?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> DraggableGestureHostView {
        let v = DraggableGestureHostView()
        v.coordinator = context.coordinator
        v.supportsSwipe = supportsSwipe
        v.install()
        return v
    }

    func updateUIView(_ view: DraggableGestureHostView, context: Context) {
        context.coordinator.parent = self
        view.rowAccessibilityLabel = accessibilityLabel
        view.rowAccessibilityHint = accessibilityHint
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: DraggableGestureOverlay
        init(_ parent: DraggableGestureOverlay) { self.parent = parent }

        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            // The long press can coexist with the scroll view's pan gesture
            // during its .possible phase (before firing), so the scroll view
            // isn't frozen. Once the long press fires, .scrollDisabled on
            // the ScrollView prevents unwanted scrolling during drag.
            if g is UILongPressGestureRecognizer, other is UIPanGestureRecognizer {
                return true
            }
            return true
        }

        @objc func handleTap(_ g: UITapGestureRecognizer) {
            if g.state == .ended { parent.onTap() }
        }

        @objc func handleSwipe(_ g: HorizontalPanGestureRecognizer) {
            let t = g.translation(in: g.view)
            switch g.state {
            case .changed:                       parent.onSwipeChanged(t.x, t.y)
            case .ended, .cancelled, .failed:    parent.onSwipeEnded(t.x)
            default: break
            }
        }

        @objc func handleLongPress(_ g: UILongPressGestureRecognizer) {
            let loc = g.location(in: nil)
            switch g.state {
            case .began:                         parent.onDragBegan(loc)
            case .changed:                       parent.onDragChanged(loc)
            case .ended, .cancelled, .failed:    parent.onDragEnded()
            default: break
            }
        }
    }
}

// MARK: - Draggable Gesture Host View

/// Transparent UIView that hosts the three gesture recognisers.
final class DraggableGestureHostView: UIView {

    weak var coordinator: DraggableGestureOverlay.Coordinator?
    var supportsSwipe: Bool = true

    var rowAccessibilityLabel: String? {
        didSet { accessibilityLabel = rowAccessibilityLabel }
    }

    var rowAccessibilityHint: String? {
        didSet { accessibilityHint = rowAccessibilityHint }
    }

    override var isAccessibilityElement: Bool {
        get { true }
        set { super.isAccessibilityElement = newValue }
    }

    override var accessibilityTraits: UIAccessibilityTraits {
        get { .button }
        set { super.accessibilityTraits = newValue }
    }

    override var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
        get {
            [
                UIAccessibilityCustomAction(
                    name: NSLocalizedString("Swipe left for options", comment: "Accessibility action"),
                    target: self,
                    selector: #selector(performSwipeAction)
                ),
                UIAccessibilityCustomAction(
                    name: NSLocalizedString("Long press to reorder", comment: "Accessibility action"),
                    target: self,
                    selector: #selector(performDragAction)
                )
            ]
        }
        set { super.accessibilityCustomActions = newValue }
    }

    @objc private func performSwipeAction() -> Bool {
        guard let parent = coordinator?.parent else { return false }
        parent.onSwipeChanged(-25, 0)
        parent.onSwipeEnded(-25)
        return true
    }

    @objc private func performDragAction() -> Bool {
        UIAccessibility.post(notification: .announcement,
                           argument: NSLocalizedString("Use two-finger drag to reorder", comment: "Accessibility instruction"))
        return true
    }

    func install() {
        guard let c = coordinator else { return }
        backgroundColor = .clear
        isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer(
            target: c, action: #selector(DraggableGestureOverlay.Coordinator.handleTap(_:)))
        configure(tap, delegate: c)

        let lp = UILongPressGestureRecognizer(
            target: c, action: #selector(DraggableGestureOverlay.Coordinator.handleLongPress(_:)))
        lp.minimumPressDuration = 0.3
        lp.allowableMovement = 100
        configure(lp, delegate: c)

        addGestureRecognizer(tap)
        addGestureRecognizer(lp)
        tap.require(toFail: lp)

        // Only install the horizontal pan (swipe) when this row supports it.
        if supportsSwipe {
            let pan = HorizontalPanGestureRecognizer(
                target: c, action: #selector(DraggableGestureOverlay.Coordinator.handleSwipe(_:)))
            pan.longPressGuard = lp
            configure(pan, delegate: c)
            addGestureRecognizer(pan)
            tap.require(toFail: pan)
        }
    }

    private func configure(_ g: UIGestureRecognizer, delegate: UIGestureRecognizerDelegate) {
        g.delegate = delegate
        g.cancelsTouchesInView = false
        g.delaysTouchesBegan = false
        g.delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        coordinator?.parent.isPressed = true
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        coordinator?.parent.isPressed = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        coordinator?.parent.isPressed = false
    }
}

// MARK: - Horizontal Pan Gesture Recognizer

/// `UIPanGestureRecognizer` that begins only on predominantly horizontal,
/// leftward motion.  Vertical or rightward motion fails the recogniser
/// immediately so the enclosing `UIScrollView`'s pan can take over.
final class HorizontalPanGestureRecognizer: UIPanGestureRecognizer {

    weak var longPressGuard: UILongPressGestureRecognizer?

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard state == .possible else { return }

        // If the long press is active or has already begun, fail the swipe
        if let lp = longPressGuard, lp.state == .began || lp.state == .changed || lp.state == .possible {
            state = .failed
            return
        }

        let t = translation(in: view)
        let absX = abs(t.x), absY = abs(t.y)
        guard absX > 4 || absY > 4 else { return }
        if absX <= absY || t.x >= 0 { state = .failed }
    }
}