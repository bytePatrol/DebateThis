import SwiftUI
import SwiftData

@main
struct DebateThisApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 750)
        .modelContainer(for: [SavedDebate.self, SavedRound.self])
    }
}
