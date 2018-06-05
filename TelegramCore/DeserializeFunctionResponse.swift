import Foundation

public final class FunctionDescription {
    let name: String
    let parameters: [(String, Any)]
    
    init(name: String, parameters: [(String, Any)]) {
        self.name = name
        self.parameters = parameters
    }
}

public final class DeserializeFunctionResponse<T> {
    private let f: (Buffer) -> T?
    
    public init(_ f: @escaping (Buffer) -> T?) {
        self.f = f
    }
    
    public func parse(_ buffer: Buffer) -> T? {
        return self.f(buffer)
    }
}

protocol TypeConstructorDescription {
    func descriptionFields() -> (String, [(String, Any)])
}
