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
    let dateType: DateType
    let doDate: Date? // For validation when setting due date
    let onDateSelected: ((Date) -> Void)?
    let onClearDate: (() -> Void)?
    let hasExistingDate: Bool
    
    @StateObject private var viewModel = DatePickerViewModel()
    @State private var currentDateType: DateType
    
    /// Creates a new date picker overlay.
    /// - Parameters:
    ///   - isPresented: Binding that controls whether the overlay is shown.
    ///   - selectedDate: The currently selected date.
    ///   - dateType: The type of date being set (do date or due date).
    ///   - doDate: The existing do date, used for validation when setting due date.
    ///   - onDateSelected: Closure called when a date is selected.
    ///   - onClearDate: Closure called when the date is cleared.
    ///   - hasExistingDate: Whether there's an existing date to show the clear button.
    public init(
        isPresented: Binding<Bool>,
        selectedDate: Binding<Date>,
        dateType: DateType,
        doDate: Date?,
        onDateSelected: ((Date) -> Void)?,
        onClearDate: (() -> Void)?,
        hasExistingDate: Bool
    ) {
        _isPresented = isPresented
        _selectedDate = selectedDate
        self.dateType = dateType
        self.doDate = doDate
        self.onDateSelected = onDateSelected
        self.onClearDate = onClearDate
        self.hasExistingDate = hasExistingDate
        _currentDateType = State(initialValue: dateType)
    }
    
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
                    currentDateType: $currentDateType,
                    doDate: doDate,
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
            currentDateType = dateType
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
                        dateType: .doDate,
                        doDate: nil,
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