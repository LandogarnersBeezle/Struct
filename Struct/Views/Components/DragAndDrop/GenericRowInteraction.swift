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
    /// Gesture pipeline for swipeable rows (tap + swipe-left-to-reveal).
    ///
    /// Installs UIKit recognisers (tap, horizontal pan) wired through a shared
    /// `UIGestureRecognizerDelegate` so the enclosing `UIScrollView`'s pan is
    /// never blocked.
    func swipeableRowInteraction(
        isHighlighted: Bool = false,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        onTap: @escaping () -> Void = {},
        onSwipeTriggered: @escaping () -> Void = {}
    ) -> some View {
        modifier(SwipeableRowInteractionModifier(
            isHighlighted:       isHighlighted,
            accessibilityLabel:  accessibilityLabel,
            accessibilityHint:   accessibilityHint,
            onTap:               onTap,
            onSwipeTriggered:    onSwipeTriggered
        ))
    }
}

// MARK: - Swipeable Row Interaction Modifier

/// Owns the per-row visual state (press highlight, swipe-offset rubber-band,
/// selection background) and forwards UIKit gesture callbacks to the caller.
struct SwipeableRowInteractionModifier: ViewModifier {

    let isHighlighted:       Bool
    let accessibilityLabel:  String?
    let accessibilityHint:   String?
    let onTap:               () -> Void
    let onSwipeTriggered:    () -> Void

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
            .animation(.easeOut(duration: 0.12), value: isPressed)
            .offset(x: offset)
            .overlay {
                SwipeableGestureOverlay(
                    isPressed:        $isPressed,
                    onTap:            onTap,
                    onSwipeChanged:   handleSwipeChanged,
                    onSwipeEnded:     { _ in handleSwipeEnded() },
                    accessibilityLabel: accessibilityLabel,
                    accessibilityHint:  accessibilityHint
                )
            }
            // VoiceOver hint for available gestures
            .accessibilityHint(accessibilityHint ?? NSLocalizedString(
                "Tap to open. Swipe left for options.",
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

// MARK: - Swipeable Gesture Overlay

/// Thin SwiftUI shell over a `GestureHostView`.  Lives in `.overlay` of the
/// row so it captures touches on the row's full bounds.
struct SwipeableGestureOverlay: UIViewRepresentable {

    @Binding var isPressed: Bool
    var onTap:             () -> Void
    var onSwipeChanged:    (CGFloat, CGFloat) -> Void
    var onSwipeEnded:      (CGFloat) -> Void

    /// Accessibility label for the row
    var accessibilityLabel: String?

    /// Accessibility hint describing available gestures
    var accessibilityHint: String?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> SwipeableGestureHostView {
        let v = SwipeableGestureHostView()
        v.coordinator = context.coordinator
        v.install()
        return v
    }

    func updateUIView(_ view: SwipeableGestureHostView, context: Context) {
        context.coordinator.parent = self
        view.rowAccessibilityLabel = accessibilityLabel
        view.rowAccessibilityHint = accessibilityHint
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: SwipeableGestureOverlay
        init(_ parent: SwipeableGestureOverlay) { self.parent = parent }

        func gestureRecognizer(_ g: UIGestureRecognizer,
                                shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            return true
        }

        func gestureRecognizer(_ g: UIGestureRecognizer,
                                shouldReceive touch: UITouch) -> Bool {
            return true
        }

        @objc func handleTap(_ g: UITapGestureRecognizer) {
            guard g.state == .ended else { return }
            parent.onTap()
            parent.isPressed = false
        }

        @objc func handleSwipe(_ g: HorizontalPanGestureRecognizer) {
            let t = g.translation(in: g.view)
            switch g.state {
            case .changed:                       parent.onSwipeChanged(t.x, t.y)
            case .ended, .cancelled, .failed:
                parent.onSwipeEnded(t.x)
                parent.isPressed = false
            default: break
            }
        }
    }
}

// MARK: - Swipeable Gesture Host View

/// Transparent UIView that hosts the gesture recognisers.
final class SwipeableGestureHostView: UIView {

    weak var coordinator: SwipeableGestureOverlay.Coordinator?

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

    func install() {
        guard let c = coordinator else { return }
        backgroundColor = .clear
        isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer(
            target: c, action: #selector(SwipeableGestureOverlay.Coordinator.handleTap(_:)))
        configure(tap, delegate: c)

        addGestureRecognizer(tap)

        let pan = HorizontalPanGestureRecognizer(
            target: c, action: #selector(SwipeableGestureOverlay.Coordinator.handleSwipe(_:)))
        configure(pan, delegate: c)
        addGestureRecognizer(pan)
        tap.require(toFail: pan)
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
        // Always reset isPressed on finger lift. On a quick tap the tap gesture
        // fires and also resets it (harmless duplicate). On a long press where
        // the pan gesture never fails (so tap.require(toFail:) blocks the tap
        // recogniser), this is the only point where the highlight gets cleared.
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

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard state == .possible else { return }

        let t = translation(in: view)
        let absX = abs(t.x), absY = abs(t.y)
        guard absX > 4 || absY > 4 else { return }
        if absX <= absY || t.x >= 0 { state = .failed }
    }
}