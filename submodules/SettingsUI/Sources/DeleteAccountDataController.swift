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
import AccountContext
import AlertUI
import PresentationDataUtils
import UrlHandling
import InviteLinksUI
import CountrySelectionUI
import PhoneInputNode
import UndoUI

private struct DeleteAccountDataArguments {
    let context: AccountContext
    let openLink: (String) -> Void
    let selectCountryCode: () -> Void
    let updatePassword: (String) -> Void
    let proceed: () -> Void
}

private enum DeleteAccountDataSection: Int32 {
    case header
    case main
}

private enum DeleteAccountEntryTag: Equatable, ItemListItemTag {
    case password
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? DeleteAccountEntryTag {
            return self == other
        } else {
            return false
        }
    }
}


private enum DeleteAccountDataEntry: ItemListNodeEntry, Equatable {
    case header(PresentationTheme, String, String, String, Bool)
    case peers(PresentationTheme, [EnginePeer])
    case phone(PresentationTheme, PresentationStrings)
    case password(PresentationTheme, String)
    case info(PresentationTheme, String)

    var section: ItemListSectionId {
        switch self {
            case .header:
                return DeleteAccountDataSection.header.rawValue
            case .peers, .info, .phone, .password:
                return DeleteAccountDataSection.main.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
            case .header:
                return 0
            case .peers:
                return 1
            case .info:
                return 2
            case .phone:
                return 3
            case .password:
                return 4
        }
    }

    static func == (lhs: DeleteAccountDataEntry, rhs: DeleteAccountDataEntry) -> Bool {
        switch lhs {
            case let .header(lhsTheme, lhsAnimation, lhsTitle, lhsText, lhsHideOnSmallScreens):
                if case let .header(rhsTheme, rhsAnimation, rhsTitle, rhsText, rhsHideOnSmallScreens) = rhs, lhsTheme === rhsTheme, lhsAnimation == rhsAnimation, lhsTitle == rhsTitle, lhsText == rhsText, lhsHideOnSmallScreens == rhsHideOnSmallScreens {
                    return true
                } else {
                    return false
                }
            case let .peers(lhsTheme, lhsPeers):
                if case let .peers(rhsTheme, rhsPeers) = rhs, lhsTheme === rhsTheme, lhsPeers == rhsPeers {
                    return true
                } else {
                    return false
                }
            case let .info(lhsTheme, lhsText):
                if case let .info(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .phone(lhsTheme, lhsStrings):
                if case let .phone(rhsTheme, rhsStrings) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings {
                    return true
                } else {
                    return false
                }
            case let .password(lhsTheme, lhsPlaceholder):
                if case let .password(rhsTheme, rhsPlaceholder) = rhs, lhsTheme === rhsTheme, lhsPlaceholder == rhsPlaceholder {
                    return true
                } else {
                    return false
                }

        }
    }
    
    static func <(lhs: DeleteAccountDataEntry, rhs: DeleteAccountDataEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! DeleteAccountDataArguments
        switch self {
            case let .header(theme, animation, title, text, hideOnSmallScreens):
                return InviteLinkHeaderItem(context: arguments.context, theme: theme, title: title, text: text, animationName: animation, hideOnSmallScreens: hideOnSmallScreens, sectionId: self.section, linkAction: nil)
            case let .peers(_, peers):
                return DeleteAccountPeersItem(context: arguments.context, theme: presentationData.theme, strings: presentationData.strings, peers: peers, sectionId: self.section)
            case let .info(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
            case .phone:
                return DeleteAccountPhoneItem(theme: presentationData.theme, strings: presentationData.strings, value: (nil, nil, ""), sectionId: self.section, selectCountryCode: {
                    arguments.selectCountryCode()
                }, updated: { _ in
                    
                })
            case let .password(_, placeholder):
                return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(), text: "", placeholder: placeholder, type: .password, returnKeyType: .done, tag: DeleteAccountEntryTag.password, sectionId: self.section, textUpdated: { value in
                    arguments.updatePassword(value)
                }, action: {
                    arguments.proceed()
                })
        }
    }
}

private func deleteAccountDataEntries(presentationData: PresentationData, mode: DeleteAccountDataMode, peers: [EnginePeer]) -> [DeleteAccountDataEntry] {
    var entries: [DeleteAccountDataEntry] = []
    
    let headerTitle: String
    let headerText: String
    let headerAnimation: String
    var hideOnSmallScreen = false
    
    switch mode {
    case .peers:
        headerAnimation = "Delete1"
        headerTitle = presentationData.strings.DeleteAccount_CloudStorageTitle
        headerText = presentationData.strings.DeleteAccount_CloudStorageText
    case .groups:
        headerAnimation = "Delete2"
        headerTitle = presentationData.strings.DeleteAccount_GroupsAndChannelsTitle
        headerText = presentationData.strings.DeleteAccount_GroupsAndChannelsText
    case .messages:
        headerAnimation = "Delete3"
        headerTitle = presentationData.strings.DeleteAccount_MessageHistoryTitle
        headerText = presentationData.strings.DeleteAccount_MessageHistoryText
    case .phone:
        headerAnimation = "Delete4"
        headerTitle = presentationData.strings.DeleteAccount_EnterPhoneNumber
        headerText = ""
        hideOnSmallScreen = true
    case .password:
        headerAnimation = "Delete5"
        headerTitle = presentationData.strings.DeleteAccount_EnterPassword
        headerText = ""
        hideOnSmallScreen = true
    }
    
    entries.append(.header(presentationData.theme, headerAnimation, headerTitle, headerText, hideOnSmallScreen))
    
    switch mode {
        case .peers:
            if !peers.isEmpty {
                entries.append(.peers(presentationData.theme, peers))
            }
        case .groups:
            if !peers.isEmpty {
                entries.append(.peers(presentationData.theme, peers))
                entries.append(.info(presentationData.theme, presentationData.strings.DeleteAccount_GroupsAndChannelsInfo))
            }
        case .messages:
            break
        case .phone:
            entries.append(.phone(presentationData.theme, presentationData.strings))
        case .password:
            entries.append(.password(presentationData.theme, presentationData.strings.LoginPassword_PasswordPlaceholder))
    }
    
    return entries
}

enum DeleteAccountDataMode {
    case peers
    case groups([EnginePeer])
    case messages
    case phone
    case password
}

private struct DeleteAccountDataState: Equatable {
    var password: String
    var isLoading: Bool
    
    static func == (lhs: DeleteAccountDataState, rhs: DeleteAccountDataState) -> Bool {
        return lhs.password == rhs.password && lhs.isLoading == rhs.isLoading
    }
}

func deleteAccountDataController(context: AccountContext, mode: DeleteAccountDataMode, twoStepAuthData: TwoStepVerificationAccessConfiguration?) -> ViewController {
    let initialState = DeleteAccountDataState(password: "", isLoading: false)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((DeleteAccountDataState) -> DeleteAccountDataState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var replaceTopControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    var updateCodeImpl: (() -> Void)?
   
    var activateInputImpl: (() -> Void)?
    var dismissInputImpl: (() -> Void)?
    
    if case .phone = mode {
        loadServerCountryCodes(accountManager: context.sharedContext.accountManager, engine: context.engine, completion: {
            updateCodeImpl?()
        })
    }

    var updateCountryCodeImpl: ((Int32, String) -> Void)?
    var proceedImpl: (() -> Void)?
    
    let arguments = DeleteAccountDataArguments(context: context, openLink: { _ in
      
    }, selectCountryCode: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let controller = AuthorizationSequenceCountrySelectionController(strings: presentationData.strings, theme: presentationData.theme)
        controller.completeWithCountryCode = { code, name in
            updateCountryCodeImpl?(Int32(code), name)
            activateInputImpl?()
        }
        dismissInputImpl?()
        pushControllerImpl?(controller)
    }, updatePassword: { password in
        updateState { current in
            var updated = current
            updated.password = password
            return updated
        }
    }, proceed: {
        proceedImpl?()
    })
    
    let preloadedGroupPeers = Promise<[EnginePeer]>([])
    
    let peers: Signal<[EnginePeer], NoError>
    switch mode {
        case .peers:
            peers = combineLatest(
                context.engine.peers.recentPeers()
                |> map { recentPeers -> [EnginePeer] in
                    if case let .peers(peers) = recentPeers {
                        return peers.map { EnginePeer($0) }
                    } else {
                        return []
                    }
                },
                context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
            ) |> map { recentPeers, accountPeer -> [EnginePeer] in
                var peers: [EnginePeer] = []
                if let accountPeer = accountPeer {
                    peers.append(accountPeer)
                }
                peers.append(contentsOf: recentPeers.prefix(9))
                return peers
            }
        
            preloadedGroupPeers.set(context.engine.peers.adminedPublicChannels(scope: .all)
            |> map { peers -> [EnginePeer] in
                return peers.map { EnginePeer($0) }
            })
        case let .groups(preloadedPeers):
            peers = .single(preloadedPeers.shuffled())
        default:
            peers = .single([])
    }
    
    let cancelImpl = {
        dismissImpl?()
        
        switch mode {
            case .peers:
                addAppLogEvent(postbox: context.account.postbox, type: "deactivate.step_cloud_cancel")
            case .groups:
                addAppLogEvent(postbox: context.account.postbox, type: "deactivate.step_groups_cancel")
            case .messages:
                addAppLogEvent(postbox: context.account.postbox, type: "deactivate.step_messages_cancel")
            case .phone:
                addAppLogEvent(postbox: context.account.postbox, type: "deactivate.step_phone_cancel")
            case .password:
                addAppLogEvent(postbox: context.account.postbox, type: "deactivate.step_2fa_cancel")
        }
    }
    
    var secondaryActionDisabled = false
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        peers,
        statePromise.get()
    )
    |> map { presentationData, peers, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            cancelImpl()
        })

        var focusItemTag: DeleteAccountEntryTag?
        var buttonTitle: String
        switch mode {
            case .phone:
                buttonTitle = ""
            case .password:
                buttonTitle = ""
                focusItemTag = .password
            default:
                buttonTitle = presentationData.strings.DeleteAccount_ComeBackLater
        }
        
        let rightNavigationButton: ItemListNavigationButton?
        if state.isLoading {
            rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
        } else {
            rightNavigationButton = nil
        }
        
        let footerItem = DeleteAccountFooterItem(theme: presentationData.theme, title: buttonTitle, secondaryTitle: presentationData.strings.DeleteAccount_Continue, action: {
            cancelImpl()
        }, secondaryAction: {
            if !secondaryActionDisabled {
                secondaryActionDisabled = true
                proceedImpl?()
            }
        })
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.DeleteAccount_DeleteMyAccountTitle), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: deleteAccountDataEntries(presentationData: presentationData, mode: mode, peers: peers), style: .blocks, focusItemTag: focusItemTag, footerItem: footerItem)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal, tabBarItem: nil)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    replaceTopControllerImpl = { [weak controller] c in
        if let navigationController = controller?.navigationController as? NavigationController {
            navigationController.pushViewController(c, completion: { [weak navigationController, weak controller, weak c] in
                if let navigationController = navigationController {
                    let controllers = navigationController.viewControllers.filter { $0 !== controller }
                    c?.navigationPresentation = .modal
                    navigationController.setViewControllers(controllers, animated: false)
                }
            })
        }
    }
    dismissImpl = { [weak controller] in
        let _ = controller?.dismiss()
    }
    updateCodeImpl = { [weak controller] in
        controller?.forEachItemNode { itemNode in
            if let itemNode = itemNode as? DeleteAccountPhoneItemNode {
                itemNode.updateCountryCode()
            }
        }
    }
    
    activateInputImpl = { [weak controller] in
        controller?.forEachItemNode { itemNode in
            if let itemNode = itemNode as? DeleteAccountPhoneItemNode {
                itemNode.activateInput()
            }
        }
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    controller.didAppear = { firstTime in
        if !firstTime {
            return
        }
        activateInputImpl?()
    }
    
    updateCountryCodeImpl = { [weak controller] code, name in
        controller?.forEachItemNode { itemNode in
            if let itemNode = itemNode as? DeleteAccountPhoneItemNode {
                itemNode.updateCountryCode(code: code, name: name)
            }
        }
    }
    
    proceedImpl = { [weak controller] in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let action: ([EnginePeer], String?) -> Void = { preloadedPeers, password in
            let nextMode: DeleteAccountDataMode?
            switch mode {
                case .peers:
                    if !preloadedPeers.isEmpty {
                        nextMode = .groups(preloadedPeers)
                    } else {
                        nextMode = .messages
                    }
                case .groups:
                    nextMode = .messages
                case .messages:
                    nextMode = .phone
                case .phone:
                    if let twoStepAuthData = twoStepAuthData, case .set = twoStepAuthData {
                        nextMode = .password
                    } else {
                        nextMode = nil
                    }
                case .password:
                    nextMode = nil
            }
            
            if let nextMode = nextMode {
                let controller = deleteAccountDataController(context: context, mode: nextMode, twoStepAuthData: twoStepAuthData)
                replaceTopControllerImpl?(controller)
            } else {
                addAppLogEvent(postbox: context.account.postbox, type: "deactivate.step_confirmation_show")
                
                presentControllerImpl?(textAlertController(context: context, title: presentationData.strings.DeleteAccount_ConfirmationAlertTitle, text: presentationData.strings.DeleteAccount_ConfirmationAlertText, actions: [TextAlertAction(type: .destructiveAction, title: presentationData.strings.DeleteAccount_ConfirmationAlertDelete, action: {
                    addAppLogEvent(postbox: context.account.postbox, type: "deactivate.final")
                    
                    invokeAppLogEventsSynchronization(postbox: context.account.postbox)
                    
                    updateState { current in
                        var updated = current
                        updated.isLoading = true
                        return updated
                    }
                    
                    let accountId = context.account.id
                    let accountManager = context.sharedContext.accountManager
                    let _ = (context.engine.auth.deleteAccount(reason: "Manual", password: password)
                    |> deliverOnMainQueue).start(error: { _ in
                        updateState { current in
                            var updated = current
                            updated.isLoading = false
                            return updated
                        }
                        
                        secondaryActionDisabled = false
                        presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
                    }, completed: {
                        dismissImpl?()
                                                
                        let presentGlobalController = context.sharedContext.presentGlobalController
                        let _ = logoutFromAccount(id: accountId, accountManager: accountManager, alreadyLoggedOutRemotely: false).start(completed: {
                            Queue.mainQueue().after(0.1) {
                                presentGlobalController(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: presentationData.strings.DeleteAccount_Success), elevatedLayout: true, animateInAsReplacement: false, action: { _ in return false }), nil)
                            }
                        })
                    })
                }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {
                    addAppLogEvent(postbox: context.account.postbox, type: "deactivate.step_confirmation_cancel")
                    
                    dismissImpl?()
                })], actionLayout: .vertical))
            }
        }
        
        switch mode {
            case .peers:
                let _ = (preloadedGroupPeers.get()
                |> take(1)
                |> deliverOnMainQueue).start(next: { peers in
                    action(peers, nil)
                })
            case .phone:
                var phoneNumber: String?
                controller?.forEachItemNode { itemNode in
                    if let itemNode = itemNode as? DeleteAccountPhoneItemNode {
                        var phoneValue = itemNode.phoneNumber
                        if phoneValue.hasPrefix("+939998") {
                            phoneValue = phoneValue.replacingOccurrences(of: "+939998", with: "+9998")
                        }
                        phoneNumber = phoneValue
                    }
                }
            
                if let phoneNumber = phoneNumber, phoneNumber.count > 4 {
                    let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                    |> deliverOnMainQueue)
                    .start(next: { accountPeer in
                        if let accountPeer = accountPeer, case let .user(user) = accountPeer, var phone = user.phone {
                            if !phone.hasPrefix("+") {
                                phone = "+\(phone)"
                            }
                            if phone != phoneNumber  {
                                secondaryActionDisabled = false
                                presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.DeleteAccount_InvalidPhoneNumberError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
                                return
                            }
                            action([], nil)
                        }
                    })
                }
            case .password:
                let state = stateValue.with { $0 }
                if !state.password.isEmpty {
                    updateState { current in
                        var updated = current
                        updated.isLoading = true
                        return updated
                    }
                    
                    let _ = (context.engine.auth.requestTwoStepVerifiationSettings(password: state.password)
                    |> deliverOnMainQueue).start(error: { error in
                        secondaryActionDisabled = false
                        
                        updateState { current in
                            var updated = current
                            updated.isLoading = false
                            return updated
                        }
                        
                        let text: String
                        switch error {
                            case .limitExceeded:
                                text = presentationData.strings.LoginPassword_FloodError
                            case .invalidPassword:
                                text = presentationData.strings.DeleteAccount_InvalidPasswordError
                            default:
                                text = presentationData.strings.Login_UnknownError
                        }
                        presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
                    }, completed: {
                        updateState { current in
                            var updated = current
                            updated.isLoading = false
                            return updated
                        }
                        
                        action([], state.password)
                    })
                    return
                }
                
            default:
                action([], nil)
        }
    }
    
    switch mode {
        case .peers:
            addAppLogEvent(postbox: context.account.postbox, type: "deactivate.step_cloud_show")
        case .groups:
            addAppLogEvent(postbox: context.account.postbox, type: "deactivate.step_groups_show")
        case .messages:
            addAppLogEvent(postbox: context.account.postbox, type: "deactivate.step_messages_show")
        case .phone:
            addAppLogEvent(postbox: context.account.postbox, type: "deactivate.step_phone_show")
        case .password:
            addAppLogEvent(postbox: context.account.postbox, type: "deactivate.step_2fa_show")
    }
    
    return controller
}

