import Foundation

private struct NoNeighborInfluence: Equatable {
}

/// A type-erased `Equatable` value.
///
/// Unlike `AnyHashable` this imposes no `Hashable` requirement on payloads — nothing hashes a
/// neighbor descriptor, and `Equatable` is the weaker constraint.
public struct AnyEquatable: Equatable {
    private let value: Any
    private let isEqualTo: (Any) -> Bool

    public init<T: Equatable>(_ value: T) {
        self.value = value
        self.isEqualTo = { other in
            guard let other = other as? T else {
                return false
            }
            return other == value
        }
    }

    public static func == (lhs: AnyEquatable, rhs: AnyEquatable) -> Bool {
        return lhs.isEqualTo(rhs.value)
    }

    /// Recovers the payload as `T`. `T` may be a concrete type or a protocol (facet).
    public func base<T>(_ type: T.Type) -> T? {
        return self.value as? T
    }

    /// Payload for items whose neighbors read nothing about them. A single shared constant, so it
    /// compares equal to itself and never causes a neighbor relayout.
    public static let noNeighborInfluence = AnyEquatable(NoNeighborInfluence())
}
