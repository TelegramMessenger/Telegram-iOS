/// A parser that always succeeds with the given value, and does not consume any input.
///
/// While not very useful on its own, the `Always` parser can be helpful when combined with other
/// parsers or operators.
///
/// When its `Output` is `Void`, it can be used as a "no-op" parser of sorts and be plugged into
/// other parser operations. For example, the ``Many`` parser can be configured with separator and
/// terminator parsers:
///
/// ```swift
/// Many {
///   Int.parser()
/// } separator: {
///   ","
/// } terminator: {
///   End()
/// }
/// ```
///
/// But also exposes initializers that omit these parsers when there is no separator or terminator
/// to be parsed:
///
/// ```swift
/// Many {
///   Prefix { $0 != "\n" }
///   "\n"
/// }
/// ```
///
/// To support this, `Many` plugs `Always<Input, Void>` into each omitted parser. As a simplified
/// example:
///
/// ```swift
/// struct Many<Element: Parser, Separator: Parser, Terminator: Parser>: Parser
/// where Separator.Input == Element.Input, Terminator.Input == Element.Input {
///   ...
/// }
///
/// extension Many where Separator == Always<Input, Void>, Terminator == Always<Input, Void> {
///   init(@ParserBuilder element: () -> Element) {
///     self.element = element()
///     self.separator = Always(())
///     self.terminator = Always(())
///   }
/// }
/// ```
///
/// This means the previous example is equivalent to:
///
/// ```swift
/// Many {
///   Prefix { $0 != "\n" }
///   "\n"
/// } separator: {
///   Always(())
/// } terminator: {
///   Always(())
/// }
/// ```
///
/// > Note: While `Always` can be used as the last alternative of a ``OneOf`` to specify a default
/// > output, the resulting parser will be throwing. Instead, prefer ``Parser/replaceError(with:)``,
/// > which returns a non-throwing parser.
public struct Always<Input, Output>: Parser {
  public let output: Output

  @inlinable
  public init(_ output: Output) {
    self.output = output
  }

  @inlinable
  public func parse(_ input: inout Input) -> Output {
    self.output
  }

  @inlinable
  public func map<NewOutput>(
    _ transform: @escaping (Output) -> NewOutput
  ) -> Always<Input, NewOutput> {
    .init(transform(self.output))
  }
}

extension Always where Input == Substring {
  @inlinable
  public init(_ output: Output) {
    self.output = output
  }
}

extension Always where Input == Substring.UTF8View {
  @inlinable
  public init(_ output: Output) {
    self.output = output
  }
}

extension Parsers {
  public typealias Always = SwiftTL.Always  // NB: Convenience type alias for discovery
}
