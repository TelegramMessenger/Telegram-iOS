import SwiftUI

struct ContentView: View {
    @Environment(TDClient.self) private var client

    var body: some View {
        switch client.authState {
        case .starting:
            LoadingView(label: "Starting…")
        case .waitTdlibParameters:
            LoadingView(label: "Configuring…")
        case .waitPhoneNumber:
            LoadingView(label: "Preparing QR…")
        case .waitCode:
            ErrorView(message: "Unexpected SMS-code prompt during QR login.")
        case .waitOtherDeviceConfirmation(let link):
            QrLoginView(link: link)
        case .waitPassword(let info):
            PasswordEntryView(info: info)
        case .ready:
            if let store = client.chatList {
                ChatListView(store: store)
            } else {
                LoadingView(label: "Loading…")
            }
        case .loggingOut:
            LoadingView(label: "Logging out…")
        case .closed:
            ClosedView()
        case .failed(let message):
            ErrorView(message: message)
        }
    }
}
