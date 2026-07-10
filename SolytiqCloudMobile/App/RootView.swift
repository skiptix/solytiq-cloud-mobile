import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var router = Router()
    @State private var store: DataStore?

    var body: some View {
        Group {
            if appState.isRestoringSession {
                splash
            } else if appState.mode == nil {
                WelcomeView()
            } else if appState.mode == .server && appState.currentUser == nil {
                ConnectServerView()
            } else if let store {
                MainTabView()
                    .environmentObject(store)
                    .environmentObject(router)
                    .environmentObject(appState.sync)
                    .fullScreenCover(isPresented: $appState.showConnectFlow) {
                        ConnectServerView()
                    }
            } else {
                splash
            }
        }
        .task {
            await appState.restoreSession()
        }
        .onAppear {
            if store == nil {
                let s = DataStore(modelContext: modelContext, appState: appState)
                s.purgeExpiredLocalTrash()
                store = s
            }
        }
        .onChange(of: appState.mode) { _, _ in
            if let store { store.purgeExpiredLocalTrash() }
            router.tab = .home
            router.listsPath = []
        }
        .onChange(of: scenePhase) { _, phase in
            // The SSE stream dies while backgrounded and its nudges are
            // missed — reconnect and reconcile as soon as we're active again.
            if phase == .active && appState.mode == .server {
                appState.sync.appBecameActive()
            }
        }
        .animation(SCMotion.screenSlide, value: appState.mode)
        .animation(SCMotion.screenSlide, value: appState.isRestoringSession)
        .preferredColorScheme(appState.colorSchemePref.colorScheme)
    }

    /// The scheme the app is actually rendering in: the explicit preference,
    /// or the live system scheme when the user chose "System".
    private var effectiveScheme: ColorScheme {
        appState.colorSchemePref.colorScheme ?? colorScheme
    }

    private var splash: some View {
        ZStack {
            LinearGradient(colors: SCGradient.backdrop(effectiveScheme),
                            startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            Image("AppLogo")
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: SCColor.primary.opacity(0.35), radius: 24, y: 12)
        }
    }
}
