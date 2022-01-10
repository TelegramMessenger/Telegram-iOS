import Foundation
import UIKit

public final class Empty: Equatable {
    static let shared: Empty = Empty()

    public static func ==(lhs: Empty, rhs: Empty) -> Bool {
        return true
    }
}

public class _Environment {
    fileprivate var data: [Int: _EnvironmentValue] = [:]
    var _isUpdated: Bool = false

    func calculateIsUpdated() -> Bool {
        if self._isUpdated {
            return true
        }
        for (_, item) in self.data {
            if let parentEnvironment = item.parentEnvironment, parentEnvironment.calculateIsUpdated() {
                return true
            }
        }
        return false
    }

    fileprivate func set<T: Equatable>(index: Int, value: EnvironmentValue<T>) {
        if let current = self.data[index] {
            self.data[index] = value
            if current as! EnvironmentValue<T> != value {
                self._isUpdated = true
            }
        } else {
            self.data[index] = value
            self._isUpdated = true
        }
    }
}

private enum EnvironmentValueStorage<T> {
    case direct(T)
    case reference(_Environment, Int)
}

public class _EnvironmentValue {
    fileprivate let parentEnvironment: _Environment?

    fileprivate init(parentEnvironment: _Environment?) {
        self.parentEnvironment = parentEnvironment
    }
}

@dynamicMemberLookup
public final class EnvironmentValue<T: Equatable>: _EnvironmentValue, Equatable {
    private var storage: EnvironmentValueStorage<T>

    public var value: T {
        switch self.storage {
        case let .direct(value):
            return value
        case let .reference(environment, index):
            return (environment.data[index] as! EnvironmentValue<T>).value
        }
    }

    fileprivate init(_ value: T) {
        self.storage = .direct(value)

        super.init(parentEnvironment: nil)
    }

    fileprivate init(environment: _Environment, index: Int) {
        self.storage = .reference(environment, index)

        super.init(parentEnvironment: environment)
    }

    public static func ==(lhs: EnvironmentValue<T>, rhs: EnvironmentValue<T>) -> Bool {
        if lhs === rhs {
            return true
        }
        // TODO: follow the reference chain for faster equality checking
        return lhs.value == rhs.value
    }

    public subscript<V>(dynamicMember keyPath: KeyPath<T, V>) -> V {
        return self.value[keyPath: keyPath]
    }
}

public class Environment<T>: _Environment {
    private let file: StaticString
    private let line: Int

    public init(_ file: StaticString = #file, _ line: Int = #line) {
        self.file = file
        self.line = line
    }
}

public extension Environment where T == Empty {
    static let value: Environment<Empty> = {
        let result = Environment<Empty>()
        result.set(index: 0, value: EnvironmentValue(Empty()))
        return result
    }()
}

public extension Environment {
    subscript(_ t1: T.Type) -> EnvironmentValue<T> where T: Equatable {
        return EnvironmentValue(environment: self, index: 0)
    }

    subscript<T1, T2>(_ t1: T1.Type) -> EnvironmentValue<T1> where T == (T1, T2), T1: Equatable, T2: Equatable {
        return EnvironmentValue(environment: self, index: 0)
    }

    subscript<T1, T2>(_ t2: T2.Type) -> EnvironmentValue<T2> where T == (T1, T2), T1: Equatable, T2: Equatable {
        return EnvironmentValue(environment: self, index: 1)
    }

    subscript<T1, T2, T3>(_ t1: T1.Type) -> EnvironmentValue<T1> where T == (T1, T2, T3), T1: Equatable, T2: Equatable, T3: Equatable {
        return EnvironmentValue(environment: self, index: 0)
    }

    subscript<T1, T2, T3>(_ t2: T2.Type) -> EnvironmentValue<T2> where T == (T1, T2, T3), T1: Equatable, T2: Equatable, T3: Equatable {
        return EnvironmentValue(environment: self, index: 1)
    }

    subscript<T1, T2, T3>(_ t3: T3.Type) -> EnvironmentValue<T3> where T == (T1, T2, T3), T1: Equatable, T2: Equatable, T3: Equatable {
        return EnvironmentValue(environment: self, index: 2)
    }

    subscript<T1, T2, T3, T4>(_ t1: T1.Type) -> EnvironmentValue<T1> where T == (T1, T2, T3, T4), T1: Equatable, T2: Equatable, T3: Equatable, T4: Equatable {
        return EnvironmentValue(environment: self, index: 0)
    }

    subscript<T1, T2, T3, T4>(_ t2: T2.Type) -> EnvironmentValue<T2> where T == (T1, T2, T3, T4), T1: Equatable, T2: Equatable, T3: Equatable, T4: Equatable {
        return EnvironmentValue(environment: self, index: 1)
    }

    subscript<T1, T2, T3, T4>(_ t3: T3.Type) -> EnvironmentValue<T3> where T == (T1, T2, T3, T4), T1: Equatable, T2: Equatable, T3: Equatable, T4: Equatable {
        return EnvironmentValue(environment: self, index: 2)
    }

    subscript<T1, T2, T3, T4>(_ t4: T4.Type) -> EnvironmentValue<T4> where T == (T1, T2, T3, T4), T1: Equatable, T2: Equatable, T3: Equatable, T4: Equatable {
        return EnvironmentValue(environment: self, index: 3)
    }
}

@resultBuilder
public struct EnvironmentBuilder {
    static var _environment: _Environment?
    private static func current<T>(_ type: T.Type) -> Environment<T> {
        return self._environment as! Environment<T>
    }

    public struct Partial<T: Equatable> {
        fileprivate var value: EnvironmentValue<T>
    }

    public static func buildBlock() -> Environment<Empty> {
        let result = self.current(Empty.self)
        result.set(index: 0, value: EnvironmentValue(Empty.shared))
        return result
    }

    public static func buildExpression<T: Equatable>(_ expression: T) -> Partial<T> {
        return Partial<T>(value: EnvironmentValue(expression))
    }

    public static func buildExpression<T: Equatable>(_ expression: EnvironmentValue<T>) -> Partial<T> {
        return Partial<T>(value: expression)
    }

    public static func buildBlock<T1: Equatable>(_ t1: Partial<T1>) -> Environment<T1> {
        let result = self.current(T1.self)
        result.set(index: 0, value: t1.value)
        return result
    }

    public static func buildBlock<T1: Equatable, T2: Equatable>(_ t1: Partial<T1>, _ t2: Partial<T2>) -> Environment<(T1, T2)> {
        let result = self.current((T1, T2).self)
        result.set(index: 0, value: t1.value)
        result.set(index: 1, value: t2.value)
        return result
    }

    public static func buildBlock<T1: Equatable, T2: Equatable, T3: Equatable>(_ t1: Partial<T1>, _ t2: Partial<T2>, _ t3: Partial<T3>) -> Environment<(T1, T2, T3)> {
        let result = self.current((T1, T2, T3).self)
        result.set(index: 0, value: t1.value)
        result.set(index: 1, value: t2.value)
        result.set(index: 2, value: t3.value)
        return result
    }

    public static func buildBlock<T1: Equatable, T2: Equatable, T3: Equatable, T4: Equatable>(_ t1: Partial<T1>, _ t2: Partial<T2>, _ t3: Partial<T3>, _ t4: Partial<T4>) -> Environment<(T1, T2, T3, T4)> {
        let result = self.current((T1, T2, T3, T4).self)
        result.set(index: 0, value: t1.value)
        result.set(index: 1, value: t2.value)
        result.set(index: 2, value: t3.value)
        result.set(index: 3, value: t4.value)
        return result
    }
}

@propertyWrapper
public struct ZeroEquatable<T>: Equatable {
    public var wrappedValue: T

    public init(_ wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }

    public static func ==(lhs: ZeroEquatable<T>, rhs: ZeroEquatable<T>) -> Bool {
        return true
    }
}
