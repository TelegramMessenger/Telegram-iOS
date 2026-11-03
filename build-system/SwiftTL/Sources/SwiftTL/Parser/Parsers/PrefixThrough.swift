/// A parser that consumes a subsequence from the beginning of its input through a given sequence of
/// elements.
///
/// This parser is named after `Sequence.prefix(through:)`, and uses similar logic under the hood to
/// consume and return input through a particular subsequence.
///
/// ```swift
/// let lineParser = PrefixThrough("\n")
///
/// var input = "Hello\nworld\n"[...]
/// try line.parse(&input)  // "Hello\n"
/// input                   // "world\n"
/// ```
public struct PrefixThrough<Input: Collection>: Parser where Input.SubSequence == Input {
  public let possibleMatch: Input
  public let areEquivalent: (Input.Element, Input.Element) -> Bool

  @inlinable
  public init(
    _ possibleMatch: Input,
    by areEquivalent: @escaping (Input.Element, Input.Element) -> Bool
  ) {
    self.possibleMatch = possibleMatch
    self.areEquivalent = areEquivalent
  }

  @inlinable
  @inline(__always)
  public func parse(_ input: inout Input) throws -> Input {
    guard let first = self.possibleMatch.first else { return self.possibleMatch }
    let count = self.possibleMatch.count
    let original = input
    while let index = input.firstIndex(where: { self.areEquivalent(first, $0) }) {
      input = input[index...]
      if input.count >= count,
        zip(input[index...], self.possibleMatch).allSatisfy(self.areEquivalent)
      {
        let index = input.index(index, offsetBy: count)
        input = input[index...]
        return original[..<index]
      }
      input.removeFirst()
    }
    throw ParsingError.expectedInput("prefix through \(formatValue(self.possibleMatch))", at: input)
  }
}

extension PrefixThrough where Input.Element: Equatable {
  @inlinable
  public init(_ possibleMatch: Input) {
    self.init(possibleMatch, by: ==)
  }
}

extension PrefixThrough where Input == Substring {
  @_disfavoredOverload
  @inlinable
  public init(_ possibleMatch: String) {
    self.init(possibleMatch[...])
  }
}

extension PrefixThrough where Input == Substring.UTF8View {
  @_disfavoredOverload
  @inlinable
  public init(_ possibleMatch: String.UTF8View) {
    self.init(String(possibleMatch)[...].utf8)
  }
}

extension Parsers {
  public typealias PrefixThrough = SwiftTL.PrefixThrough  // NB: Convenience type alias for discovery
}
