extension Parser {
  /// Returns a parser that transforms the output of this parser with a given closure.
  ///
  /// This method is similar to `Sequence.map`, `Optional.map`, and `Result.map` in the Swift
  /// standard library, as well as `Publisher.map` in the Combine framework.
  ///
  /// - Parameter transform: A closure that transforms values of this parser's output.
  /// - Returns: A parser of transformed outputs.
  @_disfavoredOverload
  @inlinable
  public func map<NewOutput>(
    _ transform: @escaping (Output) -> NewOutput
  ) -> Parsers.Map<Self, NewOutput> {
    .init(upstream: self, transform: transform)
  }
}

extension Parsers {
  /// A parser that transforms the output of another parser with a given closure.
  ///
  /// You will not typically need to interact with this type directly. Instead you will usually use
  /// the ``Parser/map(_:)`` operation, which constructs this type.
  public struct Map<Upstream: Parser, NewOutput>: Parser {
    /// The parser from which this parser receives output.
    public let upstream: Upstream

    /// The closure that transforms output from the upstream parser.
    public let transform: (Upstream.Output) -> NewOutput

    @inlinable
    public init(upstream: Upstream, transform: @escaping (Upstream.Output) -> NewOutput) {
      self.upstream = upstream
      self.transform = transform
    }

    @inlinable
    @inline(__always)
    public func parse(_ input: inout Upstream.Input) rethrows -> NewOutput {
      self.transform(try self.upstream.parse(&input))
    }
  }
}
