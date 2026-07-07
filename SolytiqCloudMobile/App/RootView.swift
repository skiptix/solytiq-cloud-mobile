import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
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
        .animation(.easeInOut(duration: 0.25), value: appState.mode)
        .animation(.easeInOut(duration: 0.25), value: appState.isRestoringSession)
    }

    private var splash: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#ede9ff"), Color(hex: "#fdf8ff"), Color(hex: "#fff0f9")],
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
