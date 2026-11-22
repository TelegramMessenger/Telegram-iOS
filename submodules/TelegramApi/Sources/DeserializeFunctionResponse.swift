import Foundation

public final class ConstructorParameterDescription {
    public let value: Optional<Any>
    
    init(_ value: Optional<Any>) {
        self.value = value
    }
}

public final class FunctionDescription {
    public let name: String
    private let lock = NSLock()
    private var storedParameters: [(String, ConstructorParameterDescription)]?
    private let makeParameters: (() -> [(String, ConstructorParameterDescription)])?

    /// Described on first use (only the logger reads it), from the request object.
    public var parameters: [(String, ConstructorParameterDescription)] {
        self.lock.lock()
        defer { self.lock.unlock() }
        if let stored = self.storedParameters {
            return stored
        }
        let made = self.makeParameters?() ?? []
        self.storedParameters = made
        return made
    }

    init(name: String, parameters: [(String, ConstructorParameterDescription)]) {
        self.name = name
        self.storedParameters = parameters
        self.makeParameters = nil
    }

    init(name: String, lazyParameters: @escaping () -> [(String, ConstructorParameterDescription)]) {
        self.name = name
        self.storedParameters = nil
        self.makeParameters = lazyParameters
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
    func descriptionFields() -> (String, [(String, ConstructorParameterDescription)])
}
