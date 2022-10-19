import Foundation
import FirebaseAuth
import EsimModels
import EsimPropertyWrappers

private let kUserToken = "user_token"

public class EsimUser: Codable {
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case firstName
        case lastName
        case referrerId
        case telegramUsername
        case telegramToken = "telegramAuthToken"
    }
    
    public let id: Int
    public let email: String?
    public let firstName: String?
    public let lastName: String?
    public var photoUrl: URL? = nil
    public let referrerId: Int?
    public let telegramUsername: String?
    public let telegramToken: String?
    
    @UserDefaultsWrapper(key: kUserToken, defaultValue: nil)
    public var token: String?
    
    // MARK: - Methods
    
    public func refreshToken(forceRefresh: Bool, completion: ((Result<String, Error>) -> Void)? = nil) {
        guard let firebaseUser = Auth.auth().currentUser else {
            completion?(.failure(MessageError.defaultError))
            return
        }
        firebaseUser.getIDTokenForcingRefresh(forceRefresh) { [weak self] token, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion?(.failure(error))
                } else if let token = token {
                    self?.token = token
                    completion?(.success(token))
                }
            }
        }
    }
}

public extension EsimUser {
    var fullName: String? {
        guard let firstName = firstName else {
            return nil
        }
        guard let lastName = lastName else {
            return nil
        }
        return [firstName,lastName].joined(separator: " ")
    }
    
    var initials: String? {
        guard let name = fullName else { return nil }
        
        let components = name.components(separatedBy: " ")
        let initials = components
            .compactMap { $0.first }
            .map { String($0) }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        
        return initials.isEmpty ? nil : initials
    }
}

public extension EsimUser {
    var linkedProviders: Set<AuthProvider> {
        if let firebaseUser = Auth.auth().currentUser {
            return Set(firebaseUser.providerData.compactMap({ self.mapProviderId($0.providerID) }))
        } else if telegramToken != nil {
            return [.telegram]
        } else {
            return []
        }
    }
    
    enum AuthProvider {
        case email
        case apple
        case google
        case telegram
    }
    
    private func mapProviderId(_ id: String) -> AuthProvider? {
        switch id {
        case "password": return .email
        case "apple.com": return .apple
        case "google.com": return .google
        default: return nil
        }
    }
}
