import SwiftUI

/// "Connect to Server" — 3-step wizard (URL → username → password), with an
/// inline 2FA step when the account requires it. Mirrors `LoginScreen` in
/// the prototype, translated to a real network call against
/// `POST /api/auth/login` on the user's own self-hosted instance.
struct ConnectServerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var twoFACode = ""
    @State private var pendingToken: String?
    @State private var setupNotice = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var shake = false
    @FocusState private var focused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private let steps = [
        (icon: "server.rack", title: "Server address", hint: "Enter the URL of your self-hosted Solytiq Cloud instance."),
        (icon: "person.fill", title: "Your username", hint: "Enter the username you use to log in."),
        (icon: "lock.fill", title: "Password", hint: "Enter your password. It never leaves this device."),
    ]

    private var totalSteps: Int { pendingToken == nil ? 3 : 4 }
    private var canAdvance: Bool {
        switch step {
        case 0: return !serverURL.trimmingCharacters(in: .whitespaces).isEmpty
        case 1: return !username.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: return !password.isEmpty
        default: return twoFACode.count >= 6
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: SCGradient.backdrop(colorScheme),
                            startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button {
                        if step > 0 { step -= 1; errorMessage = nil } else { dismiss() }
                    } label: {
                        HStack(spacing: 3) { Image(systemName: "chevron.left"); Text("Back") }
                    }
                    .foregroundStyle(SCColor.primary)
                    Spacer()
                }
                .padding(.horizontal, 24).padding(.top, 12)

                Image("AppLogo").resizable().frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: SCColor.primary.opacity(0.3), radius: 16, y: 8)
                    .padding(.top, 12)

                HStack(spacing: 6) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Capsule().fill(i <= step ? SCColor.primary : SCColor.border)
                            .frame(width: i == step ? 24 : 6, height: 5)
                            .opacity(i > step ? 0.35 : 1)
                    }
                }
                .padding(.top, 20)

                Spacer()

                VStack(spacing: 18) {
                    if step < 3 {
                        let s = steps[step]
                        VStack(spacing: 6) {
                            Text(s.title).font(.system(size: 22, weight: .bold))
                            Text(s.hint).font(.system(size: 13)).foregroundStyle(SCColor.text3)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 32)

                        Group {
                            switch step {
                            case 0:
                                TextField("cloud.example.com", text: $serverURL)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                                    .keyboardType(.URL)
                            case 1:
                                TextField("username", text: $username)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                            default:
                                SecureField("Password", text: $password)
                            }
                        }
                        .focused($focused)
                        .font(.system(size: 16, weight: .medium))
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(SCColor.card))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(SCColor.primary.opacity(0.45), lineWidth: 1.5))
                        .shadow(color: SCColor.primary.opacity(0.10), radius: 10, y: 4)
                        .padding(.horizontal, 32)
                        .offset(x: shake ? 8 : 0)

                        if setupNotice && step == 1 {
                            Label("This server has no admin account yet. Finish first-time setup in a web browser, then come back here to sign in.", systemImage: "info.circle")
                                .font(.system(size: 12)).foregroundStyle(SCColor.warning)
                                .padding(.horizontal, 32)
                        }
                    } else {
                        VStack(spacing: 6) {
                            Text("Two-factor code").font(.system(size: 22, weight: .bold))
                            Text("Enter the 6-digit code from your authenticator app.")
                                .font(.system(size: 13)).foregroundStyle(SCColor.text3).multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 32)
                        TextField("000000", text: $twoFACode)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(SCColor.card))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(SCColor.border, lineWidth: 1))
                            .padding(.horizontal, 32)
                            .offset(x: shake ? 8 : 0)
                    }

                    if let errorMessage {
                        Text(errorMessage).font(.system(size: 12.5)).foregroundStyle(SCColor.danger)
                            .multilineTextAlignment(.center).padding(.horizontal, 32)
                    }
                }

                Spacer()

                Button(action: advance) {
                    ZStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(step == 2 || step == 3 ? "Sign In" : "Continue")
                                .font(.system(size: 15.5, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(canAdvance ? SCColor.primary : SCColor.text4.opacity(0.5)))
                }
                .disabled(!canAdvance || isLoading)
                .padding(.horizontal, 24).padding(.bottom, 28)
            }
        }
        .onAppear { focused = true }
        .onChange(of: step) { _, _ in focused = true }
    }

    private func advance() {
        errorMessage = nil
        switch step {
        case 0:
            guard APIClient.normalize(serverInput: serverURL) != nil else {
                shakeInvalid("That doesn't look like a valid server address."); return
            }
            Task { await checkSetup() }
        case 1:
            step = 1 + 1
        case 2:
            Task { await login() }
        default:
            Task { await verify2FA() }
        }
    }

    private func checkSetup() async {
        guard let url = APIClient.normalize(serverInput: serverURL) else { return }
        await APIClient.shared.configure(baseURL: url, token: nil)
        isLoading = true
        defer { isLoading = false }
        setupNotice = (try? await AuthAPI().setupRequired()) ?? false
        step = 1
    }

    private func login() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await AuthAPI().login(username: username, password: password)
            if result.requires2FA == true, let pending = result.pendingToken {
                pendingToken = pending
                step = 3
                return
            }
            guard let token = result.token, let user = result.user, let url = APIClient.normalize(serverInput: serverURL) else {
                shakeInvalid("Unexpected response from the server."); return
            }
            await appState.didConnectToServer(url: url, token: token, user: user.toApp())
        } catch {
            shakeInvalid((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private func verify2FA() async {
        guard let pendingToken else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await AuthAPI().verify2FA(pendingToken: pendingToken, code: twoFACode)
            guard let token = result.token, let user = result.user, let url = APIClient.normalize(serverInput: serverURL) else {
                shakeInvalid("Unexpected response from the server."); return
            }
            await appState.didConnectToServer(url: url, token: token, user: user.toApp())
        } catch {
            shakeInvalid((error as? APIError)?.errorDescription ?? "Invalid code — please try again.")
        }
    }

    /// Validation shake from the handoff's motion table (`shake`, 420ms): a
    /// short horizontal oscillation that settles back to rest, not a single
    /// lurch.
    private func shakeInvalid(_ message: String) {
        errorMessage = message
        withAnimation(.linear(duration: 0.07).repeatCount(5, autoreverses: true)) { shake = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            withAnimation(.linear(duration: 0.07)) { shake = false }
        }
    }
}
