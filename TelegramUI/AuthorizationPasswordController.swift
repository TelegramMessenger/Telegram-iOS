import Foundation
import Display
import SwiftSignalKit
import MtProtoKitDynamic
import TelegramCore

class AuthorizationPasswordController: ViewController {
    private var account: UnauthorizedAccount
    
    private var node: AuthorizationPasswordControllerNode {
        return self.displayNode as! AuthorizationPasswordControllerNode
    }
    
    private let signInDisposable = MetaDisposable()
    private let resultPipe = ValuePipe<Api.auth.Authorization>()
    var result: Signal<Api.auth.Authorization, NoError> {
        return resultPipe.signal()
    }
    
    init(account: UnauthorizedAccount) {
        self.account = account
        
        super.init()
        
        self.title = "Password"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Next", style: .done, target: self, action: #selector(AuthorizationPasswordController.nextPressed))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        signInDisposable.dispose()
    }
    
    override func loadDisplayNode() {
        self.displayNode = AuthorizationPasswordControllerNode()
        self.displayNodeDidLoad()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.node.containerLayoutUpdated(layout, navigationBarHeight: self.navigationBar.frame.maxY, transition: transition)
    }
    
    @objc func nextPressed() {
        let password = self.node.passwordNode.attributedText?.string ?? ""
        
        self.signInDisposable.set(verifyPassword(self.account, password: password).start(next: { [weak self] result in
            if let strongSelf = self {
                strongSelf.resultPipe.putNext(result)
            }
        }))
    }
}
