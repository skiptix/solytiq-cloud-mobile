import SwiftUI
import UIKit

struct TwoFASheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var qrImage: UIImage?
    @State private var secret: String?
    @State private var code = ""
    @State private var isEnabled: Bool
    @State private var errorMessage: String?
    @State private var isLoading = false

    init() { _isEnabled = State(initialValue: false) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                if isEnabled {
                    VStack(spacing: 10) {
                        Image(systemName: "lock.shield.fill").font(.system(size: 40)).foregroundStyle(SCColor.success)
                        Text("Two-factor authentication is enabled.").font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.top, 40)
                    TextField("Enter code to disable", text: $code)
                        .keyboardType(.numberPad).multilineTextAlignment(.center)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(SCColor.card))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(SCColor.border, lineWidth: 1))
                        .padding(.horizontal, 32)
                    Button("Disable 2FA", role: .destructive) { Task { await disable() } }
                        .disabled(code.count < 6)
                } else if let qrImage {
                    Image(uiImage: qrImage).resizable().interpolation(.none)
                        .frame(width: 190, height: 190)
                        .padding(.top, 20)
                    if let secret {
                        Text(secret).font(.system(size: 12, design: .monospaced)).foregroundStyle(SCColor.text3)
                    }
                    Text("Scan with your authenticator app, then enter the 6-digit code.")
                        .font(.system(size: 12.5)).foregroundStyle(SCColor.text3).multilineTextAlignment(.center).padding(.horizontal, 32)
                    TextField("000000", text: $code)
                        .keyboardType(.numberPad).multilineTextAlignment(.center)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(SCColor.card))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(SCColor.border, lineWidth: 1))
                        .padding(.horizontal, 32)
                    Button("Enable 2FA") { Task { await enable() } }
                        .disabled(code.count < 6)
                } else if isLoading {
                    ProgressView().padding(.top, 60)
                }

                if let errorMessage {
                    Text(errorMessage).font(.system(size: 12.5)).foregroundStyle(SCColor.danger)
                }
                Spacer()
            }
            .padding(.bottom, 20)
            .navigationTitle("Two-Factor Auth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .task { await load() }
        }
    }

    private func load() async {
        isEnabled = appState.currentUser?.totpEnabled ?? false
        guard !isEnabled else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await AuthAPI().setup2FA()
            secret = response.secret
            if let range = response.qrCode.range(of: "base64,") {
                let base64 = String(response.qrCode[range.upperBound...])
                if let data = Data(base64Encoded: base64) { qrImage = UIImage(data: data) }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func enable() async {
        do {
            try await AuthAPI().enable2FA(code: code)
            isEnabled = true
            if let user = try? await AuthAPI().me() { appState.currentUser = user }
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Invalid code."
        }
    }

    private func disable() async {
        do {
            try await AuthAPI().disable2FA(code: code)
            isEnabled = false
            if let user = try? await AuthAPI().me() { appState.currentUser = user }
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Invalid code."
        }
    }
}
