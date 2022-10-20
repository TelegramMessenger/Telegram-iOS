import UIKit
import AuthenticationServices
import EsimKeychainWrapper
#if canImport(CryptoKit)
import CryptoKit
#endif

@available(iOS 13, *)
public struct AppleAuthResponse {
    public struct Metadata {
        public let email: String?
        public let fullname: String?
    }
    
    public let credential: ASAuthorizationAppleIDCredential
    public let nonce: String
    public let metadata: Metadata
}

@available(iOS 13, *)
public final class AppleAuthenticator: NSObject, RequiringPresentation {
    
    //  MARK: - Public Properties
    
    public var credential: ASAuthorizationAppleIDCredential?
    
    public weak var presentationDelegate: RequiringPresentationDelegate?
    
    //  MARK: - Private Properties
    
    private var completion: ((Result<AppleAuthResponse, AuthProviderError>) -> ())?
    
    private var currentNonce: String?
    
    private var window: UIWindow?
    
    //  MARK: - Public Functions

    public func signIn(completion: ((Result<AppleAuthResponse, AuthProviderError>) -> ())?) {
        guard let presentingViewController = presentationDelegate?.presentingViewController() else {
            fatalError("AuthProviderDelegate must provide presenting view controller for \(type(of: AppleAuthenticator.self))")
        }
        
        guard presentingViewController.view.window != nil else {
            fatalError("Presenting view controller view must located in window hierarchy \(type(of: AppleAuthenticator.self))")
        }
        
        self.completion = completion
        self.startSignInWithAppleFlow(presentingViewController: presentingViewController)
    }
    
    //  MARK: - Private Functions
    
    private func startSignInWithAppleFlow(presentingViewController: UIViewController) {
        let nonce = randomNonceString()
        currentNonce = nonce
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        #if canImport(CryptoKit)
        request.nonce = sha256(nonce)
        #endif
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
        
        window = presentingViewController.view.window
    }
    
    #if canImport(CryptoKit)
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    #endif

    // Adapted from https://auth0.com/docs/api-auth/tutorials/nonce#generate-a-cryptographically-random-nonce
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: Array<Character> =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
}

// MARK: - ASAuthorizationControllerDelegate

@available(iOS 13, *)
extension AppleAuthenticator: ASAuthorizationControllerDelegate {
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            
            // We should cache credentials because
            // we apple give us to opportunity to read credentials
            // only at first time.
            
            var email = AppleAuthKeyChainService.shared.appleUserEmail
            var fullName = AppleAuthKeyChainService.shared.appleUserName
            
            if let userEmail = appleIDCredential.email {
                email = userEmail
                AppleAuthKeyChainService.shared.saveAppleEmail(email: email)
            }
            if let userFullName = appleIDCredential.fullName {
                fullName = PersonNameComponentsFormatter().string(from: userFullName)
                AppleAuthKeyChainService.shared.saveAppleUserName(name: fullName)
            }
            
            let metadata = AppleAuthResponse.Metadata(email: email, fullname: fullName)
            let response = AppleAuthResponse(credential: appleIDCredential, nonce: nonce, metadata: metadata)
            
            self.credential = appleIDCredential
            
            completion?(.success(response))
            completion = nil
        }
    }
    
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if (error as NSError).code == 1001 {
            completion?(.failure(.cancelled(error)))
        } else {
            completion?(.failure(.underlying(error)))
        }
        completion = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

@available(iOS 13, *)
extension AppleAuthenticator: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return window!
    }
}

// MARK: - AppleAuthKeyChainService

/// A Helper class which abstract Keychain API related calls.
fileprivate class AppleAuthKeyChainService {
    
    // MARK: - Properties
    
    static let shared = AppleAuthKeyChainService()
    
    /// Returns previous saved user name if available.
    var appleUserName: String? {
        return KeychainWrapper
            .standard
            .string(forKey: Key.appAppleUserName)
    }
    
    /// Returns previous saved user appleId/email  if available.
    var appleUserEmail: String? {
        return KeychainWrapper
            .standard
            .string(forKey: Key.appAppleEmailId)
    }
    
    
    /// Saves the apple user name into keychain.
    /// - Parameter name: Apple user name retrieved form AppleLogin.
    /// - Returns: true if succeed otherwise false.
    @discardableResult
    func saveAppleUserName(name: String?) -> Bool {
        guard let name = name else { return false }
        return KeychainWrapper.standard.set(name, forKey: Key.appAppleUserName)
    }
    
    /// Saves the apple user email into keychain.
    /// - Parameter email: Apple userId/email  retrieved form AppleLogin.
    /// - Returns: true if succeed otherwise false.
    @discardableResult
    func saveAppleEmail(email: String?) -> Bool {
        guard let email = email else { return false }
        return KeychainWrapper.standard.set(email, forKey: Key.appAppleEmailId)
    }
    
    
    /// Deletes both apple user name and saved Id from keyChain.
    func deleteSavedAppleUserInfo() {
        KeychainWrapper.standard.removeObject(forKey: Key.appAppleUserName)
        KeychainWrapper.standard.removeObject(forKey: Key.appAppleEmailId)
    }
}

// MARK: - KeychainWrapper + Extensions

extension AppleAuthKeyChainService {
    enum Key {
        /// A random string used to identify saved user apple name from keychain.
        static let appAppleUserName: String = "appAppleUserName"
        
        /// A random string used to identify saved user apple email /Id from keychain.
        static let appAppleEmailId: String = "appAppleEmailId"
    }
}
