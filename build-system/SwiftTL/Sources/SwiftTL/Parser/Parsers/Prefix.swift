/// A parser that consumes a subsequence from the beginning of its input.
///
/// This parser is named after `Sequence.prefix`, which it uses under the hood to consume a number
/// of elements and return them as output. It can be configured with minimum and maximum lengths,
/// as well as a predicate.
///
/// For example, to parse as many numbers off the beginning of a substring:
///
/// ```swift
/// var input = "123 hello world"[...]
/// try Prefix { $0.isNumber }.parse(&input)  // "123"
/// input                                     // " Hello world"
/// ```
///
/// If you wanted this parser to fail if _no_ numbers are consumed, you could introduce a minimum
/// length.
///
/// ```swift
/// var input = "No numbers here"[...]
/// try Prefix(1...) { $0.isNumber }.parse(&input)
/// // error: unexpected input
/// //  --> input:1:1
/// // 1 | No numbers here
/// //   | ^ expected 1 element satisfying predicate
/// ```
///
/// If a predicate is not provided, the parser will simply consume the prefix within the minimum and
/// maximum lengths provided:
///
/// ```swift
/// var input = "Lorem ipsum dolor"[...]
/// try Prefix(2).parse(&input)  // "Lo"
/// input                        // "rem ipsum dolor"
/// ```
public struct Prefix<Input: Collection>: Parser where Input.SubSequence == Input {
  public let maxLength: Int?
  public let minLength: Int
  public let predicate: ((Input.Element) -> Bool)?

  /// Initializes a parser that consumes a subsequence from the beginning of its input.
  ///
  /// - Parameters:
  ///   - minLength: The minimum number of elements to consume for parsing to be considered
  ///     successful.
  ///   - maxLength: The maximum number of elements to consume before the parser will return its
  ///     output.
  ///   - predicate: A closure that takes an element of the input sequence as its argument and
  ///     returns `true` if the element should be included or `false` if it should be excluded. Once
  ///     the predicate returns `false` it will not be called again.
  @inlinable
  public init(
    minLength: Int = 0,
    maxLength: Int? = nil,
    while predicate: @escaping (Input.Element) -> Bool
  ) {
    self.minLength = minLength
    self.maxLength = maxLength
    self.predicate = predicate
  }

  /// Initializes a parser that consumes a subsequence from the beginning of its input.
  ///
  /// ```swift
  /// try Prefix(2...4, while: \.isNumber).parse("123456")  // "1234"
  /// try Prefix(2...4, while: \.isNumber).parse("123")     // "123"
  ///
  /// try Prefix(2...4, while: \.isNumber).parse("1")
  /// // error: unexpected input
  /// //  --> input:1:1
  /// // 1 | 1
  /// //   |  ^ expected 1 more element satisfying predicate
  /// ```
  ///
  /// - Parameters:
  ///   - length: A closed range that provides a minimum number and maximum of elements to consume
  ///     for parsing to be considered successful.
  ///   - predicate: An optional closure that takes an element of the input sequence as its argument
  ///     and returns `true` if the element should be included or `false` if it should be excluded.
  ///     Once the predicate returns `false` it will not be called again.
  @inlinable
  public init(
    _ length: ClosedRange<Int>,
    while predicate: ((Input.Element) -> Bool)? = nil
  ) {
    self.minLength = length.lowerBound
    self.maxLength = length.upperBound
    self.predicate = predicate
  }

  /// Initializes a parser that consumes a subsequence from the beginning of its input.
  ///
  /// ```swift
  /// try Prefix(4, while: \.isNumber).parse("123456")  // "1234"
  ///
  /// try Prefix(4, while: \.isNumber).parse("123")
  /// // error: unexpected input
  /// //  --> input:1:1
  /// // 1 | 123
  /// //   |    ^ expected 1 more element satisfying predicate
  /// ```
  ///
  /// - Parameters:
  ///   - length: An exact number of elements to consume for parsing to be considered successful.
  ///   - predicate: An optional closure that takes an element of the input sequence as its argument
  ///     and returns `true` if the element should be included or `false` if it should be excluded.
  ///     Once the predicate returns `false` it will not be called again.
  @inlinable
  public init(
    _ length: Int,
    while predicate: ((Input.Element) -> Bool)? = nil
  ) {
    self.minLength = length
    self.maxLength = length
    self.predicate = predicate
  }

  /// Initializes a parser that consumes a subsequence from the beginning of its input.
  ///
  /// ``` swift
  /// try Prefix(4..., while: \.isNumber).parse("123456")  // "123456"
  ///
  /// try Prefix(4..., while: \.isNumber).parse("123")
  /// // error: unexpected input
  /// //  --> input:1:1
  /// // 1 | 123
  /// //   |    ^ expected 1 more element satisfying predicate
  /// ```
  ///
  /// - Parameters:
  ///   - length: A partial range that provides a minimum number of elements to consume for
  ///     parsing to be considered successful.
  ///   - predicate: An optional closure that takes an element of the input sequence as its argument
  ///     and returns `true` if the element should be included or `false` if it should be excluded.
  ///     Once the predicate returns `false` it will not be called again.
  @inlinable
  public init(
    _ length: PartialRangeFrom<Int>,
    while predicate: ((Input.Element) -> Bool)? = nil
  ) {
    self.minLength = length.lowerBound
    self.maxLength = nil
    self.predicate = predicate
  }

  /// Initializes a parser that consumes a subsequence from the beginning of its input.
  ///
  /// ```swift
  /// try Prefix(...4, while: \.isNumber).parse("123456")  // "1234"
  /// try Prefix(...4, while: \.isNumber).parse("123")     // "123"
  /// ```
  ///
  /// - Parameters:
  ///   - length: A partial, inclusive range that provides a maximum number of elements to consume.
  ///   - predicate: An optional closure that takes an element of the input sequence as its argument
  ///     and returns `true` if the element should be included or `false` if it should be excluded.
  ///     Once the predicate returns `false` it will not be called again.
  @inlinable
  public init(
    _ length: PartialRangeThrough<Int>,
    while predicate: ((Input.Element) -> Bool)? = nil
  ) {
    self.minLength = 0
    self.maxLength = length.upperBound
    self.predicate = predicate
  }

  @inlinable
  @inline(__always)
  public func parse(_ input: inout Input) throws -> Input {
    var prefix = maxLength.map(input.prefix) ?? input
    prefix = predicate.map { prefix.prefix(while: $0) } ?? prefix
    let count = prefix.count
    input.removeFirst(count)
    guard count >= self.minLength else {
      let atLeast = self.minLength - count
      throw ParsingError.expectedInput(
        """
        \(self.minLength - count) \(count == 0 ? "" : "more ")element\(atLeast == 1 ? "" : "s")\
        \(predicate == nil ? "" : " satisfying predicate")
        """,
        at: input
      )
    }
    return prefix
  }
}

extension Prefix where Input == Substring {
  @_disfavoredOverload
  @inlinable
  public init(
    minLength: Int = 0,
    maxLength: Int? = nil,
    while predicate: @escaping (Input.Element) -> Bool
  ) {
    self.init(minLength: minLength, maxLength: maxLength, while: predicate)
  }

  @_disfavoredOverload
  @inlinable
  public init(
    _ length: ClosedRange<Int>,
    while predicate: ((Input.Element) -> Bool)? = nil
  ) {
    self.init(length, while: predicate)
  }

  @_disfavoredOverload
  @inlinable
  public init(
    _ length: Int,
    while predicate: ((Input.Element) -> Bool)? = nil
  ) {
    self.init(length, while: predicate)
  }

  @_disfavoredOverload
  @inlinable
  public init(
    _ length: PartialRangeFrom<Int>,
    while predicate: ((Input.Element) -> Bool)? = nil
  ) {
    self.init(length, while: predicate)
  }

  @_disfavoredOverload
  @inlinable
  public init(
    _ length: PartialRangeThrough<Int>,
    while predicate: ((Input.Element) -> Bool)? = nil
  ) {
    self.init(length, while: predicate)
  }
}

extension Prefix where Input == Substring.UTF8View {
  @_disfavoredOverload
  @inlinable
  public init(
    minLength: Int = 0,
    maxLength: Int? = nil,
    while predicate: @escaping (Input.Element) -> Bool
  ) {
    self.init(minLength: minLength, maxLength: maxLength, while: predicate)
  }

  @_disfavoredOverload
  @inlinable
  public init(
    _ length: ClosedRange<Int>,
    while predicate: ((Input.Element) -> Bool)? = nil
  ) {
    self.init(length, while: predicate)
  }

  @_disfavoredOverload
  @inlinable
  public init(
    _ length: Int,
    while predicate: ((Input.Element) -> Bool)? = nil
  ) {
    self.init(length, while: predicate)
  }

  @_disfavoredOverload
  @inlinable
  public init(
    _ length: PartialRangeFrom<Int>,
    while predicate: ((Input.Element) -> Bool)? = nil
  ) {
    self.init(length, while: predicate)
  }

  @_disfavoredOverload
  @inlinable
  public init(
    _ length: PartialRangeThrough<Int>,
    while predicate: ((Input.Element) -> Bool)? = nil
  ) {
    self.init(length, while: predicate)
  }
}

extension Parsers {
  public typealias Prefix = SwiftTL.Prefix  // NB: Convenience type alias for discovery
}
