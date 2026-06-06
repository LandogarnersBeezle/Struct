//
//  DatePickerViewModel.swift
//  Struct
//
//  Created by Otto Kiefer on 06.05.2026.
//

import SwiftUI
import Combine

class DatePickerViewModel: ObservableObject {
    var months: [MonthData] = [] {
        didSet {
            objectWillChange.send()
        }
    }
    
    var visibleMonthIndex: Int = 0 {
        didSet {
            objectWillChange.send()
        }
    }
    
    var isLoadingPrevious = false {
        didSet {
            objectWillChange.send()
        }
    }
    
    var isLoadingNext = false {
        didSet {
            objectWillChange.send()
        }
    }
    
    let objectWillChange = ObservableObjectPublisher()
    
    private let calendar = Calendar.current
    private let bufferSize = 10 // Number of months to load on each side
    private let maxYearRange = 100 // Years before/after current year
    
    init() {
        loadInitialMonths()
    }
    
    private func loadInitialMonths() {
        let currentDate = Date()
        let currentMonth = calendar.dp_startOfMonth(for: currentDate)
        
        // Load months around current date
        var loadedMonths: [MonthData] = []
        
        // Load past months
        for i in (1...bufferSize).reversed() {
            if let month = calendar.date(byAdding: .month, value: -i, to: currentMonth) {
                loadedMonths.append(MonthData(date: month))
            }
        }
        
        // Load current and future months
        for i in 0..<bufferSize {
            if let month = calendar.date(byAdding: .month, value: i, to: currentMonth) {
                loadedMonths.append(MonthData(date: month))
            }
        }
        
        months = loadedMonths
        visibleMonthIndex = bufferSize // Current month index
    }
    
    func loadPreviousMonthsIfNeeded(currentIndex: Int) {
        guard currentIndex <= 2, !isLoadingPrevious else { return }
        
        // Check if we've hit the minimum year
        if let firstMonth = months.first?.date {
            let year = calendar.component(.year, from: firstMonth)
            let currentYear = calendar.component(.year, from: Date())
            if currentYear - year >= maxYearRange {
                return // Hit limit
            }
        }
        
        isLoadingPrevious = true
        
        // Generate previous months
        var newMonths: [MonthData] = []
        if let firstMonth = months.first?.date {
            for i in (1...bufferSize).reversed() {
                if let month = calendar.date(byAdding: .month, value: -i, to: firstMonth) {
                    newMonths.append(MonthData(date: month))
                }
            }
        }
        
        let offset = newMonths.count
        months.insert(contentsOf: newMonths, at: 0)
        visibleMonthIndex += offset
        isLoadingPrevious = false
    }
    
    func loadNextMonthsIfNeeded(currentIndex: Int) {
        guard currentIndex >= months.count - 3, !isLoadingNext else { return }
        
        // Check if we've hit the maximum year
        if let lastMonth = months.last?.date {
            let year = calendar.component(.year, from: lastMonth)
            let currentYear = calendar.component(.year, from: Date())
            if year - currentYear >= maxYearRange {
                return // Hit limit
            }
        }
        
        isLoadingNext = true
        
        // Generate next months
        var newMonths: [MonthData] = []
        if let lastMonth = months.last?.date {
            for i in 1...bufferSize {
                if let month = calendar.date(byAdding: .month, value: i, to: lastMonth) {
                    newMonths.append(MonthData(date: month))
                }
            }
        }
        
        months.append(contentsOf: newMonths)
        isLoadingNext = false
    }
    
    func scrollToDate(_ date: Date) {
        let targetMonth = calendar.dp_startOfMonth(for: date)
        
        // Find if month already exists in loaded months
        if let index = months.firstIndex(where: { calendar.dp_isDate($0.date, inSameMonthAs: targetMonth) }) {
            visibleMonthIndex = index
        } else {
            // Need to load months around target date
            var newMonths: [MonthData] = []
            
            // Load months around target
            for i in (1...bufferSize).reversed() {
                if let month = calendar.date(byAdding: .month, value: -i, to: targetMonth) {
                    newMonths.append(MonthData(date: month))
                }
            }
            
            newMonths.append(MonthData(date: targetMonth))
            
            for i in 1...bufferSize {
                if let month = calendar.date(byAdding: .month, value: i, to: targetMonth) {
                    newMonths.append(MonthData(date: month))
                }
            }
            
            months = newMonths
            visibleMonthIndex = bufferSize
        }
    }
    
    func navigateToPreviousMonth() {
        guard visibleMonthIndex > 0 else { return }
        visibleMonthIndex -= 1
        loadPreviousMonthsIfNeeded(currentIndex: visibleMonthIndex)
    }
    
    func navigateToNextMonth() {
        guard visibleMonthIndex < months.count - 1 else { return }
        visibleMonthIndex += 1
        loadNextMonthsIfNeeded(currentIndex: visibleMonthIndex)
    }
    
    func navigateToToday() {
        scrollToDate(Date())
    }
    
    var canNavigateBack: Bool {
        visibleMonthIndex > 0
    }
    
    var canNavigateForward: Bool {
        visibleMonthIndex < months.count - 1
    }
    
    var currentMonthName: String {
        guard visibleMonthIndex < months.count else { return "" }
        return months[visibleMonthIndex].displayName
    }
}