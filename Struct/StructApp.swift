//
//  StructApp.swift
//  Struct
//
//  Created by Otto Kiefer on 01.05.2026.
//

import SwiftUI
import SwiftData

@main
struct StructApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(for: TodoItem.self)
    }
}
