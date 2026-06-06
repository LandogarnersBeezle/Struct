//
//  DatePickerOverlay.swift
//  Struct
//
//  Created by Otto Kiefer on 06.05.2026.
//

import SwiftUI

/// A reusable date selector overlay with infinite scrolling through months.
/// Features vertical scrolling, month/year navigation, sticky headers, and lazy loading.
struct DatePickerOverlay: View {
    @Binding var isPresented: Bool
    @Binding var selectedDate: Date
    let onDateSelected: ((Date) -> Void)?
    let onClearDate: (() -> Void)?
    let hasExistingDate: Bool
    
    @StateObject private var viewModel = DatePickerViewModel()
    
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