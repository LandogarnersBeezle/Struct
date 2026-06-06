//
//  DatePickerOverlay.swift
//  Struct
//
//  Created by Otto Kiefer on 06.05.2026.
//

import SwiftUI

/// A reusable date selector overlay that appears as a pop-up with a scrollable calendar view.
/// Shows 5 weeks at a time with the current week at the top. Includes quick action buttons
/// for "Today" and "Tomorrow".
struct DatePickerOverlay: View {
    @Binding var isPresented: Bool
    @Binding var selectedDate: Date
    let onDateSelected: ((Date) -> Void)?
    
    @State private var weeks: [Date] = []
    
    private let calendar = Calendar.current
    private let weeksToShow = 5
    
    var body: some View {
        ZStack {
            // Dimmed background with blur
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismiss()
                }
                .overlay {
                    VisualEffectBlur(blurStyle: .systemMaterial)
                        .ignoresSafeArea()
                }
            
            // Calendar card
            VStack(spacing: 0) {
                // Calendar with integrated action buttons
                CalendarWithActionsView(
                    selectedDate: $selectedDate,
                    weeks: $weeks,
                    onDateSelected: { date in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDate = date
                        }
                        onDateSelected?(date)
                        dismiss()
                    },
                    dismiss: dismiss
                )
            }
            .padding(.horizontal)
            .frame(maxWidth: 340, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            generateWeeks()
        }
    }
    
    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isPresented = false
        }
    }
    
    private func generateWeeks() {
        var result: [Date] = []
        let today = Date()
        
        // Find the start of the current week based on calendar's firstWeekday
        var startOfWeekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        guard let startOfWeek = calendar.date(from: startOfWeekComponents) else {
            weeks = []
            return
        }
        
        // Generate 5 weeks starting from current week
        for weekOffset in 0..<weeksToShow {
            if let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: startOfWeek) {
                result.append(weekStart)
            }
        }
        weeks = result
    }
}

// MARK: - Calendar with Integrated Action Buttons

private struct CalendarWithActionsView: View {
    @Binding var selectedDate: Date
    @Binding var weeks: [Date]
    let onDateSelected: (Date) -> Void
    let dismiss: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private let calendar = Calendar.current
    
    private let weekdaySymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.shortStandaloneWeekdaySymbols
    }()
    
    private var today: Date { Date() }
    
    /// Get all 35 days (5 weeks x 7 days) in the correct order for the grid
    private var allDays: [Date] {
        guard let firstWeekStart = weeks.first else { return [] }
        
        // Get the first day of the first week (aligned to calendar's firstWeekday)
        let firstWeekday = calendar.component(.weekday, from: firstWeekStart)
        let calendarFirstWeekday = calendar.firstWeekday
        let offset = (firstWeekday - calendarFirstWeekday + 7) % 7
        
        guard let firstDay = calendar.date(byAdding: .day, value: offset, to: firstWeekStart) else {
            return []
        }
        
        // Generate 35 days (5 weeks)
        return (0..<35).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: firstDay)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Weekday headers
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
            
            // Days grid - 5 rows of 7 days each with proper spacing
            VStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { weekIndex in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { dayIndex in
                            let dayOffset = weekIndex * 7 + dayIndex
                            if dayOffset < allDays.count {
                                let date = allDays[dayOffset]
                                let day = calendar.component(.day, from: date)
                                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                                let isTodayDate = calendar.isDate(date, inSameDayAs: today)
                                
                                DayCell(
                                    date: date,
                                    day: day,
                                    isSelected: isSelected,
                                    isToday: isTodayDate,
                                    onTap: {
                                        onDateSelected(date)
                                    }
                                )
                            } else {
                                // Empty placeholder for alignment
                                Color.clear
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            // Integrated Today/Tomorrow buttons
            HStack(spacing: 12) {
                // Today button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedDate = today
                    }
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
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDate = tomorrow
                        }
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
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Day Cell

private struct DayCell: View {
    let date: Date
    let day: Int
    let isSelected: Bool
    let isToday: Bool
    let onTap: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
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
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return Color.accentColor
        } else {
            return .primary
        }
    }
}

// Note: VisualEffectBlur is defined in FilterViewOverlay.swift and reused here

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
                        }
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: showDatePicker)
        }
    }
    
    return DatePickerPreview()
}