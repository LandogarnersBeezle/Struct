//
//  ContainerFocusViewModel.swift
//  Struct
//
//  Created by Otto Kiefer on 05.05.2026.
//

import SwiftUI
import Combine

/// ViewModel for ContainerFocusView that manages filter state and logic.
@MainActor
class ContainerFocusViewModel: ObservableObject {
    // MARK: - Types
    
    /// Represents a container entry for search/filter results.
    /// `isChild` indicates if the container belongs to a space (drives indentation).
    typealias SearchEntry = (target: ContainerTarget, isChild: Bool)
    
    // MARK: - Published Properties
    
    @Published var searchText: String = ""
    @Published var showFilterView: Bool = false
    
    // MARK: - Methods
    
    /// Closes the filter view with animation and resets search state.
    func closeFilterView() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8, blendDuration: 0)) {
            showFilterView = false
            searchText = ""
        }
    }
    
    /// Toggles the filter view visibility.
    func toggleFilterView() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8, blendDuration: 0)) {
            showFilterView.toggle()
        }
    }
    
    /// Computes filtered containers based on search text.
    /// - Parameters:
    ///   - allContainers: All available containers
    ///   - searchText: Current search text
    /// - Returns: Filtered list of containers matching the search text
    func filteredContainers(from allContainers: [SearchEntry]) -> [SearchEntry] {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return allContainers }
        return allContainers.filter { $0.target.title.localizedCaseInsensitiveContains(q) }
    }
}