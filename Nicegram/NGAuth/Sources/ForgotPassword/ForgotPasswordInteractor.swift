import EsimAuth
import NGLocalization
import Foundation

typealias ForgotPasswordInteractorInput = ForgotPasswordViewControllerOutput

protocol ForgotPasswordInteractorOutput {
    func handleEmail(isValid: Bool)
    func handleSuccess()
    
    func handleLoading(isLoading: Bool)
    func handleError(message: String?)
    func handleViewDidLoad()
}

@available(iOS 13, *)
class ForgotPasswordInteractor: ForgotPasswordInteractorInput {
    var output: ForgotPasswordInteractorOutput!
    var router: ForgotPasswordRouterInput!

    private let esimAuth: EsimAuth
    
    init(esimAuth: EsimAuth) {
        self.esimAuth = esimAuth
    }
    
    func handleViewDidLoad() {
        output.handleViewDidLoad()
    }

    func handleForgotPassword(email: String?) {
        guard let emailValue = email,
              isEmailValid(input: emailValue) else {
            return
        } 
        output.handleLoading(isLoading: true)
        esimAuth.resetPassword(email: emailValue) { [weak self] error in
            self?.output.handleLoading(isLoading: true)
            guard let self = self else { return }
            if let error = error {
                self.output.handleError(message: error.localizedDescription)
            } else {
                self.output.handleSuccess()
                self.router.dismiss()
            }
        }
    }
    
    func handleEmailInput(inputText: String) {    
        output.handleEmail(isValid: isEmailValid(input: inputText))
    }
}

@available(iOS 13, *)
private extension ForgotPasswordInteractor {
    func isEmailValid(input: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        
        return emailPred.evaluate(with: input)
    }
}
