//
//  CalendarExtensions.swift
//  Struct
//
//  Created by Otto Kiefer on 06.05.2026.
//

import Foundation

extension Calendar {
    /// Returns the start of the month for the given date
    func dp_startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
    
    /// Checks if two dates are in the same month
    func dp_isDate(_ date1: Date, inSameMonthAs date2: Date) -> Bool {
        let components1 = dateComponents([.year, .month], from: date1)
        let components2 = dateComponents([.year, .month], from: date2)
        return components1.year == components2.year && components1.month == components2.month
    }
}