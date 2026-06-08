//
//  FilterViewOverlay.swift
//  Struct
//
//  Created by Otto Kiefer on 05.05.2026.
//

import SwiftUI

/// An overlay view that provides a filter/search interface for containers.
/// Appears as a card at the top of the screen with a blurred background.
struct FilterViewOverlay: View {
    @Binding var searchText: String
    let allContainers: [ContainerFocusViewModel.SearchEntry]
    let onSelect: (ContainerTarget) -> Void
    let onClose: () -> Void
    let viewModel: ContainerFocusViewModel
    
    @FocusState private var isSearchFocused: Bool
    
    private var filteredContainers: [ContainerFocusViewModel.SearchEntry] {
        viewModel.filteredContainers(from: allContainers, searchText: searchText)
    }
    
    var body: some View {
        // Full-screen background that captures taps outside the card
        Color.clear
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture {
                onClose()
            }
            .overlay {
                // Blur effect
                VisualEffectBlur(blurStyle: .extraLight)
                    .ignoresSafeArea()
                
                // Card positioned at top
                VStack(alignment: .leading, spacing: 0) {
                    FilterSearchField(searchText: $searchText, isFocused: $isSearchFocused)
                    
                    FilterResultsView(entries: filteredContainers, onSelect: { target in
                        onClose()
                        onSelect(target)
                    })
                        .frame(maxHeight: 240)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.systemBackground))
                        .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
                )
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                // Block tap propagation from the card area
                .compositingGroup()
            }
        .onAppear {
            // Focus the search field after a tiny delay to ensure smooth animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                isSearchFocused = true
            }
        }
    }
}

// MARK: - Visual Effect Blur

/// A UIViewRepresentable that wraps UIVisualEffectView to provide a blur effect.
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}
