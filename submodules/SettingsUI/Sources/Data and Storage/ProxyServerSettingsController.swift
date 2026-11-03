import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import MtProtoKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import UrlEscaping
import UrlHandling
import QrCodeUI

private final class ProxyServerSettingsControllerArguments {
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
    case modeWeb(PresentationTheme, String, Bool)
    
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
            case .modeSocks5, .modeMtp, .modeWeb:
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
            case .modeWeb:
                return 4
            case .connectionHeader:
                return 5
            case .connectionServer:
                return 6
            case .connectionPort:
                return 7
            case .credentialsHeader:
                return 8
            case .credentialsUsername:
                return 9
            case .credentialsPassword:
                return 10
            case .credentialsSecret:
                return 11
            case .share:
                return 13
        }
    }
    
    static func <(lhs: ProxySettingsEntry, rhs: ProxySettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ProxyServerSettingsControllerArguments
        switch self {
            case let .usePasteboardSettings(_, title):
                return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.usePasteboardSettings()
                })
            case let .usePasteboardInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .modeSocks5(_, text, value):
                return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateState { state in
                        return state.withMode(.socks5)
                    }
                })
            case let .modeMtp(_, text, value):
                return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateState { state in
                        return state.withMode(.mtp)
                    }
                })
            case let .modeWeb(_, text, value):
                return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateState { state in
                        return state.withMode(.web)
                    }
                })
            case let .connectionHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .connectionServer(_, _, placeholder, text):
                return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(), text: text, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), sectionId: self.section, textUpdated: { value in
                    arguments.updateState { current in
                        var state = current
                        state.host = value
                        return state
                    }
                }, action: {})
            case let .connectionPort(_, _, placeholder, text):
                return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(), text: text, placeholder: placeholder, type: .number, sectionId: self.section, textUpdated: { value in
                    arguments.updateState { current in
                        var state = current
                        state.port = value
                        return state
                    }
                }, action: {})
            case let .credentialsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .credentialsUsername(_, _, placeholder, text):
                return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(), text: text, placeholder: placeholder, sectionId: self.section, textUpdated: { value in
                    arguments.updateState { current in
                        var state = current
                        state.username = value
                        return state
                    }
                }, action: {})
            case let .credentialsPassword(_, _, placeholder, text):
                return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(), text: text, placeholder: placeholder, type: .password, sectionId: self.section, textUpdated: { value in
                    arguments.updateState { current in
                        var state = current
                        state.password = value
                        return state
                    }
                }, action: {})
            case let .credentialsSecret(_, _, placeholder, text):
                return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(), text: text, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), sectionId: self.section, textUpdated: { value in
                    arguments.updateState { current in
                        var state = current
                        state.secret = value
                        return state
                    }
                }, action: {})
            case let .share(_, text, enabled):
                return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: enabled ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.share()
                })
        }
    }
}

enum ProxyServerSettingsControllerMode {
    case socks5
    case mtp
    case web
}

/// A WEB proxy is host + secret only: its port is always 443, so the editor omits the
/// port row and `isComplete` must not demand one.
func proxyServerSettingsControllerMode(for connection: ProxyServerConnection) -> ProxyServerSettingsControllerMode {
    switch connection {
        case .socks5:
            return .socks5
        case .mtp:
            return .mtp
        case .web:
            return .web
    }
}

struct ProxyServerSettingsControllerState: Equatable {
    var mode: ProxyServerSettingsControllerMode
    var host: String
    var port: String
    var username: String
    var password: String
    var secret: String
    
    /// Switching away from `.web` must drop the base path from the shared server field.
    /// Only a WEB address is `host/base-path`; SOCKS5 and MTProxy take a bare host, and
    /// leaving the path in place saves a server whose host contains a slash and can never
    /// resolve. Trimmed rather than canonicalized, so the user's own casing survives.
    func withMode(_ mode: ProxyServerSettingsControllerMode) -> ProxyServerSettingsControllerState {
        var state = self
        state.mode = mode
        if case .web = mode {
        } else if let separator = state.host.firstIndex(of: "/") {
            state.host = String(state.host[state.host.startIndex ..< separator])
        }
        return state
    }

    var isComplete: Bool {
        if self.host.isEmpty {
            return false
        }
        switch self.mode {
            case .socks5, .mtp:
                if self.port.isEmpty || Int(self.port) == nil {
                    return false
                }
            case .web:
                break
        }
        switch self.mode {
            case .socks5:
                break
            case .mtp:
                let secretIsValid = MTProxySecret.parse(self.secret) != nil
                if !secretIsValid {
                    return false
                }
            case .web:
                // Deliberately not MTProxySecret.parse: that accepts `ee` and domain
                // secret forms the WEB transport cannot carry.
                if canonicalWebProxyAddress(self.host) == nil || parseWebProxySecret(self.secret) == nil {
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
    entries.append(.modeWeb(presentationData.theme, presentationData.strings.SocksProxySetup_ProxyWeb, state.mode == .web))
    
    entries.append(.connectionHeader(presentationData.theme, presentationData.strings.SocksProxySetup_Connection.uppercased()))
    entries.append(.connectionServer(presentationData.theme, presentationData.strings, presentationData.strings.SocksProxySetup_Hostname, state.host))
    if case .web = state.mode {
        // A WEB relay is always HTTPS on 443; ProxyServerSettings.init pins it.
    } else {
        entries.append(.connectionPort(presentationData.theme, presentationData.strings, presentationData.strings.SocksProxySetup_Port, state.port))
    }
    
    switch state.mode {
        case .socks5:
            entries.append(.credentialsHeader(presentationData.theme, presentationData.strings.SocksProxySetup_Credentials))
            entries.append(.credentialsUsername(presentationData.theme, presentationData.strings, presentationData.strings.SocksProxySetup_Username, state.username))
            entries.append(.credentialsPassword(presentationData.theme, presentationData.strings, presentationData.strings.SocksProxySetup_Password, state.password))
        case .mtp:
            entries.append(.credentialsHeader(presentationData.theme, presentationData.strings.SocksProxySetup_RequiredCredentials))
            entries.append(.credentialsSecret(presentationData.theme, presentationData.strings, presentationData.strings.SocksProxySetup_SecretPlaceholder, state.secret))
        case .web:
            entries.append(.credentialsHeader(presentationData.theme, presentationData.strings.SocksProxySetup_RequiredCredentials))
            entries.append(.credentialsSecret(presentationData.theme, presentationData.strings, presentationData.strings.SocksProxySetup_SecretPlaceholder, state.secret))
    }
    
    entries.append(.share(presentationData.theme, presentationData.strings.Conversation_ContextMenuShare, state.isComplete))
    
    return entries
}

func proxyServerSettings(with state: ProxyServerSettingsControllerState) -> ProxyServerSettings? {
    guard state.isComplete else {
        return nil
    }
    if case .web = state.mode {
        return makeWebProxySettings(address: state.host, secret: state.secret)
    }
    guard let port = Int32(state.port) else {
        return nil
    }
    switch state.mode {
        case .socks5:
            return ProxyServerSettings(host: state.host, port: port, connection: .socks5(username: state.username.isEmpty ? nil : state.username, password: state.password.isEmpty ? nil : state.password))
        case .mtp:
            if let parsedSecret = MTProxySecret.parse(state.secret) {
                return ProxyServerSettings(host: state.host, port: port, connection: .mtp(secret: parsedSecret.serialize()))
            }
            return nil
        case .web:
            return nil
    }
}

public func proxyServerSettingsController(context: AccountContext, currentSettings: ProxyServerSettings? = nil) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    return proxyServerSettingsController(sharedContext: context.sharedContext, context: context, presentationData: presentationData, updatedPresentationData: context.sharedContext.presentationData, accountManager: context.sharedContext.accountManager, network: context.account.network, currentSettings: currentSettings)
}

func proxyServerSettingsController(sharedContext: SharedAccountContext, context: AccountContext? = nil, presentationData: PresentationData, updatedPresentationData: Signal<PresentationData, NoError>, accountManager: AccountManager<TelegramAccountManagerTypes>, network: Network, currentSettings: ProxyServerSettings?) -> ViewController {
    var currentMode: ProxyServerSettingsControllerMode = .socks5
    var currentAddress: String?
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
            case let .web(secret, _):
                // The editor's server field holds the whole `host/base-path` address, so the
                // base path survives a round trip through it.
                currentAddress = currentSettings.webProxyAddress
                currentSecret = webProxySecretString(secret)
                currentMode = .web
        }
    } else {
        let pasteboardText = UIPasteboard.general.string ?? ""
        if let webSettings = parseWebProxySettingsLink(pasteboardText) {
            pasteboardSettings = webSettings
        } else if let proxy = parseProxyUrl(sharedContext: sharedContext, url: pasteboardText) {
            if let secret = proxy.secret, let parsedSecret = MTProxySecret.parseData(secret) {
                pasteboardSettings = ProxyServerSettings(host: proxy.host, port: proxy.port, connection: .mtp(secret: parsedSecret.serialize()))
            } else {
                pasteboardSettings = ProxyServerSettings(host: proxy.host, port: proxy.port, connection: .socks5(username: proxy.username, password: proxy.password))
            }
        }
    }

    let initialState = ProxyServerSettingsControllerState(mode: currentMode, host: currentAddress ?? currentSettings?.host ?? "", port: (currentSettings?.port).flatMap { "\($0)" } ?? "", username: currentUsername ?? "", password: currentPassword ?? "", secret: currentSecret ?? "")
    let stateValue = Atomic(value: initialState)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let updateState: ((ProxyServerSettingsControllerState) -> ProxyServerSettingsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    
    var shareImpl: (() -> Void)?
    
    let arguments = ProxyServerSettingsControllerArguments(updateState: { f in
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
                    case let .web(secret, _):
                        state.mode = .web
                        state.host = pasteboardSettings.webProxyAddress ?? pasteboardSettings.host
                        state.secret = webProxySecretString(secret)
                }
                return state
            }
        }
    })
    
    let signal = combineLatest(updatedPresentationData, statePromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var presentationData = presentationData
        let updatedTheme = presentationData.theme.withModalBlocksBackground()
        presentationData = presentationData.withUpdated(theme: updatedTheme)
        
        let leftNavigationButton = ItemListNavigationButton(content: .icon(.close), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        let rightNavigationButton = ItemListNavigationButton(content: .icon(.done), style: .bold, enabled: state.isComplete, action: {
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
                        let wasEmpty = settings.servers.isEmpty
                        if !settings.servers.contains(proxyServerSettings) {
                            settings.servers.append(proxyServerSettings)
                        }
                        if wasEmpty && settings.servers.count == 1 {
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
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    dismissImpl = { [weak controller] in
        let _ = controller?.dismiss()
    }
    shareImpl = { [weak controller] in
        let state = stateValue.with { $0 }
        guard let server = proxyServerSettings(with: state) else {
            return
        }
        controller?.view.endEditing(true)
        
        let controller = QrCodeScreen(
            sharedContext: sharedContext,
            updatedPresentationData: (presentationData, updatedPresentationData),
            subject: .proxy(server: server, externalLink: false)
        )
        pushControllerImpl?(controller)
    }
    
    return controller
}
