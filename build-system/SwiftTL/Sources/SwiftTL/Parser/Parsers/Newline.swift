/// A parser that consumes a single newline from the beginning of the input.
///
/// - Note: This parser only consumes a line feed (`"\n"`) or a carriage returns with line feed
///   (`"\r\n"`). If you need richer support that covers all unicode newline characters, use a
///   ``Prefix`` parser that operates on the `Substring` level with a predicate that consumes a
///   single newline:
///
///   ```swift
///   Prefix(1) { $0.isNewline }
///   ```
/// It will consume both line feeds (`"\n"`) and carriage returns with line feeds (`"\r\n"`).
public struct Newline<Input: Collection, Bytes: Collection>: Parser
where
  Input.SubSequence == Input,
  Bytes.SubSequence == Bytes,
  Bytes.Element == UTF8.CodeUnit
{
  @usableFromInline
  let toBytes: (Input) -> Bytes

  @usableFromInline
  let fromBytes: (Bytes) -> Input

  @inlinable
  public func parse(_ input: inout Input) throws {
    var bytes = self.toBytes(input)
    if bytes.first == .init(ascii: "\n") {
      bytes.removeFirst()
    } else if bytes.first == .init(ascii: "\r"), bytes.dropFirst().first == .init(ascii: "\n") {
      bytes.removeFirst(2)
    } else {
      throw ParsingError.expectedInput(#""\n" or "\r\n""#, at: input)
    }
    input = self.fromBytes(bytes)
  }
}

// NB: Swift 5.5.2 on Linux and Windows fails to build with a simpler `Bytes == Input` constraint
extension Newline where Bytes == Input.SubSequence, Bytes.SubSequence == Input {
  @inlinable
  public init() {
    self.toBytes = { $0 }
    self.fromBytes = { $0 }
  }
}

extension Newline where Input == Substring, Bytes == Substring.UTF8View {
  @_disfavoredOverload
  @inlinable
  public init() {
    self.toBytes = { $0.utf8 }
    self.fromBytes = Substring.init
  }
}

extension Newline where Input == Substring.UTF8View, Bytes == Input {
  @_disfavoredOverload
  @inlinable
  public init() { self.init() }
}

extension Newline where Input == ArraySlice<UTF8.CodeUnit>, Bytes == Input {
  @_disfavoredOverload
  @inlinable
  public init() { self.init() }
}

extension Parsers {
  public typealias Newline = SwiftTL.Newline  // NB: Convenience type alias for discovery
}
