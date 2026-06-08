//
//  DateFormatter+Struct.swift
//  Struct
//
//  Created by Otto Kiefer on 06.05.2026.
//

import Foundation

extension DateFormatter {
    
    /// Formats a date according to the specified rules:
    /// - Today: returns "Today"
    /// - Tomorrow: returns "Tomorrow"
    /// - Next 7 days: abbreviated weekday (Mon, Tue, Wed)
    /// - Other days in current year: date + abbreviated month (7 Jun)
    /// - Days in other years: full format with year (9 Oct 2027)
    static func formattedDate(from date: Date, calendar: Calendar = .current) -> String {
        let now = Date()
        
        // Check if date is within the next 7 days
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)
        if let startOfSevenDaysFromNow = calendar.date(byAdding: .day, value: 7, to: startOfToday),
           startOfDate >= startOfToday,
           startOfDate < startOfSevenDaysFromNow {
            // Special cases for today and tomorrow
            if startOfDate == startOfToday {
                return "Today"
            } else if calendar.isDateInTomorrow(date) {
                return "Tomorrow"
            }
            // Format as abbreviated weekday
            let formatter = DateFormatter()
            formatter.locale = .current
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        }
        
        // Check if date is in the current year
        let currentYear = calendar.component(.year, from: now)
        let dateYear = calendar.component(.year, from: date)
        
        if dateYear == currentYear {
            // Format as date + abbreviated month (e.g., "7 Jun")
            let formatter = DateFormatter()
            formatter.locale = .current
            formatter.dateFormat = "d MMM"
            return formatter.string(from: date)
        } else {
            // Format with year (e.g., "9 Oct 2027")
            let formatter = DateFormatter()
            formatter.locale = .current
            formatter.dateFormat = "d MMM yyyy"
            return formatter.string(from: date)
        }
    }
}