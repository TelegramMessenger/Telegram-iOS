/// A parser that succeeds if the input is empty, and fails otherwise.
///
/// Useful as a final parser in a long sequence of parsers to guarantee that all input has been
/// consumed.
///
/// ```swift
/// let parser = Parse {
///   "Hello, "
///   Prefix { $0 != "!" }
///   "!"
///   End()  // NB: All input should be consumed.
/// }
///
/// var input = "Hello, Blob!"[...]
/// try parser.parse(&input)  // "Blob"
/// ```
///
/// This parser will fail if there are input elements that have not been consumed:
///
/// ```swift
/// input = "Hello, Blob!!"
/// try parser.parse(&input)
/// // error: unexpected input
/// //  --> input:1:13
/// // 1 | Hello, Blob!!
/// //   |             ^ expected end of input
/// ```
public struct End<Input: Collection>: Parser {
  @inlinable
  public init() {}

  @inlinable
  public func parse(_ input: inout Input) throws {
    guard input.isEmpty else {
      throw ParsingError.expectedInput("end of input", at: input)
    }
  }
}

extension End where Input == Substring {
  @_disfavoredOverload
  @inlinable
  public init() {}
}

/*extension End where Input == Substring.UTF8View {
  @_disfavoredOverload
  @inlinable
  public init() {}
}*/

extension Parsers {
  public typealias End = SwiftTL.End  // NB: Convenience type alias for discovery
}
