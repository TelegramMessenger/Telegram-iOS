extension BinaryFloatingPoint where Self: LosslessStringConvertible {
  /// A parser that consumes a floating-point number from the beginning of a collection of UTF-8
  /// code units.
  ///
  /// See <doc:Float> for more information about this parser.
  ///
  /// - Parameter inputType: The collection type of UTF-8 code units to parse.
  /// - Returns: A parser that consumes a floating-point number from the beginning of a collection
  ///   of UTF-8 code units.
  @inlinable
  public static func parser<Input>(
    of inputType: Input.Type = Input.self
  ) -> Parsers.FloatParser<Input, Self> {
    .init()
  }

  /// A parser that consumes a floating-point number from the beginning of a substring's UTF-8 view.
  ///
  /// This overload is provided to allow the `Input` generic to be inferred when it is
  /// `Substring.UTF8View`.
  ///
  /// See <doc:Float> for more information about this parser.
  ///
  /// - Parameter inputType: The `Substring.UTF8View` type. This parameter is included to mirror the
  ///   interface that parses any collection of UTF-8 code units.
  /// - Returns: A parser that consumes a floating-point number from the beginning of a substring's
  ///   UTF-8 view.
  @_disfavoredOverload
  @inlinable
  public static func parser(
    of inputType: Substring.UTF8View.Type = Substring.UTF8View.self
  ) -> Parsers.FloatParser<Substring.UTF8View, Self> {
    .init()
  }

  /// A parser that consumes a floating-point number from the beginning of a substring.
  ///
  /// This overload is provided to allow the `Input` generic to be inferred when it is `Substring`.
  ///
  /// See <doc:Float> for more information about this parser.
  ///
  /// - Parameter inputType: The `Substring` type. This parameter is included to mirror the
  ///   interface that parses any collection of UTF-8 code units.
  /// - Returns: A parser that consumes a floating-point number from the beginning of a substring.
  @_disfavoredOverload
  @inlinable
  public static func parser(
    of inputType: Substring.Type = Substring.self
  ) -> FromUTF8View<Substring, Parsers.FloatParser<Substring.UTF8View, Self>> {
    .init { Parsers.FloatParser<Substring.UTF8View, Self>() }
  }
}

extension Parsers {
  /// A parser that consumes a floating-point number from the beginning of a collection of UTF-8
  /// code units.
  ///
  /// You will not typically need to interact with this type directly. Instead you will usually use
  /// the static `parser()` method on the `BinaryFloatingPoint` of your choice, e.g.,
  /// `Double.parser()`, `Float80.parser()`, etc., all of which construct this type.
  ///
  /// See <doc:Float> for more information about this parser.
  public struct FloatParser<Input: Collection, Output: BinaryFloatingPoint>: Parser
  where
    Input.SubSequence == Input,
    Input.Element == UTF8.CodeUnit,
    Output: LosslessStringConvertible
  {
    @inlinable
    public init() {}

    @inlinable
    public func parse(_ input: inout Input) throws -> Output {
      let original = input
      let s = input.parseFloat()
      guard let n = Output(String(decoding: s, as: UTF8.self))
      else {
        throw ParsingError.expectedInput("\(Output.self)".lowercased(), from: original, to: input)
      }
      return n
    }
  }
}

extension UTF8.CodeUnit {
  @usableFromInline
  var isDigit: Bool {
    (.init(ascii: "0") ... .init(ascii: "9")).contains(self)
  }

  @usableFromInline
  var isHexDigit: Bool {
    (.init(ascii: "0") ... .init(ascii: "9")).contains(self)
      || (.init(ascii: "a") ... .init(ascii: "f")).contains(self)
      || (.init(ascii: "A") ... .init(ascii: "F")).contains(self)
  }

  @usableFromInline
  var isSign: Bool {
    self == .init(ascii: "-") || self == .init(ascii: "+")
  }
}

extension Collection where SubSequence == Self, Element == UTF8.CodeUnit {
  @inlinable
  @inline(__always)
  mutating func parseFloat() -> SubSequence {
    let original = self
    if self.first?.isSign == true {
      self.removeFirst()
    }
    if self.first == .init(ascii: "0")
      && (self.dropFirst().first == .init(ascii: "x")
        || self.dropFirst().first == .init(ascii: "X"))
    {
      self.removeFirst(2)
      let integer = self.prefix(while: { $0.isHexDigit })
      self.removeFirst(integer.count)
      if self.first == .init(ascii: ".") {
        let fractional =
          self
          .dropFirst()
          .prefix(while: { $0.isHexDigit })
        self.removeFirst(1 + fractional.count)
      }
      if self.first == .init(ascii: "p") || self.first == .init(ascii: "P") {
        var n = 1
        if self.dropFirst().first?.isSign == true { n += 1 }
        let exponent =
          self
          .dropFirst(n)
          .prefix(while: { $0.isHexDigit })
        guard !exponent.isEmpty else { return original[..<self.startIndex] }
        self.removeFirst(n + exponent.count)
      }
    } else if self.first?.isDigit == true || self.first == .init(ascii: ".") {
      let integer = self.prefix(while: { $0.isDigit })
      self.removeFirst(integer.count)
      if self.first == .init(ascii: ".") {
        let fractional =
          self
          .dropFirst()
          .prefix(while: { $0.isDigit })
        self.removeFirst(1 + fractional.count)
      }
      if self.first == .init(ascii: "e") || self.first == .init(ascii: "E") {
        var n = 1
        if self.dropFirst().first?.isSign == true { n += 1 }
        let exponent =
          self
          .dropFirst(n)
          .prefix(while: { $0.isDigit })
        guard !exponent.isEmpty else { return original[..<self.startIndex] }
        self.removeFirst(n + exponent.count)
      }
    } else if self.prefix(8).caseInsensitiveElementsEqualLowercase("infinity".utf8) {
      self.removeFirst(8)
    } else if self.prefix(3).caseInsensitiveElementsEqualLowercase("inf".utf8)
      || self.prefix(3).caseInsensitiveElementsEqualLowercase("nan".utf8)
    {
      self.removeFirst(3)
    }
    return original[..<self.startIndex]
  }

  @inlinable
  @inline(__always)
  func caseInsensitiveElementsEqualLowercase<S: Sequence>(_ other: S) -> Bool
  where S.Element == Element {
    self.elementsEqual(other, by: { $0 == $1 || $0 + 32 == $1 })
  }
}
