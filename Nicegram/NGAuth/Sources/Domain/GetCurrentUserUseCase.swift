import EsimAuth

public protocol GetCurrentUserUseCase {
    func getCurrentUser() -> EsimUser?
    func isAuthorized() -> Bool
}

public class GetCurrentUserUseCaseImpl {
    
    //  MARK: - Dependencies
    
    private let esimAuth: EsimAuth
    
    //  MARK: - Lifecycle
    
    public init(esimAuth: EsimAuth) {
        self.esimAuth = esimAuth
    }
    
}

extension GetCurrentUserUseCaseImpl: GetCurrentUserUseCase {
    public func getCurrentUser() -> EsimUser? {
        return esimAuth.currentUser
    }
    
    public func isAuthorized() -> Bool {
        guard let currentUser = esimAuth.currentUser else {
            return false
        }
        return currentUser.linkedProviders.contains(.telegram)
    }
}
