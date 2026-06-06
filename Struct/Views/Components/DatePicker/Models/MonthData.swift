//
//  MonthData.swift
//  Struct
//
//  Created by Otto Kiefer on 06.05.2026.
//

import Foundation

struct MonthData: Identifiable {
    let id = UUID()
    let date: Date
    
    var displayName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: date)
    }
    
    var shortDisplayName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMM yyyy")
        return formatter.string(from: date)
    }
    
    var weeksInMonth: [[Date?]] {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .month, for: date)!
        let firstDay = interval.start
        
        // Get the first weekday of the month
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let calendarFirstWeekday = calendar.firstWeekday
        let offset = (firstWeekday - calendarFirstWeekday + 7) % 7
        
        // Get number of days in month
        let daysInMonth = calendar.range(of: .day, in: .month, for: date)!.count
        
        var weeks: [[Date?]] = []
        var currentWeek: [Date?] = Array(repeating: nil, count: offset)
        
        for day in 1...daysInMonth {
            if let dayDate = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                currentWeek.append(dayDate)
                
                if currentWeek.count == 7 {
                    weeks.append(currentWeek)
                    currentWeek = []
                }
            }
        }
        
        // Pad the last week with nils
        while !currentWeek.isEmpty && currentWeek.count < 7 {
            currentWeek.append(nil)
        }
        if !currentWeek.isEmpty {
            weeks.append(currentWeek)
        }
        
        return weeks
    }
}