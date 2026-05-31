//
//  DataError.swift
//  Struct
//
//  Created by Otto Kiefer on 31.05.2026.
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - DataError

/// Error types for SwiftData operations throughout the app.
enum DataError: Error, LocalizedError {
    case saveFailed(Error?)
    case fetchFailed(Error?)
    case deleteFailed(Error?)
    case migrationFailed(Error?)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let underlying):
            return "Failed to save changes.\(underlying.map { " \(NSLocalizedString("Error", comment: "")): \($0.localizedDescription)" } ?? "")"
        case .fetchFailed(let underlying):
            return "Failed to fetch data.\(underlying.map { " \(NSLocalizedString("Error", comment: "")): \($0.localizedDescription)" } ?? "")"
        case .deleteFailed(let underlying):
            return "Failed to delete item.\(underlying.map { " \(NSLocalizedString("Error", comment: "")): \($0.localizedDescription)" } ?? "")"
        case .migrationFailed(let underlying):
            return "Failed to migrate data.\(underlying.map { " \(NSLocalizedString("Error", comment: "")): \($0.localizedDescription)" } ?? "")"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .saveFailed:
            return "Please try again. If the problem persists, restart the app."
        case .fetchFailed:
            return "Please try again or restart the app."
        case .deleteFailed:
            return "Please try again."
        case .migrationFailed:
            return "Some data may be out of order. Please restart the app."
        }
    }
}

// MARK: - ModelContext Extension

extension ModelContext {
    /// Saves the context and throws a `DataError` on failure.
    func saveOrThrow() throws {
        do {
            try save()
        } catch {
            throw DataError.saveFailed(error)
        }
    }

    /// Saves the context, logging errors but not throwing.
    /// Returns `true` if save succeeded, `false` otherwise.
    @discardableResult
    func saveLogging() -> Bool {
        do {
            try save()
            return true
        } catch {
            #if DEBUG
            print("❌ [DataError] Save failed: \(error)")
            #endif
            return false
        }
    }

    /// Fetches with error handling, throwing a `DataError` on failure.
    func fetchOrThrow<T>(_ descriptor: FetchDescriptor<T>) throws -> [T] {
        do {
            return try fetch(descriptor)
        } catch {
            throw DataError.fetchFailed(error)
        }
    }

    /// Fetches with error handling, returning nil on failure.
    func fetchLogging<T>(_ descriptor: FetchDescriptor<T>) -> [T]? {
        do {
            return try fetch(descriptor)
        } catch {
            #if DEBUG
            print("❌ [DataError] Fetch failed: \(error)")
            #endif
            return nil
        }
    }
}

// MARK: - Error Alert Modifier

/// A simple error alert presenter that can be used throughout the app.
struct ErrorAlert: ViewModifier {
    @Binding var error: DataError?
    var onDismiss: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .alert(
                "Error",
                isPresented: Binding(
                    get: { error != nil },
                    set: { if !$0 { error = nil; onDismiss?() } }
                ),
                actions: {
                    Button("OK", role: .cancel) {
                        error = nil
                        onDismiss?()
                    }
                },
                message: {
                    if let error {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(error.errorDescription ?? "An unknown error occurred.")
                            if let suggestion = error.recoverySuggestion {
                                Text(suggestion)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            )
    }
}

extension View {
    /// Presents an error alert when `error` is non-nil.
    func errorAlert(_ error: Binding<DataError?>, onDismiss: (() -> Void)? = nil) -> some View {
        modifier(ErrorAlert(error: error, onDismiss: onDismiss))
    }
}
