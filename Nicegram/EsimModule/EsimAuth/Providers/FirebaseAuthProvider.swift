import UIKit
import FirebaseAuth

public struct FirebaseAuthProviderResponse {
    public let firebaseUser: User
    public let profileInfo: AuthProfileMetadata
}

public struct AuthProfileMetadata {
    public var firstName: String?
    public var secondName: String?
    public let email: String?
}


public protocol FirebaseAuthProvider: AnyObject {
    func signIn(completion: ((Result<FirebaseAuthProviderResponse, AuthProviderError>) -> ())?)
}
