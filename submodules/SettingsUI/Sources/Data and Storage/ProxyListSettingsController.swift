import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import MtProtoKit
import ItemListUI
import PresentationDataUtils
import AccountContext
import UrlEscaping
import ShareController

private final class ProxySettingsControllerArguments {
    let toggleEnabled: (Bool) -> Void
    let addNewServer: () -> Void
    let activateServer: (ProxyServerSettings) -> Void
    let editServer: (ProxyServerSettings) -> Void
    let removeServer: (ProxyServerSettings) -> Void
    let setServerWithRevealedOptions: (ProxyServerSettings?, ProxyServerSettings?) -> Void
    let toggleUseForCalls: (Bool) -> Void
    let shareProxyList: () -> Void
    
    init(toggleEnabled: @escaping (Bool) -> Void, addNewServer: @escaping () -> Void, activateServer: @escaping (ProxyServerSettings) -> Void, editServer: @escaping (ProxyServerSettings) -> Void, removeServer: @escaping (ProxyServerSettings) -> Void, setServerWithRevealedOptions: @escaping (ProxyServerSettings?, ProxyServerSettings?) -> Void, toggleUseForCalls: @escaping (Bool) -> Void, shareProxyList: @escaping () -> Void) {
        self.toggleEnabled = toggleEnabled
        self.addNewServer = addNewServer
        self.activateServer = activateServer
        self.editServer = editServer
        self.removeServer = removeServer
        self.setServerWithRevealedOptions = setServerWithRevealedOptions
        self.toggleUseForCalls = toggleUseForCalls
        self.shareProxyList = shareProxyList
    }
}

private enum ProxySettingsControllerSection: Int32 {
    case enabled
    case servers
    case share
    case calls
}

private enum ProxyServerAvailabilityStatus: Equatable {
    case checking
    case notAvailable
    case available(Int32)
}

private struct DisplayProxyServerStatus: Equatable {
    let activity: Bool
    let text: String
    let textActive: Bool
}

private enum ProxySettingsControllerEntryId: Equatable, Hashable {
    case index(Int)
    case server(String, Int32, ProxyServerConnection)
}

private enum ProxySettingsControllerEntry: ItemListNodeEntry {
    case enabled(PresentationTheme, String, Bool, Bool)
    case serversHeader(PresentationTheme, String)
    case addServer(PresentationTheme, String, Bool)
    case server(Int, PresentationTheme, PresentationStrings, ProxyServerSettings, Bool, DisplayProxyServerStatus, ProxySettingsServerItemEditing, Bool)
    case shareProxyList(PresentationTheme, String)
    case useForCalls(PresentationTheme, String, Bool)
    case useForCallsInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .enabled:
                return ProxySettingsControllerSection.enabled.rawValue
            case .serversHeader, .addServer, .server:
                return ProxySettingsControllerSection.servers.rawValue
            case .shareProxyList:
                return ProxySettingsControllerSection.share.rawValue
            case .useForCalls, .useForCallsInfo:
                return ProxySettingsControllerSection.calls.rawValue
        }
    }
    
    var stableId: ProxySettingsControllerEntryId {
        switch self {
            case .enabled:
                return .index(0)
            case .serversHeader:
                return .index(1)
            case .addServer:
                return .index(2)
            case let .server(_, _, _, settings, _, _, _, _):
                return .server(settings.host, settings.port, settings.connection)
            case .shareProxyList:
                return .index(3)
            case .useForCalls:
                return .index(4)
            case .useForCallsInfo:
                return .index(5)
        }
    }
    
    static func ==(lhs: ProxySettingsControllerEntry, rhs: ProxySettingsControllerEntry) -> Bool {
        switch lhs {
            case let .enabled(lhsTheme, lhsText, lhsValue, lhsCreatesNew):
                if case let .enabled(rhsTheme, rhsText, rhsValue, rhsCreatesNew) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue, lhsCreatesNew == rhsCreatesNew {
                    return true
                } else {
                    return false
                }
            case let .serversHeader(lhsTheme, lhsText):
                if case let .serversHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .addServer(lhsTheme, lhsText, lhsEditing):
                if case let .addServer(rhsTheme, rhsText, rhsEditing) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsEditing == rhsEditing {
                    return true
                } else {
                    return false
                }
            case let .server(lhsIndex, lhsTheme, lhsStrings, lhsSettings, lhsActive, lhsStatus, lhsEditing, lhsEnabled):
                if case let .server(rhsIndex, rhsTheme, rhsStrings, rhsSettings, rhsActive, rhsStatus, rhsEditing, rhsEnabled) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsSettings == rhsSettings, lhsActive == rhsActive, lhsStatus == rhsStatus, lhsEditing == rhsEditing, lhsEnabled == rhsEnabled {
                    return true
                } else {
                    return false
                }
            case let .shareProxyList(lhsTheme, lhsText):
                if case let .shareProxyList(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
        }
    }
    
    static func <(lhs: ProxySettingsControllerEntry, rhs: ProxySettingsControllerEntry) -> Bool {
        switch lhs {
            case .enabled:
                switch rhs {
                    case .enabled:
                        return false
                    default:
                        return true
                }
            case .serversHeader:
                switch rhs {
                    case .enabled, .serversHeader:
                        return false
                    default:
                        return true
                }
            case .addServer:
                switch rhs {
                    case .enabled, .serversHeader, .addServer:
                        return false
                    default:
                        return true
                }
            case let .server(lhsIndex, _, _, _, _, _, _, _):
                switch rhs {
                    case .enabled, .serversHeader, .addServer:
                        return false
                    case let .server(rhsIndex, _, _, _, _, _, _, _):
                        return lhsIndex < rhsIndex
                    default:
                        return true
                }
            case .shareProxyList:
                switch rhs {
                    case .enabled, .serversHeader, .addServer, .server, .shareProxyList:
                        return false
                    default:
                        return true
            }
            case .useForCalls:
                switch rhs {
                    case .enabled, .serversHeader, .addServer, .server, .shareProxyList, .useForCalls:
                        return false
                    default:
                        return true
                }
            case .useForCallsInfo:
                return false
        }
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! ProxySettingsControllerArguments
        switch self {
            case let .enabled(_, text, value, createsNew):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enableInteractiveChanges: !createsNew, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    if createsNew {
                        arguments.addNewServer()
                    } else {
                        arguments.toggleEnabled(value)
                    }
                })
            case let .serversHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .addServer(_, text, _):
                return ProxySettingsActionItem(presentationData: presentationData, title: text, icon: .add, sectionId: self.section, editing: false, action: {
                    arguments.addNewServer()
                })
            case let .server(_, theme, strings, settings, active, status, editing, enabled):
                return ProxySettingsServerItem(theme: theme, strings: strings, server: settings, activity: status.activity, active: active, color: enabled ? .accent : .secondary, label: status.text, labelAccent: status.textActive, editing: editing, sectionId: self.section, action: {
                    arguments.activateServer(settings)
                }, infoAction: {
                    arguments.editServer(settings)
                }, setServerWithRevealedOptions: { lhs, rhs in
                    arguments.setServerWithRevealedOptions(lhs, rhs)
                }, removeServer: { _ in
                    arguments.removeServer(settings)
                })
            case let .shareProxyList(_, text):
                return ProxySettingsActionItem(presentationData: presentationData, title: text, sectionId: self.section, editing: false, action: {
                    arguments.shareProxyList()
                })
            case let .useForCalls(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enableInteractiveChanges: true, enabled: true, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.toggleUseForCalls(value)
                })
            case let .useForCallsInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func proxySettingsControllerEntries(theme: PresentationTheme, strings: PresentationStrings, state: ProxySettingsControllerState, proxySettings: ProxySettings, statuses: [ProxyServerSettings: ProxyServerStatus], connectionStatus: ConnectionStatus) -> [ProxySettingsControllerEntry] {
    var entries: [ProxySettingsControllerEntry] = []

    entries.append(.enabled(theme, strings.ChatSettings_ConnectionType_UseProxy, proxySettings.enabled, proxySettings.servers.isEmpty))
    entries.append(.serversHeader(theme, strings.SocksProxySetup_SavedProxies))
    entries.append(.addServer(theme, strings.SocksProxySetup_AddProxy, state.editing))
    var index = 0
    for server in proxySettings.servers {
        let status: ProxyServerStatus = statuses[server] ?? .checking
        let displayStatus: DisplayProxyServerStatus
        if proxySettings.enabled && server == proxySettings.activeServer {
            switch connectionStatus {
                case .waitingForNetwork:
                    displayStatus = DisplayProxyServerStatus(activity: true, text: strings.State_WaitingForNetwork.lowercased(), textActive: false)
                case .connecting, .updating:
                    displayStatus = DisplayProxyServerStatus(activity: true, text: strings.SocksProxySetup_ProxyStatusConnecting, textActive: false)
                case .online:
                    var text = strings.SocksProxySetup_ProxyStatusConnected
                    if case let .available(rtt) = status {
                        let pingTime: Int = Int(rtt * 1000.0)
                        text = text + ", \(strings.SocksProxySetup_ProxyStatusPing("\(pingTime)").string)"
                    }
                    displayStatus = DisplayProxyServerStatus(activity: false, text: text, textActive: true)
            }
        } else {
            var text: String
            switch server.connection {
                case .socks5:
                    text = strings.ChatSettings_ConnectionType_UseSocks5
                case .mtp:
                    text = strings.SocksProxySetup_ProxyTelegram
            }
            switch status {
                case .notAvailable:
                    text = text + ", " + strings.SocksProxySetup_ProxyStatusUnavailable
                    displayStatus = DisplayProxyServerStatus(activity: false, text: text, textActive: false)
                case .checking:
                    text = text + ", " + strings.SocksProxySetup_ProxyStatusChecking
                    displayStatus = DisplayProxyServerStatus(activity: false, text: text, textActive: false)
                case let .available(rtt):
                    let pingTime: Int = Int(rtt * 1000.0)
                    text = text + ", \(strings.SocksProxySetup_ProxyStatusPing("\(pingTime)").string)"
                    displayStatus = DisplayProxyServerStatus(activity: false, text: text, textActive: false)
            }
        }
        entries.append(.server(index, theme, strings, server, server == proxySettings.activeServer, displayStatus, ProxySettingsServerItemEditing(editable: true, editing: state.editing, revealed: state.revealedServer == server), proxySettings.enabled))
        index += 1
    }
    if !proxySettings.servers.isEmpty {
        entries.append(.shareProxyList(theme, strings.SocksProxySetup_ShareProxyList))
    }
    
    if let activeServer = proxySettings.activeServer, case .socks5 = activeServer.connection {
        entries.append(.useForCalls(theme, strings.SocksProxySetup_UseForCalls, proxySettings.useForCalls))
        entries.append(.useForCallsInfo(theme, strings.SocksProxySetup_UseForCallsHelp))
    }
    
    return entries
}

private struct ProxySettingsControllerState: Equatable {
    var editing: Bool = false
    var revealedServer: ProxyServerSettings? = nil
}

public enum ProxySettingsControllerMode {
    case `default`
    case modal
}

public func proxySettingsController(context: AccountContext, mode: ProxySettingsControllerMode = .default) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    return proxySettingsController(accountManager: context.sharedContext.accountManager, context: context, postbox: context.account.postbox, network: context.account.network, mode: mode, presentationData: presentationData, updatedPresentationData: context.sharedContext.presentationData)
}

public func proxySettingsController(accountManager: AccountManager<TelegramAccountManagerTypes>, context: AccountContext? = nil, postbox: Postbox, network: Network, mode: ProxySettingsControllerMode, presentationData: PresentationData, updatedPresentationData: Signal<PresentationData, NoError>) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    let stateValue = Atomic(value: ProxySettingsControllerState())
    let statePromise = ValuePromise<ProxySettingsControllerState>(stateValue.with { $0 })
    let updateState: ((ProxySettingsControllerState) -> ProxySettingsControllerState) -> Void = { f in
        var changed = false
        let value = stateValue.modify { current in
            let updated = f(current)
            if updated != current {
                changed = true
            }
            return updated
        }
        if changed {
            statePromise.set(value)
        }
    }
    
    var shareProxyListImpl: (() -> Void)?
    
    let arguments = ProxySettingsControllerArguments(toggleEnabled: { value in
        let _ = updateProxySettingsInteractively(accountManager: accountManager, { current in
            var current = current
            current.enabled = value
            return current
        }).start()
    }, addNewServer: {
        pushControllerImpl?(proxyServerSettingsController(presentationData: presentationData, updatedPresentationData: updatedPresentationData, accountManager: accountManager, postbox: postbox, network: network, currentSettings: nil))
    }, activateServer: { server in
        let _ = updateProxySettingsInteractively(accountManager: accountManager, { current in
            var current = current
            if current.activeServer != server {
                if let _ = current.servers.firstIndex(of: server) {
                    current.activeServer = server
                    current.enabled = true
                }
            }
            return current
        }).start()
    }, editServer: { server in
        pushControllerImpl?(proxyServerSettingsController(presentationData: presentationData, updatedPresentationData: updatedPresentationData, accountManager: accountManager, postbox: postbox, network: network, currentSettings: server))
    }, removeServer: { server in
        let _ = updateProxySettingsInteractively(accountManager: accountManager, { current in
            var current = current
            if let index = current.servers.firstIndex(of: server) {
                current.servers.remove(at: index)
                if current.activeServer == server {
                    current.activeServer = nil
                    current.enabled = false
                }
            }
            return current
        }).start()
    }, setServerWithRevealedOptions: { server, fromServer in
        updateState { state in
            var state = state
            if (server == nil && fromServer == state.revealedServer) || (server != nil && fromServer == nil) {
                state.revealedServer = server
            }
            return state
        }
    }, toggleUseForCalls: { value in
        let _ = updateProxySettingsInteractively(accountManager: accountManager, { current in
            var current = current
            current.useForCalls = value
            return current
        }).start()
    }, shareProxyList: {
       shareProxyListImpl?()
    })
    
    let proxySettings = Promise<ProxySettings>()
    proxySettings.set(accountManager.sharedData(keys: [SharedDataKeys.proxySettings])
    |> map { sharedData -> ProxySettings in
        if let value = sharedData.entries[SharedDataKeys.proxySettings]?.get(ProxySettings.self) {
            return value
        } else {
            return ProxySettings.defaultSettings
        }
    })
    
    let statusesContext = ProxyServersStatuses(network: network, servers: proxySettings.get()
    |> map { proxySettings -> [ProxyServerSettings] in
        return proxySettings.servers
    })
    
    let signal = combineLatest(updatedPresentationData, statePromise.get(), proxySettings.get(), statusesContext.statuses(), network.connectionStatus)
    |> map { presentationData, state, proxySettings, statuses, connectionStatus -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var leftNavigationButton: ItemListNavigationButton?
        if case .modal = mode {
            leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                dismissImpl?()
            })
        }
        
        let rightNavigationButton: ItemListNavigationButton?
        if proxySettings.servers.isEmpty {
            rightNavigationButton = nil
        } else if state.editing {
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                updateState { state in
                    var state = state
                    state.editing = false
                    return state
                }
            })
        } else {
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Edit), style: .regular, enabled: true, action: {
                updateState { state in
                    var state = state
                    state.editing = true
                    return state
                }
            })
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.SocksProxySetup_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: proxySettingsControllerEntries(theme: presentationData.theme, strings: presentationData.strings, state: state, proxySettings: proxySettings, statuses: statuses, connectionStatus: connectionStatus), style: .blocks)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(presentationData: ItemListPresentationData(presentationData), updatedPresentationData: updatedPresentationData |> map(ItemListPresentationData.init(_:)), state: signal, tabBarItem: nil)
    controller.navigationPresentation = .modal
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    controller.setReorderEntry({ (fromIndex: Int, toIndex: Int, entries: [ProxySettingsControllerEntry]) -> Signal<Bool, NoError> in
        let fromEntry = entries[fromIndex]
        guard case let .server(_, _, _, fromServer, _, _, _, _) = fromEntry else {
            return .single(false)
        }
        var referenceServer: ProxyServerSettings?
        var beforeAll = false
        var afterAll = false
        if toIndex < entries.count {
            switch entries[toIndex] {
                case let .server(_, _, _, toServer, _, _, _, _):
                    referenceServer = toServer
                default:
                    if entries[toIndex] < fromEntry {
                        beforeAll = true
                    } else {
                        afterAll = true
                    }
            }
        } else {
            afterAll = true
        }

        return updateProxySettingsInteractively(accountManager: accountManager, { current in
            var current = current
            if let index = current.servers.firstIndex(of: fromServer) {
                current.servers.remove(at: index)
            }
            if let referenceServer = referenceServer {
                var inserted = false
                for i in 0 ..< current.servers.count {
                    if current.servers[i] == referenceServer {
                        if fromIndex < toIndex {
                            current.servers.insert(fromServer, at: i + 1)
                        } else {
                            current.servers.insert(fromServer, at: i)
                        }
                        inserted = true
                        break
                    }
                }
                if !inserted {
                    current.servers.append(fromServer)
                }
            } else if beforeAll {
                current.servers.insert(fromServer, at: 0)
            } else if afterAll {
                current.servers.append(fromServer)
            }
            return current
        })
    })
    
    shareProxyListImpl = { [weak controller] in
        guard let context = context, let strongController = controller else {
            return
        }
        let _ = (proxySettings.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { settings in
                var result = ""
                for server in settings.servers {
                    if !result.isEmpty {
                        result += "\n\n"
                    }
                    
                    var string: String
                    switch server.connection {
                    case let .mtp(secret):
                        let secret = MTProxySecret.parseData(secret)?.serializeToString() ?? ""
                        string = "https://t.me/proxy?server=\(server.host)&port=\(server.port)"
                        string += "&secret=\((secret as NSString).addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryValueAllowed) ?? "")"
                    case let .socks5(username, password):
                        string = "https://t.me/socks?server=\(server.host)&port=\(server.port)"
                        if let username = username, let password = password {
                            string += "&user=\((username as NSString).addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryValueAllowed) ?? "")&pass=\((password as NSString).addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryValueAllowed) ?? "")"
                        }
                    }
                    
                    result += string
                }
                
                presentExternalShare(context: context, text: result, parentController: strongController)
            })
    }
    
    return controller
}
