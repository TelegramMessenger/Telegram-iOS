import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class ProxySettingsControllerArguments {
    let updateState: ((ProxySettingsControllerState) -> ProxySettingsControllerState) -> Void
    let share: () -> Void
    
    init(updateState: @escaping ((ProxySettingsControllerState) -> ProxySettingsControllerState) -> Void, share: @escaping () -> Void) {
        self.updateState = updateState
        self.share = share
    }
}

private enum ProxySettingsSection: Int32 {
    case mode
    case connection
    case credentials
    case calls
    case share
}

private enum ProxySettingsEntry: ItemListNodeEntry {
    case modeDisabled(PresentationTheme, String, Bool)
    case modeSocks5(PresentationTheme, String, Bool)
    
    case connectionHeader(PresentationTheme, String)
    case connectionServer(PresentationTheme, String, String)
    case connectionPort(PresentationTheme, String, String)
    
    case credentialsHeader(PresentationTheme, String)
    case credentialsUsername(PresentationTheme, String, String)
    case credentialsPassword(PresentationTheme, String, String)
    
    case useForCalls(PresentationTheme, String, Bool)
    case useForCallsInfo(PresentationTheme, String)
    
    case share(PresentationTheme, String, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .modeDisabled, .modeSocks5:
                return ProxySettingsSection.mode.rawValue
            case .connectionHeader, .connectionServer, .connectionPort:
                return ProxySettingsSection.connection.rawValue
            case .credentialsHeader, .credentialsUsername, .credentialsPassword:
                return ProxySettingsSection.credentials.rawValue
            case .useForCalls, .useForCallsInfo:
                return ProxySettingsSection.calls.rawValue
            case .share:
                return ProxySettingsSection.share.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .modeDisabled:
                return 0
            case .modeSocks5:
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
            case .useForCalls:
                return 8
            case .useForCallsInfo:
                return 9
            case .share:
                return 10
        }
    }
    
    static func ==(lhs: ProxySettingsEntry, rhs: ProxySettingsEntry) -> Bool {
        switch lhs {
            case let .modeDisabled(lhsTheme, lhsText, lhsValue):
                if case let .modeDisabled(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .modeSocks5(lhsTheme, lhsText, lhsValue):
                if case let .modeSocks5(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
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
            case let .useForCalls(lhsTheme, lhsText, lhsValue):
                if case let .useForCalls(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .useForCallsInfo(lhsTheme, lhsText):
                if case let .useForCallsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
    
    func item(_ arguments: ProxySettingsControllerArguments) -> ListViewItem {
        switch self {
            case let .modeDisabled(theme, text, value):
                return ItemListCheckboxItem(theme: theme, title: text, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateState { current in
                        var state = current
                        state.enabled = false
                        return state
                    }
                })
            case let .modeSocks5(theme, text, value):
                return ItemListCheckboxItem(theme: theme, title: text, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateState { current in
                        var state = current
                        state.enabled = true
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
            case let .useForCalls(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.updateState { current in
                        var state = current
                        state.useForCalls = value
                        return state
                    }
                })
            case let .useForCallsInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .share(theme, text, enabled):
                return ItemListActionItem(theme: theme, title: text, kind: enabled ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.share()
                })
        }
    }
}

private struct ProxySettingsControllerState: Equatable {
    var enabled: Bool
    var host: String
    var port: String
    var username: String
    var password: String
    var useForCalls: Bool
    
    static func ==(lhs: ProxySettingsControllerState, rhs: ProxySettingsControllerState) -> Bool {
        if lhs.enabled != rhs.enabled {
            return false
        }
        if lhs.host != rhs.host {
            return false
        }
        if lhs.port != rhs.port {
            return false
        }
        if lhs.username != rhs.username {
            return false
        }
        if lhs.password != rhs.password {
            return false
        }
        if lhs.useForCalls != rhs.useForCalls {
            return false
        }
        return true
    }
    
    var isComplete: Bool {
        if !self.enabled {
            return false
        }
        if self.host.isEmpty || self.port.isEmpty || Int(self.port) == nil {
            return false
        }
        return true
    }
}

private func proxySettingsControllerEntries(presentationData: PresentationData, state: ProxySettingsControllerState) -> [ProxySettingsEntry] {
    var entries: [ProxySettingsEntry] = []
    
    entries.append(.modeDisabled(presentationData.theme, presentationData.strings.SocksProxySetup_TypeNone, !state.enabled))
    entries.append(.modeSocks5(presentationData.theme, presentationData.strings.SocksProxySetup_TypeSocks, state.enabled))
    
    if state.enabled {
        entries.append(.connectionHeader(presentationData.theme, presentationData.strings.SocksProxySetup_Connection.uppercased()))
        entries.append(.connectionServer(presentationData.theme, presentationData.strings.SocksProxySetup_Hostname, state.host))
        entries.append(.connectionPort(presentationData.theme, presentationData.strings.SocksProxySetup_Port, state.port))
        
        entries.append(.credentialsHeader(presentationData.theme, presentationData.strings.SocksProxySetup_Credentials))
        entries.append(.credentialsUsername(presentationData.theme, presentationData.strings.SocksProxySetup_Username, state.username))
        entries.append(.credentialsPassword(presentationData.theme, presentationData.strings.SocksProxySetup_Password, state.password))
        
        entries.append(.useForCalls(presentationData.theme, presentationData.strings.SocksProxySetup_UseForCalls, state.useForCalls))
        entries.append(.useForCallsInfo(presentationData.theme, presentationData.strings.SocksProxySetup_UseForCallsHelp))
        
        entries.append(.share(presentationData.theme, presentationData.strings.Conversation_ContextMenuShare, state.isComplete))
    }
    
    return entries
}

func proxySettingsController(account: Account, currentSettings: ProxySettings?) -> ViewController {
    let initialState = ProxySettingsControllerState(enabled: currentSettings != nil, host: currentSettings?.host ?? "", port: (currentSettings?.port).flatMap { "\($0)" } ?? "", username: currentSettings?.username ?? "", password: currentSettings?.password ?? "", useForCalls: currentSettings?.useForCalls ?? false)
    let stateValue = Atomic(value: initialState)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let updateState: ((ProxySettingsControllerState) -> ProxySettingsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentImpl: ((ViewController, Any?) -> Void)?
    var dismissImpl: (() -> Void)?
    
    let arguments = ProxySettingsControllerArguments(updateState: { f in
        updateState(f)
    }, share: {
        let state = stateValue.with { $0 }
        if state.enabled && state.isComplete {
            let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
            var result = "tg://socks?server=\(state.host)&port=\(state.port)"
            if !state.username.isEmpty {
                result += "&user=\(state.username)&pass=\(state.password)"
            }
            
            UIPasteboard.general.string = result
            
            presentImpl?(standardTextAlertController(title: nil, text: presentationData.strings.Username_LinkCopied, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
        }
    })
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get()) |> deliverOnMainQueue
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState<ProxySettingsEntry>, ProxySettingsEntry.ItemGenerationArguments)) in
            let rightNavigationButton = ItemListNavigationButton(title: presentationData.strings.Common_Done, style: .bold, enabled: !state.enabled || state.isComplete, action: {
                var proxySettings: ProxySettings?
                if state.enabled && state.isComplete, let port = Int32(state.port) {
                    proxySettings = ProxySettings(host: state.host, port: port, username: state.username.isEmpty ? nil : state.username, password: state.password.isEmpty ? nil : state.password, useForCalls: state.useForCalls)
                }
                let _ = applyProxySettings(postbox: account.postbox, network: account.network, settings: proxySettings).start()
                dismissImpl?()
            })
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.SocksProxySetup_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
            let listState = ItemListNodeState(entries: proxySettingsControllerEntries(presentationData: presentationData, state: state), style: .blocks, emptyStateItem: nil, animateChanges: false)
            
            return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(account: account, state: signal)
    presentImpl = { [weak controller] c, d in
        controller?.present(c, in: .window(.root), with: d)
    }
    dismissImpl = { [weak controller] in
        let _ = (controller?.navigationController as? NavigationController)?.popViewController(animated: true)
    }
    return controller
}

