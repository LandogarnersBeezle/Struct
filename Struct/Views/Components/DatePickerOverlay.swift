//
//  DatePickerOverlay.swift
//  Struct
//
//  Created by Otto Kiefer on 06.05.2026.
//

import SwiftUI
import Combine

/// A reusable date selector overlay with infinite scrolling through months.
/// Features vertical scrolling, month/year navigation, sticky headers, and lazy loading.
struct DatePickerOverlay: View {
    @Binding var isPresented: Bool
    @Binding var selectedDate: Date
    let onDateSelected: ((Date) -> Void)?
    let onClearDate: (() -> Void)?
    let hasExistingDate: Bool
    
    @StateObject private var viewModel = DatePickerViewModel()
    
    private let calendar = Calendar.current
    
    var body: some View {
        ZStack {
            // Transparent overlay - no dimming or blur
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    dismiss()
                }
                .ignoresSafeArea()
            
            // Calendar card
            VStack(spacing: 0) {
                CalendarWithActionsView(
                    viewModel: viewModel,
                    selectedDate: $selectedDate,
                    onDateSelected: { date in
                        selectedDate = date
                        onDateSelected?(date)
                        dismiss()
                    },
                    dismiss: dismiss,
                    onClearDate: {
                        onClearDate?()
                        dismiss()
                    },
                    hasExistingDate: hasExistingDate
                )
            }
            .padding(.horizontal)
            .frame(maxWidth: 340, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            viewModel.scrollToDate(Date())
            dismissKeyboard()
        }
    }
    
    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isPresented = false
        }
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - View Model

private class DatePickerViewModel: ObservableObject {
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

// MARK: - Month Data

private struct MonthData: Identifiable {
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

// MARK: - Calendar with Integrated Action Buttons

private struct CalendarWithActionsView: View {
    @ObservedObject var viewModel: DatePickerViewModel
    @Binding var selectedDate: Date
    let onDateSelected: (Date) -> Void
    let dismiss: () -> Void
    let onClearDate: () -> Void
    let hasExistingDate: Bool
    
    @State private var scrollTarget: UUID?
    
    private let calendar = Calendar.current
    
    private var today: Date { Date() }
    
    private let weekdaySymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.shortStandaloneWeekdaySymbols
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation header with month/year and arrows
            navigationHeader
            
            // Weekday headers
            weekdayHeader
            
            // Scrollable months with weeks
            scrollableCalendar
            
            // Action buttons
            actionButtons
        }
        .background(Color(.systemBackground).opacity(0.95))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Search Header
    
    private var navigationHeader: some View {
        VStack(spacing: 8) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                
                TextField("Search dates...", text: .constant(""))
                    .font(.subheadline)
                    .disableAutocorrection(true)
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Current month indicator
            Text(viewModel.currentMonthName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Weekday Header
    
    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                Text(weekdaySymbols[index])
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Scrollable Calendar
    
    private var scrollableCalendar: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(viewModel.months) { monthData in
                        MonthView(
                            monthData: monthData,
                            selectedDate: $selectedDate,
                            onDateSelected: onDateSelected,
                            isCurrentMonth: calendar.dp_isDate(monthData.date, inSameMonthAs: Date())
                        )
                        .id(monthData.id)
                    }
                }
                .onChange(of: scrollTarget) { _, newValue in
                    if let target = newValue {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(target, anchor: .top)
                        }
                    }
                }
            }
            .onAppear {
                // Scroll to current month, positioning today's week near the top
                if let currentMonth = viewModel.months.first(where: { calendar.dp_isDate($0.date, inSameMonthAs: Date()) }) {
                    scrollTarget = currentMonth.id
                }
            }
        }
        .frame(maxHeight: 320) // Limit height for scrollable area
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 8) {
            // Today/Tomorrow buttons
            HStack(spacing: 12) {
                // Today button
                Button {
                    let today = Date()
                    selectedDate = today
                    onDateSelected(today)
                    dismiss()
                } label: {
                    Label("Today", systemImage: "sun.max.fill")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                        .cornerRadius(8)
                }
                
                // Tomorrow button
                Button {
                    if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) {
                        selectedDate = tomorrow
                        onDateSelected(tomorrow)
                        dismiss()
                    }
                } label: {
                    Label("Tomorrow", systemImage: "moon.stars.fill")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                        .cornerRadius(8)
                }
            }
            
            // Clear Date button (only shown when there's an existing date)
            if hasExistingDate {
                Button {
                    onClearDate()
                } label: {
                    Label("Clear Date", systemImage: "xmark.circle")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

// MARK: - Month View

private struct MonthView: View {
    let monthData: MonthData
    @Binding var selectedDate: Date
    let onDateSelected: (Date) -> Void
    let isCurrentMonth: Bool
    
    private let calendar = Calendar.current
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
                    onDateSelected: onDateSelected
                )
            }
        }
    }
}

// MARK: - Week Row

private struct WeekRow: View {
    let dates: [Date?]
    @Binding var selectedDate: Date
    let today: Date
    let monthData: MonthData
    let onDateSelected: (Date) -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { dayIndex in
                let dayData = dates[dayIndex]
                
                if let date = dayData {
                    let day = calendar.component(.day, from: date)
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    let isTodayDate = calendar.isDate(date, inSameDayAs: today)
                    let isOtherMonth = !calendar.dp_isDate(date, inSameMonthAs: monthData.date)
                    
                    DayCell(
                        day: day,
                        isSelected: isSelected,
                        isToday: isTodayDate,
                        isOtherMonth: isOtherMonth,
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

// MARK: - Day Cell

private struct DayCell: View {
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

// MARK: - Calendar Extension

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

// MARK: - Preview

#Preview {
    struct DatePickerPreview: View {
        @State private var showDatePicker = true
        @State private var selectedDate = Date()
        
        var body: some View {
            ZStack {
                // Sample background content
                VStack {
                    Text("Main Content")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Tap the button to show date picker")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button {
                        showDatePicker = true
                    } label: {
                        Text("Show Date Picker")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .padding()
                
                // Date picker overlay
                if showDatePicker {
                    DatePickerOverlay(
                        isPresented: $showDatePicker,
                        selectedDate: $selectedDate,
                        onDateSelected: { date in
                            print("Selected date: \(date)")
                        },
                        onClearDate: nil,
                        hasExistingDate: false
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: showDatePicker)
        }
    }
    
    return DatePickerPreview()
}