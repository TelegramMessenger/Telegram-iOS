import Foundation

public final class FunctionParameterDescription {
    public let value: Optional<Any>
    
    init(_ value: Optional<Any>) {
        self.value = value
    }
}

public final class FunctionDescription {
    public let name: String
    public let parameters: [(String, FunctionParameterDescription)]
    
    init(name: String, parameters: [(String, FunctionParameterDescription)]) {
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

public protocol TypeConstructorDescription {
    func descriptionFields() -> (String, [(String, Any)])
}
