extension Parser {
  /// Returns a parser that runs this parser, pipes its output into the given parser, and returns
  /// the output of the given parser.
  ///
  /// For example, we can try to parse an integer of exactly 4 digits by piping the output of
  /// ``Prefix`` into an `Int.parser()`:
  ///
  /// ```swift
  /// let year = Prefix(4).pipe { Int.parser() }
  ///
  /// try year.parse("2022")  // 2022
  /// try year.parse("0123")  // 123
  /// ```
  ///
  /// This parser fails if either the upstream or downstream parser fails. For example:
  ///
  /// ```swift
  /// try year.parse("123")
  /// // error: unexpected input
  /// //  --> input:1:4
  /// // 1 | 123
  /// //   |    ^ expected 1 more element
  ///
  /// try year.parse("fail!")
  /// // error: unexpected input
  /// //  --> input:1:1-4
  /// // 1 | fail!
  /// //   | ^^^^ pipe: expected integer
  /// ```
  ///
  /// - Parameter downstream: A parser that parses the output of this parser.
  /// - Returns: A parser that pipes this parser's output into another parser.  @inlinable
  public func pipe<Downstream>(
    @ParserBuilder _ build: () -> Downstream
  ) -> Parsers.Pipe<Self, Downstream> {
    .init(upstream: self, downstream: build())
  }
}

extension Parsers {
  /// A parser that runs this parser, pipes its output into the given parser, and returns the output
  /// of the given parser.
  ///
  /// You will not typically need to interact with this type directly. Instead you will usually use
  /// the ``Parser/pipe(_:)`` operation, which constructs this type.
  public struct Pipe<Upstream: Parser, Downstream: Parser>: Parser
  where Upstream.Output == Downstream.Input {
    public let upstream: Upstream
    public let downstream: Downstream

    @inlinable
    public init(upstream: Upstream, downstream: Downstream) {
      self.upstream = upstream
      self.downstream = downstream
    }

    @inlinable
    public func parse(_ input: inout Upstream.Input) rethrows -> Downstream.Output {
      let original = input
      var downstreamInput = try self.upstream.parse(&input)
      do {
        return try self.downstream.parse(&downstreamInput)
      } catch let ParsingError.failed(reason, context) {
        throw ParsingError.failed(
          "pipe: \(reason)",
          .init(
            originalInput: original,
            remainingInput: input,
            debugDescription: context.debugDescription,
            underlyingError: ParsingError.failed(reason, context)
          )
        )
      }
    }
  }
}
