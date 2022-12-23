import Combine
import NGCore
import NGCoreUI
import NGLottery
import UIKit

struct CreateTicketInput {
    
}

struct CreateTicketHandlers {
    let onSuccessTicketGeneration: () -> Void
    let close: () -> Void
}

@available(iOS 13.0, *)
class CreateTicketViewModelImpl: BaseViewModel<CreateTicketViewState, CreateTicketInput, CreateTicketHandlers> {
    
    //  MARK: - Use Cases
    
    private let getLotteryDataUseCase: GetLotteryDataUseCase
    private let createTicketUseCase: CreateTicketUseCase
    
    //  MARK: - Lifecycle
    
    init(input: CreateTicketInput, handlers: CreateTicketHandlers, getLotteryDataUseCase: GetLotteryDataUseCase, createTicketUseCase: CreateTicketUseCase) {
        self.getLotteryDataUseCase = getLotteryDataUseCase
        self.createTicketUseCase = createTicketUseCase
        
        super.init(input: input, handlers: handlers)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        getLotteryDataUseCase.lotteryDataPublisher()
            .compactMap { $0 }
            .prefix(1)
            .compactMap { lotteryData -> AnyPublisher<Date, Never> in
                let currentDate = Date()
                let blockDate = lotteryData.currentDraw.blockDate
                
                if currentDate < blockDate {
                    let delay = blockDate.timeIntervalSince1970 - currentDate.timeIntervalSince1970
                    let deferredPublisher = Just(lotteryData.nextDrawDate)
                        .delay(for: .seconds(delay), scheduler: RunLoop.main)
                    
                    return Just(lotteryData.currentDraw.date)
                        .merge(with: deferredPublisher)
                        .eraseToAnyPublisher()
                } else {
                    return Just(lotteryData.nextDrawDate)
                        .eraseToAnyPublisher()
                }
            }
            .switchToLatest()
            .sink { [weak self] drawDate in
                guard let self else { return }
                
                self.updateViewState { state in
                    state.drawDate = drawDate
                }
            }
            .store(in: &cancellables)
    }
}

//  MARK: - Logic

@available(iOS 13.0, *)
private extension CreateTicketViewModelImpl {
    func createTicket(numbers: [Int]) {
        updateViewState { $0.isLoading = true }
        createTicketUseCase.createTicket(numbers: numbers) { [weak self] error in
            guard let self else { return }
            
            self.updateViewState { $0.isLoading = false }
            
            if let error {
                Alerts.show(.error(error))
            } else {
                DispatchQueue.main.async {
                    self.handlers.onSuccessTicketGeneration()
                }
            }
        }
    }
}


//  MARK: - ViewModelImpl

@available(iOS 13.0, *)
extension CreateTicketViewModelImpl: CreateTicketViewModel {
    func requestCreateTicket(numbers: [Int]) {
        createTicket(numbers: numbers)
    }
    
    func requestClose() {
        handlers.close()
    }
}

//  MARK: - Mapping

@available(iOS 13.0, *)
private extension CreateTicketViewModelImpl {
    
}

