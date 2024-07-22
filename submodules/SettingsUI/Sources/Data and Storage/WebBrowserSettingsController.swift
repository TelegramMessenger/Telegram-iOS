import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import AccountContext
import OpenInExternalAppUI
import ItemListPeerActionItem
import UndoUI
import WebKit
import LinkPresentation

private final class WebBrowserSettingsControllerArguments {
    let context: AccountContext
    let updateDefaultBrowser: (String?) -> Void
    let updateAutologin: (Bool) -> Void
    let clearCookies: () -> Void
    let addException: () -> Void
    let clearExceptions: () -> Void
    
    init(
        context: AccountContext,
        updateDefaultBrowser: @escaping (String?) -> Void,
        updateAutologin: @escaping (Bool) -> Void,
        clearCookies: @escaping () -> Void,
        addException: @escaping () -> Void,
        clearExceptions: @escaping () -> Void
    ) {
        self.context = context
        self.updateDefaultBrowser = updateDefaultBrowser
        self.updateAutologin = updateAutologin
        self.clearCookies = clearCookies
        self.addException = addException
        self.clearExceptions = clearExceptions
    }
}

private enum WebBrowserSettingsSection: Int32 {
    case browsers
    case autologin
    case clearCookies
    case exceptions
}

private enum WebBrowserSettingsControllerEntry: ItemListNodeEntry {
    case browserHeader(PresentationTheme, String)
    case browser(PresentationTheme, String, OpenInApplication?, String?, Bool, Int32)
    
    case autologin(PresentationTheme, String, Bool)
    case autologinInfo(PresentationTheme, String)
    
    case clearCookies(PresentationTheme, String)
    case clearCookiesInfo(PresentationTheme, String)
    
    case exceptionsHeader(PresentationTheme, String)
    case exceptionsAdd(PresentationTheme, String)
    case exception(Int32, PresentationTheme, WebBrowserException)
    case exceptionsClear(PresentationTheme, String)
    case exceptionsInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .browserHeader, .browser:
                return WebBrowserSettingsSection.browsers.rawValue
            case .autologin, .autologinInfo:
                return WebBrowserSettingsSection.autologin.rawValue
            case .clearCookies, .clearCookiesInfo:
                return WebBrowserSettingsSection.clearCookies.rawValue
            case .exceptionsHeader, .exceptionsAdd, .exception, .exceptionsClear, .exceptionsInfo:
                return WebBrowserSettingsSection.exceptions.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .browserHeader:
                return 0
            case let .browser(_, _, _, _, _, index):
                return 1 + index
            case .autologin:
                return 100
            case .autologinInfo:
                return 101
            case .clearCookies:
                return 102
            case .clearCookiesInfo:
                return 103
            case .exceptionsHeader:
                return 104
            case .exceptionsAdd:
                return 105
            case let .exception(index, _, _):
                return 106 + index
            case .exceptionsClear:
                return 1000
            case .exceptionsInfo:
                return 1001
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
            case let .autologin(lhsTheme, lhsText, lhsValue):
                if case let .autologin(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .autologinInfo(lhsTheme, lhsText):
                if case let .autologinInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
            case let .clearCookiesInfo(lhsTheme, lhsText):
                if case let .clearCookiesInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .exceptionsHeader(lhsTheme, lhsText):
                if case let .exceptionsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .exception(lhsIndex, lhsTheme, lhsException):
                if case let .exception(rhsIndex, rhsTheme, rhsException) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsException == rhsException {
                    return true
                } else {
                    return false
                }
            case let .exceptionsAdd(lhsTheme, lhsText):
                if case let .exceptionsAdd(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .exceptionsClear(lhsTheme, lhsText):
                if case let .exceptionsClear(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .exceptionsInfo(lhsTheme, lhsText):
                if case let .exceptionsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
        
    static func <(lhs: WebBrowserSettingsControllerEntry, rhs: WebBrowserSettingsControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! WebBrowserSettingsControllerArguments
        switch self {
            case let .browserHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .browser(_, title, application, identifier, selected, _):
                return WebBrowserItem(context: arguments.context, presentationData: presentationData, title: title, application: application, checked: selected, sectionId: self.section) {
                    arguments.updateDefaultBrowser(identifier)
                }
            case let .autologin(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateAutologin(updatedValue)
                })
            case let .autologinInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .clearCookies(_, text):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.accentDeleteIconImage(presentationData.theme), title: text, sectionId: self.section, height: .generic, color: .accent, editing: false, action: {
                    arguments.clearCookies()
                })
            case let .clearCookiesInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .exceptionsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .exception(_, _, exception):
                return WebBrowserDomainExceptionItem(presentationData: presentationData, context: arguments.context, title: exception.title, label: exception.domain, sectionId: self.section, style: .blocks)
            case let .exceptionsAdd(_, text):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.plusIconImage(presentationData.theme), title: text, sectionId: self.section, height: .generic, color: .accent, editing: false, action: {
                    arguments.addException()
                })
            case let .exceptionsClear(_, text):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.deleteIconImage(presentationData.theme), title: text, sectionId: self.section, height: .generic, color: .destructive, editing: false, action: {
                    arguments.clearExceptions()
                })
            case let .exceptionsInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func webBrowserSettingsControllerEntries(context: AccountContext, presentationData: PresentationData, settings: WebBrowserSettings) -> [WebBrowserSettingsControllerEntry] {
    var entries: [WebBrowserSettingsControllerEntry] = []
    
    let options = availableOpenInOptions(context: context, item: .url(url: "http://telegram.org"))
    
    entries.append(.browserHeader(presentationData.theme, presentationData.strings.WebBrowser_OpenLinksIn_Title))
    entries.append(.browser(presentationData.theme, presentationData.strings.WebBrowser_Telegram, nil, nil, settings.defaultWebBrowser == nil, 0))
    
    var index: Int32 = 1
    for option in options {
        entries.append(.browser(presentationData.theme, option.title, option.application, option.identifier, option.identifier == settings.defaultWebBrowser, index))
        index += 1
    }
    
    if settings.defaultWebBrowser == nil {
        entries.append(.autologin(presentationData.theme, presentationData.strings.WebBrowser_AutoLogin, settings.autologin))
        entries.append(.autologinInfo(presentationData.theme, presentationData.strings.WebBrowser_AutoLogin_Info))
        
        entries.append(.clearCookies(presentationData.theme, presentationData.strings.WebBrowser_ClearCookies))
        entries.append(.clearCookiesInfo(presentationData.theme, presentationData.strings.WebBrowser_ClearCookies_Info))
        
        entries.append(.exceptionsHeader(presentationData.theme, presentationData.strings.WebBrowser_Exceptions_Title))
        entries.append(.exceptionsAdd(presentationData.theme, presentationData.strings.WebBrowser_Exceptions_AddException))
        
        var exceptionIndex: Int32 = 0
        for exception in settings.exceptions {
            entries.append(.exception(exceptionIndex, presentationData.theme, exception))
            exceptionIndex += 1
        }
        
        if !settings.exceptions.isEmpty {
            entries.append(.exceptionsClear(presentationData.theme, presentationData.strings.WebBrowser_Exceptions_Clear))
        }
        
        entries.append(.exceptionsInfo(presentationData.theme, presentationData.strings.WebBrowser_Exceptions_Info))
    }
    
    return entries
}

public func webBrowserSettingsController(context: AccountContext) -> ViewController {
    var clearCookiesImpl: (() -> Void)?
    var addExceptionImpl: (() -> Void)?
    var clearExceptionsImpl: (() -> Void)?
    
    let arguments = WebBrowserSettingsControllerArguments(
        context: context,
        updateDefaultBrowser: { identifier in
            let _ = updateWebBrowserSettingsInteractively(accountManager: context.sharedContext.accountManager, {
                $0.withUpdatedDefaultWebBrowser(identifier)
            }).start()
        },
        updateAutologin: { autologin in
            let _ = updateWebBrowserSettingsInteractively(accountManager: context.sharedContext.accountManager, {
                $0.withUpdatedAutologin(autologin)
            }).start()
        },
        clearCookies: {
            clearCookiesImpl?()
        },
        addException: {
            addExceptionImpl?()
        },
        clearExceptions: {
            clearExceptionsImpl?()
        }
    )
    
    let previousSettings = Atomic<WebBrowserSettings?>(value: nil)
    
    let signal = combineLatest(
        context.sharedContext.presentationData,
        context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.webBrowserSettings])
    )
    |> deliverOnMainQueue
    |> map { presentationData, sharedData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.webBrowserSettings]?.get(WebBrowserSettings.self) ?? WebBrowserSettings.defaultSettings
        let previousSettings = previousSettings.swap(settings)
        
        var animateChanges = false
        if let previousSettings {
            if previousSettings.defaultWebBrowser != settings.defaultWebBrowser {
                animateChanges = true
            }
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.WebBrowser_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: webBrowserSettingsControllerEntries(context: context, presentationData: presentationData, settings: settings), style: .blocks, animateChanges: animateChanges)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    clearCookiesImpl = { [weak controller] in
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: Date(timeIntervalSince1970: 0), completionHandler:{})
                
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
    }
    
    addExceptionImpl = { [weak controller] in
        let linkController = webBrowserDomainController(context: context, apply: { url in
            if let url {
                let _ = fetchDomainExceptionInfo(url: url).startStandalone(next: { newException in
                    let _ = updateWebBrowserSettingsInteractively(accountManager: context.sharedContext.accountManager, { currentSettings in
                        var currentExceptions = currentSettings.exceptions
                        for exception in currentExceptions {
                            if exception.domain == newException.domain {
                                return currentSettings
                            }
                        }
                        currentExceptions.append(newException)
                        return currentSettings.withUpdatedExceptions(currentExceptions)
                    }).start()
                })
            }
        })
        controller?.present(linkController, in: .window(.root))
    }
    
    clearExceptionsImpl = {
        let _ = updateWebBrowserSettingsInteractively(accountManager: context.sharedContext.accountManager, { currentSettings in
            return currentSettings.withUpdatedExceptions([])
        }).start()
    }
    
    return controller
}

private func cleanDomain(url: String) -> (domain: String, fullUrl: String) {
    if let parsedUrl = URL(string: url) {
        let host: String?
        let scheme = parsedUrl.scheme ?? "https"
        if #available(iOS 16.0, *) {
            host = parsedUrl.host(percentEncoded: true)?.lowercased()
        } else {
            host = parsedUrl.host?.lowercased()
        }
        return (host ?? url, "\(scheme)://\(host ?? "")")
    } else {
        return (url, url)
    }
}

private func fetchDomainExceptionInfo(url: String) -> Signal<WebBrowserException, NoError> {
    let (domain, domainUrl) = cleanDomain(url: url)
    if #available(iOS 13.0, *), let url = URL(string: domainUrl) {
        return Signal { subscriber in
            let metadataProvider = LPMetadataProvider()
            metadataProvider.shouldFetchSubresources = true
            metadataProvider.startFetchingMetadata(for: url, completionHandler: { metadata, _ in
                let title = metadata?.value(forKey: "_siteName") as? String ?? metadata?.title
                subscriber.putNext(WebBrowserException(domain: domain, title: title ?? domain))
                subscriber.putCompletion()
            })
            return ActionDisposable {
                metadataProvider.cancel()
            }
        }
    } else {
        return .single(WebBrowserException(domain: domain, title: domain))
    }
}
