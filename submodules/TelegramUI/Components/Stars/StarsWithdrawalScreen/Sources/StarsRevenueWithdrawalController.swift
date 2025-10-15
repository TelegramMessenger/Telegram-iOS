import Foundation
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import AccountContext
import PasswordSetupUI
import Markdown
import OwnershipTransferController

public func confirmStarsRevenueWithdrawalController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: EnginePeer.Id, amount: Int64, present: @escaping (ViewController, Any?) -> Void, completion: @escaping (String) -> Void) -> ViewController {
    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
    
    var dismissImpl: (() -> Void)?
    var proceedImpl: (() -> Void)?
    
    let disposable = MetaDisposable()
    
    let contentNode = ChannelOwnershipTransferAlertContentNode(theme: AlertControllerTheme(presentationData: presentationData), ptheme: presentationData.theme, strings: presentationData.strings, title: presentationData.strings.Monetization_Withdraw_EnterPassword_Title, text: presentationData.strings.Monetization_Withdraw_EnterPassword_Text, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?()
    }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Monetization_Withdraw_EnterPassword_Done, action: {
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
    controller.dismissed = { _ in
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
        
        let signal = context.engine.peers.requestStarsRevenueWithdrawalUrl(peerId: peerId, ton: false, amount: amount, password: contentNode.password)
        disposable.set((signal |> deliverOnMainQueue).start(next: { url in
            dismissImpl?()
            completion(url)
        }, error: { [weak contentNode] error in
            var errorTextAndActions: (String, [TextAlertAction])?
            switch error {
                case .invalidPassword:
                    contentNode?.animateError()
                case .limitExceeded:
                    errorTextAndActions = (presentationData.strings.TwoStepAuth_FloodError, [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
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

public func starsRevenueWithdrawalController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: EnginePeer.Id, amount: Int64, initialError: RequestStarsRevenueWithdrawalError, present: @escaping (ViewController, Any?) -> Void, completion: @escaping (String) -> Void) -> ViewController {
    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
    let theme = AlertControllerTheme(presentationData: presentationData)
    
    var title: NSAttributedString? = NSAttributedString(string: presentationData.strings.OwnershipTransfer_SecurityCheck, font: Font.semibold(presentationData.listsFontSize.itemListBaseFontSize), textColor: theme.primaryColor, paragraphAlignment: .center)
    
    var text = presentationData.strings.Monetization_Withdraw_SecurityRequirements
    let textFontSize = presentationData.listsFontSize.baseDisplaySize * 13.0 / 17.0
    
    var actions: [TextAlertAction] = []
    switch initialError {
        case .requestPassword:
        return confirmStarsRevenueWithdrawalController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, amount: amount, present: present, completion: completion)
        case .twoStepAuthTooFresh, .authSessionTooFresh:
            text = text + presentationData.strings.Monetization_Withdraw_ComeBackLater
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
        default:
            title = nil
            text = presentationData.strings.Login_UnknownError
            actions = [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]
    }
    
    let body = MarkdownAttributeSet(font: Font.regular(textFontSize), textColor: theme.primaryColor)
    let bold = MarkdownAttributeSet(font: Font.semibold(textFontSize), textColor: theme.primaryColor)
    let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in return nil }), textAlignment: .center)
    
    return richTextAlertController(context: context, title: title, text: attributedText, actions: actions)
}
