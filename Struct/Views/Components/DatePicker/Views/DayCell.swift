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
    let isDisabled: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            guard !isDisabled else { return }
            onTap()
        }) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(isDisabled ? Color.gray : Color.accentColor)
                        .frame(width: 36, height: 36)
                } else if isToday {
                    Circle()
                        .stroke(isDisabled ? Color.gray.opacity(0.5) : Color.accentColor, lineWidth: 2)
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
        .opacity(isOtherMonth ? 0.3 : (isDisabled ? 0.3 : 1.0))
    }
    
    private var textColor: Color {
        if isDisabled {
            return .gray
        } else if isSelected {
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