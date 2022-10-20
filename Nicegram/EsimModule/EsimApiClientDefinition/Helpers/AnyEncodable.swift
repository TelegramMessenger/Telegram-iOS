import Foundation

public struct AnyEncodable {
    
    //  MARK: - Private Properties

    private let wrapped: Encodable
    
    //  MARK: - Lifecycle
    
    public init?(_ wrapped: Encodable?) {
        if let wrapped = wrapped {
            self.wrapped = wrapped
        } else {
            return nil
        }
    }
}

extension AnyEncodable: Encodable {
    public func encode(to encoder: Encoder) throws {
        try wrapped.encode(to: encoder)
    }
}
