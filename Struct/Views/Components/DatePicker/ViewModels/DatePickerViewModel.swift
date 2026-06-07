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
    private let maxFutureYears = 5 // Allow scrolling 5 years into the future
    
    init() {
        loadInitialMonths()
    }
    
    private func loadInitialMonths() {
        let currentDate = Date()
        let currentMonth = calendar.dp_startOfMonth(for: currentDate)
        
        // Load current and future months only (no past months)
        var loadedMonths: [MonthData] = []
        
        // Calculate the maximum month (5 years from now)
        let maxFutureMonth = calendar.date(byAdding: .year, value: maxFutureYears, to: currentMonth)!
        
        // Load all months from current to 5 years in the future (60 months)
        var monthCounter = 0
        while monthCounter < maxFutureYears * 12 + 1 { // +1 to include the last month
            if let month = calendar.date(byAdding: .month, value: monthCounter, to: currentMonth),
                   calendar.compare(month, to: maxFutureMonth, toGranularity: .month) != .orderedDescending {
                loadedMonths.append(MonthData(date: month))
            }
            monthCounter += 1
        }
        
        months = loadedMonths
        visibleMonthIndex = 0 // Current month is the first month
    }
    
    func loadPreviousMonthsIfNeeded(currentIndex: Int) {
        // No longer needed - we don't show past months
        // The first month is always the current month
    }
    
    func loadNextMonthsIfNeeded(currentIndex: Int) {
        // All months are pre-loaded for 5 years, no need to load more
        // The limit is already enforced in loadInitialMonths
    }
    
    func scrollToDate(_ date: Date) {
        let targetMonth = calendar.dp_startOfMonth(for: date)
        
        // Find if month already exists in loaded months
        if let index = months.firstIndex(where: { calendar.dp_isDate($0.date, inSameMonthAs: targetMonth) }) {
            visibleMonthIndex = index
        }
        // If month not found, it's outside our range - do nothing
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