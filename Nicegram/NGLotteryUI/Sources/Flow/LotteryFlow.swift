import NGCore
import NGSubscription
import UIKit

//  MARK: - Definition

public struct LotteryFlowInput {
    public init() {}
}

public struct LotteryFlowHandlers {
    let close: () -> Void
    
    public init(close: @escaping () -> Void) {
        self.close = close
    }
}

public protocol LotteryFlow: Flow where Input == LotteryFlowInput, Handlers == LotteryFlowHandlers {}

//  MARK: - Implementation

class LotteryFlowImpl {
    
    //  MARK: - Dependencies
    
    private let navigationController: UINavigationController
    
    //  MARK: - Child Flow Factories
    
    private let subscriptionBuilder: SubscriptionBuilder
    
    //  MARK: - Screen Factories
    
    private let splashFactory: SplashFactory
    private let createTicketFactory: CreateTicketFactory
    
    //  MARK: - Lifecycle
    
    init(navigationController: UINavigationController, subscriptionBuilder: SubscriptionBuilder, splashFactory: SplashFactory, createTicketFactory: CreateTicketFactory) {
        self.navigationController = navigationController
        self.subscriptionBuilder = subscriptionBuilder
        self.splashFactory = splashFactory
        self.createTicketFactory = createTicketFactory
    }
}

extension LotteryFlowImpl: LotteryFlow {
    public func makeStartViewController(input: LotteryFlowInput, handlers: LotteryFlowHandlers) -> UIViewController {
        let input = SplashInput()
        
        var routeToSubscribeImpl: (() -> Void)?
        
        let handlers = SplashHandlers(routeToCreateTicket: { [weak self] in
            guard let self else { return }
            let createTicketController = self.makeCreateTicketController(
                onSuccessTicketGeneration: { [weak self] in
                    self?.navigationController.popViewController(animated: true)
                },
                close: { [weak self] in
                    self?.navigationController.popViewController(animated: true)
                }
            )
            self.navigationController.pushViewController(createTicketController, animated: true)
        }, routeToSubscribe: {
            routeToSubscribeImpl?()
        }, close: handlers.close)
        
        let controller = splashFactory.makeViewController(input: input, handlers: handlers, flow: self)
        
        routeToSubscribeImpl = { [weak self, weak controller] in
            guard let self, let controller else { return }
            let subscriptionController = self.makeSubscriptionStartController()
            subscriptionController.modalPresentationStyle = .fullScreen
            controller.present(subscriptionController, animated: true)
        }
        
        return controller
    }
}

private extension LotteryFlowImpl {
    func makeCreateTicketController(onSuccessTicketGeneration: @escaping () -> Void, close: @escaping () -> Void) -> UIViewController {
        let input = CreateTicketInput()
        let handlers = CreateTicketHandlers(onSuccessTicketGeneration: onSuccessTicketGeneration, close: close)
        return createTicketFactory.makeViewController(input: input, handlers: handlers, flow: self)
    }
    
    func makeSubscriptionStartController() -> UIViewController {
        return subscriptionBuilder.build()
    }
}


