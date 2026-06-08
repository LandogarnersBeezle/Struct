//
//  MonthView.swift
//  Struct
//
//  Created by Otto Kiefer on 06.05.2026.
//

import SwiftUI

struct MonthView: View {
    let monthData: MonthData
    @Binding var selectedDate: Date
    let currentDateType: DateType
    let doDate: Date?
    let hasSelectedDate: Bool
    let onDateSelected: (Date) -> Void
    let isCurrentMonth: Bool
    
    private let today = Date()
    
    var body: some View {
        VStack(spacing: 0) {
            // Month header
            HStack {
                Text(monthData.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isCurrentMonth ? .accentColor : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                
                Spacer()
            }
            .background(Color(.systemBackground))
            
            // Week rows
            ForEach(0..<monthData.weeksInMonth.count, id: \.self) { weekIndex in
                WeekRow(
                    dates: monthData.weeksInMonth[weekIndex],
                    selectedDate: $selectedDate,
                    today: today,
                    monthData: monthData,
                    currentDateType: currentDateType,
                    doDate: doDate,
                    hasSelectedDate: hasSelectedDate,
                    onDateSelected: onDateSelected
                )
            }
        }
    }
}