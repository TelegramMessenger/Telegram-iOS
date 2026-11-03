extension CaseIterable where Self: RawRepresentable, RawValue == Int {
  /// A parser that consumes a case-iterable, raw representable value from the beginning of a
  /// collection of a substring.
  ///
  /// See <doc:CaseIterable> for more info.
  ///
  /// - Parameter inputType: The `Substring` type. This parameter is included to mirror the
  ///   interface that parses any collection of UTF-8 code units.
  /// - Returns: A parser that consumes a case-iterable, raw representable value from the beginning
  ///   of a substring.
  @inlinable
  public static func parser(
    of inputType: Substring.Type = Substring.self
  ) -> Parsers.CaseIterableRawRepresentableParser<Substring, Self, String> {
    .init(toPrefix: { String($0) }, areEquivalent: ==)
  }

  /// A parser that consumes a case-iterable, raw representable value from the beginning of a
  /// collection of a substring's UTF-8 view.
  ///
  /// See <doc:CaseIterable> for more info.
  ///
  /// - Parameter inputType: The `Substring.UTF8View` type. This parameter is included to mirror the
  ///   interface that parses any collection of UTF-8 code units.
  /// - Returns: A parser that consumes a case-iterable, raw representable value from the beginning
  ///   of a substring's UTF-8 view.
  @inlinable
  public static func parser(
    of inputType: Substring.UTF8View.Type = Substring.UTF8View.self
  ) -> Parsers.CaseIterableRawRepresentableParser<Substring.UTF8View, Self, String.UTF8View> {
    .init(toPrefix: { String($0).utf8 }, areEquivalent: ==)
  }

  /// A parser that consumes a case-iterable, raw representable value from the beginning of a
  /// collection of UTF-8 code units.
  ///
  /// - Parameter inputType: The collection type of UTF-8 code units to parse.
  /// - Returns: A parser that consumes a case-iterable, raw representable value from the beginning
  ///   of a collection of UTF-8 code units.
  @inlinable
  public static func parser<Input>(
    of inputType: Input.Type = Input.self
  ) -> Parsers.CaseIterableRawRepresentableParser<Input, Self, String.UTF8View>
  where
    Input.SubSequence == Input,
    Input.Element == UTF8.CodeUnit
  {
    .init(toPrefix: { String($0).utf8 }, areEquivalent: ==)
  }
}

extension CaseIterable where Self: RawRepresentable, RawValue == String {
  /// A parser that consumes a case-iterable, raw representable value from the beginning of a
  /// collection of a substring.
  ///
  /// See <doc:CaseIterable> for more info.
  ///
  /// - Parameter inputType: The `Substring` type. This parameter is included to mirror the
  ///   interface that parses any collection of UTF-8 code units.
  /// - Returns: A parser that consumes a case-iterable, raw representable value from the beginning
  ///   of a substring.
  @inlinable
  public static func parser(
    of inputType: Substring.Type = Substring.self
  ) -> Parsers.CaseIterableRawRepresentableParser<Substring, Self, String> {
    .init(toPrefix: { $0 }, areEquivalent: ==)
  }

  /// A parser that consumes a case-iterable, raw representable value from the beginning of a
  /// collection of a substring's UTF-8 view.
  ///
  /// See <doc:CaseIterable> for more info.
  ///
  /// - Parameter inputType: The `Substring.UTF8View` type. This parameter is included to mirror the
  ///   interface that parses any collection of UTF-8 code units.
  /// - Returns: A parser that consumes a case-iterable, raw representable value from the beginning
  ///   of a substring's UTF-8 view.
  @inlinable
  public static func parser(
    of inputType: Substring.UTF8View.Type = Substring.UTF8View.self
  ) -> Parsers.CaseIterableRawRepresentableParser<Substring.UTF8View, Self, String.UTF8View> {
    .init(toPrefix: { $0.utf8 }, areEquivalent: ==)
  }

  /// A parser that consumes a case-iterable, raw representable value from the beginning of a
  /// collection of UTF-8 code units.
  ///
  /// - Parameter inputType: The collection type of UTF-8 code units to parse.
  /// - Returns: A parser that consumes a case-iterable, raw representable value from the beginning
  ///   of a collection of UTF-8 code units.
  @inlinable
  public static func parser<Input>(
    of inputType: Input.Type = Input.self
  ) -> Parsers.CaseIterableRawRepresentableParser<Input, Self, String.UTF8View>
  where
    Input.SubSequence == Input,
    Input.Element == UTF8.CodeUnit
  {
    .init(toPrefix: { $0.utf8 }, areEquivalent: ==)
  }
}

extension Parsers {
  public struct CaseIterableRawRepresentableParser<
    Input: Collection, Output: CaseIterable & RawRepresentable, Prefix: Collection
  >: Parser
  where
    Input.SubSequence == Input,
    Output.RawValue: Comparable,
    Prefix.Element == Input.Element
  {
    @usableFromInline
    let cases: [(case: Output, prefix: Prefix, count: Int)]

    @usableFromInline
    let areEquivalent: (Input.Element, Input.Element) -> Bool

    @usableFromInline
    init(
      toPrefix: @escaping (Output.RawValue) -> Prefix,
      areEquivalent: @escaping (Input.Element, Input.Element) -> Bool
    ) {
      self.areEquivalent = areEquivalent
      self.cases = Output.allCases
        .map {
          let prefix = toPrefix($0.rawValue)
          return ($0, prefix, prefix.count)
        }
        .sorted(by: { $0.count > $1.count })
    }

    @inlinable
    public func parse(_ input: inout Input) throws -> Output {
      for (`case`, prefix, count) in self.cases {
        if input.starts(with: prefix, by: self.areEquivalent) {
          input.removeFirst(count)
          return `case`
        }
      }
      throw ParsingError.expectedInput("case of \"\(Output.self)\"", at: input)
    }
  }
}
