import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TextFormat
import AccountContext
import PresentationDataUtils
import PasswordSetupUI
import OldChannelsController
import ComponentFlow
import AlertComponent
import AlertInputFieldComponent

private func commitChannelOwnershipTransferController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    peer: EnginePeer,
    member: TelegramUser,
    present: @escaping (ViewController, Any?) -> Void,
    push: @escaping (ViewController) -> Void,
    completion: @escaping (EnginePeer.Id?) -> Void
) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings

    let inputState = AlertInputFieldComponent.ExternalState()

    let doneIsEnabled: Signal<Bool, NoError> = inputState.valueSignal
    |> map { value in
        return !value.isEmpty
    }
    
    let doneInProgressPromise = ValuePromise<Bool>(false)
    
    var content: [AnyComponentWithIdentity<AlertComponentEnvironment>] = []
    content.append(AnyComponentWithIdentity(
        id: "title",
        component: AnyComponent(
            AlertTitleComponent(title: strings.Channel_OwnershipTransfer_EnterPassword)
        )
    ))
    content.append(AnyComponentWithIdentity(
        id: "text",
        component: AnyComponent(
            AlertTextComponent(content: .plain(strings.Channel_OwnershipTransfer_EnterPasswordText))
        )
    ))

    var applyImpl: (() -> Void)?
    content.append(AnyComponentWithIdentity(
        id: "input",
        component: AnyComponent(
            AlertInputFieldComponent(
                context: context,
                placeholder: strings.Channel_OwnershipTransfer_PasswordPlaceholder,
                isSecureTextEntry: true,
                isInitiallyFocused: true,
                externalState: inputState,
                returnKeyAction: {
                    applyImpl?()
                }
            )
        )
    ))
    
    var effectiveUpdatedPresentationData: (PresentationData, Signal<PresentationData, NoError>)
    if let updatedPresentationData {
        effectiveUpdatedPresentationData = updatedPresentationData
    } else {
        effectiveUpdatedPresentationData = (presentationData, context.sharedContext.presentationData)
    }
    
    var dismissImpl: (() -> Void)?
    let alertController = AlertScreen(
        configuration: AlertScreen.Configuration(allowInputInset: true),
        content: content,
        actions: [
            .init(title: strings.Common_Cancel),
            .init(title: strings.OwnershipTransfer_Transfer, type: .default, action: {
                applyImpl?()
            }, autoDismiss: false, isEnabled: doneIsEnabled, progress: doneInProgressPromise.get())
        ],
        updatedPresentationData: effectiveUpdatedPresentationData
    )
    applyImpl = {
        doneInProgressPromise.set(true)
        
        let signal: Signal<EnginePeer.Id?, ChannelOwnershipTransferError>
        if case let .channel(peer) = peer {
            signal = context.peerChannelMemberCategoriesContextsManager.transferOwnership(engine: context.engine, peerId: peer.id, memberId: member.id, password: inputState.value) |> mapToSignal { _ in
                return .complete()
            }
            |> then(.single(nil))
        } else if case let .legacyGroup(peer) = peer {
            signal = context.engine.peers.convertGroupToSupergroup(peerId: peer.id)
            |> map(Optional.init)
            |> mapError { error -> ChannelOwnershipTransferError in
                switch error {
                case .tooManyChannels:
                    return .tooMuchJoined
                default:
                    return .generic
                }
            }
            |> deliverOnMainQueue
            |> mapToSignal { upgradedPeerId -> Signal<EnginePeer.Id?, ChannelOwnershipTransferError> in
                guard let upgradedPeerId = upgradedPeerId else {
                    return .fail(.generic)
                }
                return context.peerChannelMemberCategoriesContextsManager.transferOwnership(engine: context.engine, peerId: upgradedPeerId, memberId: member.id, password: inputState.value) |> mapToSignal { _ in
                    return .complete()
                }
                |> then(.single(upgradedPeerId))
            }
        } else {
            signal = .never()
        }
        
        let _ = (signal
        |> deliverOnMainQueue).start(next: { upgradedPeerId in
            dismissImpl?()
            completion(upgradedPeerId)
        }, error: { error in
            var isGroup = true
            if case let .channel(channel) = peer, case .broadcast = channel.info {
                isGroup = false
            }
            
            doneInProgressPromise.set(false)
            
            var errorTextAndActions: (String, [TextAlertAction])?
            switch error {
            case .tooMuchJoined:
                push(oldChannelsController(context: context, intent: .upgrade))
                return
            case .invalidPassword:
                inputState.animateError()
            case .limitExceeded:
                errorTextAndActions = (strings.TwoStepAuth_FloodError, [TextAlertAction(type: .defaultAction, title: strings.Common_OK, action: {})])
            case .adminsTooMuch:
                errorTextAndActions = (isGroup ? strings.Group_OwnershipTransfer_ErrorAdminsTooMuch :  strings.Channel_OwnershipTransfer_ErrorAdminsTooMuch, [TextAlertAction(type: .defaultAction, title: strings.Common_OK, action: {})])
            case .userPublicChannelsTooMuch:
                errorTextAndActions = (strings.Channel_OwnershipTransfer_ErrorPublicChannelsTooMuch, [TextAlertAction(type: .defaultAction, title: strings.Common_OK, action: {})])
            case .userLocatedGroupsTooMuch:
                errorTextAndActions = (strings.Group_OwnershipTransfer_ErrorLocatedGroupsTooMuch, [TextAlertAction(type: .defaultAction, title: strings.Common_OK, action: {})])
            case .userBlocked, .restricted:
                errorTextAndActions = (isGroup ? strings.Group_OwnershipTransfer_ErrorPrivacyRestricted :  strings.Channel_OwnershipTransfer_ErrorPrivacyRestricted, [TextAlertAction(type: .defaultAction, title: strings.Common_OK, action: {})])
            default:
                errorTextAndActions = (strings.Login_UnknownError, [TextAlertAction(type: .defaultAction, title: strings.Common_OK, action: {})])
            }

            if let (text, actions) = errorTextAndActions {
                dismissImpl?()
                present(textAlertController(context: context, title: nil, text: text, actions: actions), nil)
            }
        })
    }
    dismissImpl = { [weak alertController] in
        alertController?.dismiss(completion: nil)
    }
    return alertController
}

private func confirmChannelOwnershipTransferController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    peer: EnginePeer,
    member: TelegramUser,
    onLeave: Bool,
    present: @escaping (ViewController, Any?) -> Void,
    push: @escaping (ViewController) -> Void,
    completion: @escaping (EnginePeer.Id?) -> Void
) -> ViewController {
    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
    
    var isGroup = true
    if case let .channel(channel) = peer, case .broadcast = channel.info {
        isGroup = false
    }
    
    var title: String
    var text: String
    if isGroup {
        title = presentationData.strings.Group_OwnershipTransfer_Title
        text = onLeave ? presentationData.strings.Group_OwnershipTransfer_DescriptionShortInfo(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), EnginePeer.user(member).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string : presentationData.strings.Group_OwnershipTransfer_DescriptionInfo(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), EnginePeer.user(member).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
    } else {
        title = presentationData.strings.Channel_OwnershipTransfer_Title
        text = presentationData.strings.Channel_OwnershipTransfer_DescriptionInfo(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), EnginePeer.user(member).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
    }
    
    let controller = textAlertController(
        context: context,
        updatedPresentationData: updatedPresentationData,
        title: title,
        text: text,
        actions: [
            TextAlertAction(type: .genericAction, title: presentationData.strings.Channel_OwnershipTransfer_ChangeOwner, action: {
                present(commitChannelOwnershipTransferController(context: context, peer: peer, member: member, present: present, push: push, completion: completion), nil)
            }),
            TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {})
        ],
        actionLayout: .vertical
    )
    return controller
}

public func channelOwnershipTransferController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    peer: EnginePeer,
    member: TelegramUser,
    onLeave: Bool,
    initialError: ChannelOwnershipTransferError,
    present: @escaping (ViewController, Any?) -> Void,
    push: @escaping (ViewController) -> Void,
    completion: @escaping (EnginePeer.Id?) -> Void
) -> ViewController {
    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
    let strings = presentationData.strings
    
    var title: String? = strings.OwnershipTransfer_SecurityCheck
    var text = strings.OwnershipTransfer_SecurityRequirements
    
    var isGroup = true
    if case let .channel(channel) = peer, case .broadcast = channel.info {
        isGroup = false
    }
    
    var actions: [AlertScreen.Action] = [
        .init(title: strings.Common_OK, type: .default)
    ]
    switch initialError {
    case .requestPassword:
        return confirmChannelOwnershipTransferController(context: context, updatedPresentationData: updatedPresentationData, peer: peer, member: member, onLeave: onLeave, present: present, push: push, completion: completion)
    case .twoStepAuthTooFresh, .authSessionTooFresh:
        text = text + strings.OwnershipTransfer_ComeBackLater
    case .twoStepAuthMissing:
        actions = [
            .init(title: strings.OwnershipTransfer_SetupTwoStepAuth, type: .default, action: {
                let controller = SetupTwoStepVerificationController(context: context, initialState: .automatic, stateUpdated: { update, shouldDismiss, controller in
                    if shouldDismiss {
                        controller.dismiss()
                    }
                })
                present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }),
            .init(title: strings.Common_Cancel)
        ]
    case .adminsTooMuch:
        title = nil
        text = isGroup ? strings.Group_OwnershipTransfer_ErrorAdminsTooMuch : strings.Channel_OwnershipTransfer_ErrorAdminsTooMuch
    case .userPublicChannelsTooMuch:
        title = nil
        text = strings.Channel_OwnershipTransfer_ErrorPublicChannelsTooMuch
    case .userBlocked, .restricted:
        title = nil
        text = isGroup ? strings.Group_OwnershipTransfer_ErrorPrivacyRestricted : strings.Channel_OwnershipTransfer_ErrorPrivacyRestricted
    default:
        title = nil
        text = strings.Login_UnknownError
    }
    
    return AlertScreen(
        context: context,
        configuration: AlertScreen.Configuration(actionAlignment: .vertical),
        title: title,
        text: text,
        actions: actions
    )
}
