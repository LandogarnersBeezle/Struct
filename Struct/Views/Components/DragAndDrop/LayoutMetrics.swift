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

    // MARK: - Auto-Scroll Metrics

    /// Distance from edge to trigger auto-scroll
    var autoScrollThreshold: CGFloat

    /// Maximum auto-scroll speed in points per second
    var autoScrollMaxSpeed: CGFloat

    // MARK: - Presets

    /// Metrics for the container focus view (slightly different spacing)
    static let focusView = LayoutMetrics(
        rowHeight: 48,
        headerHeight: 40,
        autoScrollThreshold: 60,
        autoScrollMaxSpeed: 300
    )

}
