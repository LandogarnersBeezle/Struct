//
//  InboxRow.swift
//  Struct
//
//  Created by Otto Kiefer on 10.06.2026.
//

import SwiftUI

// MARK: - Inbox Row

/// Dedicated inbox row component for the sidebar.
///
/// This component displays the inbox as a special row at the top of the
/// sidebar, showing the inbox title and count of open tasks. It uses
/// accessibility labels to communicate the state to VoiceOver users.
struct InboxRow: View {
    let inbox: List
    let onSelect: (ContainerTarget) -> Void

    private var openTaskCount: Int {
        inbox.items.filter { !$0.isCompleted }.count
    }

    private var accessibilityLabel: String {
        if openTaskCount > 0 {
            return String(format: NSLocalizedString("Inbox, %d open task%@", comment: "Inbox accessibility label"),
                         openTaskCount, openTaskCount == 1 ? "" : "s")
        } else {
            return NSLocalizedString("Inbox, no open tasks", comment: "Inbox accessibility label")
        }
    }

    private var accessibilityHint: String {
        NSLocalizedString("Tap to view inbox items", comment: "Inbox accessibility hint")
    }

    var body: some View {
        Button {
            onSelect(.list(inbox))
        } label: {
            ContainerRowView(
                symbol: "tray",
                title: inbox.title,
                openTaskCount: openTaskCount,
                color: List.containerColor
            )
        }
        .buttonStyle(ContainerRowButtonStyle())
        .padding(5)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
}