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
    let onSave: (String, Date?, Date?) -> Void

    @State private var title: String = ""
    @State private var doDate: Date? = nil
    @State private var dueDate: Date? = nil
    @State private var showDatePicker: Bool = false
    @State private var datePickerType: DateType = .doDate
    @State private var hasSelectedDoDate: Bool = false
    @State private var hasSelectedDueDate: Bool = false
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 12) {
                // Title field with calendar icon / date display and deadline icon
                HStack(spacing: 8) {
                    // Do Date icon button
                    Button {
                        datePickerType = .doDate
                        showDatePicker = true
                    } label: {
                        if hasSelectedDoDate, let doDate = doDate {
                            // Show formatted date
                            Text(doDate, style: .date)
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
                    
                    Spacer()
                    
                    // Deadline icon button (only shown when do date is set)
                    if hasSelectedDoDate {
                        Button {
                            datePickerType = .dueDate
                            showDatePicker = true
                        } label: {
                            if hasSelectedDueDate, let dueDate = dueDate {
                                // Show formatted date with red color
                                Text(dueDate, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(6)
                                    .padding(.horizontal, 2)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(6)
                            } else {
                                // Show flag icon
                                Image(systemName: "flag.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(6)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
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
                        onSave(title, doDate, dueDate)
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
                        selectedDate: Binding(
                            get: { datePickerType == .doDate ? (doDate ?? Date()) : (dueDate ?? Date()) },
                            set: { newValue in
                                if datePickerType == .doDate {
                                    doDate = newValue
                                } else {
                                    dueDate = newValue
                                }
                            }
                        ),
                        dateType: datePickerType,
                        doDate: doDate,
                        onDateSelected: { date in
                            if datePickerType == .doDate {
                                doDate = date
                                hasSelectedDoDate = true
                            } else {
                                dueDate = date
                                hasSelectedDueDate = true
                            }
                            showDatePicker = false
                        },
                        onClearDate: {
                            if datePickerType == .doDate {
                                hasSelectedDoDate = false
                                doDate = nil
                            } else {
                                hasSelectedDueDate = false
                                dueDate = nil
                            }
                        },
                        hasExistingDate: datePickerType == .doDate ? hasSelectedDoDate : hasSelectedDueDate
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showDatePicker)
        .animation(.easeInOut(duration: 0.2), value: hasSelectedDoDate)
    }
}

#Preview {
    TaskCreationCardView(
        onCancel: {},
        onSave: { _, _, _ in }
    )
    .padding()
}