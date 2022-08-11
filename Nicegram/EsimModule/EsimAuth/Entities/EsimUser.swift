import Foundation
import FirebaseAuth
import EsimPropertyWrappers

private let kUserToken = "user_token"

public class EsimUser: Codable {
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case firstName
        case lastName
        case referrerId
        // TODO: !Check parsing, when there is not key telegramToken
        case telegramToken = "telegramAuthToken"
    }
    
    public let id: Int
    public let email: String?
    public let firstName: String?
    public let lastName: String?
    public var photoUrl: URL? = nil
    public let referrerId: Int?
    public let telegramToken: String?
    
    public var fullName: String? {
        guard let firstName = firstName else {
            return nil
        }
        guard let lastName = lastName else {
            return nil
        }
        return [firstName,lastName].joined(separator: " ")
    }
    
    public var initials: String? {
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
    
    @UserDefaultsWrapper(key: kUserToken, defaultValue: nil)
    public var token: String?
    
    // MARK: - Object life cylce
    
    public init(id: Int,
                email: String?,
                firstName: String?,
                lastName: String?,
                photoURL: URL?,
                referrerId: Int?,
                telegramToken: String? = nil) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.photoUrl = photoURL
        self.referrerId = referrerId
        self.telegramToken = telegramToken
    }
    
    // MARK: - Methods
    
    public func refreshToken(forceRefresh: Bool, completion: ((Result<String, Error>) -> Void)? = nil) {
        Auth.auth().currentUser?.getIDTokenForcingRefresh(forceRefresh) { [weak self] token, error in
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
