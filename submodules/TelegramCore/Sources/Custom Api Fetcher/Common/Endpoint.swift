import Foundation

public protocol Endpoint {
    associatedtype Content
    func makeRequest() -> URLRequest
}

final public class AnyEndpoint<Content: Decodable>: Endpoint {
    
    private let _endpoint: () -> (URLRequest)
    
    public init<C: Endpoint>(_ concrete: C) where C.Content == Content {
        _endpoint =  concrete.makeRequest
    }
    public func makeRequest() -> URLRequest {
        _endpoint()
    }
    
    public func content(from response: URLResponse?, with body: Data) throws -> Content {
        try ResponseValidator.validate(response, with: body)
        let resource = try JSONDecoder.default.decode(Content.self, from: body)
        return content(from: resource)
    }
    
    private func content(from: Content) -> Content { return from}
}

protocol DateFormatterProtocol {
    func date(from string: String) -> Date?
}

extension JSONDecoder {
    static let `default`: JSONDecoder = {
        let decoder = JSONDecoder()
        let rfc3339DateFormatter: DateFormatter = .rfc3339DateFormatter
        decoder.dateDecodingStrategy = .formatted(rfc3339DateFormatter)
        return decoder
    }()
}

extension DateFormatter: DateFormatterProtocol {
    public static let rfc3339DateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        return formatter
    }()
}
