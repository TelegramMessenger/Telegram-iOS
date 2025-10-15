import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
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
import LinkPresentation
import CoreServices
import PersistentStringHash
import UrlHandling

private final class WebBrowserSettingsControllerArguments {
    let context: AccountContext
    let updateDefaultBrowser: (String?) -> Void
    let clearCookies: () -> Void
    let clearCache: () -> Void
    let addException: () -> Void
    let removeException: (String) -> Void
    let clearExceptions: () -> Void
    
    init(
        context: AccountContext,
        updateDefaultBrowser: @escaping (String?) -> Void,
        clearCookies: @escaping () -> Void,
        clearCache: @escaping () -> Void,
        addException: @escaping () -> Void,
        removeException: @escaping (String) -> Void,
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
    case exceptions
}

private enum WebBrowserSettingsControllerEntry: ItemListNodeEntry {
    case browserHeader(PresentationTheme, String)
    case browser(PresentationTheme, String, OpenInApplication?, String?, Bool, Int32)
    
    case clearCookies(PresentationTheme, String)
    case clearCache(PresentationTheme, String)
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
            case .clearCookies, .clearCache, .clearCookiesInfo:
                return WebBrowserSettingsSection.clearCookies.rawValue
            case .exceptionsHeader, .exceptionsAdd, .exception, .exceptionsClear, .exceptionsInfo:
                return WebBrowserSettingsSection.exceptions.rawValue
        }
    }
    
    var stableId: UInt64 {
        switch self {
            case .browserHeader:
                return 0
            case let .browser(_, _, _, _, _, index):
                return UInt64(1 + index)
            case .clearCookies:
                return 102
            case .clearCache:
                return 103
            case .clearCookiesInfo:
                return 104
            case .exceptionsHeader:
                return 105
            case .exceptionsAdd:
                return 106
            case let .exception(_, _, exception):
                return 2000 + exception.domain.persistentHashValue
            case .exceptionsClear:
                return 1000
            case .exceptionsInfo:
                return 1001
        }
    }
    
    var sortId: Int32 {
        switch self {
            case .browserHeader:
                return 0
            case let .browser(_, _, _, _, _, index):
                return 1 + index
            case .clearCookies:
                return 102
            case .clearCache:
                return 103
            case .clearCookiesInfo:
                return 104
            case .exceptionsHeader:
                return 105
            case .exceptionsAdd:
                return 106
            case let .exception(index, _, _):
                return 107 + index
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
        return lhs.sortId < rhs.sortId
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
            case let .clearCookies(_, text):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.accentDeleteIconImage(presentationData.theme), title: text, sectionId: self.section, height: .generic, color: .accent, editing: false, action: {
                    arguments.clearCookies()
                })
            case let .clearCache(_, text):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.accentDeleteIconImage(presentationData.theme), title: text, sectionId: self.section, height: .generic, color: .accent, editing: false, action: {
                    arguments.clearCache()
                })
            case let .clearCookiesInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .exceptionsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .exception(_, _, exception):
                return WebBrowserDomainExceptionItem(presentationData: presentationData, context: arguments.context, title: exception.title, label: exception.domain, icon: exception.icon, sectionId: self.section, style: .blocks, deleted: {
                    arguments.removeException(exception.domain)
                })
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
        entries.append(.clearCookies(presentationData.theme, presentationData.strings.WebBrowser_ClearCookies))
//        entries.append(.clearCache(presentationData.theme, presentationData.strings.WebBrowser_ClearCache))
        entries.append(.clearCookiesInfo(presentationData.theme, presentationData.strings.WebBrowser_ClearCookies_Info))
        
        entries.append(.exceptionsHeader(presentationData.theme, presentationData.strings.WebBrowser_Exceptions_Title))
        entries.append(.exceptionsAdd(presentationData.theme, presentationData.strings.WebBrowser_Exceptions_AddException))
        
        var exceptionIndex: Int32 = 0
        for exception in settings.exceptions.reversed() {
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
    var clearCacheImpl: (() -> Void)?
    var addExceptionImpl: (() -> Void)?
    var removeExceptionImpl: ((String) -> Void)?
    var clearExceptionsImpl: (() -> Void)?
    
    let arguments = WebBrowserSettingsControllerArguments(
        context: context,
        updateDefaultBrowser: { identifier in
            let _ = updateWebBrowserSettingsInteractively(accountManager: context.sharedContext.accountManager, {
                $0.withUpdatedDefaultWebBrowser(identifier)
            }).start()
        },
        clearCookies: {
            clearCookiesImpl?()
        },
        clearCache: {
            clearCacheImpl?()
        },
        addException: {
            addExceptionImpl?()
        },
        removeException: { domain in
            removeExceptionImpl?(domain)
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
            if previousSettings.exceptions.count != settings.exceptions.count {
                animateChanges = true
            }
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.WebBrowser_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: webBrowserSettingsControllerEntries(context: context, presentationData: presentationData, settings: settings), style: .blocks, animateChanges: animateChanges)
        
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
    
    addExceptionImpl = { [weak controller] in
        var dismissImpl: (() -> Void)?
        let linkController = webBrowserDomainController(context: context, apply: { url in
            if let url {
                let _ = (fetchDomainExceptionInfo(context: context, url: url)
                |> deliverOnMainQueue).startStandalone(next: { newException in
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
                    dismissImpl?()
                })
            }
        })
        dismissImpl = { [weak linkController] in
            linkController?.view.endEditing(true)
            linkController?.dismissAnimated()
        }
        controller?.present(linkController, in: .window(.root))
    }
    
    removeExceptionImpl = { domain in
        let _ = updateWebBrowserSettingsInteractively(accountManager: context.sharedContext.accountManager, { currentSettings in
            let updatedExceptions = currentSettings.exceptions.filter { $0.domain != domain  }
            return currentSettings.withUpdatedExceptions(updatedExceptions)
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
                    let _ = updateWebBrowserSettingsInteractively(accountManager: context.sharedContext.accountManager, { currentSettings in
                        return currentSettings.withUpdatedExceptions([])
                    }).start()
                })
            ]
        )
        controller?.present(alertController, in: .window(.root))
    }
    
    return controller
}

private func fetchDomainExceptionInfo(context: AccountContext, url: String) -> Signal<WebBrowserException, NoError> {
    let (domain, domainUrl) = cleanDomain(url: url)
    if #available(iOS 13.0, *), let url = URL(string: domainUrl) {
        return Signal { subscriber in
            let metadataProvider = LPMetadataProvider()
            metadataProvider.shouldFetchSubresources = true
            metadataProvider.startFetchingMetadata(for: url, completionHandler: { metadata, _ in
                let completeWithImage: (Data?) -> Void = { imageData in
                    var image: TelegramMediaImage?
                    if let imageData, let parsedImage = UIImage(data: imageData) {
                        let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                        context.sharedContext.accountManager.mediaBox.storeResourceData(resource.id, data: imageData)
                        image = TelegramMediaImage(
                            imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: Int64.random(in: Int64.min ... Int64.max)),
                            representations: [
                                TelegramMediaImageRepresentation(
                                    dimensions: PixelDimensions(width: Int32(parsedImage.size.width), height: Int32(parsedImage.size.height)),
                                    resource: resource,
                                    progressiveSizes: [],
                                    immediateThumbnailData: nil,
                                    hasVideo: false,
                                    isPersonal: false
                                )
                            ],
                            immediateThumbnailData: nil,
                            reference: nil,
                            partialReference: nil,
                            flags: []
                        )
                    }
                    
                    let title = metadata?.value(forKey: "_siteName") as? String ?? metadata?.title
                    subscriber.putNext(WebBrowserException(domain: domain, title: title ?? domain, icon: image))
                    subscriber.putCompletion()
                }
                
                if let imageProvider = metadata?.iconProvider {
                    imageProvider.loadFileRepresentation(forTypeIdentifier: kUTTypeImage as String, completionHandler: { imageUrl, _ in
                        guard let imageUrl, let imageData = try? Data(contentsOf: imageUrl) else {
                            completeWithImage(nil)
                            return
                        }
                        completeWithImage(imageData)
                    })
                } else {
                    completeWithImage(nil)
                }
            })
            return ActionDisposable {
                metadataProvider.cancel()
            }
        }
    } else {
        return .single(WebBrowserException(domain: domain, title: domain, icon: nil))
    }
}
