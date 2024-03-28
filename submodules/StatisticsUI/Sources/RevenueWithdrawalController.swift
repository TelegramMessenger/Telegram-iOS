import Foundation
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import PeerInfoUI
import AccountContext

func revenueWithdrawalController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: EnginePeer.Id, present: @escaping (ViewController, Any?) -> Void, completion: @escaping (String) -> Void) -> ViewController {
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
        
        let signal = context.engine.peers.requestChannelRevenueWithdrawalUrl(peerId: peerId, password: contentNode.password)
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
