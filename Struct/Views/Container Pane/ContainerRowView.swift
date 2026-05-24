//
//  ContainerRowView.swift
//  Struct
//
//  Created by Otto Kiefer on 05.05.2026.
//

import SwiftUI

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
            }
        }
        .padding(.vertical, 3)
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
