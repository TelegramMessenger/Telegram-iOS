import Foundation

public struct SpecialOffer {
    public let id: String
    public let url: URL
    public let shouldAutoshowToPremiumUser: Bool
    public let autoshowTimeInterval: TimeInterval?
    
    public init(id: String, url: URL, shouldAutoshowToPremiumUser: Bool, autoshowTimeInterval: TimeInterval?) {
        self.id = id
        self.url = url
        self.shouldAutoshowToPremiumUser = shouldAutoshowToPremiumUser
        self.autoshowTimeInterval = autoshowTimeInterval
    }
}
