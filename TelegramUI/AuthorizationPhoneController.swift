import Foundation
import Display
import SwiftSignalKit
import MtProtoKitDynamic
import TelegramCore

class AuthorizationPhoneController: ViewController {
    private var account: UnauthorizedAccount
    
    private var node: AuthorizationPhoneControllerNode {
        return self.displayNode as! AuthorizationPhoneControllerNode
    }
    
    private let codeDisposable = MetaDisposable()
    private let resultPipe = ValuePipe<(UnauthorizedAccount, Api.auth.SentCode, String)>()
    var result: Signal<(UnauthorizedAccount, Api.auth.SentCode, String), NoError> {
        return resultPipe.signal()
    }
    
    init(account: UnauthorizedAccount) {
        self.account = account
        
        super.init()
        
        self.title = "Telegram"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Next", style: .done, target: self, action: #selector(AuthorizationPhoneController.nextPressed))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        codeDisposable.dispose()
    }
    
    override func loadDisplayNode() {
        self.displayNode = AuthorizationPhoneControllerNode()
        self.displayNodeDidLoad()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.node.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }

    @objc func nextPressed() {
        let phone = self.node.phoneNode.attributedText?.string ?? ""
        let account = self.account
        let sendCode = Api.functions.auth.sendCode(flags: 0, phoneNumber: phone, currentNumber: nil, apiId: 10840, apiHash: "33c45224029d59cb3ad0c16134215aeb", langCode: "en")
        
        let signal = account.network.request(sendCode)
            |> map { result in
                return (result, account)
            } |> `catch` { error -> Signal<(Api.auth.SentCode, UnauthorizedAccount), MTRpcError> in
                switch error.errorDescription {
                    case Regex("(PHONE_|USER_|NETWORK_)MIGRATE_(\\d+)"):
                        let range = error.errorDescription.range(of: "MIGRATE_")!
                        let updatedMasterDatacenterId = Int32(error.errorDescription.substring(from: range.upperBound))!
                        let updatedAccount = account.changedMasterDatacenterId(updatedMasterDatacenterId)
                        return updatedAccount
                            |> mapToSignalPromotingError { updatedAccount -> Signal<(Api.auth.SentCode, UnauthorizedAccount), MTRpcError> in
                                return updatedAccount.network.request(sendCode)
                                    |> map { sentCode in
                                        return (sentCode, updatedAccount)
                                    }
                            }
                    case _:
                        return .fail(error)
                }
            }
    
        codeDisposable.set(signal.start(next: { [weak self] (result, account) in
            if let strongSelf = self {
                strongSelf.account = account
                strongSelf.resultPipe.putNext((account, result, phone))
            }
        }))
    }
}
