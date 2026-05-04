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
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Space.self, Project.self, List.self, Item.self
            )
            List.ensureInbox(in: container.mainContext)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(container)
    }
}
