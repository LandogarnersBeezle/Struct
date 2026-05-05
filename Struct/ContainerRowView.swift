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
                .font(Font.body.bold())
            Text("\(String(describing: sortIndex))")
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    ContainerRowView(symbol: "list.bullet", title: "Demo List", sortIndex: 0)
}
