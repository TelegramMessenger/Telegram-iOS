public struct FromUTF8View<Input, UTF8Parser: Parser>: Parser
where UTF8Parser.Input == Substring.UTF8View {
  public let utf8Parser: UTF8Parser
  public let toUTF8: (Input) -> Substring.UTF8View
  public let fromUTF8: (Substring.UTF8View) -> Input

  @inlinable
  public func parse(_ input: inout Input) rethrows -> UTF8Parser.Output {
    var utf8 = self.toUTF8(input)
    defer { input = self.fromUTF8(utf8) }
    return try self.utf8Parser.parse(&utf8)
  }
}

extension FromUTF8View where Input == Substring {
  @inlinable
  public init(@ParserBuilder _ build: () -> UTF8Parser) {
    self.utf8Parser = build()
    self.toUTF8 = \.utf8
    self.fromUTF8 = Substring.init
  }
}

extension FromUTF8View where Input == Substring.UnicodeScalarView {
  @_disfavoredOverload
  @inlinable
  public init(@ParserBuilder _ build: () -> UTF8Parser) {
    self.utf8Parser = build()
    self.toUTF8 = { Substring($0).utf8 }
    self.fromUTF8 = { Substring($0).unicodeScalars }
  }
}
