import SwiftUI

/// First screen — mode picker ("On This Phone" vs "Connect to Server"),
/// matching `WelcomeScreen` in the prototype.
struct WelcomeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var selection: AppMode?
    @State private var goToConnect = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: SCGradient.backdrop(colorScheme),
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(spacing: 14) {
                        Image("AppLogo")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: SCColor.primary.opacity(0.38), radius: 24, y: 12)
                        VStack(spacing: 5) {
                            Text("Solytiq Cloud").font(.system(size: 26, weight: .bold))
                            Text("Your self-hosted task manager.")
                                .font(.system(size: 13.5)).foregroundStyle(SCColor.text3)
                        }
                    }
                    .padding(.top, 40)

                    VStack(spacing: 10) {
                        modeCard(.local, icon: "iphone", title: "On This Phone", badge: "Private",
                                 desc: "Tasks stay on device. No account or internet required.")
                        modeCard(.server, icon: "icloud.fill", title: "Connect to Server", badge: nil,
                                 desc: "Sign in to your self-hosted Solytiq Cloud instance. Sync across devices.")
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    Button(action: proceed) {
                        HStack(spacing: 7) {
                            Text("Continue").font(.system(size: 15.5, weight: .semibold))
                            if selection != nil { Image(systemName: "arrow.right").font(.system(size: 14)) }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(selection != nil ? SCColor.primary : SCColor.text4.opacity(0.5)))
                    }
                    .disabled(selection == nil)
                    .padding(.horizontal, 24)

                    Text("You can switch modes anytime from Settings.")
                        .font(.system(size: 11)).foregroundStyle(SCColor.text4)
                        .padding(.bottom, 24)
                }
            }
            .navigationDestination(isPresented: $goToConnect) { ConnectServerView() }
        }
    }

    private func modeCard(_ mode: AppMode, icon: String, title: String, badge: String?, desc: String) -> some View {
        let active = selection == mode
        return Button { selection = mode } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(active ? SCColor.primary : SCColor.primaryBg)
                    Image(systemName: icon).font(.system(size: 21)).foregroundStyle(active ? .white : SCColor.primary)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(SCColor.text)
                        if let badge {
                            Text(badge.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(SCColor.success)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Capsule().fill(SCColor.success.opacity(0.12)))
                        }
                    }
                    Text(desc).font(.system(size: 13)).foregroundStyle(SCColor.text3).multilineTextAlignment(.leading)
                }
                Spacer()
                ZStack {
                    Circle().strokeBorder(active ? SCColor.primary : SCColor.border, lineWidth: 1.5)
                        .background(Circle().fill(active ? SCColor.primary : .clear))
                    if active { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white) }
                }
                .frame(width: 22, height: 22)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(active ? SCColor.card : SCColor.card.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(active ? SCColor.primary : SCColor.border, lineWidth: 1.5))
            .shadow(color: active ? SCColor.primary.opacity(0.22) : .clear, radius: 16, y: 6)
        }
        .scPressStyle()
        .animation(SCMotion.interactive, value: active)
    }

    private func proceed() {
        guard let selection else { return }
        if selection == .local {
            appState.selectLocalMode()
        } else {
            goToConnect = true
        }
    }
}
