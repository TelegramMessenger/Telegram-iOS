extension Parser {
  /// Transforms the `Input` of a parser.
  ///
  /// This operator allows you to transform a parser of `Input`s into one on `NewInput`s, via a
  /// writable key path from `NewInput` to `Input`. Intuitively you can think of this as a way of
  /// transforming a parser on local data into one on more global data.
  ///
  /// For example, the parser `Int.parser()` parses `Substring.UTF8View` collections into integers,
  /// and there's a key path from `Substring.UTF8View` to `Substring`, and so we can `pullback`:
  ///
  /// ```swift
  /// var input = "123 Hello world"[...]
  /// let output = try Int.parser().pullback(\.utf8).parse(&input)  // 123
  /// input                                                         // " Hello world"
  /// ```
  ///
  /// This has allowed us to parse `Substring`s with something that is only defined on
  /// `Substring.UTF8View`.
  ///
  /// - Parameter keyPath: A key path to pull parsing back along from this parser's input to a new
  ///   input.
  /// - Returns: A parser that parses new input.
  @inlinable
  public func pullback<NewInput>(
    _ keyPath: WritableKeyPath<NewInput, Input>
  ) -> Parsers.Pullback<Self, NewInput> {
    .init(downstream: self, keyPath: keyPath)
  }
}

extension Parsers {
  /// Transforms the `Input` of a downstream parser.
  ///
  /// You will not typically need to interact with this type directly. Instead you will usually use
  /// the ``Parser/pullback(_:)`` operator, which constructs this type.
  public struct Pullback<Downstream: Parser, Input>: Parser {
    public let downstream: Downstream
    public let keyPath: WritableKeyPath<Input, Downstream.Input>

    @inlinable
    public init(downstream: Downstream, keyPath: WritableKeyPath<Input, Downstream.Input>) {
      self.downstream = downstream
      self.keyPath = keyPath
    }

    @inlinable
    public func parse(_ input: inout Input) rethrows -> Downstream.Output {
      try self.downstream.parse(&input[keyPath: self.keyPath])
    }

    @inlinable
    public func pullback<NewInput>(
      _ keyPath: WritableKeyPath<NewInput, Input>
    ) -> Pullback<Downstream, NewInput> {
      .init(downstream: self.downstream, keyPath: keyPath.appending(path: self.keyPath))
    }
  }
}
