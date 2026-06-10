//
//  LayoutMetrics.swift
//  Struct
//
//  Created by Otto Kiefer on 10.06.2026.
//

import SwiftUI

// MARK: - Layout Metrics

/// Configurable layout constants for drag-and-drop views.
///
/// This struct provides consistent metrics across different views
/// (sidebar, focus view, etc.) and allows for easy adjustment of spacing.
struct LayoutMetrics {
    // MARK: - Row Metrics

    /// Height of a standard content row (list, project, task, etc.)
    var rowHeight: CGFloat

    /// Height of a section header (space header, group header, etc.)
    var headerHeight: CGFloat

    /// Spacing between rows within a section
    var rowSpacing: CGFloat

    /// Spacing after each section (before the next header)
    var sectionSpacing: CGFloat

    // MARK: - Card Metrics

    /// Corner radius for floating drag cards
    var cardCornerRadius: CGFloat

    /// Shadow radius for floating drag cards
    var cardShadowRadius: CGFloat

    /// Shadow opacity for floating drag cards
    var cardShadowOpacity: CGFloat

    /// Opacity of floating drag cards
    var cardOpacity: CGFloat

    // MARK: - Drop Gap Metrics

    /// Line width for drop gap dashed border
    var dropGapLineWidth: CGFloat

    /// Dash pattern for drop gap border
    var dropGapDashPattern: [CGFloat]

    /// Corner radius for drop gap
    var dropGapCornerRadius: CGFloat

    // MARK: - Auto-Scroll Metrics

    /// Distance from edge to trigger auto-scroll
    var autoScrollThreshold: CGFloat

    /// Maximum auto-scroll speed in points per second
    var autoScrollMaxSpeed: CGFloat

    // MARK: - Animation Metrics

    /// Duration of spring animations for drag operations
    var dragSpringDuration: CGFloat

    /// Bounce coefficient for drag springs
    var dragSpringBounce: CGFloat

    /// Duration of fade-out animation for floating cards
    var cardFadeOutDuration: CGFloat

    // MARK: - Presets

    /// Default metrics for the sidebar view
    static let sidebar = LayoutMetrics(
        rowHeight: 44,
        headerHeight: 44,
        rowSpacing: 0,
        sectionSpacing: 8,
        cardCornerRadius: 10,
        cardShadowRadius: 12,
        cardShadowOpacity: 0.18,
        cardOpacity: 0.5,
        dropGapLineWidth: 1.5,
        dropGapDashPattern: [6, 3],
        dropGapCornerRadius: 8,
        autoScrollThreshold: 60,
        autoScrollMaxSpeed: 300,
        dragSpringDuration: 0.22,
        dragSpringBounce: 0,
        cardFadeOutDuration: 0.18
    )

    /// Metrics for the container focus view (slightly different spacing)
    static let focusView = LayoutMetrics(
        rowHeight: 48,
        headerHeight: 40,
        rowSpacing: 0,
        sectionSpacing: 4,
        cardCornerRadius: 10,
        cardShadowRadius: 12,
        cardShadowOpacity: 0.18,
        cardOpacity: 0.5,
        dropGapLineWidth: 1.5,
        dropGapDashPattern: [6, 3],
        dropGapCornerRadius: 8,
        autoScrollThreshold: 60,
        autoScrollMaxSpeed: 300,
        dragSpringDuration: 0.22,
        dragSpringBounce: 0,
        cardFadeOutDuration: 0.18
    )

    // MARK: - Helper Methods

    /// Estimates the total height of content for auto-scroll calculations.
    /// - Parameters:
    ///   - rowCount: Number of content rows
    ///   - headerCount: Number of section headers
    ///   - hasInbox: Whether an inbox row is present
    ///   - inboxHeight: Height of the inbox row (if present)
    ///   - bottomPadding: Additional bottom padding
    /// - Returns: Estimated total height
    func estimateContentHeight(
        rowCount: Int,
        headerCount: Int,
        hasInbox: Bool = false,
        inboxHeight: CGFloat = 54,
        bottomPadding: CGFloat = 80
    ) -> CGFloat {
        var total: CGFloat = 0

        if hasInbox {
            total += inboxHeight
        }

        for _ in 0..<headerCount {
            total += headerHeight
            total += CGFloat(rowCount) * rowHeight
            total += sectionSpacing
        }

        total += bottomPadding

        return total
    }
}
