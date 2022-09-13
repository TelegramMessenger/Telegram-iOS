import Foundation
import AccountContext
import Display
import NGExtensions
import NGModels
import NGSubscription

class NGDeeplinkHandler {
    
    //  MARK: - Dependencies
    
    private let tgAccountContext: AccountContext
    private let navigationController: NavigationController?
    
    //  MARK: - Lifecycle
    
    init(tgAccountContext: AccountContext, navigationController: NavigationController?) {
        self.tgAccountContext = tgAccountContext
        self.navigationController = navigationController
    }
    
    //  MARK: - Public Functions
    
    func handle(url: String) -> Bool {
        guard let url = URL(string: url) else { return false }
        return handle(url: url)
    }
    
    //  MARK: - Private Functions

    private func handle(url: URL) -> Bool {
        if handleUniversalLink(url) {
            return true
        }
        
        if handleDeeplink(url) {
            return true
        }
        
        return false
    }
    
    private func handleUniversalLink(_ url: URL) -> Bool {
        guard url.scheme == "https",
              url.host == "nicegram.app",
              url.path == "/deeplink",
              let deeplinkParam = url.queryItems["url"],
              let deeplink = URL(string: deeplinkParam) else { return false }
        
        return handleDeeplink(deeplink)
    }
    
    private func handleDeeplink(_ url: URL) -> Bool {
        guard url.scheme == "ncg" else { return false }
        
        switch url.host {
        case "nicegramPremium":
            return handleNicegramPremium(url: url)
        case "assistant":
            return handleAssistant(url: url)
        case "getEsim":
            return handlePurchaseEsim(url: url)
        default:
            return false
        }
    }
}

//  MARK: - Child Handlers
// TODO: Extract each handler to separate class

private extension NGDeeplinkHandler {
    func handleNicegramPremium(url: URL) -> Bool {
        let presentationData = tgAccountContext.sharedContext.currentPresentationData.with({ $0 })
        
        let c = SubscriptionBuilderImpl(presentationData: presentationData).build()
        c.modalPresentationStyle = .fullScreen
        
        navigationController?.topViewController?.present(c, animated: true)
        
        return true
    }
    
    func handleAssistant(url: URL) -> Bool {
        showNicegramAssistant(deeplink: AssistantDeeplink())
        return true
    }
    
    func handlePurchaseEsim(url: URL) -> Bool {
        let bundleId: Int?
        if let bundleIdParam = url.queryItems["bundleId"] {
            bundleId = Int(bundleIdParam)
        } else {
            bundleId = nil
        }
        
        showNicegramAssistant(deeplink: PurchaseEsimDeeplink(bundleId: bundleId))
        
        return true
    }
}

//  MARK: - Helpers

private extension NGDeeplinkHandler {
    private func showNicegramAssistant(deeplink: Deeplink) {
        guard let rootController = navigationController as? TelegramRootController else { return }
        rootController.openChatsController(activateSearch: false)
        rootController.popToRoot(animated: true)
        rootController.chatListController?.showNicegramAssistant(deeplink: deeplink)
    }
}

