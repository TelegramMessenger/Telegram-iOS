import EsimAuth
import NGEnv

typealias AssistantAuthInteractorInput = AssistantAuthViewControllerOutput

@available(iOS 13, *)
protocol AssistantAuthInteractorOutput {
    func onViewDidLoad()
}

@available(iOS 13, *)
class AssistantAuthInteractor: AssistantAuthInteractorInput {    
    var output: AssistantAuthInteractorOutput!
    var router: AssistantAuthRouterInput!
    
    private let esimAuth: EsimAuth
    private var googleAuth: GoogleFirebaseAuthenticator?
    private var appleAuth: AppleFirebaseAuthenticator?
    
    init(esimAuth: EsimAuth) {
        self.esimAuth = esimAuth
    }
    
    func loginWithGoogle(with authenticator: GoogleFirebaseAuthenticator?) {
        guard let authenticator = authenticator else { return } 
        esimAuth.signIn(with: authenticator, referrerId: nil) { result in
            switch result {
            case .success(let esimUser):
                break
            case .failure(let esimError):
                break
            }
        }
    }
    
    func loginWithApple(with authenticator: AppleFirebaseAuthenticator?) {
        guard let authenticator = authenticator else { return } 
        esimAuth.signIn(with: authenticator, referrerId: nil) { result in
            switch result {
            case .success(let esimUser):
                break
            case .failure(let esimError):
                break
            }
        }
    }
    
    func onLoginWithGoogle(with delegate: RequiringPresentationDelegate) {
        googleAuth = GoogleFirebaseAuthenticator(clientId: NGENV.google_client_id)
        googleAuth?.presentationDelegate = delegate
        loginWithGoogle(with: googleAuth)
    }
    
    func onLoginWithApple(with delegate: RequiringPresentationDelegate) {
        appleAuth = AppleFirebaseAuthenticator()
        appleAuth?.presentationDelegate = delegate
        loginWithApple(with: appleAuth)
    }
    
    func onViewDidLoad() {
        output.onViewDidLoad()
    }
    
    func onDismiss() {
        router.dismiss()
    }
    
    func onLoginWithEmail() {
        router.showLogin()
    }
}
