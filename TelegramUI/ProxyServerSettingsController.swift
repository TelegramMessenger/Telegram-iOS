import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import MtProtoKitDynamic

private func shareLink(for server: ProxyServerSettings) -> String {
    var link: String
    switch server.connection {
    case let .mtp(secret):
        let secret = hexString(secret)
        link = "https://t.me/proxy?server=\(server.host)&port=\(server.port)"
        link += "&secret=\(secret.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryValueAllowed) ?? "")"
    case let .socks5(username, password):
        link = "https://t.me/socks?server=\(server.host)&port=\(server.port)"
        link += "&user=\(username?.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryValueAllowed) ?? "")&pass=\(password?.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryValueAllowed) ?? "")"
    }
    return link
}

private final class proxyServerSettingsControllerArguments {
    let updateState: ((ProxyServerSettingsControllerState) -> ProxyServerSettingsControllerState) -> Void
    let share: () -> Void
    let usePasteboardSettings: () -> Void
    
    init(updateState: @escaping ((ProxyServerSettingsControllerState) -> ProxyServerSettingsControllerState) -> Void, share: @escaping () -> Void, usePasteboardSettings: @escaping () -> Void) {
        self.updateState = updateState
        self.share = share
        self.usePasteboardSettings = usePasteboardSettings
    }
}

private enum ProxySettingsSection: Int32 {
    case pasteboard
    case mode
    case connection
    case credentials
    case share
}

private enum ProxySettingsEntry: ItemListNodeEntry {
    case usePasteboardSettings(PresentationTheme, String)
    case usePasteboardInfo(PresentationTheme, String)
    
    case modeSocks5(PresentationTheme, String, Bool)
    case modeMtp(PresentationTheme, String, Bool)
    
    case connectionHeader(PresentationTheme, String)
    case connectionServer(PresentationTheme, String, String)
    case connectionPort(PresentationTheme, String, String)
    
    case credentialsHeader(PresentationTheme, String)
    case credentialsUsername(PresentationTheme, String, String)
    case credentialsPassword(PresentationTheme, String, String)
    case credentialsSecret(PresentationTheme, String, String)
    
    case share(PresentationTheme, String, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .usePasteboardSettings, .usePasteboardInfo:
                return ProxySettingsSection.pasteboard.rawValue
            case .modeSocks5, .modeMtp:
                return ProxySettingsSection.mode.rawValue
            case .connectionHeader, .connectionServer, .connectionPort:
                return ProxySettingsSection.connection.rawValue
            case .credentialsHeader, .credentialsUsername, .credentialsPassword, .credentialsSecret:
                return ProxySettingsSection.credentials.rawValue
            case .share:
                return ProxySettingsSection.share.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .usePasteboardSettings:
                return 0
            case .usePasteboardInfo:
                return 1
            case .modeSocks5:
                return 2
            case .modeMtp:
                return 3
            case .connectionHeader:
                return 4
            case .connectionServer:
                return 5
            case .connectionPort:
                return 6
            case .credentialsHeader:
                return 7
            case .credentialsUsername:
                return 8
            case .credentialsPassword:
                return 9
            case .credentialsSecret:
                return 10
            case .share:
                return 11
        }
    }
    
    static func <(lhs: ProxySettingsEntry, rhs: ProxySettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: proxyServerSettingsControllerArguments) -> ListViewItem {
        switch self {
            case let .usePasteboardSettings(theme, title):
                return ItemListActionItem(theme: theme, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.usePasteboardSettings()
                })
            case let .usePasteboardInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .modeSocks5(theme, text, value):
                return ItemListCheckboxItem(theme: theme, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateState { state in
                        var state = state
                        state.mode = .socks5
                        return state
                    }
                })
            case let .modeMtp(theme, text, value):
                return ItemListCheckboxItem(theme: theme, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateState { state in
                        var state = state
                        state.mode = .mtp
                        return state
                    }
                })
            case let .connectionHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .connectionServer(theme, placeholder, text):
                return ItemListSingleLineInputItem(theme: theme, title: NSAttributedString(), text: text, placeholder: placeholder, sectionId: self.section, textUpdated: { value in
                    arguments.updateState { current in
                        var state = current
                        state.host = value
                        return state
                    }
                }, action: {})
            case let .connectionPort(theme, placeholder, text):
                return ItemListSingleLineInputItem(theme: theme, title: NSAttributedString(), text: text, placeholder: placeholder, type: .number, sectionId: self.section, textUpdated: { value in
                    arguments.updateState { current in
                        var state = current
                        state.port = value
                        return state
                    }
                }, action: {})
            case let .credentialsHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .credentialsUsername(theme, placeholder, text):
                return ItemListSingleLineInputItem(theme: theme, title: NSAttributedString(), text: text, placeholder: placeholder, sectionId: self.section, textUpdated: { value in
                    arguments.updateState { current in
                        var state = current
                        state.username = value
                        return state
                    }
                }, action: {})
            case let .credentialsPassword(theme, placeholder, text):
                return ItemListSingleLineInputItem(theme: theme, title: NSAttributedString(), text: text, placeholder: placeholder, type: .password, sectionId: self.section, textUpdated: { value in
                    arguments.updateState { current in
                        var state = current
                        state.password = value
                        return state
                    }
                }, action: {})
            case let .credentialsSecret(theme, placeholder, text):
                return ItemListSingleLineInputItem(theme: theme, title: NSAttributedString(), text: text, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), sectionId: self.section, textUpdated: { value in
                    arguments.updateState { current in
                        var state = current
                        state.secret = value
                        return state
                    }
                }, action: {})
            case let .share(theme, text, enabled):
                return ItemListActionItem(theme: theme, title: text, kind: enabled ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.share()
                })
        }
    }
}

private enum ProxyServerSettingsControllerMode {
    case socks5
    case mtp
}

private struct ProxyServerSettingsControllerState: Equatable {
    var mode: ProxyServerSettingsControllerMode
    var host: String
    var port: String
    var username: String
    var password: String
    var secret: String
    
    var isComplete: Bool {
        if self.host.isEmpty || self.port.isEmpty || Int(self.port) == nil {
            return false
        }
        switch self.mode {
            case .socks5:
                break
            case .mtp:
                let data = dataWithHexString(self.secret)
                var secretIsValid = false
                if data.count == 16 {
                    secretIsValid = true
                } else if data.count == 17 && MTSocksProxySettings.secretSupportsExtendedPadding(data) {
                    secretIsValid = true
                }
                if !secretIsValid {
                    return false
                }
        }
        return true
    }
}

private func proxyServerSettingsControllerEntries(presentationData: (theme: PresentationTheme, strings: PresentationStrings), state: ProxyServerSettingsControllerState, pasteboardSettings: ProxyServerSettings?) -> [ProxySettingsEntry] {
    var entries: [ProxySettingsEntry] = []
    
    if let _ = pasteboardSettings {
        entries.append(.usePasteboardSettings(presentationData.theme, presentationData.strings.SocksProxySetup_PasteFromClipboard))
    }
    
    entries.append(.modeSocks5(presentationData.theme, presentationData.strings.SocksProxySetup_ProxySocks5, state.mode == .socks5))
    entries.append(.modeMtp(presentationData.theme, presentationData.strings.SocksProxySetup_ProxyTelegram, state.mode == .mtp))
    
    entries.append(.connectionHeader(presentationData.theme, presentationData.strings.SocksProxySetup_Connection.uppercased()))
    entries.append(.connectionServer(presentationData.theme, presentationData.strings.SocksProxySetup_Hostname, state.host))
    entries.append(.connectionPort(presentationData.theme, presentationData.strings.SocksProxySetup_Port, state.port))
    
    switch state.mode {
        case .socks5:
            entries.append(.credentialsHeader(presentationData.theme, presentationData.strings.SocksProxySetup_Credentials))
            entries.append(.credentialsUsername(presentationData.theme, presentationData.strings.SocksProxySetup_Username, state.username))
            entries.append(.credentialsPassword(presentationData.theme, presentationData.strings.SocksProxySetup_Password, state.password))
        case .mtp:
            entries.append(.credentialsHeader(presentationData.theme, presentationData.strings.SocksProxySetup_RequiredCredentials))
            entries.append(.credentialsSecret(presentationData.theme, presentationData.strings.SocksProxySetup_SecretPlaceholder, state.secret))
    }
    
    entries.append(.share(presentationData.theme, presentationData.strings.Conversation_ContextMenuShare, state.isComplete))
    
    return entries
}

private func proxyServerSettings(with state: ProxyServerSettingsControllerState) -> ProxyServerSettings? {
    if state.isComplete, let port = Int32(state.port) {
        switch state.mode {
            case .socks5:
                return ProxyServerSettings(host: state.host, port: port, connection: .socks5(username: state.username.isEmpty ? nil : state.username, password: state.password.isEmpty ? nil : state.password))
            case .mtp:
                let data = dataWithHexString(state.secret)
                var secretIsValid = false
                if data.count == 16 {
                    secretIsValid = true
                } else if data.count == 17 && MTSocksProxySettings.secretSupportsExtendedPadding(data) {
                    secretIsValid = true
                }
                if secretIsValid {
                    return ProxyServerSettings(host: state.host, port: port, connection: .mtp(secret: data))
                }
        }
    }
    return nil
}

func proxyServerSettingsController(theme: PresentationTheme, strings: PresentationStrings, updatedPresentationData: Signal<(theme: PresentationTheme, strings: PresentationStrings), NoError>, postbox: Postbox, network: Network, currentSettings: ProxyServerSettings?) -> ViewController {
    var currentMode: ProxyServerSettingsControllerMode = .socks5
    var currentUsername: String?
    var currentPassword: String?
    var currentSecret: String?
    var pasteboardSettings: ProxyServerSettings?
    if let currentSettings = currentSettings {
        switch currentSettings.connection {
            case let .socks5(username, password):
                currentUsername = username
                currentPassword = password
                currentMode = .socks5
            case let .mtp(secret):
                currentSecret = hexString(secret)
                currentMode = .mtp
        }
    } else {
        if let proxy = parseProxyUrl(UIPasteboard.general.string ?? "") {
            if let secret = proxy.secret, secret.count == 16 || (secret.count == 17 && MTSocksProxySettings.secretSupportsExtendedPadding(secret)) {
                pasteboardSettings = ProxyServerSettings(host: proxy.host, port: proxy.port, connection: .mtp(secret: secret))
            } else {
                pasteboardSettings = ProxyServerSettings(host: proxy.host, port: proxy.port, connection: .socks5(username: proxy.username, password: proxy.password))
            }
        }
    }

    let initialState = ProxyServerSettingsControllerState(mode: currentMode, host: currentSettings?.host ?? "", port: (currentSettings?.port).flatMap { "\($0)" } ?? "", username: currentUsername ?? "", password: currentPassword ?? "", secret: currentSecret ?? "")
    let stateValue = Atomic(value: initialState)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let updateState: ((ProxyServerSettingsControllerState) -> ProxyServerSettingsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentImpl: ((ViewController, Any?) -> Void)?
    var dismissImpl: (() -> Void)?
    
    var shareImpl: (() -> Void)?
    
    let arguments = proxyServerSettingsControllerArguments(updateState: { f in
        updateState(f)
    }, share: {
        shareImpl?()
    }, usePasteboardSettings: {
        if let pasteboardSettings = pasteboardSettings {
            updateState { state in
                var state = state
                state.host = pasteboardSettings.host
                state.port = "\(pasteboardSettings.port)"
                switch pasteboardSettings.connection {
                    case let .socks5(username, password):
                        state.mode = .socks5
                        state.username = username ?? ""
                        state.password = password ?? ""
                    case let .mtp(secret):
                        state.mode = .mtp
                        state.secret = hexString(secret)
                }
                return state
            }
        }
    })
    
    let signal = combineLatest(updatedPresentationData, statePromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState<ProxySettingsEntry>, ProxySettingsEntry.ItemGenerationArguments)) in
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        let rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: state.isComplete, action: {
            if let proxyServerSettings = proxyServerSettings(with: state) {
                let _ = (updateProxySettingsInteractively(postbox: postbox, network: network, { settings in
                    var settings = settings
                    if let currentSettings = currentSettings {
                        if let index = settings.servers.index(of: currentSettings) {
                            settings.servers[index] = proxyServerSettings
                            if settings.activeServer == currentSettings {
                                settings.activeServer = proxyServerSettings
                            }
                        }
                    } else {
                        settings.servers.append(proxyServerSettings)
                        if settings.servers.count == 1 {
                            settings.activeServer = proxyServerSettings
                        }
                    }
                    return settings
                }) |> deliverOnMainQueue).start(completed: {
                    dismissImpl?()
                })
            }
        })
        
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.SocksProxySetup_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(entries: proxyServerSettingsControllerEntries(presentationData: presentationData, state: state, pasteboardSettings: pasteboardSettings), style: .blocks, emptyStateItem: nil, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(theme: theme, strings: strings, updatedPresentationData: updatedPresentationData, state: signal, tabBarItem: nil)
    presentImpl = { [weak controller] c, d in
        controller?.present(c, in: .window(.root), with: d)
    }
    dismissImpl = { [weak controller] in
        let _ = controller?.dismiss()
    }
    
    shareImpl = {
        let state = stateValue.with { $0 }
        guard let server = proxyServerSettings(with: state) else {
            return
        }
        
        let controller = ShareProxyServerActionSheetController(theme: theme, strings: strings, updatedPresentationData: updatedPresentationData, link: shareLink(for: server))
        presentImpl?(controller, nil)
    }
    
    return controller
}

