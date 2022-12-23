import Combine

@available(iOS 13.0, *)
public protocol GetPremiumStatusUseCase {
    func premiumStatusPublisher() -> AnyPublisher<Bool, Never>
}

@available(iOS 13.0, *)
public class GetPremiumStatusUseCaseImpl {
    
    //  MARK: - Dependencies
    
    private let premiumStatusRepository: PremiumStatusRepository
    
    //  MARK: - Lifecycle
    
    public init(premiumStatusRepository: PremiumStatusRepository) {
        self.premiumStatusRepository = premiumStatusRepository
    }
    
}

@available(iOS 13.0, *)
extension GetPremiumStatusUseCaseImpl: GetPremiumStatusUseCase {
    public func premiumStatusPublisher() -> AnyPublisher<Bool, Never> {
        return premiumStatusRepository.currentSubscriptionIdPublisher()
            .map { $0 != nil }
            .eraseToAnyPublisher()
    }
}
