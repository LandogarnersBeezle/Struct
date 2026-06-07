//
//  WeekRow.swift
//  Struct
//
//  Created by Otto Kiefer on 06.05.2026.
//

import SwiftUI

struct WeekRow: View {
    let dates: [Date?]
    @Binding var selectedDate: Date
    let today: Date
    let monthData: MonthData
    let currentDateType: DateType
    let doDate: Date?
    let onDateSelected: (Date) -> Void
    
    private let calendar = Calendar.current
    
    /// Check if a date should be disabled
    private func isDateDisabled(_ date: Date) -> Bool {
        // Get start of day for the date
        let startOfDate = calendar.startOfDay(for: date)
        let startOfToday = calendar.startOfDay(for: today)
        
        // Always disable dates before today
        if startOfDate < startOfToday {
            return true
        }
        
        // When setting due date, also disable dates before doDate
        if currentDateType == .dueDate, let doDate = doDate {
            let startOfDoDate = calendar.startOfDay(for: doDate)
            if startOfDate < startOfDoDate {
                return true
            }
        }
        
        return false
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { dayIndex in
                let dayData = dates[dayIndex]
                
                if let date = dayData {
                    let day = calendar.component(.day, from: date)
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    let isTodayDate = calendar.isDate(date, inSameDayAs: today)
                    let isOtherMonth = !calendar.dp_isDate(date, inSameMonthAs: monthData.date)
                    let isDisabled = isDateDisabled(date)
                    
                    DayCell(
                        day: day,
                        isSelected: isSelected,
                        isToday: isTodayDate,
                        isOtherMonth: isOtherMonth,
                        isDisabled: isDisabled,
                        onTap: {
                            onDateSelected(date)
                        }
                    )
                } else {
                    // Empty placeholder
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}