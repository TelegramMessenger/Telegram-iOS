/// A parser that runs the given parser and succeeds with `nil` if it fails.
///
/// Use this parser when you are parsing into an output data model that contains `nil`.
///
/// When the wrapped parser fails ``Optionally`` will backtrack any consumption of the input so
/// that later parsers can attempt to parser the input:
///
/// ```swift
/// let parser = Parse {
///   "Hello,"
///   Optionally { " "; Bool.parser() }
///   " world!"
/// }
///
/// try parser.parse("Hello, world!")      // nil 1️⃣
/// try parser.parse("Hello, true world!") // true
/// ```
///
/// If ``Optionally`` did not backtrack then 1️⃣ would fail because it would consume a space,
/// causing the `" world!"` parser to fail since there is no longer any space to consume.
/// Read the article <doc:Backtracking> to learn more about how backtracking works.
///
/// If you are optionally parsing input that should coalesce into some default, you can skip the
/// optionality and instead use ``replaceError(with:)`` with a default:
///
/// ```swift
/// Optionally { Int.parser() }
///   .map { $0 ?? 0 }
///
/// // vs.
///
/// Int.parser()
///   .replaceError(with: 0)
/// ```
public struct Optionally<Wrapped: Parser>: Parser {
  public let wrapped: Wrapped

  @inlinable
  public init(@ParserBuilder _ build: () -> Wrapped) {
    self.wrapped = build()
  }

  @inlinable
  public func parse(_ input: inout Wrapped.Input) -> Wrapped.Output? {
    let original = input
    do {
      return try self.wrapped.parse(&input)
    } catch {
      input = original
      return nil
    }
  }
}
