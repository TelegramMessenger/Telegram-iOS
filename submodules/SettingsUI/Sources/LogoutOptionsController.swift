import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import OverlayStatusController
import AccountContext
import AlertUI
import PresentationDataUtils
import UrlHandling

private struct LogoutOptionsItemArguments {
    let addAccount: () -> Void
    let setPasscode: () -> Void
    let clearCache: () -> Void
    let changePhoneNumber: () -> Void
    let contactSupport: () -> Void
    let logout: () -> Void
}

private enum LogoutOptionsSection: Int32 {
    case options
    case logOut
}

private enum LogoutOptionsEntry: ItemListNodeEntry, Equatable {
    case alternativeHeader(PresentationTheme, String)
    case addAccount(PresentationTheme, String, String)
    case setPasscode(PresentationTheme, String, String)
    case clearCache(PresentationTheme, String, String)
    case changePhoneNumber(PresentationTheme, String, String)
    case contactSupport(PresentationTheme, String, String)
    case logout(PresentationTheme, String)
    case logoutInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .alternativeHeader, .addAccount, .setPasscode, .clearCache, .changePhoneNumber, .contactSupport:
                return LogoutOptionsSection.options.rawValue
            case .logout, .logoutInfo:
                return LogoutOptionsSection.logOut.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .alternativeHeader:
                return 0
            case .addAccount:
                return 1
            case .setPasscode:
                return 2
            case .clearCache:
                return 3
            case .changePhoneNumber:
                return 4
            case .contactSupport:
                return 5
            case .logout:
                return 6
            case .logoutInfo:
                return 7
        }
    }
    
    static func <(lhs: LogoutOptionsEntry, rhs: LogoutOptionsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! LogoutOptionsItemArguments
        switch self {
            case let .alternativeHeader(_, title):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: title, sectionId: self.section)
            case let .addAccount(_, title, text):
                return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.addAccount, title: title, label: text, labelStyle: .multilineDetailText, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.addAccount()
                })
            case let .setPasscode(_, title, text):
                return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.setPasscode, title: title, label: text, labelStyle: .multilineDetailText, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.setPasscode()
                })
            case let .clearCache(_, title, text):
                return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.clearCache, title: title, label: text, labelStyle: .multilineDetailText, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.clearCache()
                })
            case let .changePhoneNumber(_, title, text):
                return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.changePhoneNumber, title: title, label: text, labelStyle: .multilineDetailText, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.changePhoneNumber()
                })
            case let .contactSupport(_, title, text):
                return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.support, title: title, label: text, labelStyle: .multilineDetailText, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.contactSupport()
                })
            case let .logout(_, title):
                return ItemListActionItem(presentationData: presentationData, title: title, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.logout()
                })
            case let .logoutInfo(_, title):
                return ItemListTextItem(presentationData: presentationData, text: .plain(title), sectionId: self.section)
        }
    }
}

private func logoutOptionsEntries(presentationData: PresentationData, canAddAccounts: Bool, hasPasscode: Bool, hasWallets: Bool) -> [LogoutOptionsEntry] {
    var entries: [LogoutOptionsEntry] = []
    entries.append(.alternativeHeader(presentationData.theme, presentationData.strings.LogoutOptions_AlternativeOptionsSection))
    if canAddAccounts {
        entries.append(.addAccount(presentationData.theme, presentationData.strings.LogoutOptions_AddAccountTitle, presentationData.strings.LogoutOptions_AddAccountText))
    }
    if !hasPasscode {
        entries.append(.setPasscode(presentationData.theme, presentationData.strings.LogoutOptions_SetPasscodeTitle, presentationData.strings.LogoutOptions_SetPasscodeText))
    }
    entries.append(.clearCache(presentationData.theme, presentationData.strings.LogoutOptions_ClearCacheTitle, presentationData.strings.LogoutOptions_ClearCacheText))
    entries.append(.changePhoneNumber(presentationData.theme, presentationData.strings.LogoutOptions_ChangePhoneNumberTitle, presentationData.strings.LogoutOptions_ChangePhoneNumberText))
    entries.append(.contactSupport(presentationData.theme, presentationData.strings.LogoutOptions_ContactSupportTitle, presentationData.strings.LogoutOptions_ContactSupportText))
    entries.append(.logout(presentationData.theme, presentationData.strings.LogoutOptions_LogOut))
    entries.append(.logoutInfo(presentationData.theme, presentationData.strings.LogoutOptions_LogOutInfo))
    return entries
}

public func logoutOptionsController(context: AccountContext, navigationController: NavigationController, canAddAccounts: Bool, phoneNumber: String) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var replaceTopControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    
    let supportPeerDisposable = MetaDisposable()
    
    let arguments = LogoutOptionsItemArguments(addAccount: {
        let isTestingEnvironment = context.account.testingEnvironment
        context.sharedContext.beginNewAuth(testingEnvironment: isTestingEnvironment)
        
        dismissImpl?()
    }, setPasscode: {
        let _ = passcodeOptionsAccessController(context: context, pushController: { controller in
            replaceTopControllerImpl?(controller)
        }, completion: { _ in
            replaceTopControllerImpl?(passcodeOptionsController(context: context))
        }).start(next: { controller in
            if let controller = controller {
                pushControllerImpl?(controller)
            }
        })
        dismissImpl?()
    }, clearCache: {
        pushControllerImpl?(storageUsageController(context: context))
        dismissImpl?()
    }, changePhoneNumber: {
        let introController = PrivacyIntroController(context: context, mode: .changePhoneNumber(phoneNumber), proceedAction: {
            replaceTopControllerImpl?(ChangePhoneNumberController(context: context))
        })
        pushControllerImpl?(introController)
        dismissImpl?()
    }, contactSupport: { [weak navigationController] in
        let supportPeer = Promise<PeerId?>()
        supportPeer.set(context.engine.peers.supportPeerId())
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        var faqUrl = presentationData.strings.Settings_FAQ_URL
        if faqUrl == "Settings.FAQ_URL" || faqUrl.isEmpty {
            faqUrl = "https://telegram.org/faq#general"
        }
        let resolvedUrl = resolveInstantViewUrl(account: context.account, url: faqUrl)
        
        let resolvedUrlPromise = Promise<ResolvedUrl>()
        resolvedUrlPromise.set(resolvedUrl)
        
        let openFaq: (Promise<ResolvedUrl>) -> Void = { resolvedUrl in
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
            presentControllerImpl?(controller, nil)
            let _ = (resolvedUrl.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak controller] resolvedUrl in
                controller?.dismiss()
                dismissImpl?()
                
                context.sharedContext.openResolvedUrl(resolvedUrl, context: context, urlContext: .generic, navigationController: navigationController, forceExternal: false, openPeer: { peer, navigation in
                }, sendFile: nil, sendSticker: nil, requestMessageActionUrlAuth: nil, joinVoiceChat: nil, present: { controller, arguments in
                    pushControllerImpl?(controller)
                }, dismissInput: {}, contentContext: nil)
            })
        }
        
        presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.Settings_FAQ_Intro, actions: [
            TextAlertAction(type: .genericAction, title: presentationData.strings.Settings_FAQ_Button, action: {
                openFaq(resolvedUrlPromise)
                dismissImpl?()
            }),
            TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                supportPeerDisposable.set((supportPeer.get()
                |> take(1)
                |> deliverOnMainQueue).start(next: { peerId in
                    if let peerId = peerId, let navigationController = navigationController {
                        dismissImpl?()
                        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(id: peerId)))
                    }
                }))
            })
        ]), nil)
    }, logout: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let alertController = textAlertController(context: context, title: presentationData.strings.Settings_LogoutConfirmationTitle, text: presentationData.strings.Settings_LogoutConfirmationText, actions: [
            TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
            }),
            TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                let _ = logoutFromAccount(id: context.account.id, accountManager: context.sharedContext.accountManager, alreadyLoggedOutRemotely: false).start()
                dismissImpl?()
            })
        ])
        presentControllerImpl?(alertController, nil)
    })
    
    #if ENABLE_WALLET
    let hasWallets = context.hasWallets
    #else
    let hasWallets: Signal<Bool, NoError> = .single(false)
    #endif
    
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        context.sharedContext.accountManager.accessChallengeData(),
        hasWallets
    )
    |> map { presentationData, accessChallengeData, hasWallets -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        
        var hasPasscode = false
        switch accessChallengeData.data {
            case .numericalPassword, .plaintextPassword:
                hasPasscode = true
            default:
                break
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.LogoutOptions_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: logoutOptionsEntries(presentationData: presentationData, canAddAccounts: canAddAccounts, hasPasscode: hasPasscode, hasWallets: hasWallets), style: .blocks)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal, tabBarItem: nil)
    controller.navigationPresentation = .modal
    pushControllerImpl = { [weak navigationController] value in
        navigationController?.pushViewController(value, animated: false)
    }
    presentControllerImpl = { [weak controller] value, arguments in
        controller?.present(value, in: .window(.root), with: arguments ?? ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }
    replaceTopControllerImpl = { [weak navigationController] c in
        navigationController?.replaceTopController(c, animated: true)
    }
    dismissImpl = { [weak controller] in
        let _ = controller?.dismiss()
    }
    
    return controller
}

