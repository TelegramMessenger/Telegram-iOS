import Foundation
import EsimAuth
import NGLogging
import NGModels
import NGRepositories
import NGSpecialOffer

typealias AssistantInteractorInput = AssistantViewControllerOutput

protocol AssistantInteractorOutput {
    func onViewDidAppear()
    func handleAuth(isAuthorized: Bool, isAnimated: Bool)
    func handleLoading(isLoading: Bool)
    func handleViewDidLoad() 
    func handleLogout()
    func handle(specialOffer: SpecialOffer)
    func handleSuccessSignInWithTelegram()
}

class AssistantInteractor: AssistantInteractorInput {
    var output: AssistantInteractorOutput!
    var router: AssistantRouterInput!

    private let esimAuth: EsimAuth
    private let userEsimsRepository: UserEsimsRepository
    private let getSpecialOfferUseCase: GetSpecialOfferUseCase
    private let eventsLogger: EventsLogger
    
    private var deeplink: Deeplink?
    private var specialOffer: SpecialOffer?
    private var isAuthorized = false
    
    init(deeplink: Deeplink?, esimAuth: EsimAuth, userEsimsRepository: UserEsimsRepository, getSpecialOfferUseCase: GetSpecialOfferUseCase, eventsLogger: EventsLogger) {
        self.deeplink = deeplink
        self.esimAuth = esimAuth
        self.userEsimsRepository = userEsimsRepository
        self.getSpecialOfferUseCase = getSpecialOfferUseCase
        self.eventsLogger = eventsLogger
    }
    
    func onViewDidLoad() {
        output.handleViewDidLoad()
        trySignInWithTelegram()
        fetchSpecialOffer()
    }
    
    func onViewDidAppear() {
        output.onViewDidAppear()
        tryHandleDeeplink()
    }
    
    func handleAuth(isAnimated: Bool) {
        isAuthorized = esimAuth.isAuthorized
        output.handleAuth(isAuthorized: isAuthorized, isAnimated: isAnimated)
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
        router.showLogin()
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
}

private extension AssistantInteractor {
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
    
    func tryHandleDeeplink() {
        guard let deeplink = deeplink else { return }
        
        if deeplink is PurchaseEsimDeeplink {
            router.showMyEsims(deeplink: deeplink)
        }
        
        self.deeplink = nil
    }
}
