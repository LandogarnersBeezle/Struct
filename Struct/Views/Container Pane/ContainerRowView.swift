//
//  ContainerRowView.swift
//  Struct
//
//  Created by Otto Kiefer on 05.05.2026.
//

import SwiftUI

// MARK: - ContainerRowButtonStyle

/// A button style that gives every container row a subtle pressed-state
/// indication — a faint background flash and a barely-perceptible scale-down —
/// just before the navigation transition fires.
struct ContainerRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.08 : 0))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - ContainerRowView

struct ContainerRowView: View {

    let symbol: String
    let title: String
    let openTaskCount: Int
    var color: Color = .primary

    var body: some View {
        HStack {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(title)
                .lineLimit(1)
            Spacer()
            if openTaskCount > 0 {
                Text("\(openTaskCount)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    // .padding(2)
                    // .background(content: {
                    //     RoundedRectangle(cornerRadius: 4)
                    //         .fill(Color.secondary.opacity(0.1))
                    // })
                    .padding(.trailing, 5)
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .fontWeight(.semibold)
    }
}

#Preview {
    VStack(spacing: 0) {
        ContainerRowView(symbol: "tray",        title: "Inbox",             openTaskCount: 3)
        ContainerRowView(symbol: "list.bullet", title: "Groceries",         openTaskCount: 4)
        ContainerRowView(symbol: "list.bullet", title: "Books to Read",     openTaskCount: 0)
        ContainerRowView(symbol: "folder",      title: "Apartment Move",    openTaskCount: 3)
        ContainerRowView(symbol: "folder",      title: "Marathon Training",  openTaskCount: 2)
    }
    .padding(.horizontal)
}
