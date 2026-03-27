/// A parser that runs the given parser, but does not consume any input.
///
/// It lets the upstream parser "peek" into the input without consuming it.
///
/// For example, identifiers (variables, functions, etc.) in Swift allow the first character to be a
/// letter or underscore, but not a digit, but subsequent characters can be digits. _E.g._, `foo123`
/// is a valid identifier, but `123foo` is not. We can create an identifier parser by using `Peek`
/// to first check if the input starts with a letter or underscore, and if it does, return the
/// remainder of the input up to the first character that is not a letter, a digit, or an
/// underscore.
///
/// ```swift
/// let identifier = Parse {
///   Peek { Prefix(1) { $0.isLetter || $0 == "_" } }
///   Prefix { $0.isNumber || $0.isLetter || $0 == "_" }
/// }
///
/// try identifier.parse("foo123") // ✅ "foo123"
/// try identifier.parse("_foo123") // ✅ "_foo123"
/// try identifier.parse("1_foo123") // ❌
/// // error: unexpected input
/// //  --> input:1:1
/// // 1 | 1_foo123
/// //   | ^ expected 1 element satisfying predicate
/// ```
public struct Peek<Upstream: Parser>: Parser {
  public let upstream: Upstream

  /// Construct a parser that runs the given parser, but does not consume any input.
  ///
  /// - Parameter build: A parser this parser wants to inspect.
  @inlinable
  public init(@ParserBuilder _ build: () -> Upstream) {
    self.upstream = build()
  }

  @inlinable
  public func parse(_ input: inout Upstream.Input) rethrows {
    let original = input
    _ = try self.upstream.parse(&input)
    input = original
  }
}
