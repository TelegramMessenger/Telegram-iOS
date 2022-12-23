import NGAuth
import NGSecondPhone
import UIKit
import NGCoreUI
import NGEnv
import NGLotteryUI
import NGModels
import NGMyEsims
import NGSpecialOffer
import NGTheme
import Postbox

protocol AssistantRouterInput: AnyObject {
    /// Test method
    func dismiss()
    func showMyEsims(deeplink: Deeplink?)
    func showChat(chatURL: URL?)
    func dismissWithBot(session: String)
    func showSpecialOffer(id: String)
    func showLottery()
}

final class AssistantRouter: AssistantRouterInput {
    private weak var assistantListener: AssistantListener?
    
    weak var parentViewController: AssistantViewController?
    
    private let myEsimsBuilder: MyEsimsBuilder
    private let specialOfferBuilder: SpecialOfferBuilder
    private let lotteryFlowFactory: LotteryFlowFactory
    
    init(assistantListener: AssistantListener?,
         myEsimsBuilder: MyEsimsBuilder,
         specialOfferBuilder: SpecialOfferBuilder,
         lotteryFlowFactory: LotteryFlowFactory,
         ngTheme: NGThemeColors) {
        self.assistantListener = assistantListener
        self.myEsimsBuilder = myEsimsBuilder
        self.specialOfferBuilder = specialOfferBuilder
        self.lotteryFlowFactory = lotteryFlowFactory
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
        
        parentViewController?.present(vc, animated: true)
    }
    
    func showLottery() {
        let navigation = makeDefaultNavigationController()
        
        let flow = lotteryFlowFactory.makeFlow(navigationController: navigation)
        
        let input = LotteryFlowInput()
        
        let handlers = LotteryFlowHandlers(
            close: { [weak self] in
                self?.parentViewController?.dismiss(animated: true)
            }
        )
        
        let lotteryController = flow.makeStartViewController(input: input, handlers: handlers)
        
        navigation.setViewControllers([lotteryController], animated: false)
        navigation.modalPresentationStyle = .overFullScreen
        
        parentViewController?.present(navigation, animated: true)
    }
}
