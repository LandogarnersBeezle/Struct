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
        viewModel.filteredContainers(from: allContainers)
    }
    
    var body: some View {
        ZStack {
            // Blurred background - avoids safe area transition issues
            Color.clear
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    onClose()
                }
                .overlay {
                    // Blur effect applied to the entire background
                    VisualEffectBlur(blurStyle: .systemMaterial)
                        .ignoresSafeArea()
                }
            
            // Filter card at the top
            VStack(alignment: .leading, spacing: 0) {
                VStack(spacing: 0) {
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
                .padding(.horizontal)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
