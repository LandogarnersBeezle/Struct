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
    let sortIndex: Int

    var body: some View {
        HStack {
            Image(systemName: symbol)
                .frame(width: 24)
            Text(title)
                .font(.appFont.weight(.regular))
                .lineLimit(1)
            Text("\(sortIndex)")
                .font(.appFont.weight(.light))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 3)
    }
}

#Preview {
    VStack(spacing: 0) {
        ContainerRowView(symbol: "tray",        title: "Inbox",           sortIndex: 0)
        ContainerRowView(symbol: "list.bullet", title: "Groceries",       sortIndex: 0)
        ContainerRowView(symbol: "list.bullet", title: "Books to Read",   sortIndex: 1)
        ContainerRowView(symbol: "folder",      title: "Apartment Move",  sortIndex: 0)
        ContainerRowView(symbol: "folder",      title: "Marathon Training", sortIndex: 1)
    }
    .padding(.horizontal)
}
