import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ActivityIndicator
import TextFormat
import AccountContext
import AlertUI
import PresentationDataUtils
import PasswordSetupUI
import Markdown
import PeerInfoUI

private func commitOwnershipTransferController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, present: @escaping (ViewController, Any?) -> Void, commit: @escaping (String) -> Signal<MessageActionCallbackResult, MessageActionCallbackError>, completion: @escaping (MessageActionCallbackResult) -> Void) -> ViewController {
    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
    
    var dismissImpl: (() -> Void)?
    var proceedImpl: (() -> Void)?
    
    let disposable = MetaDisposable()
    
    let contentNode = ChannelOwnershipTransferAlertContentNode(theme: AlertControllerTheme(presentationData: presentationData), ptheme: presentationData.theme, strings: presentationData.strings, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?()
    }), TextAlertAction(type: .defaultAction, title: presentationData.strings.OwnershipTransfer_Transfer, action: {
        proceedImpl?()
    })])
    
    contentNode.complete = {
        proceedImpl?()
    }
    
    let controller = AlertController(theme: AlertControllerTheme(presentationData: presentationData), contentNode: contentNode)
    let presentationDataDisposable = (updatedPresentationData?.signal ?? context.sharedContext.presentationData).start(next: { [weak controller, weak contentNode] presentationData in
        controller?.theme = AlertControllerTheme(presentationData: presentationData)
        contentNode?.theme = presentationData.theme
    })
    controller.dismissed = {
        presentationDataDisposable.dispose()
        disposable.dispose()
    }
    dismissImpl = { [weak controller, weak contentNode] in
        contentNode?.dismissInput()
        controller?.dismissAnimated()
    }
    proceedImpl = { [weak contentNode] in
        guard let contentNode = contentNode else {
            return
        }
        contentNode.updateIsChecking(true)
        
        disposable.set((commit(contentNode.password) |> deliverOnMainQueue).start(next: { result in
            completion(result)
            dismissImpl?()
        }, error: { [weak contentNode] error in
            var errorTextAndActions: (String, [TextAlertAction])?
            switch error {
                case .invalidPassword:
                    contentNode?.animateError()
                case .limitExceeded:
                    errorTextAndActions = (presentationData.strings.TwoStepAuth_FloodError, [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                case .userBlocked, .restricted:
                    errorTextAndActions = (presentationData.strings.Group_OwnershipTransfer_ErrorPrivacyRestricted, [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                default:
                    errorTextAndActions = (presentationData.strings.Login_UnknownError, [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
            }
            contentNode?.updateIsChecking(false)
            
            if let (text, actions) = errorTextAndActions {
                dismissImpl?()
                present(textAlertController(context: context, title: nil, text: text, actions: actions), nil)
            }
        }))
    }
    
    return controller
}


func ownershipTransferController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, initialError: MessageActionCallbackError, present: @escaping (ViewController, Any?) -> Void, commit: @escaping (String) -> Signal<MessageActionCallbackResult, MessageActionCallbackError>, completion: @escaping (MessageActionCallbackResult) -> Void) -> ViewController {
    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
    let theme = AlertControllerTheme(presentationData: presentationData)
    
    var title: NSAttributedString? = NSAttributedString(string: presentationData.strings.OwnershipTransfer_SecurityCheck, font: Font.medium(presentationData.listsFontSize.itemListBaseFontSize), textColor: theme.primaryColor, paragraphAlignment: .center)
    
    var text = presentationData.strings.OwnershipTransfer_SecurityRequirements
    var actions: [TextAlertAction] = []
    
    switch initialError {
        case .requestPassword:
            return commitOwnershipTransferController(context: context, updatedPresentationData: updatedPresentationData, present: present, commit: commit, completion: completion)
        case .twoStepAuthTooFresh, .authSessionTooFresh:
            text = text + presentationData.strings.OwnershipTransfer_ComeBackLater
            actions = [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]
        case .twoStepAuthMissing:
            actions = [TextAlertAction(type: .genericAction, title: presentationData.strings.OwnershipTransfer_SetupTwoStepAuth, action: {
                let controller = SetupTwoStepVerificationController(context: context, initialState: .automatic, stateUpdated: { update, shouldDismiss, controller in
                    if shouldDismiss {
                        controller.dismiss()
                    }
                })
                present(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {})]
        case .userBlocked, .restricted:
            title = nil
            text = presentationData.strings.Group_OwnershipTransfer_ErrorPrivacyRestricted
            actions = [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]
        default:
            title = nil
            text = presentationData.strings.Login_UnknownError
            actions = [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]
    }
    
    let body = MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.primaryColor)
    let bold = MarkdownAttributeSet(font: Font.semibold(13.0), textColor: theme.primaryColor)
    let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .center)
    
    return richTextAlertController(context: context, title: title, text: attributedText, actions: actions)
}
