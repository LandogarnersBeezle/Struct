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
            container = try Self.makeContainer()
        } catch {
            #if DEBUG
            // Dev-only self-heal: SwiftData failed to load the persistent store
            // (typically a schema change without a SchemaMigrationPlan). Wipe
            // the default store and retry once. MUST be replaced with a proper
            // VersionedSchema + SchemaMigrationPlan before this app ships or
            // accumulates data worth keeping.
            Self.wipeDefaultStore()
            do {
                container = try Self.makeContainer()
            } catch {
                fatalError("Failed to create ModelContainer after wipe: \(error)")
            }
            #else
            fatalError("Failed to create ModelContainer: \(error)")
            #endif
        }
        List.ensureInbox(in: container.mainContext)
    }

    private static func makeContainer() throws -> ModelContainer {
        try ModelContainer(for: Space.self, Project.self, List.self, Item.self)
    }

    #if DEBUG
    private static func wipeDefaultStore() {
        let fm = FileManager.default
        let dir = URL.applicationSupportDirectory
        for name in ["default.store", "default.store-shm", "default.store-wal"] {
            try? fm.removeItem(at: dir.appending(path: name))
        }
    }
    #endif

    var body: some Scene {
        WindowGroup {
            ContainersView()
        }
        .modelContainer(container)
    }
}
