import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import MtProtoKitDynamic

private final class proxyServerSettingsControllerArguments {
    let updateState: ((ProxyServerSettingsControllerState) -> ProxyServerSettingsControllerState) -> Void
    let share: () -> Void
    
    init(updateState: @escaping ((ProxyServerSettingsControllerState) -> ProxyServerSettingsControllerState) -> Void, share: @escaping () -> Void) {
        self.updateState = updateState
        self.share = share
    }
}

private enum ProxySettingsSection: Int32 {
    case mode
    case connection
    case credentials
    case share
}

private enum ProxySettingsEntry: ItemListNodeEntry {
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
            case .modeSocks5:
                return 0
            case .modeMtp:
                return 1
            case .connectionHeader:
                return 2
            case .connectionServer:
                return 3
            case .connectionPort:
                return 4
            case .credentialsHeader:
                return 5
            case .credentialsUsername:
                return 6
            case .credentialsPassword:
                return 7
            case .credentialsSecret:
                return 8
            case .share:
                return 9
        }
    }
    
    static func ==(lhs: ProxySettingsEntry, rhs: ProxySettingsEntry) -> Bool {
        switch lhs {
            case let .modeSocks5(lhsTheme, lhsText, lhsValue):
                if case let .modeSocks5(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .modeMtp(lhsTheme, lhsText, lhsValue):
                if case let .modeMtp(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .connectionHeader(lhsTheme, lhsText):
                if case let .connectionHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .connectionServer(lhsTheme, lhsText, lhsValue):
                if case let .connectionServer(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .connectionPort(lhsTheme, lhsText, lhsValue):
                if case let .connectionPort(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .credentialsHeader(lhsTheme, lhsText):
                if case let .credentialsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .credentialsUsername(lhsTheme, lhsText, lhsValue):
                if case let .credentialsUsername(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .credentialsPassword(lhsTheme, lhsText, lhsValue):
                if case let .credentialsPassword(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .credentialsSecret(lhsTheme, lhsText, lhsValue):
                if case let .credentialsSecret(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .share(lhsTheme, lhsText, lhsValue):
                if case let .share(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ProxySettingsEntry, rhs: ProxySettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: proxyServerSettingsControllerArguments) -> ListViewItem {
        switch self {
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
                return ItemListSingleLineInputItem(theme: theme, title: NSAttributedString(), text: text, placeholder: placeholder, type: .regular, sectionId: self.section, textUpdated: { value in
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

private func proxyServerSettingsControllerEntries(presentationData: PresentationData, state: ProxyServerSettingsControllerState) -> [ProxySettingsEntry] {
    var entries: [ProxySettingsEntry] = []
    
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

func proxyServerSettingsController(account: Account, currentSettings: ProxyServerSettings?) -> ViewController {
    var currentMode: ProxyServerSettingsControllerMode = .socks5
    var currentUsername: String?
    var currentPassword: String?
    var currentSecret: String?
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
    }
    let initialState = ProxyServerSettingsControllerState(mode: currentMode, host: currentSettings?.host ?? "", port: (currentSettings?.port).flatMap { "\($0)" } ?? "", username: currentUsername ?? "", password: currentPassword ?? "", secret: currentSecret ?? "")
    let stateValue = Atomic(value: initialState)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let updateState: ((ProxyServerSettingsControllerState) -> ProxyServerSettingsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentImpl: ((ViewController, Any?) -> Void)?
    var dismissImpl: (() -> Void)?
    
    let arguments = proxyServerSettingsControllerArguments(updateState: { f in
        updateState(f)
    }, share: {
        let state = stateValue.with { $0 }
        if state.isComplete {
            let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
            var result: String
            switch state.mode {
                case .mtp:
                    result = "tg://proxy?server=\(state.host)&port=\(state.port)"
                    result += "&secret=\((state.secret as NSString).addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryValueAllowed) ?? "")"
                case .socks5:
                    result = "tg://socks?server=\(state.host)&port=\(state.port)"
                    if !state.username.isEmpty {
                        result += "&user=\((state.username as NSString).addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryValueAllowed) ?? "")&pass=\((state.password as NSString).addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryValueAllowed) ?? "")"
                    }
            }
            
            UIPasteboard.general.string = result
            
            presentImpl?(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: presentationData.strings.Username_LinkCopied, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
        }
    })
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get()) |> deliverOnMainQueue
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState<ProxySettingsEntry>, ProxySettingsEntry.ItemGenerationArguments)) in
            let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                dismissImpl?()
            })
            let rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: state.isComplete, action: {
                var proxyServerSettings: ProxyServerSettings?
                if state.isComplete, let port = Int32(state.port) {
                    switch state.mode {
                        case .socks5:
                            proxyServerSettings = ProxyServerSettings(host: state.host, port: port, connection: .socks5(username: state.username.isEmpty ? nil : state.username, password: state.password.isEmpty ? nil : state.password))
                        case .mtp:
                            let data = dataWithHexString(state.secret)
                            var secretIsValid = false
                            if data.count == 16 {
                                secretIsValid = true
                            } else if data.count == 17 && MTSocksProxySettings.secretSupportsExtendedPadding(data) {
                                secretIsValid = true
                            }
                            if secretIsValid {
                                proxyServerSettings = ProxyServerSettings(host: state.host, port: port, connection: .mtp(secret: data))
                            }
                    }
                }
                if let proxyServerSettings = proxyServerSettings {
                    let _ = (updateProxySettingsInteractively(postbox: account.postbox, network: account.network, { settings in
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
            let listState = ItemListNodeState(entries: proxyServerSettingsControllerEntries(presentationData: presentationData, state: state), style: .blocks, emptyStateItem: nil, animateChanges: false)
            
            return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(account: account, state: signal)
    presentImpl = { [weak controller] c, d in
        controller?.present(c, in: .window(.root), with: d)
    }
    dismissImpl = { [weak controller] in
        let _ = controller?.dismiss()
    }
    return controller
}

