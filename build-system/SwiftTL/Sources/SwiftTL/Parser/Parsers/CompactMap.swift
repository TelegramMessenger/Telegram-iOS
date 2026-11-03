extension Parser {
  /// Returns a parser that outputs the non-`nil` result of calling the given closure with the
  /// output of this parser.
  ///
  /// This method is similar to `Sequence.compactMap` in the Swift standard library, as well as
  /// `Publisher.compactMap` in the Combine framework.
  ///
  /// ```swift
  /// let evenParser = Int.parser().compactMap { $0.isMultiple(of: 2) }
  ///
  /// var input = "124 hello world"[...]
  /// try evenParser.parse(&input)  // 124
  /// input                         // " hello world"
  /// ```
  ///
  /// This parser fails when the provided closure returns `nil`. For example, the following parser tries
  /// to convert two characters into a hex digit, but fails to do so because `"GG"` is not a valid
  /// hex number:
  ///
  /// ```swift
  /// var input = "GG0000"[...]
  /// let hex = try Prefix(2).compactMap { Int(String($0), radix: 16) }.parse(&input)
  /// // error: failed to process "Int" from "GG"
  /// //  --> input:1:1-2
  /// // 1 | GG0000
  /// //   | ^^
  /// ```
  ///
  /// - Parameter transform: A closure that accepts output of this parser as its argument and
  ///   returns an optional value.
  /// - Returns: A parser that outputs the non-`nil` result of calling the given transformation
  ///   with the output of this parser.
  @_disfavoredOverload
  @inlinable
  public func compactMap<NewOutput>(
    _ transform: @escaping (Output) -> NewOutput?
  ) -> Parsers.CompactMap<Self, NewOutput> {
    .init(upstream: self, transform: transform)
  }
}

extension Parsers {
  /// A parser that outputs the non-`nil` result of calling the given transformation with the output
  /// of its upstream parser.
  ///
  /// You will not typically need to interact with this type directly. Instead you will usually use
  /// the ``Parser/compactMap(_:)`` operation, which constructs this type.
  public struct CompactMap<Upstream: Parser, Output>: Parser {
    public let upstream: Upstream
    public let transform: (Upstream.Output) -> Output?

    @inlinable
    public init(
      upstream: Upstream,
      transform: @escaping (Upstream.Output) -> Output?
    ) {
      self.upstream = upstream
      self.transform = transform
    }

    @inlinable
    public func parse(_ input: inout Upstream.Input) throws -> Output {
      let original = input
      let output = try self.upstream.parse(&input)
      guard let newOutput = self.transform(output)
      else {
        throw ParsingError.failed(
          summary: """
            failed to process "\(Output.self)" from \(formatValue(output))
            """,
          from: original,
          to: input
        )
      }
      return newOutput
    }
  }
}
