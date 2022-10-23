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
import AccountUtils
import PremiumUI
import PasswordSetupUI

private struct DeleteAccountOptionsArguments {
    let changePhoneNumber: () -> Void
    let addAccount: () -> Void
    let setupPrivacy: () -> Void
    let setupTwoStepAuth: () -> Void
    let setPasscode: () -> Void
    let clearCache: () -> Void
    let clearSyncedContacts: () -> Void
    let deleteChats: () -> Void
    let contactSupport: () -> Void
    let deleteAccount: () -> Void
}

private enum DeleteAccountOptionsSection: Int32 {
    case add
    case privacy
    case remove
    case support
    case delete
}

private enum DeleteAccountOptionsEntry: ItemListNodeEntry, Equatable {
    case changePhoneNumber(PresentationTheme, String, String)
    case addAccount(PresentationTheme, String, String)

    case changePrivacy(PresentationTheme, String, String)
    case setTwoStepAuth(PresentationTheme, String, String)
    case setPasscode(PresentationTheme, String, String)

    case clearCache(PresentationTheme, String, String)
    case clearSyncedContacts(PresentationTheme, String, String)
    case deleteChats(PresentationTheme, String, String)

    case contactSupport(PresentationTheme, String, String)

    case deleteAccount(PresentationTheme, String)

    var section: ItemListSectionId {
        switch self {
            case .changePhoneNumber, .addAccount:
                return DeleteAccountOptionsSection.add.rawValue
            case .changePrivacy, .setTwoStepAuth, .setPasscode:
                return DeleteAccountOptionsSection.privacy.rawValue
            case .clearCache, .clearSyncedContacts, .deleteChats:
                return DeleteAccountOptionsSection.remove.rawValue
            case .contactSupport:
                return DeleteAccountOptionsSection.support.rawValue
            case .deleteAccount:
                return DeleteAccountOptionsSection.delete.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
            case .changePhoneNumber:
                return 0
            case .addAccount:
                return 1
            case .changePrivacy:
                return 2
            case .setTwoStepAuth:
                return 3
            case .setPasscode:
                return 4
            case .clearCache:
                return 5
            case .clearSyncedContacts:
                return 6
            case .deleteChats:
                return 7
            case .contactSupport:
                return 8
            case .deleteAccount:
                return 9
        }
    }

    static func <(lhs: DeleteAccountOptionsEntry, rhs: DeleteAccountOptionsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! DeleteAccountOptionsArguments
        switch self {
            case let .changePhoneNumber(_, title, text):
                return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.changePhoneNumber, title: title, label: text, labelStyle: .multilineDetailText, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.changePhoneNumber()
                })
            case let .addAccount(_, title, text):
                return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.deleteAddAccount, title: title, label: text, labelStyle: .multilineDetailText, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.addAccount()
                })
            case let .changePrivacy(_, title, text):
                return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.security, title: title, label: text, labelStyle: .multilineDetailText, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.setupPrivacy()
                })
            case let .setTwoStepAuth(_, title, text):
                return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.deleteSetTwoStepAuth, title: title, label: text, labelStyle: .multilineDetailText, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.setupTwoStepAuth()
                })
            case let .setPasscode(_, title, text):
                return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.deleteSetPasscode, title: title, label: text, labelStyle: .multilineDetailText, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.setPasscode()
                })
            case let .clearCache(_, title, text):
                return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.dataAndStorage, title: title, label: text, labelStyle: .multilineDetailText, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.clearCache()
                })
            case let .clearSyncedContacts(_, title, text):
                return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.clearSynced, title: title, label: text, labelStyle: .multilineDetailText, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.clearSyncedContacts()
                })
            case let .deleteChats(_, title, text):
                return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.deleteChats, title: title, label: text, labelStyle: .multilineDetailText, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.deleteChats()
                })
            case let .contactSupport(_, title, text):
                return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.support, title: title, label: text, labelStyle: .multilineDetailText, sectionId: self.section, style: .blocks, disclosureStyle: .arrow, action: {
                    arguments.contactSupport()
                })
            case let .deleteAccount(_, title):
                return ItemListActionItem(presentationData: presentationData, title: title, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.deleteAccount()
                })
        }
    }
}

private func deleteAccountOptionsEntries(presentationData: PresentationData, canAddAccounts: Bool, hasTwoStepAuth: Bool, hasPasscode: Bool) -> [DeleteAccountOptionsEntry] {
    var entries: [DeleteAccountOptionsEntry] = []

    entries.append(.changePhoneNumber(presentationData.theme, presentationData.strings.DeleteAccount_Options_ChangePhoneNumberTitle, presentationData.strings.DeleteAccount_Options_ChangePhoneNumberText))
    if canAddAccounts {
        entries.append(.addAccount(presentationData.theme, presentationData.strings.DeleteAccount_Options_AddAccountTitle, presentationData.strings.DeleteAccount_Options_AddAccountText))
    }

    entries.append(.changePrivacy(presentationData.theme, presentationData.strings.DeleteAccount_Options_ChangePrivacyTitle, presentationData.strings.DeleteAccount_Options_ChangePrivacyText))
    if !hasTwoStepAuth {
        entries.append(.setTwoStepAuth(presentationData.theme, presentationData.strings.DeleteAccount_Options_SetTwoStepAuthTitle, presentationData.strings.DeleteAccount_Options_SetTwoStepAuthText))
    }
    if !hasPasscode {
        entries.append(.setPasscode(presentationData.theme, presentationData.strings.DeleteAccount_Options_SetPasscodeTitle, presentationData.strings.DeleteAccount_Options_SetPasscodeText))
    }
    entries.append(.clearCache(presentationData.theme, presentationData.strings.DeleteAccount_Options_ClearCacheTitle, presentationData.strings.DeleteAccount_Options_ClearCacheText))
    entries.append(.clearSyncedContacts(presentationData.theme, presentationData.strings.DeleteAccount_Options_ClearSyncedContactsTitle, presentationData.strings.DeleteAccount_Options_ClearSyncedContactsText))
    entries.append(.deleteChats(presentationData.theme, presentationData.strings.DeleteAccount_Options_DeleteChatsTitle, presentationData.strings.DeleteAccount_Options_DeleteChatsText))

    entries.append(.contactSupport(presentationData.theme, presentationData.strings.DeleteAccount_Options_ContactSupportTitle, presentationData.strings.DeleteAccount_Options_ContactSupportText))

    entries.append(.deleteAccount(presentationData.theme, presentationData.strings.DeleteAccount_DeleteMyAccount))

    return entries
}

public func deleteAccountOptionsController(context: AccountContext, navigationController: NavigationController, hasTwoStepAuth: Bool, twoStepAuthData: TwoStepVerificationAccessConfiguration?) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var replaceTopControllerImpl: ((ViewController, Bool) -> Void)?
    var dismissImpl: (() -> Void)?

    let supportPeerDisposable = MetaDisposable()
    
    let arguments = DeleteAccountOptionsArguments(changePhoneNumber: {
        addAppLogEvent(postbox: context.account.postbox, type: "deactivate.options_phone_change_tap")
        
        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.engine.account.peerId))
        |> deliverOnMainQueue).start(next: { accountPeer in
            guard let accountPeer = accountPeer, case let .user(user) = accountPeer else {
                return
            }
            let introController = PrivacyIntroController(context: context, mode: .changePhoneNumber(user.phone ?? ""), proceedAction: {
                replaceTopControllerImpl?(ChangePhoneNumberController(context: context), false)
            })
            pushControllerImpl?(introController)
            dismissImpl?()
        })
    }, addAccount: {
        addAppLogEvent(postbox: context.account.postbox, type: "deactivate.options_add_account_tap")
        
        let _ = (activeAccountsAndPeers(context: context)
        |> take(1)
        |> deliverOnMainQueue
        ).start(next: { accountAndPeer, accountsAndPeers in
            var maximumAvailableAccounts: Int = 3
            if accountAndPeer?.1.isPremium == true && !context.account.testingEnvironment {
                maximumAvailableAccounts = 4
            }
            var count: Int = 1
            for (accountContext, peer, _) in accountsAndPeers {
                if !accountContext.account.testingEnvironment {
                    if peer.isPremium {
                        maximumAvailableAccounts = 4
                    }
                    count += 1
                }
            }

            if count >= maximumAvailableAccounts {
                var replaceImpl: ((ViewController) -> Void)?
                let controller = PremiumLimitScreen(context: context, subject: .accounts, count: Int32(count), action: {
                    let controller = PremiumIntroScreen(context: context, source: .accounts)
                    replaceImpl?(controller)
                })
                replaceImpl = { [weak controller] c in
                    controller?.replace(with: c)
                }
                pushControllerImpl?(controller)
            } else {
                context.sharedContext.beginNewAuth(testingEnvironment: context.account.testingEnvironment)

                dismissImpl?()
            }
        })
    }, setupPrivacy: {
        addAppLogEvent(postbox: context.account.postbox, type: "deactivate.options_privacy_tap")
        
        replaceTopControllerImpl?(makePrivacyAndSecurityController(context: context), false)
    }, setupTwoStepAuth: {
        addAppLogEvent(postbox: context.account.postbox, type: "deactivate.options_2fa_tap")
        
        if let data = twoStepAuthData {
            switch data {
            case .set:
                break
            case let .notSet(pendingEmail):
                if pendingEmail == nil {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let controller = TwoFactorAuthSplashScreen(sharedContext: context.sharedContext, engine: .authorized(context.engine), mode: .intro(.init(
                        title: presentationData.strings.TwoFactorSetup_Intro_Title,
                        text: presentationData.strings.TwoFactorSetup_Intro_Text,
                        actionText: presentationData.strings.TwoFactorSetup_Intro_Action,
                        doneText: presentationData.strings.TwoFactorSetup_Done_Action
                    )))

                    replaceTopControllerImpl?(controller, false)
                    return
                }
            }
        }

        let controller = twoStepVerificationUnlockSettingsController(context: context, mode: .access(intro: false, data: twoStepAuthData.flatMap({ Signal<TwoStepVerificationUnlockSettingsControllerData, NoError>.single(.access(configuration: $0)) })))
        replaceTopControllerImpl?(controller, false)
    }, setPasscode: {
        addAppLogEvent(postbox: context.account.postbox, type: "deactivate.options_passcode_tap")
        
        let _ = passcodeOptionsAccessController(context: context, pushController: { controller in
            replaceTopControllerImpl?(controller, false)
        }, completion: { _ in
            replaceTopControllerImpl?(passcodeOptionsController(context: context), false)
        }).start(next: { controller in
            if let controller = controller {
                pushControllerImpl?(controller)
            }
        })
        dismissImpl?()
    }, clearCache: {
        addAppLogEvent(postbox: context.account.postbox, type: "deactivate.options_clear_cache_tap")
        
        pushControllerImpl?(storageUsageController(context: context))
        dismissImpl?()
    }, clearSyncedContacts: {
        addAppLogEvent(postbox: context.account.postbox, type: "deactivate.options_clear_contacts_tap")
        
        replaceTopControllerImpl?(dataPrivacyController(context: context), false)
    }, deleteChats: {
        addAppLogEvent(postbox: context.account.postbox, type: "deactivate.options_delete_chats_tap")
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        var faqUrl = presentationData.strings.DeleteAccount_DeleteMessagesURL
        if faqUrl == "DeleteAccount.DeleteMessagesURL" || faqUrl.isEmpty {
            faqUrl = "https://telegram.org/faq#q-can-i-delete-my-messages"
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
        
        openFaq(resolvedUrlPromise)
    }, contactSupport: { [weak navigationController] in
        addAppLogEvent(postbox: context.account.postbox, type: "deactivate.options_support_tap")
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let supportPeer = Promise<PeerId?>()
        supportPeer.set(context.engine.peers.supportPeerId())
        
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

        let alertController = textAlertController(context: context, title: nil, text: presentationData.strings.Settings_FAQ_Intro, actions: [
            TextAlertAction(type: .genericAction, title: presentationData.strings.Settings_FAQ_Button, action: {
                openFaq(resolvedUrlPromise)
                dismissImpl?()
            }),
            TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                supportPeerDisposable.set((supportPeer.get()
                |> take(1)
                |> deliverOnMainQueue).start(next: { peerId in
                    guard let peerId = peerId else {
                        return
                    }
                    let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                    |> deliverOnMainQueue).start(next: { peer in
                        guard let peer = peer else {
                            return
                        }
                        if let navigationController = navigationController {
                            dismissImpl?()
                            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer)))
                        }
                    })
                }))
            })
        ])
        alertController.dismissed = { _ in
            addAppLogEvent(postbox: context.account.postbox, type: "deactivate.options_support_cancel")
        }
        presentControllerImpl?(alertController, nil)
    }, deleteAccount: {
        let controller = deleteAccountDataController(context: context, mode: .peers, twoStepAuthData: twoStepAuthData)
        replaceTopControllerImpl?(controller, true)
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        context.sharedContext.accountManager.accessChallengeData(),
        activeAccountsAndPeers(context: context)
    )
    |> map { presentationData, accessChallengeData, accountsAndPeers -> (ItemListControllerState, (ItemListNodeState, Any)) in
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
        
        let canAddAccounts = accountsAndPeers.1.count + 1 < maximumNumberOfAccounts

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.DeleteAccount_AlternativeOptionsTitle), leftNavigationButton: leftNavigationButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: deleteAccountOptionsEntries(presentationData: presentationData, canAddAccounts: canAddAccounts, hasTwoStepAuth: hasTwoStepAuth, hasPasscode: hasPasscode), style: .blocks)

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
    replaceTopControllerImpl = { [weak navigationController] c, complex in
        if complex {
            navigationController?.pushViewController(c, completion: { [weak navigationController, weak controller, weak c] in
                if let navigationController = navigationController {
                    let controllers = navigationController.viewControllers.filter { $0 !== controller }
                    c?.navigationPresentation = .modal
                    navigationController.setViewControllers(controllers, animated: false)
                }
            })
        } else {
            if c is PrivacyAndSecurityControllerImpl {
                if let navigationController = navigationController {
                    if let existing = navigationController.viewControllers.first(where: { $0 is PrivacyAndSecurityControllerImpl }) as? ViewController {
                        existing.scrollToTop?()
                        dismissImpl?()
                    } else {
                        navigationController.replaceTopController(c, animated: true)
                    }
                }
            } else {
                navigationController?.replaceTopController(c, animated: true)
            }
        }
    }
    dismissImpl = { [weak controller] in
        let _ = controller?.dismiss()
    }
    
    addAppLogEvent(postbox: context.account.postbox, type: "deactivate.options_show")

    return controller
}

