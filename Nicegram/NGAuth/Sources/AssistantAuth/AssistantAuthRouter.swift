import UIKit

protocol AssistantAuthRouterInput: AnyObject {
    func dismiss()
    func showLogin()
}

final class AssistantAuthRouter: AssistantAuthRouterInput {
    weak var parentViewController: AssistantAuthViewController?
    
    private let loginBuilder: LoginBuilder
    private let regist: RegistrationBuilder
    
    init(loginBuilder: LoginBuilder,
         regist: RegistrationBuilder) {
        self.loginBuilder = loginBuilder
        self.regist = regist
    }

    func dismiss() {
        parentViewController?.dismiss(animated: false, completion: nil)
    }
    
    func showLogin() {
        let loginViewController = loginBuilder.build()
        parentViewController?.navigationController?.pushViewController(loginViewController, animated: true)
    }
    
//    func showLogin() {
//        let vc = regist.build()
//        parentViewController.navigationController?.pushViewController(vc, animated: true)
//    }
}
