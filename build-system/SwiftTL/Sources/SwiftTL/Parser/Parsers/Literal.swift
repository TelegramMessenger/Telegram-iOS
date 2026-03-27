extension Array: Parser where Element: Equatable {
  @inlinable
  public func parse(_ input: inout ArraySlice<Element>) throws {
    guard input.starts(with: self) else {
      throw ParsingError.expectedInput(self.debugDescription, at: input)
    }
    input.removeFirst(self.count)
  }
}

extension String: Parser {
  @inlinable
  public func parse(_ input: inout Substring) throws {
    guard input.starts(with: self) else {
      throw ParsingError.expectedInput(self.debugDescription, at: input)
    }
    input.removeFirst(self.count)
  }
}

extension String.UnicodeScalarView: Parser {
  @inlinable
  public func parse(_ input: inout Substring.UnicodeScalarView) throws {
    guard input.starts(with: self) else {
      throw ParsingError.expectedInput(String(self).debugDescription, at: input)
    }
    input.removeFirst(self.count)
  }
}

extension String.UTF8View: Parser {
  @inlinable
  public func parse(_ input: inout Substring.UTF8View) throws {
    guard input.starts(with: self) else {
      throw ParsingError.expectedInput(String(self).debugDescription, at: input)
    }
    input.removeFirst(self.count)
  }
}
