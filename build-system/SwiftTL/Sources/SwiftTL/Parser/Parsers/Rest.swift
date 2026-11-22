/// A parser that consumes everything to the end of the collection and returns this subsequence as
/// its output.
///
/// ```swift
/// var input = "Hello"[...]
/// Rest().parse(&input)  // "Hello"
/// input                 // ""
/// ```
///
/// This parser fails if there is no input to consume:
///
/// ```swift
/// try Rest().parse("")
///
/// /// error: unexpected input
/// ///  --> input:1:1
/// /// 1 |
/// ///   | ^ expected a non-empty input
/// ```
///
/// If you want to allow for the possibility of an empty remaining input you can use the
/// ``Optionally`` parser to parse an optional output value, or the ``replaceError(with:)`` method
/// to coalesce the error into a default output value.
public struct Rest<Input: Collection>: Parser where Input.SubSequence == Input {
  @inlinable
  public init() {}

  @inlinable
  public func parse(_ input: inout Input) throws -> Input {
    guard !input.isEmpty
    else { throw ParsingError.expectedInput("a non-empty input", at: input) }
    let output = input
    input.removeFirst(input.count)
    return output
  }
}

extension Rest where Input == Substring {
  @_disfavoredOverload
  @inlinable
  public init() {}
}

extension Rest where Input == Substring.UTF8View {
  @_disfavoredOverload
  @inlinable
  public init() {}
}

extension Parsers {
  public typealias Rest = SwiftTL.Rest  // NB: Convenience type alias for discovery
}
