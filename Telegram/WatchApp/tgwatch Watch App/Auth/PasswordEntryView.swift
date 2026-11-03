import SwiftUI

struct PasswordEntryView: View {
    let info: PasswordInfo

    @Environment(TDClient.self) private var client
    @State private var password = ""
    @State private var submitting = false
    @State private var errorMessage: String?

    /// Drives the error `.alert`: presented whenever `errorMessage` is set,
    /// and clears it on dismiss. Mirrors the optional-state→Bool binding
    /// pattern used by `AccountsListView`.
    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if !info.hint.isEmpty {
                        Text("Hint: \(info.hint)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Enter your cloud password")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .accessibilityIdentifier("passwordField")
                    Button(action: submit) {
                        Group {
                            if submitting {
                                ProgressView()
                            } else {
                                Text("Continue")
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .padding(.vertical, 6)
                        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("passwordContinue")
                }
                .padding()
            }
            .navigationTitle("Password")
            .navigationBarTitleDisplayMode(.inline)
            // Force the nav bar to materialize so the title renders under the
            // clock — watchOS-26 skips chrome on a NavigationStack root view
            // otherwise (same reason as ChatListView).
            .toolbar(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        returnToQr()
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .disabled(submitting)
                    .accessibilityIdentifier("passwordBackToQr")
                }
            }
            .alert(errorMessage ?? "", isPresented: errorAlertBinding) {
                Button("OK", role: .cancel) { errorMessage = nil }
            }
            .onAppear {
#if DEBUG
                if password.isEmpty,
                   let preset = ProcessInfo.processInfo.environment["TGWATCH_PASSWORD"],
                   !preset.isEmpty {
                    password = preset
                    submit()
                }
#endif
            }
            .accountSwitcherSheet(presentation: .sheet, logoutAffordance: .suppressed)
        }
    }

    /// Returns to QR code entry. Blocked while a password check is in flight
    /// (TDLib rejects `requestQrCodeAuthentication` with a pending auth query).
    /// On success TDLib transitions to `waitOtherDeviceConfirmation` and this
    /// view is torn down; on failure the message lands in the existing alert.
    private func returnToQr() {
        guard !submitting else { return }
        Task {
            errorMessage = await client.returnToQrCode()
        }
    }

    private func submit() {
        // Button is always painted enabled; ignore taps when there's nothing
        // to submit or a submission is already in flight.
        guard !password.isEmpty, !submitting else { return }
        let passwordCopy = password
        submitting = true
        Task {
            let error = await client.submitPassword(passwordCopy)
            submitting = false
            errorMessage = error
        }
    }
}
