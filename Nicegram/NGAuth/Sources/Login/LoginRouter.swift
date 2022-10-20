import UIKit
import EsimAuth
import NGEnv
import NGExtensions

protocol LoginRouterInput: AnyObject {
    /// Test method
    func dismiss() 
    func showForgotPassword()
    func showSignIn()
    func showTelegramSignInBot(session: String)
}

final class LoginRouter: LoginRouterInput {
    private let registrationBuilder: RegistrationBuilder
    private let forgotPasswordBuilder: ForgotPasswordBuilder
    
    weak var parentViewController: LoginViewController?

    init(
        registrationBuilder: RegistrationBuilder,
        forgotPasswordBuilder: ForgotPasswordBuilder
    ) {
        self.registrationBuilder = registrationBuilder
        self.forgotPasswordBuilder = forgotPasswordBuilder
    }
    

    func dismiss() {
        parentViewController?.navigationController?.popViewController(animated: false)
    }
    
    func showForgotPassword() {
        let forgotPasswordVC = forgotPasswordBuilder.build()
        parentViewController?.navigationController?.pushViewController(forgotPasswordVC, animated: true)
    }
    
    func showSignIn() {
        let registrationVC = registrationBuilder.build()
        parentViewController?.navigationController?.pushViewController(registrationVC, animated: true)
    }
    
    func showTelegramSignInBot(session: String) {
        parentViewController?.navigationController?.dismiss(animated: true, completion: { 
            guard var url = URL(string: "ncg://resolve") else { return }
            url = url
                .appending("domain", value: NGENV.telegram_auth_bot)
                .appending("start", value: session)
            
            UIApplication.shared.openURL(url)
        })
    }
}

