import Foundation

public final class FunctionDescription: CustomStringConvertible {
    private let generator: () -> String
    
    init(_ generator: @escaping () -> String) {
        self.generator = generator
    }
    
    public var description: String {
        return self.generator()
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
