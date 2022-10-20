import NGAlert
import NGLocalization

typealias RegistrationPresenterInput = RegistrationInteractorOutput

protocol RegistrationPresenterOutput: AnyObject {
    func display(titleText: String?)
    func display(emailPlaceholder: String?)
    func display(passwordPlaceholder: String?)
    func display(firstNamePlaceholder: String?)
    func display(lastNamePlaceholder: String?)
    func display(registrtionText: String?)
    func display(questionText: String?)
    func display(loginText: String?)
    
    func display(firstNameError: String?)
    func display(lastNameError: String?)
    func display(emailError: String?)
    func display(passwordError: String?)
    
    func displayValidEmail()

    func displayAlert(message: String, titleText: String)
    func display(isRegistEnabled: Bool)
    func display(error: String?)
    func display(isLoading: Bool)
}

final class RegistrationPresenter: RegistrationPresenterInput {    
    weak var output: RegistrationPresenterOutput!
    
    func handleViewDidLoad() {
        output.display(titleText: ngLocalized("Nicegram.Registration.Title"))
        output.display(emailPlaceholder: ngLocalized("Nicegram.Registration.Email"))
        output.display(passwordPlaceholder: ngLocalized("Nicegram.Registration.Password"))
        output.display(firstNamePlaceholder: ngLocalized("Nicegram.Registration.FirstName"))
        output.display(lastNamePlaceholder: ngLocalized("Nicegram.Registration.LastName"))
        output.display(registrtionText: ngLocalized("Nicegram.Registration.Button"))
        output.display(questionText: ngLocalized("Nicegram.Registration.Question"))
        output.display(loginText: ngLocalized("Nicegram.Registration.LogIn"))
    }

    func handleFirstName(isValid: Bool) {
        if isValid {
            return
        } else {
            output.display(firstNameError: nil)
        }
    }
    
    func handleLastName(isValid: Bool) {
        if isValid {
            return
        } else {
            output.display(lastNameError: nil)
        }
    }
    
    func handleEmail(isValid: Bool) {
        if isValid {
            output.displayValidEmail()
        } else {
            output.display(emailError: ngLocalized("Nicegram.Registration.Email.Error"))
        }
    }
    
    func handlePassword(isValid: Bool) {
        if isValid {
            return
        } else {
            output.display(passwordError: nil)
        }
    }
    
    func handleSuccess() {
        output.displayAlert(message: ngLocalized("Nicegram.Alert.InboxCheck"), titleText: ngLocalized("Nicegram.Alert.Continue"))
    }
    
    func handleCredentials(isValid: Bool) {
        output.display(isRegistEnabled: isValid)
    }
    
    func handleLoading(isLoading: Bool) {
        output.display(isLoading: isLoading)
    }
    
    func handleError(message: String?) {
        output.display(error: message)
    }
}
