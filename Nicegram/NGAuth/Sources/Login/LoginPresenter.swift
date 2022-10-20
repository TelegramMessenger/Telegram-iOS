import EsimAuth
import EsimApiClient
import NGLocalization

typealias LoginPresenterInput = LoginInteractorOutput

protocol LoginPresenterOutput: AnyObject {
    func displayValidEmail()
    func display(isLoginEnabled: Bool)
    func display(error: String?)
    func display(emailError: String?)
    func display(passwordError: String?)
    func display(isLoading: Bool)
    
    func display(titleText: String?)
    func display(emailPlaceholder: String?)
    func display(passwordPlaceholder: String?)
    func display(loginTitleText: String?)
    func display(signUpTitleText: String?)
    func display(forgotPasswordText: String?)
    func display(questionText: String?)
    func display(continueText: String?)
    
    func displayAlert(message: String, titleText: String)
}

final class LoginPresenter: LoginPresenterInput {
    weak var output: LoginPresenterOutput!
    
    func handleViewDidLoad() {
        output.display(titleText: ngLocalized("Nicegram.Login.Title"))
        output.display(emailPlaceholder: ngLocalized("Nicegram.Login.Email.Placeholder"))
        output.display(passwordPlaceholder: ngLocalized("Nicegram.Login.Password.Placeholder"))
        output.display(loginTitleText: ngLocalized("Nicegram.Login.Button"))
        output.display(signUpTitleText: ngLocalized("Nicegram.Login.SignUp"))
        output.display(forgotPasswordText: ngLocalized("Nicegram.Login.ForgotPass"))
        output.display(questionText: ngLocalized("Nicegram.Login.isRegister"))
        output.display(continueText: ngLocalized("Nicegram.Login.OrContinue"))
    }
    
    func handleEmail(isValid: Bool) {
        if isValid {
            output.displayValidEmail()
        } else {
            output.display(emailError: ngLocalized("Nicegram.Registration.Email.Error"))
        }
    }
    
    func handlePassword(isValid: Bool) { 
        if !isValid {
            output.display(passwordError: nil)
        }
    }
    
    func handleCredentials(isValid: Bool) {
        output.display(isLoginEnabled: isValid)
    }
    
    func handleError(message: String?) {
        output.display(error: message)
    }
    
    func handleLoading(isLoading: Bool) {
        output.display(isLoading: isLoading)
    }
    
    func handleAlert() {
        output.displayAlert(message: ngLocalized("Nicegram.Alert.InboxCheck"), titleText: ngLocalized("Nicegram.Alert.Continue"))
    }
}
