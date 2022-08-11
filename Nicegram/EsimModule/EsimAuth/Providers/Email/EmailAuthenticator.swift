import FirebaseAuth
import EsimModels
import EsimPropertyWrappers

public final class EmailAuthenticator {
    
    //  MARK: - Private Properties

    private let bundleId: String
    
    @UserDefaultsWrapper(key: "temporary_user_data", defaultValue: nil)
    private var temporaryUserInfo: TemporaryUserInfo?
    
    //  MARK: - Lifecycle
    
    public init(bundleId: String) {
        self.bundleId = bundleId
    }
    
    //  MARK: - Public Functions
    
    public func signIn(email: String, password: String, onSentVerificationEmail: (() -> ())?, completion: @escaping (Result<FirebaseAuthProviderResponse, AuthProviderError>) -> ()) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(.underlying(self.mapFirebaseError(error))))
            } else if let user = authResult?.user {
                var profileInfo = AuthProfileMetadata(firstName: user.displayName, secondName: nil, email: email)

                if user.isEmailVerified {
                    let matchesTemporaryUser = (user.uid == self.temporaryUserInfo?.firebaseUID)
                    if matchesTemporaryUser {
                        profileInfo.firstName = self.temporaryUserInfo?.firstName
                        profileInfo.secondName = self.temporaryUserInfo?.secondName
                        
                        self.temporaryUserInfo = nil
                    }
                    
                    let response = FirebaseAuthProviderResponse(firebaseUser: user, profileInfo: profileInfo)
                    completion(.success(response))
                } else {
                    self.sendVerificationEmail(to: user) { error in
                        if error == nil {
                            self.temporaryUserInfo = .init(firebaseUID: user.uid, firstName: user.displayName, secondName: nil)
                        }
                        
                        onSentVerificationEmail?()
                    }
                }
            } else {
                completion(.failure(.unexpected))
            }
        }
    }
    
    public func sendPasswordReset(withEmail email: String, completion: @escaping (Error?) -> ()) {
        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            completion(self?.mapFirebaseError(error))
        }
    }
    
    public func createUser(_ info: CreateUserDTO, onSentVerificationEmail: (() -> ())?, completion: ((Result<User, Error>) -> Void)?) {
        Auth.auth().createUser(withEmail: info.email, password: info.password) { [weak self] authResult, error in
            guard let self = self else { return }
            
            if let error = error {
                completion?(.failure(self.mapFirebaseError(error)))
                return
            }
            
            guard let authResult = authResult else { return }
            
            let request = authResult.user.createProfileChangeRequest()
            request.displayName = "\(info.firstName) \(info.lastName)"
            
            request.commitChanges { error in
                if let error = error {
                    completion?(.failure(error))
                    return
                }
                
                if authResult.user.isEmailVerified {
                    completion?(.success(authResult.user))
                } else {
                    self.sendVerificationEmail(to: authResult.user) { error in
                        if let error = error {
                            completion?(.failure(error))
                        } else {
                            self.temporaryUserInfo = .init(firebaseUID: authResult.user.uid, firstName: info.firstName, secondName: info.lastName)
                            onSentVerificationEmail?()
                        }
                    }
                }
            }
        }
    }
    
    //  MARK: - Private Functions

    private func sendVerificationEmail(to user: User, completion: @escaping (Error?) -> ()) {
        let actionCodeSettings = ActionCodeSettings()
        actionCodeSettings.setIOSBundleID(bundleId)
        user.sendEmailVerification(with: actionCodeSettings) { [weak self] error in
            completion(self?.mapFirebaseError(error))
        }
    }
    
    private func mapFirebaseError(_ error: Error) -> Error {
        let localizationKey: String
        switch (error as NSError).userInfo[AuthErrorUserInfoNameKey] as? String {
        case "ERROR_USER_NOT_FOUND":
            localizationKey = "Auth.ErrorUserNotFound"
        case "ERROR_WRONG_PASSWORD":
            localizationKey = "Auth.ErrorWrongPassword"
        case "ERROR_EMAIL_ALREADY_IN_USE":
            localizationKey = "Auth.ErrorAlreadyInUse"
        default:
            localizationKey = "Nicegram.Alert.BaseError"
        }
        
        return MessageError(message: NSLocalizedString(localizationKey, comment: ""))
    }
    
    private func mapFirebaseError(_ error: Error?) -> Error? {
        if let error = error {
            return mapFirebaseError(error)
        } else {
            return  nil
        }
    }
}

private struct TemporaryUserInfo: Codable {
    let firebaseUID: String
    let firstName: String?
    let secondName: String?
}
