import Foundation

extension CharacterSet: Parser {
  @inlinable
  public func parse(_ input: inout Substring) -> Substring {
    let output = input.unicodeScalars.prefix(while: self.contains)
    input.unicodeScalars.removeFirst(output.count)
    return Substring(output)
  }
}
