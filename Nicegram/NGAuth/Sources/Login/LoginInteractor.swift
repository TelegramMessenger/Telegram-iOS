import Foundation
import AccountContext
import EsimAuth
import EsimApiClient
import NGEnv

typealias LoginInteractorInput = LoginViewControllerOutput

protocol LoginInteractorOutput {
    func handleViewDidLoad()
    func handleEmail(isValid: Bool)
    func handlePassword(isValid: Bool)
    func handleCredentials(isValid: Bool)
    
    func handleAlert()
    func handleLoading(isLoading: Bool)
    func handleError(message: String?)
}

@available(iOS 13, *)
final class LoginInteractor: LoginInteractorInput {
    var output: LoginInteractorOutput!
    var router: LoginRouter!
    
    private let tgAccountContext: AccountContext
    private let esimAuth: EsimAuth
    private weak var loginListener: LoginListener?

    private var googleAuth: GoogleFirebaseAuthenticator?
    private var appleAuth: AppleFirebaseAuthenticator?
    private var emailAuth: EmailAuthenticatorAdapter?
    private let telegramAuthenticator: TelegramAuthenticator
    
    private var emailValue: String?
    private var passwordValue: String?

    init(tgAccountContext: AccountContext,
         esimAuth: EsimAuth,
         telegramAuthenticator: TelegramAuthenticator,
         loginListener: LoginListener?) {
        self.tgAccountContext = tgAccountContext
        self.esimAuth = esimAuth
        self.telegramAuthenticator = telegramAuthenticator
        self.loginListener = loginListener
    }
    
    func onViewDidLoad() {
        output.handleViewDidLoad()
    }
    
    func handleDismiss() {
        router.dismiss()
        router = nil
    }
    
    func onSignIn() {
        router.showSignIn()
    }
    
    func onForgotPassword() {
        router.showForgotPassword()
    }
    
    func onLoginWithGoogle(with delegate: RequiringPresentationDelegate) {
        output.handleLoading(isLoading: true)
        googleAuth = GoogleFirebaseAuthenticator(clientId: NGENV.google_client_id)
        googleAuth?.presentationDelegate = delegate
        guard let authenticator = googleAuth else { return } 
        esimAuth.signIn(with: authenticator, referrerId: nil) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.output.handleLoading(isLoading: false)
                switch result {
                case .success:
                    self.router.dismiss()
                    self.router = nil
                    self.loginListener?.onLogin()
                case .failure(let esimError):
                    guard !esimError.isCancelled else { return }
                    self.output.handleError(message: esimError.localizedDescription)
                }
            }
        }
    }
    
    func onLoginWithApple(with delegate: RequiringPresentationDelegate) {
        output.handleLoading(isLoading: true)
        appleAuth = AppleFirebaseAuthenticator()
        appleAuth?.presentationDelegate = delegate
        guard let authenticator = appleAuth else { return } 
        esimAuth.signIn(with: authenticator, referrerId: nil) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.output.handleLoading(isLoading: false)
                switch result {
                case .success:
                    self.router.dismiss()
                    self.router = nil
                    self.loginListener?.onLogin()
                case .failure(let esimError):
                    guard !esimError.isCancelled else { return }
                    self.output.handleError(message: esimError.localizedDescription)
                }
            }
        }
    }
    
    func onLoginWithTelegram() {
        let telegramIdInt64 = tgAccountContext.account.peerId.id._internalGetInt64Value()
        let telegramId = TelegramID(id: telegramIdInt64)
        
        output.handleLoading(isLoading: true)
        telegramAuthenticator.fetchSession(telegramId: telegramId) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.output.handleLoading(isLoading: false)
                
                switch result {
                case .success(let session):
                    self.router.dismiss()
                    self.router = nil
                    self.loginListener?.onOpenTelegamBot(session: session.id)
                case .failure(let error):
                    self.output.handleError(message: error.localizedDescription)
                }
            }
        }
    }
    
    func handleEmailInput(inputText: String, onFinishEditing: Bool) {
        emailValue = inputText
        
        if onFinishEditing {
            output.handleEmail(isValid: isEmailValid(input: inputText))
        }
    }
    
    func handlePasswordInput(inputText: String, onFinishEditing: Bool) {
        passwordValue = inputText
        
        if onFinishEditing {
            output.handlePassword(isValid: isPasswordValid(input: inputText))
        }
    }
    
    func handleCredentials(email: String, password: String) {
        let isValid = isPasswordValid(input: password) && isEmailValid(input: email)
        output.handleCredentials(isValid: isValid)
    }
    
    func handleLogin() {
        emailAuth = EmailAuthenticatorAdapter(bundleId: NGENV.bundle_id)
        guard let email = emailValue, let password = passwordValue else {
            return
        }
        if !isEmailValid(input: email) {
            output.handleEmail(isValid: false)
        }
        
        if !isPasswordValid(input: password){
            output.handlePassword(isValid: false)
        }
        output.handleLoading(isLoading: true)
        emailAuth?.prepareForSignIn(email: email, password: password, onSentVerificationEmail: { [weak self] in
            self?.output.handleAlert()
        })
        
        esimAuth.signIn(with: emailAuth!, referrerId: nil) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.output.handleLoading(isLoading: false)
                switch result {
                case .success:
                    self.router.dismiss()
                    self.router = nil
                    self.loginListener?.onLogin()
                case .failure(let error):
                    self.output.handleError(message: error.localizedDescription)
                }
            }
        }
    }
}

@available(iOS 13, *)
private extension LoginInteractor {
    func isEmailValid(input: String) -> Bool {
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
