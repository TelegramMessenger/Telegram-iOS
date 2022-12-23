import Combine
import Foundation
import EsimAuth
import NGAppCache
import NGAuth
import NGCoreUI
import NGLogging
import NGLottery
import NGModels
import NGRemoteConfig
import NGRepositories
import NGSpecialOffer
import UIKit

typealias AssistantInteractorInput = AssistantViewControllerOutput

protocol AssistantInteractorOutput {
    func onViewDidAppear()
    func handleUser(_: EsimUser?, animated: Bool)
    func handleLoading(isLoading: Bool)
    func handleViewDidLoad() 
    func handleLogout()
    func handle(specialOffer: SpecialOffer)
    func handleSuccessSignInWithTelegram()
    func presentLottery(_: Bool)
    func presentLottery(jackpot: Money)
}

@available(iOS 13.0, *)
class AssistantInteractor: AssistantInteractorInput {
    var output: AssistantInteractorOutput!
    var router: AssistantRouterInput!

    private let esimAuth: EsimAuth
    private let userEsimsRepository: UserEsimsRepository
    private let getCurrentUserUseCase: GetCurrentUserUseCase
    private let getSpecialOfferUseCase: GetSpecialOfferUseCase
    private let getReferralLinkUseCase: GetReferralLinkUseCase
    private let initiateLoginWithTelegramUseCase: InitiateLoginWithTelegramUseCase
    private let getLotteryDataUseCase: GetLotteryDataUseCase
    private let eventsLogger: EventsLogger
    
    private var deeplink: Deeplink?
    private var specialOffer: SpecialOffer?
    private var isAuthorized = false
    private var cancellables = Set<AnyCancellable>()
    
    
    init(deeplink: Deeplink?, esimAuth: EsimAuth, userEsimsRepository: UserEsimsRepository, getCurrentUserUseCase: GetCurrentUserUseCase, getSpecialOfferUseCase: GetSpecialOfferUseCase, getReferralLinkUseCase: GetReferralLinkUseCase, initiateLoginWithTelegramUseCase: InitiateLoginWithTelegramUseCase, getLotteryDataUseCase: GetLotteryDataUseCase, eventsLogger: EventsLogger) {
        self.deeplink = deeplink
        self.esimAuth = esimAuth
        self.userEsimsRepository = userEsimsRepository
        self.getCurrentUserUseCase = getCurrentUserUseCase
        self.getSpecialOfferUseCase = getSpecialOfferUseCase
        self.getReferralLinkUseCase = getReferralLinkUseCase
        self.initiateLoginWithTelegramUseCase = initiateLoginWithTelegramUseCase
        self.getLotteryDataUseCase = getLotteryDataUseCase
        self.eventsLogger = eventsLogger
    }
    
    func onViewDidLoad() {
        output.handleViewDidLoad()
        trySignInWithTelegram()
        fetchSpecialOffer()
        subscribeToLotteryChange()
    }
    
    func onViewDidAppear() {
        output.onViewDidAppear()
        tryHandleDeeplink()
    }
    
    func handleAuth(isAnimated: Bool) {
        let currentUser: EsimUser?
        if getCurrentUserUseCase.isAuthorized() {
            currentUser = getCurrentUserUseCase.getCurrentUser()
        } else {
            currentUser = nil
        }
        
        handleUser(currentUser, animated: isAnimated)
    }
    
    func handleDismiss() {
        router.dismiss()
        router = nil
    }
    
    func handleMyEsims() {
        router.showMyEsims(deeplink: nil)
    }
    
    func handleChat(chatURL: URL?) {
        router.showChat(chatURL: chatURL)
    }
    
    func handleOnLogin() {
        initiateLoginWithTelegram()
    }
    
    func handleLogout() {
        output.handleLoading(isLoading: true)
        esimAuth.signOut { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.output.handleLoading(isLoading: false)
                switch result {
                case .success(_):
                    self.userEsimsRepository.clear()
                    self.output.handleLogout()
                case .failure(let error):
                    print(error.localizedDescription)
                }
            }
        }
    }
    
    func handleSpecialOffer() {
        guard let specialOffer = specialOffer else {
            return
        }

        eventsLogger.logEvent(name: "special_offer_assistant_with_id_\(specialOffer.id)")
        router.showSpecialOffer(id: specialOffer.id)
    }
    
    func handleTelegramBot(session: String) {
        router.dismissWithBot(session: session)
        router = nil
    }
    
    func handleLottery() {
        router.showLottery()
    }
    
    func handleLotteryReferral() {
        if let url = getReferralLinkUseCase.getReferralLink() {
            UIApplication.shared.open(url)
        }
    }
}

@available(iOS 13.0, *)
private extension AssistantInteractor {
    func handleUser(_ user: EsimUser?, animated: Bool) {
        isAuthorized = (user != nil)
        output.handleUser(user, animated: animated)
    }
    
    func trySignInWithTelegram() {
        output.handleLoading(isLoading: true)
        esimAuth.trySignInWithTelegram { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.output.handleLoading(isLoading: false)
                switch result {
                case .success:
                    guard !self.isAuthorized else { break }
                    self.isAuthorized = true
                    self.handleAuth(isAnimated: true)
                    self.output.handleSuccessSignInWithTelegram()
                case .failure:
                    break
                }
            }
        }
    }
    
    func fetchSpecialOffer() {
        getSpecialOfferUseCase.fetchSpecialOffer { [weak self] specialOffer in
            guard let self = self else { return }
            guard let specialOffer = specialOffer else { return }
            
            DispatchQueue.main.async {
                self.specialOffer = specialOffer
                self.output.handle(specialOffer: specialOffer)
            }
        }
    }
    
    func initiateLoginWithTelegram() {
        output.handleLoading(isLoading: true)
        initiateLoginWithTelegramUseCase.initiateLoginWithTelegram { [weak self] result in
            guard let self else { return }
            
            DispatchQueue.main.async {
                self.output.handleLoading(isLoading: false)
                switch result {
                case .success(let url):
                    UIApplication.shared.open(url)
                case .failure(let error):
                    Alerts.show(.error(error))
                }
            }
        }
    }
    
    func subscribeToLotteryChange() {
        guard !hideLottery else { return }
        getLotteryDataUseCase.lotteryDataPublisher()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] lotteryData in
                guard let self else { return }
                
                if let lotteryData {
                    self.output.presentLottery(jackpot: lotteryData.currentDraw.jackpot)
                    self.output.presentLottery(true)
                    
                    AppCache.wasLotteryShown = true
                } else {
                    self.output.presentLottery(false)
                }
            }
            .store(in: &cancellables)
    }
    
    func tryHandleDeeplink() {
        guard let deeplink = deeplink else { return }
        
        if deeplink is PurchaseEsimDeeplink {
            router.showMyEsims(deeplink: deeplink)
        }
        
        self.deeplink = nil
    }
}
