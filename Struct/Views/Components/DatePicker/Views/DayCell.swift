//
//  DayCell.swift
//  Struct
//
//  Created by Otto Kiefer on 06.05.2026.
//

import SwiftUI

struct DayCell: View {
    let day: Int
    let isSelected: Bool
    let isToday: Bool
    let isOtherMonth: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 36, height: 36)
                } else if isToday {
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 2)
                        .frame(width: 36, height: 36)
                }
                
                Text("\(day)")
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(textColor)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isOtherMonth ? 0.3 : 1.0)
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return Color.accentColor
        } else if isOtherMonth {
            return .secondary
        } else {
            return .primary
        }
    }
}