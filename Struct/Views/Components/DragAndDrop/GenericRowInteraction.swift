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
            // No scale-down on press — the row stays full size. Only a grey
            // background flash indicates the touch. On long press (>1s) the
            // floating drag system applies a scale-up (lift) effect.
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
        
        /// Tracks when scrolling last occurred for this coordinator's view
        private var lastScrollTime: TimeInterval = 0
        private let scrollCooldownDuration: TimeInterval = 0.5
        
        /// The time when the current press began (set by DraggableGestureHostView.touchesBegan).
        var pressStartTime: TimeInterval = 0
        
        /// A pending, cancellable navigation work item scheduled ~0.3s after press start.
        /// Created on touch-up (tap) and cancelled when the long press fires (drag).
        private var pendingNavigationWork: DispatchWorkItem?
        
        /// Whether the long press gesture has already fired (drag has begun).
        private var longPressDidFire: Bool = false
        
        /// Check if we should allow long press based on recent scroll activity
        private func shouldAllowLongPress(for view: UIView?) -> Bool {
            // Find the scroll view in the responder chain
            var responder = view?.next
            while let current = responder {
                if let scrollView = current as? UIScrollView,
                   scrollView.isDragging || scrollView.isDecelerating {
                    lastScrollTime = Date().timeIntervalSince1970
                    return false
                }
                responder = current.next
            }
            
            // Check cooldown period
            let timeSinceLastScroll = Date().timeIntervalSince1970 - lastScrollTime
            return timeSinceLastScroll >= scrollCooldownDuration
        }

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
        
        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldReceive touch: UITouch) -> Bool {
            // Allow long press to proceed — scroll detection is handled by
            // DraggableGestureHostView which cancels the long press if scrolling
            return true
        }

        @objc func handleTap(_ g: UITapGestureRecognizer) {
            guard g.state == .ended else { return }
            // The tap fires on touch-up. Schedule navigation with a ~0.3s delay
            // from the original press start time so the grey background is visible.
            let elapsed = CACurrentMediaTime() - pressStartTime
            let remainingDelay = max(0, 0.3 - elapsed)
            
            // Cancel any previous pending work (shouldn't happen, but be safe)
            pendingNavigationWork?.cancel()
            
            let work = DispatchWorkItem { [weak self] in
                self?.parent.onTap()
                // Reset isPressed after navigation fires
                self?.parent.isPressed = false
            }
            pendingNavigationWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + remainingDelay, execute: work)
        }

        @objc func handleSwipe(_ g: HorizontalPanGestureRecognizer) {
            let t = g.translation(in: g.view)
            switch g.state {
            case .changed:                       parent.onSwipeChanged(t.x, t.y)
            case .ended, .cancelled, .failed:
                // Cancel pending navigation and reset isPressed — swipe takes priority
                pendingNavigationWork?.cancel()
                pendingNavigationWork = nil
                parent.onSwipeEnded(t.x)
                parent.isPressed = false
            default: break
            }
        }

        @objc func handleLongPress(_ g: UILongPressGestureRecognizer) {
            let loc = g.location(in: nil)
            switch g.state {
            case .began:
                // Cancel any pending tap navigation — long press takes priority
                pendingNavigationWork?.cancel()
                pendingNavigationWork = nil
                longPressDidFire = true
                parent.onDragBegan(loc)
            case .changed:                       parent.onDragChanged(loc)
            case .ended, .cancelled, .failed:
                longPressDidFire = false
                parent.onDragEnded()
                // Reset isPressed state when drag ends
                parent.isPressed = false
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
    
    /// The scroll view's pan gesture, used to detect active scrolling
    private weak var scrollViewPanGesture: UIPanGestureRecognizer?
    
    /// Timestamp when scrolling last occurred (had significant velocity)
    private var lastScrollTime: TimeInterval = 0
    
    /// Duration after scrolling ends during which drag is disabled
    private let scrollCooldownDuration: TimeInterval = 0.5
    
    /// Reference to the long press gesture for cancellation during scroll
    private var longPressGesture: UILongPressGestureRecognizer?
    
    /// Timer to reset the scroll cooldown state
    private var scrollCooldownTimer: Timer?
    
    /// Flag to indicate if the current long press should be ignored due to scrolling
    private var shouldIgnoreLongPress: Bool = false

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
    
    /// Check if scrolling is currently active or recently occurred
    /// This prevents drag initiation during or immediately after scrolling
    var isScrollingActively: Bool {
        // Check if scroll view pan gesture is active
        if let pan = scrollViewPanGesture,
           pan.state == .changed || pan.state == .began {
            let velocity = pan.velocity(in: superview)
            // If there's significant velocity, we're actively scrolling
            if abs(velocity.y) > 50 || abs(velocity.x) > 50 {
                lastScrollTime = Date().timeIntervalSince1970
                return true
            }
        }
        
        // Check if we're still in the cooldown period after scrolling
        let timeSinceLastScroll = Date().timeIntervalSince1970 - lastScrollTime
        if timeSinceLastScroll < scrollCooldownDuration {
            return true
        }
        
        return false
    }
    
    /// Find and store the scroll view's pan gesture from the responder chain
    private func findScrollViewPanGesture() {
        var responder: UIResponder? = self
        while let current = responder {
            if let scrollView = current as? UIScrollView {
                scrollViewPanGesture = scrollView.panGestureRecognizer
                return
            }
            responder = current.next
        }
    }

    func install() {
        guard let c = coordinator else { return }
        backgroundColor = .clear
        isUserInteractionEnabled = true
        
        // Find the scroll view's pan gesture for scroll detection
        findScrollViewPanGesture()
        
        // Observe the scroll view's pan gesture to track scrolling state
        if let panGesture = scrollViewPanGesture {
            panGesture.addTarget(self, action: #selector(handleScrollViewPan(_:)))
        }

        let tap = UITapGestureRecognizer(
            target: c, action: #selector(DraggableGestureOverlay.Coordinator.handleTap(_:)))
        configure(tap, delegate: c)

        let lp = UILongPressGestureRecognizer(
            target: c, action: #selector(DraggableGestureOverlay.Coordinator.handleLongPress(_:)))
        lp.minimumPressDuration = 1.0  // Increased to 1 second to prevent accidental triggers
        lp.allowableMovement = 100
        configure(lp, delegate: c)
        longPressGesture = lp

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
    
    /// Called when the scroll view's pan gesture state changes
    @objc private func handleScrollViewPan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .changed:
            let velocity = gesture.velocity(in: superview)
            // If there's significant velocity, update the last scroll time
            if abs(velocity.y) > 50 || abs(velocity.x) > 50 {
                lastScrollTime = Date().timeIntervalSince1970
                // Cancel any pending long press to prevent accidental drag
                longPressGesture?.state = .cancelled
            }
        case .ended, .cancelled, .failed:
            // When scrolling ends, start a cooldown timer
            startScrollCooldownTimer()
        default:
            break
        }
    }
    
    /// Start a timer to reset the scroll cooldown state after a delay
    private func startScrollCooldownTimer() {
        scrollCooldownTimer?.invalidate()
        scrollCooldownTimer = Timer.scheduledTimer(withTimeInterval: scrollCooldownDuration, repeats: false) { [weak self] _ in
            self?.lastScrollTime = 0 // Reset to allow drag again
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
        // Record press start time so the Coordinator can calculate elapsed
        // time for the 0.3s delayed navigation on tap.
        coordinator?.pressStartTime = CACurrentMediaTime()
        coordinator?.parent.isPressed = true
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        // Do NOT reset isPressed here — the tap handler's DispatchWorkItem
        // (scheduled ~0.3s after press start) is responsible for resetting
        // it when navigation fires. This keeps the grey background visible
        // during the delay. touchesCancelled below handles cancellation.
        // Long press handler also resets isPressed when drag ends.
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        coordinator?.parent.isPressed = false
    }
    
    deinit {
        scrollCooldownTimer?.invalidate()
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

        // If the long press has already begun/fired, fail the swipe
        // The .possible state is the default resting state — do NOT fail the
        // swipe there, otherwise the gesture never gets a chance to start.
        if let lp = longPressGuard, lp.state == .began || lp.state == .changed {
            state = .failed
            return
        }

        let t = translation(in: view)
        let absX = abs(t.x), absY = abs(t.y)
        guard absX > 4 || absY > 4 else { return }
        if absX <= absY || t.x >= 0 { state = .failed }
    }
}