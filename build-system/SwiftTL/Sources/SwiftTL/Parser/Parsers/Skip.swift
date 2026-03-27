/// A parser that discards the output of another parser.
public struct Skip<Parsers: Parser>: Parser {
  /// The parser from which this parser receives output.
  public let parsers: Parsers

  @inlinable
  public init(@ParserBuilder _ build: () -> Parsers) {
    self.parsers = build()
  }

  @inlinable
  public func parse(_ input: inout Parsers.Input) rethrows {
    _ = try self.parsers.parse(&input)
  }
}

extension Parsers {
  public typealias Skip = SwiftTL.Skip  // NB: Convenience type alias for discovery
}
