//
//  DatePickerOverlay.swift
//  Struct
//
//  Created by Otto Kiefer on 06.05.2026.
//

import SwiftUI

/// Type of date being selected
public enum DateType {
    case doDate
    case dueDate
}

/// A reusable date selector overlay with infinite scrolling through months.
/// Features vertical scrolling, month/year navigation, sticky headers, and lazy loading.
struct DatePickerOverlay: View {
    @Binding var isPresented: Bool
    @Binding var selectedDate: Date
    @Binding var datePickerType: DateType  // Binding to update the parent's date type
    let dateType: DateType
    let doDate: Date? // For validation when setting due date
    let dueDate: Date? // The current due date value
    let onSave: ((Date?, Date?) -> Void)?
    let onCancel: (() -> Void)?
    let onClearDate: (() -> Void)?
    
    @StateObject private var viewModel = DatePickerViewModel()
    @State private var currentDateType: DateType
    @State private var tempSelectedDate: Date
    @State private var tempDoDate: Date?
    @State private var tempDueDate: Date?
    @State private var validationAlert: String?
    
    private let calendar = Calendar.current
    
    /// Creates a new date picker overlay.
    /// - Parameters:
    ///   - isPresented: Binding that controls whether the overlay is shown.
    ///   - selectedDate: The currently selected date.
    ///   - dateType: The type of date being set (do date or due date).
    ///   - doDate: The existing do date, used for validation when setting due date.
    ///   - onSave: Closure called when save is tapped.
    ///   - onCancel: Closure called when cancel is tapped.
    ///   - onClearDate: Closure called when the date is cleared.
    ///   - hasExistingDate: Whether there's an existing date to show the clear button.
    public init(
        isPresented: Binding<Bool>,
        selectedDate: Binding<Date>,
        datePickerType: Binding<DateType>,
        dateType: DateType,
        doDate: Date?,
        dueDate: Date?,
        onSave: ((Date?, Date?) -> Void)?,
        onCancel: (() -> Void)?,
        onClearDate: (() -> Void)?
    ) {
        _isPresented = isPresented
        _selectedDate = selectedDate
        _datePickerType = datePickerType
        self.dateType = dateType
        self.doDate = doDate
        self.dueDate = dueDate
        self.onSave = onSave
        self.onCancel = onCancel
        self.onClearDate = onClearDate
        _currentDateType = State(initialValue: dateType)
        _tempSelectedDate = State(initialValue: selectedDate.projectedValue.wrappedValue)
        // Only set temp dates to existing values, not to the default Date()
        _tempDoDate = State(initialValue: doDate)
        _tempDueDate = State(initialValue: dueDate)
    }
    
    var body: some View {
        ZStack {
            // Transparent overlay - no dimming or blur
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    cancel()
                }
                .ignoresSafeArea()
            
            // Calendar card
            VStack(spacing: 0) {
                CalendarWithActionsView(
                    viewModel: viewModel,
                    selectedDate: $tempSelectedDate,
                    currentDateType: $currentDateType,
                    doDate: tempDoDate,
                    dueDate: tempDueDate,
                    onSave: {
                        // Only update the binding if there's an actual date to save
                        // (not the default Date() when no date was selected)
                        if datePickerType == .doDate && tempDoDate != nil {
                            selectedDate = tempSelectedDate
                        } else if datePickerType == .dueDate && tempDueDate != nil {
                            selectedDate = tempSelectedDate
                        }
                        onSave?(tempDoDate, tempDueDate)
                        dismiss()
                    },
                    onCancel: {
                        cancel()
                    },
                    dismiss: dismiss,
                    onClearDate: {
                        // Clear the appropriate date(s) based on current type
                        if currentDateType == .dueDate {
                            // Clear due date only
                            tempDueDate = nil
                        } else {
                            // On doDate tab - clear do date and due date (since due date can't exist without do date)
                            tempDoDate = nil
                            tempDueDate = nil
                        }
                        // Reset selectedDate to remove highlight from calendar
                        tempSelectedDate = Date()
                    },
                    hasExistingDate: tempDoDate != nil || tempDueDate != nil,
                    onDateTypeChanged: { oldType, newType in
                        // Update the parent's datePickerType to match
                        datePickerType = newType
                        
                        if newType == .doDate && oldType == .dueDate {
                            // Switching from dueDate to doDate - set selectedDate to the doDate value
                            tempSelectedDate = tempDoDate ?? Date()
                        } else if newType == .dueDate && oldType == .doDate {
                            // Switching from doDate to dueDate - set selectedDate to the dueDate value
                            tempSelectedDate = tempDueDate ?? Date()
                        }
                    },
                    onDateSelected: { date in
                        // Validate date constraints
                        if currentDateType == .doDate {
                            // Do date must be <= due date (if due date exists)
                            if let dueDate = tempDueDate, calendar.compare(date, to: dueDate, toGranularity: .day) == .orderedDescending {
                                // Selected do date is after due date, adjust due date
                                tempDueDate = date
                            }
                            tempDoDate = date
                        } else {
                            // Due date must be >= do date (if do date exists)
                            if let doDate = tempDoDate, calendar.compare(date, to: doDate, toGranularity: .day) == .orderedAscending {
                                // Selected due date is before do date, adjust do date
                                tempDoDate = date
                            }
                            tempDueDate = date
                        }
                        tempSelectedDate = date
                    }
                )
            }
            .padding(.horizontal)
            .frame(maxWidth: 340, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            currentDateType = dateType
            tempSelectedDate = selectedDate
            // Only set temp dates to existing values, not to the default Date()
            tempDoDate = doDate
            tempDueDate = dueDate
            viewModel.scrollToDate(Date())
            dismissKeyboard()
        }
    }
    
    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isPresented = false
        }
    }
    
    private func cancel() {
        onCancel?()
        dismiss()
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
                        datePickerType: .constant(DateType.doDate),
                        dateType: .doDate,
                        doDate: nil,
                        dueDate: nil,
                        onSave: { doDate, dueDate in
                            print("Saved doDate: \(String(describing: doDate)), dueDate: \(String(describing: dueDate))")
                        },
                        onCancel: {
                            print("Cancelled")
                        },
                        onClearDate: nil
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: showDatePicker)
        }
    }
    
    return DatePickerPreview()
}