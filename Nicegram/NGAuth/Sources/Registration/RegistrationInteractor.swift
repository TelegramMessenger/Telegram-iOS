import EsimApiClient
import EsimAuth
import Foundation

typealias RegistrationInteractorInput = RegistrationViewControllerOutput

protocol RegistrationInteractorOutput {
    func handleViewDidLoad()
    func handleFirstName(isValid: Bool)
    func handleLastName(isValid: Bool)
    func handleEmail(isValid: Bool)
    func handlePassword(isValid: Bool)
    func handleCredentials(isValid: Bool)
    
    func handleSuccess()
    
    func handleLoading(isLoading: Bool)
    func handleError(message: String?)
}

class RegistrationInteractor: RegistrationInteractorInput {
    var output: RegistrationInteractorOutput!
    var router: RegistrationRouter!
    
    var firstNameValue: String?
    var lastNameValue: String?
    var emailValue: String?
    var passwordValue: String?
    
    private var esimAuth: EsimAuth
    
    init(esimAuth: EsimAuth) {
        self.esimAuth = esimAuth
    }
    
    func onViewDidLoad() {
        output.handleViewDidLoad()
    }
    
    func onSignUp() {
        guard checkForRegistration() else {
            output.handleCredentials(isValid: false)
            return 
        }
        let user = CreateUserDTO(
            firstName: firstNameValue ?? "",
            lastName: lastNameValue ?? "", 
            email: emailValue ?? "",
            password: passwordValue ?? "",
            referrerId: nil
        )
        output.handleLoading(isLoading: true)
        esimAuth.createUser(user) { [weak self] in
            guard let self = self else { return }
            self.output.handleLoading(isLoading: false)
            self.output.handleSuccess()
        } completion: { [weak self] result in
            guard let self = self else { return }
            self.output.handleLoading(isLoading: false)
            switch result {
            case .success(let user):
                print(user.email ?? "")
            case .failure(let error):
                self.output.handleError(message: error.localizedDescription)
            }
        }
    }
    
    func handleDismiss() {
        router.dismiss()
    }
    
    func handleFirstNameInput(inputText: String, onFinishEditing: Bool) {
        firstNameValue = inputText
        handleCredentials()
        if onFinishEditing {
            output.handleFirstName(isValid: !inputText.isEmpty)
        }
    }
    
    func handleLastNameInput(inputText: String, onFinishEditing: Bool) {
        lastNameValue = inputText
        handleCredentials()
        if onFinishEditing {
            output.handleLastName(isValid: !inputText.isEmpty)
        }
    }

    func handleEmailInput(inputText: String, onFinishEditing: Bool) {
        emailValue = inputText
        handleCredentials()
        if onFinishEditing {
            output.handleEmail(isValid: isEmailValid(input: inputText))
        }
    }
    
    func handlePasswordInput(inputText: String, onFinishEditing: Bool) {
        passwordValue = inputText
        handleCredentials()
        if onFinishEditing {
            output.handlePassword(isValid: isPasswordValid(input: inputText))
        }
    }
    
    private func handleCredentials() {
        guard let firstName = firstNameValue, !firstName.isEmpty,
              let lastName = lastNameValue, !lastName.isEmpty,
              let email = emailValue, isEmailValid(input: email),
              let password = passwordValue, isPasswordValid(input: password) else {
                  output.handleCredentials(isValid: false)
                  return
              }
        output.handleCredentials(isValid: true)
    }
    
    func checkForRegistration() -> Bool {
        guard let _ = firstNameValue else {
            return false
        }
        guard let _ = lastNameValue else {
            return false
        }
        guard let email = emailValue, isEmailValid(input: email) else {
            return false
        }
        guard let password = passwordValue, isPasswordValid(input: password) else {
            return false
        }
        return true
    }
    
    private func isEmailValid(input: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        
        return emailPred.evaluate(with: input)
    }

    func isPasswordValid(input: String) -> Bool {
        let passwordRegEx = #"[^\s.]{6,}$"#
        let passwordPred = NSPredicate(format:"SELF MATCHES %@", passwordRegEx)
        
        return passwordPred.evaluate(with: input)
    }
}
