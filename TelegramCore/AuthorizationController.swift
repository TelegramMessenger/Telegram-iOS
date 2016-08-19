import Foundation
import Display
import SwiftSignalKit

public class AuthorizationController: NavigationController {
    private var account: UnauthorizedAccount!
    
    private let authorizedAccountValue = Promise<Account>()
    public var authorizedAccount: Signal<Account, NoError> {
        return authorizedAccountValue.get()
    }
    
    public init(account: UnauthorizedAccount) {
        self.account = account
        let phoneController = AuthorizationPhoneController(account: account)
        
        super.init()
        
        self.pushViewController(phoneController, animated: false)
        
        let authorizationSequence = phoneController.result |> mapToSignal { (account, sentCode, phone) -> Signal<Api.auth.Authorization, NoError> in
            return deferred { [weak self] in
                if let strongSelf = self {
                    strongSelf.account = account
                    let codeController = AuthorizationCodeController(account: account, phone: phone, sentCode: sentCode)
                    strongSelf.pushViewController(codeController, animated: true)
                    
                    return codeController.result |> mapToSignal { result -> Signal<Api.auth.Authorization, NoError> in
                        switch result {
                            case let .Authorization(authorization):
                                return single(authorization, NoError.self)
                            case .Password:
                                return deferred { [weak self] () -> Signal<Api.auth.Authorization, NoError> in
                                    if let strongSelf = self {
                                        let passwordController = AuthorizationPasswordController(account: account)
                                        strongSelf.pushViewController(passwordController, animated: true)
                                        
                                        return passwordController.result
                                    } else {
                                        return complete(Api.auth.Authorization.self, NoError.self)
                                    }
                                } |> runOn(Queue.mainQueue())
                        }
                    }
                } else {
                    return complete(Api.auth.Authorization.self, NoError.self)
                }
            } |> runOn(Queue.mainQueue())
        }
        
        let accountSignal = authorizationSequence |> mapToSignal { [weak self] authorization -> Signal<Account, NoError> in
            if let strongSelf = self {
                switch authorization {
                case let .authorization(user):
                    let user = TelegramUser(user: user)
                    return account.postbox.modify { modifier -> AccountState in
                        let state = AuthorizedAccountState(masterDatacenterId: strongSelf.account.masterDatacenterId, peerId: user.id, state: nil)
                        modifier.setState(state)
                        return state
                    } |> map { state in
                        return Account(id: account.id, postbox: account.postbox, network: account.network, peerId: user.id)
                    }
                }
            } else {
                return .complete()
            }
        }
        
        self.authorizedAccountValue.set(accountSignal)
    }
    
    override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
}
