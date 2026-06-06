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