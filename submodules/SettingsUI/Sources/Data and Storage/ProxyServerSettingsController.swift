import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import MtProtoKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import UrlEscaping
import UrlHandling
import ShareController

private func shareLink(for server: ProxyServerSettings) -> String {
    var link: String
    switch server.connection {
    case let .mtp(secret):
        let secret = MTProxySecret.parseData(secret)?.serializeToString() ?? ""
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
    case connectionServer(PresentationTheme, PresentationStrings, String, String)
    case connectionPort(PresentationTheme, PresentationStrings, String, String)
    
    case credentialsHeader(PresentationTheme, String)
    case credentialsUsername(PresentationTheme, PresentationStrings, String, String)
    case credentialsPassword(PresentationTheme, PresentationStrings, String, String)
    case credentialsSecret(PresentationTheme, PresentationStrings, String, String)
    
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
                return 12
        }
    }
    
    static func <(lhs: ProxySettingsEntry, rhs: ProxySettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! proxyServerSettingsControllerArguments
        switch self {
            case let .usePasteboardSettings(_, title):
                return ItemListActionItem(presentationData: presentationData, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.usePasteboardSettings()
                })
            case let .usePasteboardInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .modeSocks5(_, text, value):
                return ItemListCheckboxItem(presentationData: presentationData, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateState { state in
                        var state = state
                        state.mode = .socks5
                        return state
                    }
                })
            case let .modeMtp(_, text, value):
                return ItemListCheckboxItem(presentationData: presentationData, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateState { state in
                        var state = state
                        state.mode = .mtp
                        return state
                    }
                })
            case let .connectionHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .connectionServer(_, _, placeholder, text):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: text, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), sectionId: self.section, textUpdated: { value in
                    arguments.updateState { current in
                        var state = current
                        state.host = value
                        return state
                    }
                }, action: {})
            case let .connectionPort(_, _, placeholder, text):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: text, placeholder: placeholder, type: .number, sectionId: self.section, textUpdated: { value in
                    arguments.updateState { current in
                        var state = current
                        state.port = value
                        return state
                    }
                }, action: {})
            case let .credentialsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .credentialsUsername(_, _, placeholder, text):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: text, placeholder: placeholder, sectionId: self.section, textUpdated: { value in
                    arguments.updateState { current in
                        var state = current
                        state.username = value
                        return state
                    }
                }, action: {})
            case let .credentialsPassword(_, _, placeholder, text):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: text, placeholder: placeholder, type: .password, sectionId: self.section, textUpdated: { value in
                    arguments.updateState { current in
                        var state = current
                        state.password = value
                        return state
                    }
                }, action: {})
            case let .credentialsSecret(_, _, placeholder, text):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: text, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), sectionId: self.section, textUpdated: { value in
                    arguments.updateState { current in
                        var state = current
                        state.secret = value
                        return state
                    }
                }, action: {})
            case let .share(_, text, enabled):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: enabled ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
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
                let secretIsValid = MTProxySecret.parse(self.secret) != nil
                if !secretIsValid {
                    return false
                }
        }
        return true
    }
}

private func proxyServerSettingsControllerEntries(presentationData: PresentationData, state: ProxyServerSettingsControllerState, pasteboardSettings: ProxyServerSettings?) -> [ProxySettingsEntry] {
    var entries: [ProxySettingsEntry] = []
    
    if let _ = pasteboardSettings {
        entries.append(.usePasteboardSettings(presentationData.theme, presentationData.strings.SocksProxySetup_PasteFromClipboard))
    }
    
    entries.append(.modeSocks5(presentationData.theme, presentationData.strings.SocksProxySetup_ProxySocks5, state.mode == .socks5))
    entries.append(.modeMtp(presentationData.theme, presentationData.strings.SocksProxySetup_ProxyTelegram, state.mode == .mtp))
    
    entries.append(.connectionHeader(presentationData.theme, presentationData.strings.SocksProxySetup_Connection.uppercased()))
    entries.append(.connectionServer(presentationData.theme, presentationData.strings, presentationData.strings.SocksProxySetup_Hostname, state.host))
    entries.append(.connectionPort(presentationData.theme, presentationData.strings, presentationData.strings.SocksProxySetup_Port, state.port))
    
    switch state.mode {
        case .socks5:
            entries.append(.credentialsHeader(presentationData.theme, presentationData.strings.SocksProxySetup_Credentials))
            entries.append(.credentialsUsername(presentationData.theme, presentationData.strings, presentationData.strings.SocksProxySetup_Username, state.username))
            entries.append(.credentialsPassword(presentationData.theme, presentationData.strings, presentationData.strings.SocksProxySetup_Password, state.password))
        case .mtp:
            entries.append(.credentialsHeader(presentationData.theme, presentationData.strings.SocksProxySetup_RequiredCredentials))
            entries.append(.credentialsSecret(presentationData.theme, presentationData.strings, presentationData.strings.SocksProxySetup_SecretPlaceholder, state.secret))
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
                let parsedSecret = MTProxySecret.parse(state.secret)
                if let parsedSecret = parsedSecret {
                    return ProxyServerSettings(host: state.host, port: port, connection: .mtp(secret: parsedSecret.serialize()))
                }
        }
    }
    return nil
}

public func proxyServerSettingsController(context: AccountContext, currentSettings: ProxyServerSettings? = nil) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    return proxyServerSettingsController(context: context, presentationData: presentationData, updatedPresentationData: context.sharedContext.presentationData, accountManager: context.sharedContext.accountManager, postbox: context.account.postbox, network: context.account.network, currentSettings: currentSettings)
}

func proxyServerSettingsController(context: AccountContext? = nil, presentationData: PresentationData, updatedPresentationData: Signal<PresentationData, NoError>, accountManager: AccountManager<TelegramAccountManagerTypes>, postbox: Postbox, network: Network, currentSettings: ProxyServerSettings?) -> ViewController {
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
            if let secret = proxy.secret, let parsedSecret = MTProxySecret.parseData(secret) {
                pasteboardSettings = ProxyServerSettings(host: proxy.host, port: proxy.port, connection: .mtp(secret: parsedSecret.serialize()))
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
    
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
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
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        let rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: state.isComplete, action: {
            if let proxyServerSettings = proxyServerSettings(with: state) {
                let _ = (updateProxySettingsInteractively(accountManager: accountManager, { settings in
                    var settings = settings
                    if let currentSettings = currentSettings {
                        if let index = settings.servers.firstIndex(of: currentSettings) {
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
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.SocksProxySetup_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: proxyServerSettingsControllerEntries(presentationData: presentationData, state: state, pasteboardSettings: pasteboardSettings), style: .blocks, emptyStateItem: nil, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(presentationData: ItemListPresentationData(presentationData), updatedPresentationData: updatedPresentationData |> map(ItemListPresentationData.init(_:)), state: signal, tabBarItem: nil)
    controller.navigationPresentation = .modal
    presentControllerImpl = { [weak controller] c, d in
        controller?.present(c, in: .window(.root), with: d)
    }
    dismissImpl = { [weak controller] in
        let _ = controller?.dismiss()
    }
    shareImpl = { [weak controller] in
        let state = stateValue.with { $0 }
        guard let server = proxyServerSettings(with: state) else {
            return
        }
        
        let link = shareLink(for: server)
        controller?.view.endEditing(true)
        
        let controller = ShareProxyServerActionSheetController(presentationData: presentationData, updatedPresentationData: updatedPresentationData, link: link)
        presentControllerImpl?(controller, nil)
    }
    
    return controller
}

