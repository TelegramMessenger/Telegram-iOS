import UIKit
import NGAuth
import NGEnv
import NGExtensions
import NGModels
import NGPurchaseEsim
import NGSetupEsim

protocol MyEsimsRouterInput: AnyObject {
    func routeToPurchaseEsim(regionId: Int, deeplink: Deeplink?)
    func routeToTopUpEsim(icc: String, regionId: Int)
    func routeToSetupEsim(activationInfo: EsimActivationInfo)
    func dismiss()
    func dismissWithBot(session: String)
}

final class MyEsimsRouter: MyEsimsRouterInput {
    weak var parentViewController: MyEsimsViewController?
    
    //  MARK: - Dependencies
    
    private let purchaseEsimBuilder: PurchaseEsimBuilder
    private let setupEsimBuilder: SetupEsimBuilder
    
    //  MARK: - Listener
    
    weak var purchaseEsimListener: PurchaseEsimListener?
    weak var loginListener: LoginListener?
    
    //  MARK: - Lifecycle
    
    init(purchaseEsimBuilder: PurchaseEsimBuilder, setupEsimBuilder: SetupEsimBuilder) {
        self.purchaseEsimBuilder = purchaseEsimBuilder
        self.setupEsimBuilder = setupEsimBuilder
    }
    
    func routeToPurchaseEsim(regionId: Int, deeplink: Deeplink?) {
        let vc = purchaseEsimBuilder.build(icc: nil, regionId: regionId, deeplink: deeplink, listener: self, loginListener: loginListener)
        parentViewController?.navigationController?.pushViewController(vc, animated: true)
    }
    
    func routeToTopUpEsim(icc: String, regionId: Int) {
        let vc = purchaseEsimBuilder.build(icc: icc, regionId: regionId, deeplink: nil, listener: self, loginListener: loginListener)
        parentViewController?.navigationController?.pushViewController(vc, animated: true)
    }
    
    func routeToSetupEsim(activationInfo: EsimActivationInfo) {
        let vc = setupEsimBuilder.build(activationInfo: activationInfo)
        parentViewController?.navigationController?.pushViewController(vc, animated: true)
    }

    func dismiss() {
        parentViewController?.dismiss(animated: true, completion: nil)
    }
    
    func dismissWithBot(session: String) {
        parentViewController?.navigationController?.dismiss(animated: true, completion: { 
            guard var url = URL(string: "ncg://resolve") else { return }
            url = url
                .appending("domain", value: NGENV.telegram_auth_bot)
                .appending("start", value: session)
            
            UIApplication.shared.openURL(url)
        })
    }
}

//  MARK: - PurchaseEsimListener

extension MyEsimsRouter: PurchaseEsimListener {
    func didPurchase(esim: UserEsim) {
        guard let parent = parentViewController else { return } 
        let setupEsimVc = setupEsimBuilder.build(activationInfo: esim.activationInfo)
        parentViewController?.navigationController?.popTo(parent, thenPush: setupEsimVc, animated: true)
        purchaseEsimListener?.didPurchase(esim: esim)
    }
    
    func didTopUp(esim: UserEsim) {
        guard let parent = parentViewController else { return } 
        parentViewController?.navigationController?.popToViewController(parent, animated: true)
        purchaseEsimListener?.didTopUp(esim: esim)
    }
}
