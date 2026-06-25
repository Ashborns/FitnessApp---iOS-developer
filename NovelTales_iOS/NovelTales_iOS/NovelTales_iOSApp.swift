//
//  NovelTales_iOSApp.swift
//  NovelTales_iOS
//
//  Created by 12 on 2026/6/25.
//

import SwiftUI

@main
struct NovelTales_iOSApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
