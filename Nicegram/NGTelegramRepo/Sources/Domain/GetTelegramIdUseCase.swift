import AccountContext

public struct TelegramID {
    public let int64Value: Int64
}

public protocol GetTelegramIdUseCase {
    func getTelegramId() -> TelegramID?
}

@available(iOS 13.0, *)
public class GetTelegramIdUseCaseImpl {
    
    //  MARK: - Dependencies
    
    private let accountContext: AccountContext
    
    //  MARK: - Lifecycle
    
    public init(accountContext: AccountContext) {
        self.accountContext = accountContext
    }
}

@available(iOS 13.0, *)
extension GetTelegramIdUseCaseImpl: GetTelegramIdUseCase {
    public func getTelegramId() -> TelegramID? {
        return TelegramID(int64Value: accountContext.account.peerId.id._internalGetInt64Value())
    }
}
