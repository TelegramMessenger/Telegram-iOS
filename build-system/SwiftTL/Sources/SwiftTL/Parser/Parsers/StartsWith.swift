/// A parser that parses a sequence of elements from its input.
///
/// This parser is named after `Sequence.starts(with:)`, and tests that the input it is parsing
/// starts with a given subsequence by calling this method under the hood.
///
/// If `true`, it consumes this prefix and returns `Void`:
///
/// ```swift
/// var input = "Hello, Blob!"[...]
///
/// StartsWith("Hello, ").parse(&input)  // ()
/// input                                // "Blob!"
/// ```
///
/// If `false`, it fails and leaves input intact:
///
/// ```swift
/// var input = "Goodnight, Blob!"[...]
/// try StartsWith("Hello, ").parse(&input)
/// // error: unexpected input
/// //  --> input:1:1
/// // 1 | Goodnight, Blob!
/// //   | ^ expected "Hello, "
/// ```
///
/// This parser returns `Void` and _not_ the sequence of elements it consumes because the sequence
/// is already known at the time the parser is created (it is the value quite literally passed to
/// ``StartsWith/init(_:)``).
///
/// In many circumstances you can omit the `StartsWith` parser entirely and just use the collection
/// as the parser. For example:
///
/// ```swift
/// var input = "Hello, Blob!"[...]
///
/// try "Hello, ".parse(&input)  // ()
/// input                        // "Blob!"
/// ```
public struct StartsWith<Input: Collection>: Parser where Input.SubSequence == Input {
  public let count: Int
  public let possiblePrefix: AnyCollection<Input.Element>
  public let startsWith: (Input) -> Bool

  /// Initializes a parser that successfully returns `Void` when the initial elements of its input
  /// are equivalent to the elements in another sequence, using the given predicate as the
  /// equivalence test.
  ///
  /// - Parameters:
  ///   - possiblePrefix: A sequence to compare to the start of an input sequence.
  ///   - areEquivalent: A predicate that returns `true` if its two arguments are equivalent;
  ///     otherwise, `false`.
  @inlinable
  public init<PossiblePrefix>(
    _ possiblePrefix: PossiblePrefix,
    by areEquivalent: @escaping (Input.Element, Input.Element) -> Bool
  )
  where
    PossiblePrefix: Collection,
    PossiblePrefix.Element == Input.Element
  {
    self.count = possiblePrefix.count
    self.possiblePrefix = AnyCollection(possiblePrefix)
    self.startsWith = { input in input.starts(with: possiblePrefix, by: areEquivalent) }
  }

  @inlinable
  public func parse(_ input: inout Input) throws {
    guard self.startsWith(input) else {
      throw ParsingError.expectedInput(formatValue(self.possiblePrefix), at: input)
    }
    input.removeFirst(self.count)
  }
}

extension Parsers.StartsWith where Input.Element: Equatable {
  /// Initializes a parser that successfully returns `Void` when the initial elements of its input
  /// are equivalent to the elements in another sequence.
  ///
  /// - Parameter possiblePrefix: A sequence to compare to the start of an input sequence.
  @inlinable
  public init<PossiblePrefix>(_ possiblePrefix: PossiblePrefix)
  where
    PossiblePrefix: Collection,
    PossiblePrefix.Element == Input.Element
  {
    self.init(possiblePrefix, by: ==)
  }
}

extension Parsers {
  public typealias StartsWith = SwiftTL.StartsWith  // NB: Convenience type alias for discovery
}
