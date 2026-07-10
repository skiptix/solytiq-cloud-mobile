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
    @State private var showPassword = false
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

    private var currentIcon: String { step < 3 ? steps[step].icon : "lock.shield.fill" }
    private var currentTitle: String { step < 3 ? steps[step].title : "Two-factor code" }
    private var currentHint: String { step < 3 ? steps[step].hint : "Enter the 6-digit code from your authenticator app." }
    private var fieldLabel: String {
        switch step {
        case 0: return "Server URL"
        case 1: return "Username"
        case 2: return "Password"
        default: return "Authentication code"
        }
    }
    private var helperText: String {
        switch step {
        case 0: return "Your server address looks like https://cloud.yourdomain.com"
        case 1: return "Use the same username you set up on your server."
        case 2: return "We never store your password. Sessions stay on this device."
        default: return "Open your authenticator app to read the current 6-digit code."
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
                    .padding(.top, 20)

                HStack(spacing: 6) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Capsule().fill(i <= step ? SCColor.primary : SCColor.border)
                            .frame(width: i == step ? 24 : 6, height: 5)
                            .opacity(i > step ? 0.35 : 1)
                    }
                }
                .padding(.top, 20)

                ScrollView {
                    VStack(spacing: 16) {
                        stepCard
                        Text(helperText)
                            .font(.system(size: 11)).foregroundStyle(SCColor.text4)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 32)
                }
            }
        }
        .onAppear { focused = true }
        .onChange(of: step) { _, _ in focused = true }
    }

    /// Frosted "step card" matching the prototype's LoginScreen: icon tile +
    /// STEP N OF M eyebrow + title, hint, a labeled tinted input, an optional
    /// entered-info summary on the password step, and an in-card CTA.
    private var stepCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous).fill(SCColor.primaryBg)
                    Image(systemName: currentIcon).font(.system(size: 22)).foregroundStyle(SCColor.primary)
                }
                .frame(width: 48, height: 48)
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(SCColor.primaryBg2, lineWidth: 1))
                VStack(alignment: .leading, spacing: 3) {
                    Text("STEP \(min(step, 3) + 1) OF \(totalSteps)")
                        .font(.system(size: 10, weight: .bold)).tracking(0.8).foregroundStyle(SCColor.primary)
                    Text(currentTitle).font(.system(size: 20, weight: .bold)).foregroundStyle(SCColor.text)
                }
                Spacer(minLength: 0)
            }

            Text(currentHint).font(.system(size: 13)).foregroundStyle(SCColor.text3)

            inputField

            if setupNotice && step == 1 {
                Label("This server has no admin account yet. Finish first-time setup in a web browser, then come back here to sign in.", systemImage: "info.circle")
                    .font(.system(size: 12)).foregroundStyle(SCColor.warning)
            }

            if step == 2 { summaryRows }

            if let errorMessage {
                Text(errorMessage).font(.system(size: 12.5)).foregroundStyle(SCColor.danger)
            }

            Button(action: advance) {
                ZStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        HStack(spacing: 8) {
                            if step >= 2 {
                                Image(systemName: "lock.fill").font(.system(size: 14))
                                Text("Sign In")
                            } else {
                                Text("Continue")
                                Image(systemName: "arrow.right").font(.system(size: 14))
                            }
                        }
                        .font(.system(size: 15, weight: .bold))
                    }
                }
                .foregroundStyle(canAdvance ? .white : SCColor.text4)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(canAdvance ? SCColor.primary : SCColor.hover))
            }
            .disabled(!canAdvance || isLoading)
        }
        .padding(.horizontal, 22).padding(.vertical, 26)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(SCColor.card.opacity(0.85)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.white.opacity(0.85), lineWidth: 0.5))
        .shadow(color: SCColor.primary.opacity(0.12), radius: 20, y: 12)
        .offset(x: shake ? 8 : 0)
    }

    private var inputField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(fieldLabel.uppercased())
                    .font(.system(size: 10, weight: .bold)).tracking(0.8).foregroundStyle(SCColor.text4)
                Spacer()
                if step == 2 {
                    Button(showPassword ? "Hide" : "Show") { showPassword.toggle() }
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(SCColor.primary)
                }
            }
            Group {
                switch step {
                case 0:
                    TextField("https://cloud.example.com", text: $serverURL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(.system(size: 14, design: .monospaced))
                case 1:
                    TextField("your_username", text: $username)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .font(.system(size: 16, weight: .semibold))
                case 2:
                    Group {
                        if showPassword {
                            TextField("••••••••", text: $password)
                        } else {
                            SecureField("••••••••", text: $password)
                        }
                    }
                    .font(.system(size: 18))
                default:
                    TextField("000000", text: $twoFACode)
                        .keyboardType(.numberPad)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                }
            }
            .focused($focused)
            .foregroundStyle(SCColor.text)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(SCColor.cardTinted))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(SCColor.border, lineWidth: 0.5))
    }

    private var summaryRows: some View {
        VStack(spacing: 6) {
            summaryRow(icon: "server.rack", label: serverURL, editStep: 0)
            summaryRow(icon: "person.fill", label: username, editStep: 1)
        }
    }

    private func summaryRow(icon: String, label: String, editStep: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(SCColor.text4)
            Text(label).font(.system(size: 12.5)).foregroundStyle(SCColor.text3).lineLimit(1)
            Button("Edit") { step = editStep; errorMessage = nil }
                .font(.system(size: 11, weight: .bold)).foregroundStyle(SCColor.primary)
            Spacer(minLength: 0)
        }
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
