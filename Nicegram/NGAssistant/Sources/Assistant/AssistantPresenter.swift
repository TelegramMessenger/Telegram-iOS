import UIKit
import NGLocalization
import NGRemoteConfig
import NGSpecialOffer

typealias AssistantPresenterInput = AssistantInteractorOutput

protocol AssistantPresenterOutput: AnyObject {
    func display(isAuthorized: Bool, isAnimated: Bool)
    func display(isLoading: Bool)
    
    func display(viewItem: PersonalAssistantItem)
    func display(titleText: String?)
    func display(comunityText: String?)
    func display(loginTitleText: String?)
    func display(specialOffer: SpecialOfferViewModel, animated: Bool)
    func displaySuccessToast()
    func displayCommunitySection(isHidden: Bool)
    
    func onLogout()
}

final class AssistantPresenter: AssistantPresenterInput {
    weak var output: AssistantPresenterOutput?
    
    private var viewDidAppear = false
    
    func onViewDidAppear() {
        viewDidAppear = true
    }
    
    func handleAuth(isAuthorized: Bool, isAnimated: Bool) {
        output?.display(isAuthorized: isAuthorized, isAnimated: isAnimated)
    }
    
    func handleLoading(isLoading: Bool) {
        output?.display(isLoading: isLoading)
    }
    
    func handleLogout() {
        output?.onLogout()
    }
    
    func handleViewDidLoad() {
        let mobileDataItem = PersonalAssistantItem(
            image: UIImage(named: "PAMobileData"), 
            title: ngLocalized("Nicegram.Assistant.MobileData"),
            subtitle: ngLocalized("Nicegram.Assistant.MobileData.Esim"), 
            description: ngLocalized("Nicegram.Assistant.MobileData.Description"),
            item: .mobileData
        )
        output?.display(viewItem: mobileDataItem)
        
        let telegramChannelItem = PersonalAssistantItem(
            image: UIImage(named: "ng.telegram"),
            title: ngLocalized("Nicegram.Assistant.NicegramCommunity.OfficialChannel"), 
            subtitle: nil, 
            description: nil, 
            item: .channel
        )
        output?.display(viewItem: telegramChannelItem)
        
        let telegramChatItem = PersonalAssistantItem(
            image: UIImage(named: "ng.telegram"),
            title: ngLocalized("Nicegram.Assistant.NicegramCommunity.OfficialСhat"), 
            subtitle: nil, 
            description: nil, 
            item: .chat
        )
        output?.display(viewItem: telegramChatItem)
        
        let supportItem = PersonalAssistantItem(
            image: UIImage(named: "PAMessageQuestion"),
            title: ngLocalized("Nicegram.Assistant.Support"), 
            subtitle: nil, 
            description: nil, 
            item: .support
        )
        output?.display(viewItem: supportItem)
        
        let rateUsItem = PersonalAssistantItem(
            image: UIImage(named: "PARate"),
            title: ngLocalized("Nicegram.Assistant.Rate us"), 
            subtitle: nil, 
            description: nil, 
            item: .rateUs
        )
        output?.display(viewItem: rateUsItem)
        
        let logoutItem = PersonalAssistantItem(
            image: UIImage(named: "PALogOut"),
            title: ngLocalized("Nicegram.Assistant.Logout"), 
            subtitle: nil, 
            description: nil, 
            item: .logout
        )
        output?.display(viewItem: logoutItem)
        
        output?.display(titleText: ngLocalized("Nicegram.Assistant.Title"))
        output?.display(comunityText: ngLocalized("Nicegram.Assistant.NicegramCommunity").uppercased())
        output?.display(loginTitleText: ngLocalized("Nicegram.Assistant.SignIn"))
        
        output?.displayCommunitySection(isHidden: hideUnblock)
    }
    
    func handle(specialOffer: SpecialOffer) {
        output?.display(specialOffer: mapSpecialOfferToViewModel(specialOffer), animated: viewDidAppear)
    }
    
    func handleSuccessSignInWithTelegram() {
        output?.displaySuccessToast()
    }
}

//  MARK: - Mapping

private extension AssistantPresenter {
    func mapSpecialOfferToViewModel(_ specialOffer: SpecialOffer) -> SpecialOfferViewModel {
        return SpecialOfferViewModel(
            id: specialOffer.id,
            image: UIImage(named: "ng.ticket.discount"),
            title: ngLocalized("Nicegram.Assistant.SpecialOffer")
        )
    }
}
