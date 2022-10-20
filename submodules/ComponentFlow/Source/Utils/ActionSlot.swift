import Foundation

public final class Action<Arguments> {
    public let action: (Arguments) -> Void
    
    public init(_ action: @escaping (Arguments) -> Void) {
        self.action = action
    }
    
    public func callAsFunction(_ arguments: Arguments) {
        self.action(arguments)
    }
}

public final class ActionSlot<Arguments>: Equatable {
    private var target: ((Arguments) -> Void)?
    
    public init() {
    }
    
    public static func ==(lhs: ActionSlot<Arguments>, rhs: ActionSlot<Arguments>) -> Bool {
        return lhs === rhs
    }
    
    public func connect(_ target: @escaping (Arguments) -> Void) {
        self.target = target
    }
    
    public func invoke(_ arguments: Arguments) {
        self.target?(arguments)
    }
}
