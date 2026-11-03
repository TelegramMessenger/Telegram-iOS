import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import PresentationDataUtils
import ItemListUI
import AccountContext
import OpenInExternalAppUI
import ItemListPeerActionItem
import UndoUI
import WebKit
import PersistentStringHash

private final class WebBrowserSettingsControllerArguments {
    let context: AccountContext
    let updateDefaultBrowser: (String?) -> Void
    let clearCookies: () -> Void
    let clearCache: () -> Void
    let addException: (Bool) -> Void
    let removeException: (AccountWebBrowserException) -> Void
    let clearExceptions: () -> Void
    
    init(
        context: AccountContext,
        updateDefaultBrowser: @escaping (String?) -> Void,
        clearCookies: @escaping () -> Void,
        clearCache: @escaping () -> Void,
        addException: @escaping (Bool) -> Void,
        removeException: @escaping (AccountWebBrowserException) -> Void,
        clearExceptions: @escaping () -> Void
    ) {
        self.context = context
        self.updateDefaultBrowser = updateDefaultBrowser
        self.clearCookies = clearCookies
        self.clearCache = clearCache
        self.addException = addException
        self.removeException = removeException
        self.clearExceptions = clearExceptions
    }
}

private enum WebBrowserSettingsSection: Int32 {
    case browsers
    case clearCookies
    case neverExceptions
    case alwaysExceptions
    case clear
}

private enum WebBrowserSettingsControllerEntry: ItemListNodeEntry {
    case browserHeader(PresentationTheme, String)
    case browser(PresentationTheme, String, OpenInApplication?, String?, Bool, Int32)
    case browserInfo(PresentationTheme, String)
    
    case clearCookies(PresentationTheme, String)
    case clearCache(PresentationTheme, String)
    case clearCookiesInfo(PresentationTheme, String)
    
    case neverHeader(PresentationTheme, String)
    case neverAdd(PresentationTheme, String)
    case neverException(Int32, PresentationTheme, AccountWebBrowserException)
    case neverExceptionsInfo(PresentationTheme, String)
    case neverExceptionsClear(PresentationTheme, String)
    
    case alwaysHeader(PresentationTheme, String)
    case alwaysAdd(PresentationTheme, String)
    case alwaysException(Int32, PresentationTheme, AccountWebBrowserException)
    case alwaysExceptionsInfo(PresentationTheme, String)
    case alwaysExceptionsClear(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .browserHeader, .browser, .browserInfo:
                return WebBrowserSettingsSection.browsers.rawValue
            case .clearCookies, .clearCache, .clearCookiesInfo:
                return WebBrowserSettingsSection.clearCookies.rawValue
            case .neverHeader, .neverAdd, .neverException, .neverExceptionsInfo:
                return WebBrowserSettingsSection.neverExceptions.rawValue
            case .alwaysHeader, .alwaysAdd, .alwaysException, .alwaysExceptionsInfo:
                return WebBrowserSettingsSection.alwaysExceptions.rawValue
            case .neverExceptionsClear, .alwaysExceptionsClear:
                return WebBrowserSettingsSection.clear.rawValue
        }
    }
    
    var stableId: UInt64 {
        switch self {
            case .browserHeader:
                return 0
            case let .browser(_, _, _, _, _, index):
                return UInt64(1 + index)
            case .browserInfo:
                return 101
            case .clearCookies:
                return 102
            case .clearCache:
                return 103
            case .clearCookiesInfo:
                return 104
            case .neverHeader:
                return 105
            case .neverAdd:
                return 106
            case let .neverException(_, _, exception):
                return 107 + exception.domain.persistentHashValue
            case .neverExceptionsInfo:
                return 1001
            case .neverExceptionsClear:
                return 1002
            case .alwaysHeader:
                return 1003
            case .alwaysAdd:
                return 1004
            case let .alwaysException(_, _, exception):
                return 1005 + exception.domain.persistentHashValue
            case .alwaysExceptionsInfo:
                return 2000
            case .alwaysExceptionsClear:
                return 3000
        }
    }
    
    var sortId: Int32 {
        switch self {
            case .browserHeader:
                return 0
            case let .browser(_, _, _, _, _, index):
                return 1 + index
            case .browserInfo:
                return 101
            case .clearCookies:
                return 102
            case .clearCache:
                return 103
            case .clearCookiesInfo:
                return 104
            case .neverHeader:
                return 105
            case .neverAdd:
                return 106
            case let .neverException(index, _, _):
                return 107 + index
            case .neverExceptionsInfo:
                return 1001
            case .neverExceptionsClear:
                return 1002
            case .alwaysHeader:
                return 1003
            case .alwaysAdd:
                return 1004
            case let .alwaysException(index, _, _):
                return 1005 + index
            case .alwaysExceptionsInfo:
                return 2000
            case .alwaysExceptionsClear:
                return 3000
        }
    }
    
    static func ==(lhs: WebBrowserSettingsControllerEntry, rhs: WebBrowserSettingsControllerEntry) -> Bool {
        switch lhs {
            case let .browserHeader(lhsTheme, lhsText):
                if case let .browserHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .browser(lhsTheme, lhsTitle, lhsApplication, lhsIdentifier, lhsSelected, lhsIndex):
                if case let .browser(rhsTheme, rhsTitle, rhsApplication, rhsIdentifier, rhsSelected, rhsIndex) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsApplication == rhsApplication, lhsIdentifier == rhsIdentifier, lhsSelected == rhsSelected, lhsIndex == rhsIndex {
                    return true
                } else {
                    return false
                }
            case let .browserInfo(lhsTheme, lhsText):
                if case let .browserInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .clearCookies(lhsTheme, lhsText):
                if case let .clearCookies(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .clearCache(lhsTheme, lhsText):
                if case let .clearCache(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .clearCookiesInfo(lhsTheme, lhsText):
                if case let .clearCookiesInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .neverHeader(lhsTheme, lhsText):
                if case let .neverHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .neverException(lhsIndex, lhsTheme, lhsException):
                if case let .neverException(rhsIndex, rhsTheme, rhsException) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsException == rhsException {
                    return true
                } else {
                    return false
                }
            case let .neverAdd(lhsTheme, lhsText):
                if case let .neverAdd(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .neverExceptionsInfo(lhsTheme, lhsText):
                if case let .neverExceptionsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .neverExceptionsClear(lhsTheme, lhsText):
                if case let .neverExceptionsClear(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .alwaysHeader(lhsTheme, lhsText):
                if case let .alwaysHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .alwaysException(lhsIndex, lhsTheme, lhsException):
                if case let .alwaysException(rhsIndex, rhsTheme, rhsException) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsException == rhsException {
                    return true
                } else {
                    return false
                }
            case let .alwaysAdd(lhsTheme, lhsText):
                if case let .alwaysAdd(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .alwaysExceptionsInfo(lhsTheme, lhsText):
                if case let .alwaysExceptionsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .alwaysExceptionsClear(lhsTheme, lhsText):
                if case let .alwaysExceptionsClear(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
        
    static func <(lhs: WebBrowserSettingsControllerEntry, rhs: WebBrowserSettingsControllerEntry) -> Bool {
        return lhs.sortId < rhs.sortId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! WebBrowserSettingsControllerArguments
        switch self {
            case let .browserHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .browser(_, title, application, identifier, selected, _):
                return WebBrowserItem(context: arguments.context, presentationData: presentationData, systemStyle: .glass, title: title, application: application, identifier: identifier, checked: selected, sectionId: self.section) {
                    arguments.updateDefaultBrowser(identifier)
                }
            case let .browserInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .clearCookies(_, text):
                return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .generic, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.clearCookies()
                })
            case let .clearCache(_, text):
                return ItemListPeerActionItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesItemList.accentDeleteIconImage(presentationData.theme), title: text, sectionId: self.section, height: .generic, color: .accent, editing: false, action: {
                    arguments.clearCache()
                })
            case let .clearCookiesInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .neverHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .neverException(_, _, exception):
                return WebBrowserDomainExceptionItem(presentationData: presentationData, systemStyle: .glass, context: arguments.context, title: exception.title, label: exception.domain, favicon: exception.favicon, sectionId: self.section, style: .blocks, deleted: {
                    arguments.removeException(exception)
                })
            case let .neverAdd(_, text):
                return ItemListPeerActionItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesItemList.plusIconImage(presentationData.theme), title: text, sectionId: self.section, height: .generic, color: .accent, editing: false, action: {
                    arguments.addException(false)
                })
            case let .neverExceptionsInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .neverExceptionsClear(_, text):
                return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.clearExceptions()
                })
            case let .alwaysHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .alwaysException(_, _, exception):
                return WebBrowserDomainExceptionItem(presentationData: presentationData, systemStyle: .glass, context: arguments.context, title: exception.title, label: exception.domain, favicon: exception.favicon, sectionId: self.section, style: .blocks, deleted: {
                    arguments.removeException(exception)
                })
            case let .alwaysAdd(_, text):
                return ItemListPeerActionItem(presentationData: presentationData, systemStyle: .glass, icon: PresentationResourcesItemList.plusIconImage(presentationData.theme), title: text, sectionId: self.section, height: .generic, color: .accent, editing: false, action: {
                    arguments.addException(true)
                })
            case let .alwaysExceptionsInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .alwaysExceptionsClear(_, text):
                return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text, kind: .destructive, alignment: .center, sectionId: self.section, style: .blocks, action: {
                    arguments.clearExceptions()
                })
        }
    }
}

private func webBrowserSettingsControllerEntries(context: AccountContext, presentationData: PresentationData, localSettings: WebBrowserSettings, accountSettings: AccountWebBrowserSettings) -> [WebBrowserSettingsControllerEntry] {
    var entries: [WebBrowserSettingsControllerEntry] = []
    
    let options = availableOpenInOptions(context: context, item: .url(url: "https://telegram.org"))
    let defaultExternalBrowser = localSettings.defaultWebBrowser ?? "default"
    
    entries.append(.browserHeader(presentationData.theme, presentationData.strings.WebBrowser_OpenLinksIn_Title))
    entries.append(.browser(presentationData.theme, presentationData.strings.WebBrowser_Telegram, nil, nil, !accountSettings.openExternalBrowser, 0))
        
    var index: Int32 = 1
    for option in options {
        entries.append(.browser(presentationData.theme, option.title, option.application, option.identifier, accountSettings.openExternalBrowser && option.identifier == defaultExternalBrowser, index))
        index += 1
    }
    
    entries.append(.browserInfo(presentationData.theme, presentationData.strings.WebBrowser_OpenLinksInfo))
    
    entries.append(.clearCookies(presentationData.theme, presentationData.strings.WebBrowser_ClearCookies))
    entries.append(.clearCookiesInfo(presentationData.theme, presentationData.strings.WebBrowser_ClearCookies_Info))
    
    if accountSettings.openExternalBrowser {
        entries.append(.neverHeader(presentationData.theme, presentationData.strings.WebBrowser_Exceptions_OpenInApp))
        entries.append(.neverAdd(presentationData.theme, presentationData.strings.WebBrowser_Exceptions_AddException))
        
        var exceptionIndex: Int32 = 0
        for exception in accountSettings.inAppExceptions.reversed() {
            entries.append(.neverException(exceptionIndex, presentationData.theme, exception))
            exceptionIndex += 1
        }
        entries.append(.neverExceptionsInfo(presentationData.theme, presentationData.strings.WebBrowser_Exceptions_InAppInfo))
        
        if !accountSettings.inAppExceptions.isEmpty {
            entries.append(.neverExceptionsClear(presentationData.theme, presentationData.strings.WebBrowser_Exceptions_DeleteAll))
        }
    } else {
        entries.append(.alwaysHeader(presentationData.theme, presentationData.strings.WebBrowser_Exceptions_DontOpenInApp))
        entries.append(.alwaysAdd(presentationData.theme, presentationData.strings.WebBrowser_Exceptions_AddException))
        
        var exceptionIndex: Int32 = 0
        for exception in accountSettings.externalExceptions.reversed() {
            entries.append(.alwaysException(exceptionIndex, presentationData.theme, exception))
            exceptionIndex += 1
        }
        entries.append(.alwaysExceptionsInfo(presentationData.theme, presentationData.strings.WebBrowser_Exceptions_Info))
        
        if !accountSettings.externalExceptions.isEmpty {
            entries.append(.alwaysExceptionsClear(presentationData.theme, presentationData.strings.WebBrowser_Exceptions_DeleteAll))
        }
    }
        
    return entries
}

public func webBrowserSettingsController(context: AccountContext) -> ViewController {
    var clearCookiesImpl: (() -> Void)?
    var clearCacheImpl: (() -> Void)?
    var addExceptionImpl: ((Bool) -> Void)?
    var removeExceptionImpl: ((AccountWebBrowserException) -> Void)?
    var clearExceptionsImpl: (() -> Void)?
    
    let arguments = WebBrowserSettingsControllerArguments(
        context: context,
        updateDefaultBrowser: { identifier in
            let openExternalBrowser = identifier != nil
            if let identifier {
                let _ = (updateWebBrowserSettingsInteractively(accountManager: context.sharedContext.accountManager, {
                    $0.withUpdatedDefaultWebBrowser(identifier)
                })
                |> then(updateRemoteWebBrowserSettings(postbox: context.account.postbox, network: context.account.network, openExternalBrowser: openExternalBrowser))).start()
            } else {
                let _ = updateRemoteWebBrowserSettings(postbox: context.account.postbox, network: context.account.network, openExternalBrowser: openExternalBrowser).start()
            }
        },
        clearCookies: {
            clearCookiesImpl?()
        },
        clearCache: {
            clearCacheImpl?()
        },
        addException: { external in
            addExceptionImpl?(external)
        },
        removeException: { exception in
            removeExceptionImpl?(exception)
        },
        clearExceptions: {
            clearExceptionsImpl?()
        }
    )
    
    let previousSettings = Atomic<(WebBrowserSettings, AccountWebBrowserSettings)?>(value: nil)
    
    let signal = combineLatest(
        context.sharedContext.presentationData,
        context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.webBrowserSettings]),
        context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: PreferencesKeys.webBrowserSettings))
    )
    |> deliverOnMainQueue
    |> map { presentationData, sharedData, accountSettingsEntry -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let localSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.webBrowserSettings]?.get(WebBrowserSettings.self) ?? WebBrowserSettings.defaultSettings
        let accountSettings = accountSettingsEntry?.get(AccountWebBrowserSettings.self) ?? AccountWebBrowserSettings.defaultSettings
        let previousSettings = previousSettings.swap((localSettings, accountSettings))
        
        var animateChanges = false
        if let previousSettings {
            if previousSettings.0.defaultWebBrowser != localSettings.defaultWebBrowser || previousSettings.1.openExternalBrowser != accountSettings.openExternalBrowser {
                animateChanges = true
            }
            if previousSettings.1.externalExceptions.count != accountSettings.externalExceptions.count || previousSettings.1.inAppExceptions.count != accountSettings.inAppExceptions.count {
                animateChanges = true
            }
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.WebBrowser_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: webBrowserSettingsControllerEntries(context: context, presentationData: presentationData, localSettings: localSettings, accountSettings: accountSettings), style: .blocks, animateChanges: animateChanges)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    clearCookiesImpl = { [weak controller] in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let alertController = textAlertController(
            context: context,
            updatedPresentationData: nil,
            title: nil,
            text: presentationData.strings.WebBrowser_ClearCookies_ClearConfirmation_Text,
            actions: [
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                TextAlertAction(type: .defaultAction, title: presentationData.strings.WebBrowser_ClearCookies_ClearConfirmation_Clear, action: {
                    WKWebsiteDataStore.default().removeData(ofTypes: [WKWebsiteDataTypeCookies, WKWebsiteDataTypeLocalStorage, WKWebsiteDataTypeSessionStorage], modifiedSince: Date(timeIntervalSince1970: 0), completionHandler:{})
                            
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    controller?.present(UndoOverlayController(
                        presentationData: presentationData,
                        content: .info(
                            title: nil,
                            text: presentationData.strings.WebBrowser_ClearCookies_Succeed,
                            timeout: nil,
                            customUndoText: nil
                        ),
                        elevatedLayout: false,
                        position: .bottom,
                        action: { _ in return false }), in: .current
                    )
                })
            ]
        )
        controller?.present(alertController, in: .window(.root))
    }
    
    clearCacheImpl = { [weak controller] in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let alertController = textAlertController(
            context: context,
            updatedPresentationData: nil,
            title: nil,
            text: presentationData.strings.WebBrowser_ClearCache_ClearConfirmation_Text,
            actions: [
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                TextAlertAction(type: .defaultAction, title: presentationData.strings.WebBrowser_ClearCache_ClearConfirmation_Clear, action: {
                    WKWebsiteDataStore.default().removeData(ofTypes: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache], modifiedSince: Date(timeIntervalSince1970: 0), completionHandler:{})
                            
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    controller?.present(UndoOverlayController(
                        presentationData: presentationData,
                        content: .info(
                            title: nil,
                            text: presentationData.strings.WebBrowser_ClearCache_Succeed,
                            timeout: nil,
                            customUndoText: nil
                        ),
                        elevatedLayout: false,
                        position: .bottom,
                        action: { _ in return false }), in: .current
                    )
                })
            ]
        )
        controller?.present(alertController, in: .window(.root))
    }
    
    addExceptionImpl = { [weak controller] external in
        var dismissImpl: (() -> Void)?
        let linkController = webBrowserDomainController(context: context, external: external, apply: { url in
            if let url {
                let _ = (context.account.postbox.transaction { transaction -> AccountWebBrowserSettings in
                    return transaction.getPreferencesEntry(key: PreferencesKeys.webBrowserSettings)?.get(AccountWebBrowserSettings.self) ?? AccountWebBrowserSettings.defaultSettings
                }
                |> mapToSignal { settings -> Signal<Bool, NoError> in
                    return toggleWebBrowserSettingsException(postbox: context.account.postbox, network: context.account.network, openExternalBrowser: !settings.openExternalBrowser, delete: false, url: url)
                }
                |> deliverOnMainQueue).startStandalone(next: { _ in
                    dismissImpl?()
                })
            }
        })
        dismissImpl = { [weak linkController] in
            linkController?.view.endEditing(true)
            linkController?.dismiss(completion: nil)
        }
        controller?.present(linkController, in: .window(.root))
    }
    
    removeExceptionImpl = { exception in
        let url = exception.url.isEmpty ? exception.domain : exception.url
        let _ = (context.account.postbox.transaction { transaction -> AccountWebBrowserSettings in
            return transaction.getPreferencesEntry(key: PreferencesKeys.webBrowserSettings)?.get(AccountWebBrowserSettings.self) ?? AccountWebBrowserSettings.defaultSettings
        }
        |> mapToSignal { settings -> Signal<Bool, NoError> in
            return toggleWebBrowserSettingsException(postbox: context.account.postbox, network: context.account.network, openExternalBrowser: !settings.openExternalBrowser, delete: true, url: url)
        }).start()
    }
    
    clearExceptionsImpl = { [weak controller] in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let alertController = textAlertController(
            context: context,
            updatedPresentationData: nil,
            title: nil,
            text: presentationData.strings.WebBrowser_Exceptions_ClearConfirmation_Text,
            actions: [
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                TextAlertAction(type: .defaultAction, title: presentationData.strings.WebBrowser_Exceptions_ClearConfirmation_Clear, action: {
                    let _ = deleteWebBrowserSettingsExceptions(postbox: context.account.postbox, network: context.account.network).start()
                })
            ]
        )
        controller?.present(alertController, in: .window(.root))
    }
    
    return controller
}
