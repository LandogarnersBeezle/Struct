//
//  StructApp.swift
//  Struct
//
//  Created by Otto Kiefer on 01.05.2026.
//

import SwiftUI
import SwiftData

extension Font {

    // Base styles
    static let appFont     = Font.custom("CossetteTexte-Regular", size: 16)
    static let appHeadline = Font.custom("CossetteTexte-Bold",    size: 16)

    // Dynamic-type-aware variants (scale with accessibility size settings)
    static let appTitle2     = Font.custom("CossetteTexte-Bold",    size: 22, relativeTo: .title2)
    static let appTitle3     = Font.custom("CossetteTexte-Bold",    size: 20, relativeTo: .title3)
    static let appSubheadline = Font.custom("CossetteTexte-Regular", size: 15, relativeTo: .subheadline)
    static let appCaption    = Font.custom("CossetteTexte-Regular", size: 12, relativeTo: .caption)

}

@main
struct StructApp: App {
    let container: ModelContainer

    init() {
        
        
        
        
        
        
//        // Apply CossetteTexte to UIKit navigation bar titles.
//        // SwiftUI's .font() modifier does not reach UINavigationBar.
//        let regular = UIFont(name: "CossetteTexte-Regular", size: 17) ?? .systemFont(ofSize: 17)
//        let bold    = UIFont(name: "CossetteTexte-Bold",    size: 17) ?? .boldSystemFont(ofSize: 17)
//
//        let appearance = UINavigationBarAppearance()
//        appearance.configureWithDefaultBackground()
//        appearance.titleTextAttributes     = [.font: regular]   // .inline titles
//        appearance.largeTitleTextAttributes = [.font: bold]      // .large titles (future-proof)
//
//        UINavigationBar.appearance().standardAppearance   = appearance
//        UINavigationBar.appearance().scrollEdgeAppearance = appearance
//        UINavigationBar.appearance().compactAppearance    = appearance

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
                .font(.appFont)
        }
        .modelContainer(container)
    }
}
