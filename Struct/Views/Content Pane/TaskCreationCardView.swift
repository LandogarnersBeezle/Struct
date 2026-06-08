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
    let targetContainer: ContainerTarget
    let allContainers: [ContainerFocusViewModel.SearchEntry]
    let viewModel: ContainerFocusViewModel
    let onContainerSelect: (ContainerTarget) -> Void
    let onCancel: () -> Void
    /// Callback to notify parent when date picker visibility changes (for blurring background)
    let onDatePickerVisibilityChanged: ((Bool) -> Void)?
    /// Callback to notify parent when container selector should be shown
    let onShowContainerSelector: () -> Void
    /// Callback to update the selected container when chosen from the filter overlay
    let onContainerSelected: ((ContainerTarget) -> Void)?
    /// Binding to receive updates from parent about selected container
    let selectedContainerBinding: Binding<ContainerTarget?>
    /// Callback to notify parent that filter search should be focused
    let onFocusFilterSearch: () -> Void
    let onSave: (String, Date?, Date?) -> Void

    @State private var title: String = ""
    @State private var doDate: Date? = nil
    @State private var dueDate: Date? = nil
    @State private var showDatePicker: Bool = false
    @State private var datePickerType: DateType = .doDate
    @State private var hasSelectedDoDate: Bool = false
    @State private var hasSelectedDueDate: Bool = false
    @State private var selectedContainer: ContainerTarget
    @FocusState private var isTitleFocused: Bool
    
    private let calendar = Calendar.current
    
    init(
        targetContainer: ContainerTarget,
        allContainers: [ContainerFocusViewModel.SearchEntry],
        viewModel: ContainerFocusViewModel,
        onContainerSelect: @escaping (ContainerTarget) -> Void,
        onCancel: @escaping () -> Void,
        onDatePickerVisibilityChanged: ((Bool) -> Void)?,
        onShowContainerSelector: @escaping () -> Void,
        onContainerSelected: ((ContainerTarget) -> Void)? = nil,
        selectedContainerBinding: Binding<ContainerTarget?>,
        onFocusFilterSearch: @escaping () -> Void = {},
        onSave: @escaping (String, Date?, Date?) -> Void
    ) {
        self.targetContainer = targetContainer
        self.allContainers = allContainers
        self.viewModel = viewModel
        self.onContainerSelect = onContainerSelect
        self.onCancel = onCancel
        self.onDatePickerVisibilityChanged = onDatePickerVisibilityChanged
        self.onShowContainerSelector = onShowContainerSelector
        self.onContainerSelected = onContainerSelected
        self.selectedContainerBinding = selectedContainerBinding
        self.onFocusFilterSearch = onFocusFilterSearch
        self.onSave = onSave
        _selectedContainer = State(initialValue: targetContainer)
    }
    
    // MARK: - Date Formatting Helper
    
    /// Formats a date using the shared DateFormatter utility.
    /// See `DateFormatter.formattedDate(from:calendar:)` for formatting rules.
    private func formattedDate(from date: Date) -> String {
        DateFormatter.formattedDate(from: date, calendar: calendar)
    }
    
    // MARK: - Breadcrumb Helpers
    
    /// Builds the breadcrumb view for the currently selected container.
    @ViewBuilder
    private var breadcrumbView: some View {
        switch selectedContainer {
        case .space(let space):
            spaceBreadcrumb(space: space)
        case .list(let list):
            listBreadcrumb(list: list)
        case .project(let project):
            projectBreadcrumb(project: project)
        }
    }
    
    /// A tappable breadcrumb button that shows the current container and opens the selector when tapped.
    private var breadcrumbButton: some View {
        Button {
            onShowContainerSelector()
            onFocusFilterSearch()
        } label: {
            breadcrumbView
        }
        .buttonStyle(.plain)
        .onChange(of: selectedContainer) { _, newValue in
            onContainerSelected?(newValue)
        }
        .onChange(of: selectedContainerBinding.wrappedValue) { _, newValue in
            if let newTarget = newValue {
                selectedContainer = newTarget
            }
        }
    }
    
    private func spaceBreadcrumb(space: Space) -> some View {
        HStack(spacing: 4) {
            Image(systemName: space.symbolName)
                .font(.caption2)
                .foregroundColor(Space.containerColor)
            Text(space.name)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private func listBreadcrumb(list: List) -> some View {
        HStack(spacing: 4) {
            if let space = list.space {
                Image(systemName: space.symbolName)
                    .font(.caption2)
                    .foregroundColor(Space.containerColor)
                Text(space.name)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("/")
                    .font(.caption2)
                    .foregroundColor(Color.gray.opacity(0.5))
            }
            Image(systemName: list.kind == .inbox ? "tray" : "list.bullet")
                .font(.caption2)
                .foregroundColor(List.containerColor)
            Text(list.title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private func projectBreadcrumb(project: Project) -> some View {
        HStack(spacing: 4) {
            Image(systemName: project.space.symbolName)
                .font(.caption2)
                .foregroundColor(Space.containerColor)
            Text(project.space.name)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("/")
                .font(.caption2)
                .foregroundColor(Color.gray.opacity(0.5))
            Image(systemName: "folder")
                .font(.caption2)
                .foregroundColor(Project.containerColor)
            Text(project.title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

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
                            // Show formatted date using special formula
                            Text(formattedDate(from: doDate))
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
                                // Show formatted date with red color using special formula
                                Text(formattedDate(from: dueDate))
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

                // Container breadcrumb (tappable to change destination)
                breadcrumbButton
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

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
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.gray, lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            
            // Date picker overlay - positioned at the top, overlaying the card
            if showDatePicker {
                VStack {
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
                        datePickerType: $datePickerType,
                        dateType: datePickerType,
                        doDate: doDate,
                        dueDate: dueDate,
                        onSave: { newDoDate, newDueDate in
                            // Save both dates from the picker
                            // Only update if the date is not nil (nil means it was cleared)
                            if newDoDate != nil {
                                doDate = newDoDate
                                hasSelectedDoDate = true
                            } else if datePickerType == .doDate {
                                // If do date was cleared and we're on do date tab, clear it
                                hasSelectedDoDate = false
                                doDate = nil
                            }
                            if newDueDate != nil {
                                dueDate = newDueDate
                                hasSelectedDueDate = true
                            } else if datePickerType == .dueDate {
                                // If due date was cleared and we're on due date tab, clear it
                                hasSelectedDueDate = false
                                dueDate = nil
                            }
                            // If do date was cleared, also clear due date (due date can't exist without do date)
                            if newDoDate == nil && datePickerType == .doDate {
                                hasSelectedDueDate = false
                                dueDate = nil
                            }
                            showDatePicker = false
                        },
                        onCancel: {
                            // Restore original dates on cancel
                            showDatePicker = false
                        },
                        onClearDate: {
                            if datePickerType == .doDate {
                                hasSelectedDoDate = false
                                doDate = nil
                                hasSelectedDueDate = false
                                dueDate = nil
                            } else {
                                hasSelectedDueDate = false
                                dueDate = nil
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .padding(.top, 50)
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showDatePicker)
        .animation(.easeInOut(duration: 0.2), value: hasSelectedDoDate)
        .animation(.easeInOut(duration: 0.2), value: hasSelectedDueDate)
        .onChange(of: showDatePicker) { _, newValue in
            onDatePickerVisibilityChanged?(newValue)
        }
    }
}

#Preview {
    TaskCreationCardView(
        targetContainer: .space(Space(name: "Personal", sortIndex: 0)),
        allContainers: [],
        viewModel: ContainerFocusViewModel(),
        onContainerSelect: { _ in },
        onCancel: {},
        onDatePickerVisibilityChanged: nil,
        onShowContainerSelector: {},
        onContainerSelected: nil,
        selectedContainerBinding: .constant(nil),
        onFocusFilterSearch: {},
        onSave: { _, _, _ in }
    )
    .padding()
}
