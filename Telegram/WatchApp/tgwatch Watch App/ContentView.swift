import SwiftUI

struct ContentView: View {
    @Environment(TDClient.self) private var client

    var body: some View {
        switch client.authState {
        case .starting:
            LoadingView(label: L("Watch.Auth.Starting"))
        case .waitTdlibParameters:
            LoadingView(label: L("Watch.Auth.Configuring"))
        case .waitPhoneNumber:
            LoadingView(label: L("Watch.Auth.PreparingQr"))
        case .waitCode:
            ErrorView(message: L("Watch.Auth.UnexpectedCodePrompt"))
        case .waitOtherDeviceConfirmation(let link):
            QrLoginView(link: link)
        case .waitPassword(let info):
            PasswordEntryView(info: info)
        case .ready:
            if let store = client.chatList {
                ChatListView(store: store)
            } else {
                LoadingView(label: L("Watch.Common.Loading"))
            }
        case .loggingOut:
            LoadingView(label: L("Watch.Auth.LoggingOut"))
        case .closed:
            ClosedView()
        case .failed(let message):
            ErrorView(message: message)
        }
    }
}
