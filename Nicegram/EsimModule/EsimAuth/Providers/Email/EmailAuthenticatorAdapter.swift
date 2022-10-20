public final class EmailAuthenticatorAdapter {
    
    //  MARK: - Private Properties

    private let emailAuthenticator: EmailAuthenticator
    
    private var email: String?
    private var password: String?
    
    private var onSentVerificationEmail: (() -> ())?
    
    //  MARK: - Lifecycle
    
    public init(bundleId: String) {
        emailAuthenticator = .init(bundleId: bundleId)
    }
    
    //  MARK: - Public Functions

    public func prepareForSignIn(email: String, password: String, onSentVerificationEmail: @escaping () -> ()) {
        self.email = email
        self.password = password
        self.onSentVerificationEmail = onSentVerificationEmail
    }
    
    //  MARK: - Private Functions

    private func resetInfo() {
        email = nil
        password = nil
        onSentVerificationEmail = nil
    }
}

extension EmailAuthenticatorAdapter: FirebaseAuthProvider {
    public func signIn(completion: ((Result<FirebaseAuthProviderResponse, AuthProviderError>) -> ())?) {
        guard let email = email, let password = password else {
            fatalError("You must call prepareForSignIn before signIn")
        }
        
        emailAuthenticator.signIn(email: email, password: password, onSentVerificationEmail: onSentVerificationEmail) { [weak self] result in
            self?.resetInfo()
            completion?(result)
        }
    }
}
