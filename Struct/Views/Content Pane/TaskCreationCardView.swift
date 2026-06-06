//
//  TaskCreationCardView.swift
//  Struct
//
//  Created by Otto Kiefer on 06.05.2026.
//

import SwiftUI
import SwiftData

/// An expanded task creation card that slides in at the top of the content area
/// when the user taps the + button. Contains a title field with Cancel / Save
/// buttons and a date picker.
struct TaskCreationCardView: View {
    let onCancel: () -> Void
    let onSave: (String, Date) -> Void

    @State private var title: String = ""
    @State private var selectedDate: Date = Date()
    @State private var showDatePicker: Bool = false
    @State private var hasSelectedDate: Bool = false
    @State private var existingDate: Date? = nil
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 12) {
                // Title field with calendar icon / date display
                HStack(spacing: 8) {
                    // Calendar icon button that shows selected date when set
                    Button {
                        showDatePicker = true
                    } label: {
                        if hasSelectedDate {
                            // Show formatted date
                            Text(selectedDate, style: .date)
                                .font(.caption)
                                .foregroundColor(.accentColor)
                                .padding(6)
                                .padding(.horizontal, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(6)
                        } else {
                            // Show calendar icon
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                                .padding(6)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                    
                    TextField("Task title", text: $title, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .focused($isTitleFocused)
                        .onAppear {
                            isTitleFocused = true
                        }
                }

                // Buttons
                HStack(spacing: 12) {
                    Button(role: .cancel) {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        onSave(title, selectedDate)
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            
            // Date picker overlay - positioned below the card with spacing
            if showDatePicker {
                VStack {
                    Spacer(minLength: 140) // Push overlay below the card with gap
                    DatePickerOverlay(
                        isPresented: $showDatePicker,
                        selectedDate: $selectedDate,
                        onDateSelected: { _ in
                            hasSelectedDate = true
                            existingDate = selectedDate
                            showDatePicker = false
                        },
                        onClearDate: {
                            hasSelectedDate = false
                            existingDate = nil
                            selectedDate = Date()
                        },
                        hasExistingDate: hasSelectedDate
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showDatePicker)
    }
}

#Preview {
    TaskCreationCardView(
        onCancel: {},
        onSave: { _, _ in }
    )
    .padding()
}
