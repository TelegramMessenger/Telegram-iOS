import Combine
import NGAuth
import NGCore
import NGCoreUI
import NGLogging
import NGLottery
import NGSubscription
import UIKit

struct SplashInput {
    
}

struct SplashHandlers {
    let routeToCreateTicket: () -> Void
    let routeToSubscribe: () -> Void
    let close: () -> Void
}

@available(iOS 13.0, *)
class SplashViewModelImpl: BaseViewModel<SplashViewState, SplashInput, SplashHandlers> {
    
    private struct Constants {
        static var moreInfoUrl: URL {
            URL(string: "https://lotto.nicegram.app")!
        }
    }
    
    //  MARK: - Use Cases
    
    private let getLotteryDataUseCase: GetLotteryDataUseCase
    private let getPremiumStatusUseCase: GetPremiumStatusUseCase
    private let getTicketForPremiumUseCase : GetTicketForPremiumUseCase
    private let getCurrentUserUseCase: GetCurrentUserUseCase
    private let initiateLoginWithTelegramUseCase: InitiateLoginWithTelegramUseCase
    private let loadLotteryDataUseCase: LoadLotteryDataUseCase
    private let getReferralLinkUseCase: GetReferralLinkUseCase
    
    private let eventsLogger: EventsLogger
    
    //  MARK: - Lifecycle
    
    init(input: SplashInput, handlers: SplashHandlers, getLotteryDataUseCase: GetLotteryDataUseCase, getPremiumStatusUseCase: GetPremiumStatusUseCase, getTicketForPremiumUseCase: GetTicketForPremiumUseCase, getCurrentUserUseCase: GetCurrentUserUseCase, initiateLoginWithTelegramUseCase: InitiateLoginWithTelegramUseCase, loadLotteryDataUseCase: LoadLotteryDataUseCase, getReferralLinkUseCase: GetReferralLinkUseCase, eventsLogger: EventsLogger) {
        self.getLotteryDataUseCase = getLotteryDataUseCase
        self.getPremiumStatusUseCase = getPremiumStatusUseCase
        self.getTicketForPremiumUseCase = getTicketForPremiumUseCase
        self.getCurrentUserUseCase = getCurrentUserUseCase
        self.initiateLoginWithTelegramUseCase = initiateLoginWithTelegramUseCase
        self.loadLotteryDataUseCase = loadLotteryDataUseCase
        self.getReferralLinkUseCase = getReferralLinkUseCase
        self.eventsLogger = eventsLogger
        
        super.init(input: input, handlers: handlers)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        subscribeToDataChange()
        refreshData()
        
        eventsLogger.logEvent(name: "lottery_splash_show")
    }
}

//  MARK: - Logic

@available(iOS 13.0, *)
private extension SplashViewModelImpl {
    func subscribeToDataChange() {
        getLotteryDataUseCase.lotteryDataPublisher()
            .compactMap { $0 }
            .combineLatest(getPremiumStatusUseCase.premiumStatusPublisher())
            .sink { [weak self] lotteryData, hasPremium in
                guard let self else { return }
                
                self.updateViewState { state in
                    state.nextDraw = .init(
                        id: lotteryData.currentDraw.date,
                        jackpot: lotteryData.currentDraw.jackpot,
                        date: lotteryData.currentDraw.date
                    )
                    state.lastDraw = self.mapToPastDraw(lotteryData.lastDraw)
                    state.pastDraws = lotteryData.pastDraws.compactMap { self.mapToPastDraw($0) }
                    state.userActiveTickets = lotteryData.userActiveTickets.map { ticket in
                        return .init(numbers: ticket.numbers, date: ticket.drawDate)
                    }
                    state.availableUserTicketsCount = lotteryData.userAvailableTicketsCount

                    if hasPremium {
                        if let nextDate = lotteryData.nextTicketForPremiumDate,
                           nextDate > Date() {
                            state.premiumSection = .alreadyReceived(nextDate: nextDate)
                        } else {
                            state.premiumSection = .getTicket
                        }
                    } else {
                        state.premiumSection = .subscribe
                    }

                    state.userPastTickets = lotteryData.userPastTickets.compactMap { ticketWithDraw in
                        return .init(
                            date: ticketWithDraw.draw.date,
                            ticket: ticketWithDraw.ticket.numbers,
                            winningNumbers: ticketWithDraw.draw.winningNumbers
                        )
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func getTicketForPremium() {
        guard getCurrentUserUseCase.isAuthorized() else {
            Alerts.show(.needLoginWithTelegram { [weak self] in
                self?.initiateLoginWithTelegram()
            })
            return
        }
        
        updateViewState { $0.isLoading = true }
        getTicketForPremiumUseCase.getTicket { [weak self] error in
            guard let self else { return }
            
            self.updateViewState { $0.isLoading = false }
            
            if let error {
                Alerts.show(.error(error))
            } else {
                Toasts.show(.success())
            }
        }
    }
    
    func initiateLoginWithTelegram() {
        updateViewState { $0.isLoading = true }
        initiateLoginWithTelegramUseCase.initiateLoginWithTelegram { [weak self] result in
            guard let self else { return }
            
            self.updateViewState { $0.isLoading = false }
            
            switch result {
            case .success(let url):
                DispatchQueue.main.async {
                    UIApplication.shared.open(url)
                }
            case .failure(let error):
                Alerts.show(.error(error))
            }
        }
    }
    
    func refreshData() {
        loadLotteryDataUseCase.loadLotteryData { _ in }
    }
}


//  MARK: - ViewModelImpl

@available(iOS 13.0, *)
extension SplashViewModelImpl: SplashViewModel {
    func requestTab(_ tab: SplashViewState.Tab) {
        updateViewState { $0.tab = tab }
    }
    
    func requestGetTicket() {
        updateViewState { state in
            state.tab = .myTickets
            state.forceShowHowToGetTicket = true
        }
        updateViewState { $0.forceShowHowToGetTicket = false }
    }
    
    func requestCreateTicket() {
        handlers.routeToCreateTicket()
    }
    
    func requestSubscribe() {
        handlers.routeToSubscribe()
    }
    
    func requestTicketForPremium() {
        getTicketForPremium()
    }
    
    func requestTicketForReferral() {
        if let url = getReferralLinkUseCase.getReferralLink() {
            UIApplication.shared.open(url)
        }
    }
    
    func requestMoreInfo() {
        UIApplication.shared.open(Constants.moreInfoUrl)
    }
    
    func requestPullToRefresh() {
        refreshData()
    }
    
    func requestClose() {
        handlers.close()
    }
}

//  MARK: - Mapping

@available(iOS 13.0, *)
private extension SplashViewModelImpl {
    func mapToPastDraw(_ draw: PastDraw?) -> SplashViewState.PastDraw? {
        guard let draw else { return nil }
        return .init(date: draw.date, winningNumbers: draw.winningNumbers)
    }
}

