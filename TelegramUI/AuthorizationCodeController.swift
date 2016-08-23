import Foundation
import Display
import SwiftSignalKit
import MtProtoKit
import TelegramCore

enum AuthorizationCodeResult {
    case Authorization(Api.auth.Authorization)
    case Password
}

class AuthorizationCodeController: ViewController {
    let account: UnauthorizedAccount
    let phone: String
    let sentCode: Api.auth.SentCode
    
    var node: AuthorizationCodeControllerNode {
        return self.displayNode as! AuthorizationCodeControllerNode
    }
    
    let signInDisposable = MetaDisposable()
    let resultPipe = ValuePipe<AuthorizationCodeResult>()
    var result: Signal<AuthorizationCodeResult, NoError> {
        return resultPipe.signal()
    }
    
    init(account: UnauthorizedAccount, phone: String, sentCode: Api.auth.SentCode) {
        self.account = account
        self.phone = phone
        self.sentCode = sentCode
        
        super.init()
        
        self.title = "Code"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Next", style: .done, target: self, action: #selector(AuthorizationCodeController.nextPressed))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.signInDisposable.dispose()
    }
    
    override func loadDisplayNode() {
        self.displayNode = AuthorizationCodeControllerNode()
        self.displayNodeDidLoad()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.node.containerLayoutUpdated(layout, navigationBarHeight: self.navigationBar.frame.maxY, transition: transition)
    }
    
    @objc func nextPressed() {
        var phoneCodeHash: String?
        switch self.sentCode {
            case let .sentCode(_, _, apiPhoneCodeHash, _, _):
                phoneCodeHash = apiPhoneCodeHash
            default:
                break
        }
        if let phoneCodeHash = phoneCodeHash {
            let signal = self.account.network.request(Api.functions.auth.signIn(phoneNumber: self.phone, phoneCodeHash: phoneCodeHash, phoneCode: node.codeNode.attributedText?.string ?? "")) |> map { authorization in
                return AuthorizationCodeResult.Authorization(authorization)
            } |> `catch` { error -> Signal<AuthorizationCodeResult, MTRpcError> in
                switch (error.errorCode, error.errorDescription) {
                    case (401, "SESSION_PASSWORD_NEEDED"):
                        return .single(.Password)
                    case _:
                        return .fail(error)
                }
            }
            
            self.signInDisposable.set(signal.start(next: { [weak self] result in
                if let strongSelf = self {
                    strongSelf.resultPipe.putNext(result)
                }
            }))
        }
    }
}
