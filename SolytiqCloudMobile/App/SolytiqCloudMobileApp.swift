import SwiftUI
import SwiftData

@main
struct SolytiqCloudMobileApp: App {
    let modelContainer: ModelContainer
    @StateObject private var appState = AppState()

    init() {
        let schema = Schema(LocalSchema.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create the on-device store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .modelContainer(modelContainer)
                .tint(SCColor.primary)
        }
    }
}
