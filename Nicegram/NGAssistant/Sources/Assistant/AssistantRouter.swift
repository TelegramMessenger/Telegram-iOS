import NGAuth
import NGSecondPhone
import UIKit
import NGEnv
import NGModels
import NGMyEsims
import NGSpecialOffer
import NGTheme
import NGTransitions
import Postbox

protocol AssistantRouterInput: AnyObject {
    /// Test method
    func dismiss()
    func showMyEsims(deeplink: Deeplink?)
    func showLogin()
    func showChat(chatURL: URL?)
    func dismissWithBot(session: String)
    func showSpecialOffer(id: String)
}

final class AssistantRouter: AssistantRouterInput {
    private weak var assistantListener: AssistantListener?
    
    weak var parentViewController: AssistantViewController?
    
    private let myEsimsBuilder: MyEsimsBuilder
    private let loginBuilder: LoginBuilder
    private let specialOfferBuilder: SpecialOfferBuilder
    
    private let popupTransition: PopupTransition
    
    init(assistantListener: AssistantListener?,
         myEsimsBuilder: MyEsimsBuilder,
         loginBuilder: LoginBuilder,
         specialOfferBuilder: SpecialOfferBuilder,
         ngTheme: NGThemeColors) {
        self.assistantListener = assistantListener
        self.myEsimsBuilder = myEsimsBuilder
        self.loginBuilder = loginBuilder
        self.specialOfferBuilder = specialOfferBuilder
        self.popupTransition = PopupTransition(blurStyle: ngTheme.blurStyle)
    }

    func dismiss() {
        parentViewController?.dismiss(animated: false, completion: nil)
    }
    
    func showMyEsims(deeplink: Deeplink?) {
        let animated = (deeplink == nil)
        let vc = myEsimsBuilder.build(deeplink: deeplink)
        parentViewController?.navigationController?.setNavigationBarHidden(false, animated: animated)
        parentViewController?.navigationController?.pushViewController(vc, animated: animated)
    }
    
    func showChat(chatURL: URL?) {
        parentViewController?.dismiss(animated: false) { [weak self] in
            guard let self = self else { return }
            self.assistantListener?.onOpenChat(chatURL: chatURL)
        }
    }
    
    func showLogin() {
        let loginViewController = loginBuilder.build()
        parentViewController?.navigationController?.pushViewController(loginViewController, animated: true)
    }
    
    func dismissWithBot(session: String) {
        parentViewController?.dismiss(animated: true, completion: { 
            guard var url = URL(string: "ncg://resolve") else { return }
            url = url
                .appending("domain", value: NGENV.telegram_auth_bot)
                .appending("start", value: session)
            
            UIApplication.shared.openURL(url)
        })
    }
    
    func showSpecialOffer(id: String) {
        let vc = specialOfferBuilder.build(offerId: id) { [weak self] in
            self?.parentViewController?.dismiss(animated: true)
        }
        
        vc.modalPresentationStyle = .custom
        vc.transitioningDelegate = popupTransition
        
        parentViewController?.present(vc, animated: true)
    }
}
