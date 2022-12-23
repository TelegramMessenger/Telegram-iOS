import NGAppContext
import NGLottery
import UIKit

protocol CreateTicketFactory {
    func makeViewController(input: CreateTicketInput, handlers: CreateTicketHandlers, flow: any LotteryFlow) -> UIViewController
}

@available(iOS 13.0, *)
class CreateTicketFactoryImpl {
    
    //  MARK: - Dependencies
    
    private let appContext: AppContext
    
    //  MARK: - Lifecycle
    
    init(appContext: AppContext) {
        self.appContext = appContext
    }
}

@available(iOS 13.0, *)
extension CreateTicketFactoryImpl: CreateTicketFactory {
    func makeViewController(input: CreateTicketInput, handlers: CreateTicketHandlers, flow: any LotteryFlow) -> UIViewController {
        let getLotteryDataUseCase = appContext.resolveGetLotteryDataUseCase()
        
        let createTicketUseCase = CreateTicketUseCaseImpl(
            createTicketService: CreateTicketServiceImpl(
                apiClient: appContext.resolveApiClient()
            ),
            lotteryDataRepository: appContext.lotteryDataRepository
        )
        
        let viewModel = CreateTicketViewModelImpl(input: input, handlers: handlers, getLotteryDataUseCase: getLotteryDataUseCase, createTicketUseCase: createTicketUseCase)
        
        let view = CreateTicketViewController(viewModel: viewModel, flowHolder: flow)
        
        return view
    }
}
