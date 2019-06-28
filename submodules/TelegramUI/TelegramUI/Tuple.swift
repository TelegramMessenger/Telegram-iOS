import Foundation

public final class Tuple1<T0> {
    public let _0: T0
    
    public init(_ _0: T0) {
        self._0 = _0
    }
}

public final class Tuple2<T0, T1> {
    public let _0: T0
    public let _1: T1
    
    public init(_ _0: T0, _ _1: T1) {
        self._0 = _0
        self._1 = _1
    }
}

public final class Tuple3<T0, T1, T2> {
    public let _0: T0
    public let _1: T1
    public let _2: T2
    
    public init(_ _0: T0, _ _1: T1, _ _2: T2) {
        self._0 = _0
        self._1 = _1
        self._2 = _2
    }
}

public func Tuple<T0>(_ _0: T0) -> Tuple1<T0> {
    return Tuple1(_0)
}

public func Tuple<T0, T1>(_ _0: T0, _ _1: T1) -> Tuple2<T0, T1> {
    return Tuple2(_0, _1)
}

public func Tuple<T0, T1, T2>(_ _0: T0, _ _1: T1, _ _2: T2) -> Tuple3<T0, T1, T2> {
    return Tuple3(_0, _1, _2)
}
