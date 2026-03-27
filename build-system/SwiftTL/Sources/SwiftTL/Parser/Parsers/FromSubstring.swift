/// A parser that transforms a parser on `Substring` into a parser on another view.
///
/// The `FromSubstring` operator allows you to mix and match representation levels of strings
/// so that you can maximize how much you parse on the faster, but more complex, lower level
/// representations and then switch to slower, but safer, higher level representations for
/// when you need that power.
///
/// For example, to parse "café" as a collection of UTF8 code units you must be careful to parse
/// both representations of "é":
///
/// ```swift
/// OneOf {
///   "caf\u{00E9}".utf8   // LATIN SMALL LETTER E WITH ACUTE
///   "cafe\u{0301}".utf8  // E + COMBINING ACUTE ACCENT
/// }
/// ```
///
/// Alternatively, you can parse the ASCII characters of "caf" as UTF8 code units, and then
/// switch to the higher level substring representation to parse "é" so that you don't have
/// to worry about UTF8 normalization:
///
/// ```swift
/// Parse {
///   "caf".utf8
///
///   // Parse any recognized "é" character, including:
///   //   - LATIN SMALL LETTER E WITH ACUTE ("\u{00E9}")
///   //   - E + COMBINING ACUTE ACCENT ("e\u{0301}")
///   FromSubstring { "é" }
/// }
/// ```
public struct FromSubstring<Input, SubstringParser: Parser>: Parser
where SubstringParser.Input == Substring {
  public let substringParser: SubstringParser
  public let toSubstring: (Input) -> Substring
  public let fromSubstring: (Substring) -> Input

  @inlinable
  public func parse(_ input: inout Input) rethrows -> SubstringParser.Output {
    var substring = self.toSubstring(input)
    defer { input = self.fromSubstring(substring) }
    return try self.substringParser.parse(&substring)
  }
}

extension FromSubstring where Input == ArraySlice<UInt8> {
  @inlinable
  public init(@ParserBuilder _ build: () -> SubstringParser) {
    self.substringParser = build()
    self.toSubstring = { Substring(decoding: $0, as: UTF8.self) }
    self.fromSubstring = { ArraySlice($0.utf8) }
  }
}

extension FromSubstring where Input == Substring.UnicodeScalarView {
  @_disfavoredOverload
  @inlinable
  public init(@ParserBuilder _ build: () -> SubstringParser) {
    self.substringParser = build()
    self.toSubstring = Substring.init
    self.fromSubstring = \.unicodeScalars
  }
}

extension FromSubstring where Input == Substring.UTF8View {
  @inlinable
  public init(@ParserBuilder _ build: () -> SubstringParser) {
    self.substringParser = build()
    self.toSubstring = Substring.init
    self.fromSubstring = \.utf8
  }
}
