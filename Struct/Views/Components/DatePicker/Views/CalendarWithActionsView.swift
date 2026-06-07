//
//  CalendarWithActionsView.swift
//  Struct
//
//  Created by Otto Kiefer on 06.05.2026.
//

import SwiftUI

struct CalendarWithActionsView: View {
    @ObservedObject var viewModel: DatePickerViewModel
    @Binding var selectedDate: Date
    @Binding var currentDateType: DateType
    let doDate: Date? // For validation when setting due date
    let dueDate: Date? // The current due date value
    let onSave: () -> Void
    let onCancel: () -> Void
    let dismiss: () -> Void
    let onClearDate: () -> Void
    let hasExistingDate: Bool
    
    // Callbacks to update dates when switching between date types
    let onDateTypeChanged: ((DateType, DateType) -> Void)?  // (oldType, newType)
    
    // Callback when a date is selected in the calendar
    let onDateSelected: ((Date) -> Void)?
    
    @State private var scrollTarget: UUID?
    
    private let calendar = Calendar.current
    
    private var today: Date { Date() }
    
    private let weekdaySymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.shortStandaloneWeekdaySymbols
    }()
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }
    
    // MARK: - Date Formatting Helper
    
    /// Formats a date according to the specified rules:
    /// - Next 7 days: abbreviated weekday (Mon, Tue, Wed)
    /// - Other days in current year: date + abbreviated month (7 Jun)
    /// - Days in other years: full format with year (9 Oct 2027)
    private func formattedDate(from date: Date) -> String {
        let now = Date()
        
        // Check if date is within the next 7 days
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)
        if let startOfSevenDaysFromNow = calendar.date(byAdding: .day, value: 7, to: startOfToday),
           startOfDate >= startOfToday,
           startOfDate < startOfSevenDaysFromNow {
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with cancel, date type buttons, and save
            headerRow
            
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
    
    // MARK: - Header Row
    
    private var headerRow: some View {
        HStack(spacing: 8) {
            // Cancel button (round with X icon)
            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
            }
            
            // Do Date button (icon only, with date if set)
            Button {
                withAnimation {
                    let oldType = currentDateType
                    currentDateType = .doDate
                    if oldType != .doDate {
                        onDateTypeChanged?(oldType, .doDate)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 14))
                    // Always show the doDate value (nil if not set)
                    if let displayDate = doDate {
                        Text(formattedDate(from: displayDate))
                            .font(.caption2)
                    }
                }
                .fontWeight(currentDateType == .doDate ? .semibold : .medium)
                .foregroundColor(currentDateType == .doDate ? .accentColor : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(currentDateType == .doDate ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(8)
            }
            
            // Deadline button (icon only, with date if set) - keep space even when hidden
            Button {
                withAnimation {
                    let oldType = currentDateType
                    currentDateType = .dueDate
                    if oldType != .dueDate {
                        onDateTypeChanged?(oldType, .dueDate)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 14))
                    // Always show the dueDate value (nil if not set)
                    if let displayDate = dueDate {
                        Text(formattedDate(from: displayDate))
                            .font(.caption2)
                    }
                }
                .fontWeight(currentDateType == .dueDate ? .semibold : .medium)
                .foregroundColor(currentDateType == .dueDate ? .red : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(currentDateType == .dueDate ? Color.red.opacity(0.2) : Color.clear)
                .cornerRadius(8)
            }
            .opacity(doDate != nil ? 1 : 0)
            .disabled(doDate == nil)
            
            // Save button (round with checkmark icon)
            Button {
                onSave()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor)
                    .cornerRadius(16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    // MARK: - Search Header
    
    private var navigationHeader: some View {
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
        .padding(.top, 8)
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
                            currentDateType: currentDateType,
                            doDate: doDate,
                            onDateSelected: { date in
                                selectedDate = date
                                onDateSelected?(date)
                            },
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
            // Clear Date button (only shown when there's an existing date)
            if hasExistingDate {
                Button {
                    onClearDate()
                } label: {
                    Label(clearButtonLabel, systemImage: "xmark.circle")
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
    
    // MARK: - Clear Button Label
    
    private var clearButtonLabel: String {
        if currentDateType == .dueDate {
            return "Clear due date"
        } else {
            // On doDate tab
            if dueDate != nil {
                return "Clear dates"
            } else {
                return "Clear do date"
            }
        }
    }
}
