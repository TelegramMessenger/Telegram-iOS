import Combine
import Foundation

@available(iOS 13.0, *)
public protocol PremiumStatusRepository {
    func currentSubscriptionIdPublisher() -> AnyPublisher<String?, Never>
}

@available(iOS 13.0, *)
public class PremiumStatusRepositoryImpl {
    
    //  MARK: - Dependencies
    
    private let userDefaults: UserDefaults = .standard
    
    //  MARK: - Lifecycle
    
    public init() {}
}

@available(iOS 13.0, *)
extension PremiumStatusRepositoryImpl: PremiumStatusRepository {
    public func currentSubscriptionIdPublisher() -> AnyPublisher<String?, Never> {
        return userDefaults
            .publisher(for: \.currentProductID)
            .eraseToAnyPublisher()
    }
}

private extension UserDefaults {
    @objc var currentProductID: String? {
        get {
            return string(forKey: "currentProductID")
        }
    }
}
