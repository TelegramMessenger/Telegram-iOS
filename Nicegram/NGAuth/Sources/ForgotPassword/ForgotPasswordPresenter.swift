import NGLocalization

typealias ForgotPasswordPresenterInput = ForgotPasswordInteractorOutput

protocol ForgotPasswordPresenterOutput: AnyObject { 
    func display(isEmailValid: Bool) 
    func displaySuccess()
    
    func display(error: String?)
    func display(isLoading: Bool)
    func display(emailError: String?)
    
    func display(emailPlaceholder: String?)
    func display(titleText: String?)
    func display(subtitleText: String?)
    func display(sendCodeTitleText: String?)
}

final class ForgotPasswordPresenter: ForgotPasswordPresenterInput {
    weak var output: ForgotPasswordPresenterOutput!
    
    func handleViewDidLoad() {
        output.display(emailPlaceholder: ngLocalized("Nicegram.ForgotPass.Email.Title"))
        output.display(titleText: ngLocalized("Nicegram.ForgotPass.Title"))
        output.display(subtitleText: ngLocalized("Nicegram.ForgotPass.Subtitle"))
        output.display(sendCodeTitleText: ngLocalized("Nicegram.ForgotPass.Button"))
    }

    func handleEmail(isValid: Bool) {
        output.display(isEmailValid: isValid) 
        if !isValid {
            output.display(emailError: ngLocalized("Nicegram.Registration.Email.Error"))
        }
    }
    
    func handleSuccess() {
        output.displaySuccess()
    }
    
    func handleError(message: String?) {
        output.display(error: message)
    }
    
    func handleLoading(isLoading: Bool) {
        output.display(isLoading: isLoading)
    }
}
