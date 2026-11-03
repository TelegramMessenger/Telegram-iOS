extension Parser {
  /// Returns a parser that filters output from this parser when its output does not satisfy the
  /// given predicate.
  ///
  /// This method is similar to `Sequence.filter` in the Swift standard library, as well as
  /// `Publisher.filter` in the Combine framework.
  ///
  /// This parser fails if the predicate is not satisfied on the output of the upstream parser. For example,
  /// the following parser consumes only even integers and so fails when an odd integer is used:
  ///
  /// ```swift
  /// var input = "43 Hello, world!"[...]
  /// let number = try Int.parser().filter { $0.isMultiple(of: 2) }.parse(&input)
  /// // error: processed value 43 failed to satisfy predicate
  /// //  --> input:1:1-2
  /// // 1 | 43 Hello, world!
  /// //   | ^^ processed input
  /// ```
  ///
  /// - Parameter predicate: A closure that takes an output from this parser and returns a Boolean
  ///   value indicating whether the output should be returned.
  /// - Returns: A parser that filters its output.
  @_disfavoredOverload
  @inlinable
  public func filter(_ predicate: @escaping (Output) -> Bool) -> Parsers.Filter<Self> {
    .init(upstream: self, predicate: predicate)
  }
}

extension Parsers {
  /// A parser that filters the output of an upstream parser when it does not satisfy a predicate.
  ///
  /// You will not typically need to interact with this type directly. Instead you will usually use
  /// the ``Parser/filter(_:)`` operation, which constructs this type.
  public struct Filter<Upstream: Parser>: Parser {
    public let upstream: Upstream
    public let predicate: (Upstream.Output) -> Bool

    @inlinable
    public init(upstream: Upstream, predicate: @escaping (Upstream.Output) -> Bool) {
      self.upstream = upstream
      self.predicate = predicate
    }

    @inlinable
    public func parse(_ input: inout Upstream.Input) throws -> Upstream.Output {
      let original = input
      let output = try self.upstream.parse(&input)
      guard self.predicate(output)
      else {
        throw ParsingError.failed(
          summary: "processed value \(formatValue(output)) failed to satisfy predicate",
          label: "processed input",
          from: original,
          to: input
        )
      }
      return output
    }
  }
}
