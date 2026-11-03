/// A parser that waits for a call to its ``parse(_:)`` method before running the given closure to
/// create a parser for the given input.
public final class Lazy<LazyParser: Parser>: Parser {
  @usableFromInline
  internal var lazyParser: LazyParser?

  public let createParser: () -> LazyParser

  @inlinable
  public init(@ParserBuilder createParser: @escaping () -> LazyParser) {
    self.createParser = createParser
  }

  @inlinable
  public func parse(_ input: inout LazyParser.Input) rethrows -> LazyParser.Output {
    guard let parser = self.lazyParser else {
      let parser = self.createParser()
      self.lazyParser = parser
      return try parser.parse(&input)
    }
    return try parser.parse(&input)
  }
}

extension Parsers {
  public typealias Lazy = SwiftTL.Lazy  // NB: Convenience type alias for discovery
}
