import Foundation

public struct CreateUserDTO {
    public let firstName: String
    public let lastName: String
    public let email: String
    public let password: String
    public let referrerId: Int?
    
    public init(firstName: String, lastName: String, email: String, password: String, referrerId: Int?) {
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.password = password
        self.referrerId = referrerId
    }
}
