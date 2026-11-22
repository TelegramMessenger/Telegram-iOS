extension Parser {
  /// A parser that replaces its error with a provided output.
  ///
  /// Useful for providing a default output for a parser.
  ///
  /// For example, we could create a parser that parses a plus or minus sign and maps the result to
  /// a positive or negative multiplier respectively, or else defaults to a positive multiplier:
  ///
  /// ```swift
  /// let sign = OneOf {
  ///   "+".map { 1 }
  ///   "-".map { -1 }
  /// }
  /// .replaceError(with: 1)
  /// ```
  ///
  /// Notably this parser is non-throwing:
  ///
  /// ```swift
  /// var input = "-123"[...]
  ///
  /// // No `try` required:
  /// sign.parse(&input)  // -1
  /// input               // "123"
  ///
  /// // Simply returns the default when parsing fails:
  /// sign.parse(&input)  // 1
  /// ```
  ///
  /// This means it can be used to turn throwing parsers into non-throwing ones, which is important
  /// for building up complex parsers that cannot fail.
  ///
  /// - Parameter output: An output to return should the upstream parser fail.
  /// - Returns: A parser that never fails.
  @inlinable
  public func replaceError(with output: Output) -> Parsers.ReplaceError<Self> {
    .init(output: output, upstream: self)
  }
}

extension Parsers {
  /// A parser that replaces its error with a provided output.
  ///
  /// You will not typically need to interact with this type directly. Instead you will usually use
  /// the ``Parser/replaceError(with:)`` operation, which constructs this type.
  public struct ReplaceError<Upstream: Parser>: Parser {
    @usableFromInline
    let output: Upstream.Output

    @usableFromInline
    let upstream: Upstream

    @usableFromInline
    init(output: Upstream.Output, upstream: Upstream) {
      self.output = output
      self.upstream = upstream
    }

    @inlinable
    public func parse(_ input: inout Upstream.Input) -> Upstream.Output {
      let original = input
      do {
        return try self.upstream.parse(&input)
      } catch {
        input = original
        return self.output
      }
    }
  }
}
