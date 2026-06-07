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
    
    /// Check if a date should be disabled based on current type and doDate
    private func isDateDisabled(_ date: Date) -> Bool {
        // Only disable dates when setting due date and doDate is set
        guard currentDateType == .dueDate, let doDate = doDate else {
            return false
        }
        // Disable dates before doDate (compare by day, ignoring time)
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let doDateComponents = calendar.dateComponents([.year, .month, .day], from: doDate)
        
        if dateComponents.year != doDateComponents.year {
            return (dateComponents.year ?? 0) < (doDateComponents.year ?? 0)
        }
        if dateComponents.month != doDateComponents.month {
            return (dateComponents.month ?? 0) < (doDateComponents.month ?? 0)
        }
        return (dateComponents.day ?? 0) < (doDateComponents.day ?? 0)
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