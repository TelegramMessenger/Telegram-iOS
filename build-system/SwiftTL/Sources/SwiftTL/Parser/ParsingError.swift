import Foundation

@usableFromInline
enum ParsingError: Error {
  case failed(String, Context)
  case manyFailed([Error], Context)

  @usableFromInline
  static func expectedInput(_ description: String, at remainingInput: Any) -> Self {
    .failed(
      summary: "unexpected input",
      label: "expected \(description)",
      at: remainingInput
    )
  }

  @usableFromInline
  static func expectedInput(
    _ description: String,
    from originalInput: Any,
    to remainingInput: Any
  ) -> Self {
    .failed(
      summary: "unexpected input",
      label: "expected \(description)",
      from: originalInput,
      to: remainingInput
    )
  }

  @usableFromInline
  static func failed(summary: String, label: String = "", at remainingInput: Any) -> Self {
    .failed(label, .init(remainingInput: remainingInput, debugDescription: summary))
  }

  @usableFromInline
  static func failed(
    summary: String, label: String = "", from originalInput: Any, to remainingInput: Any
  ) -> Self {
    .failed(
      label,
      .init(
        originalInput: originalInput,
        remainingInput: remainingInput,
        debugDescription: summary
      )
    )
  }

  @usableFromInline
  static func manyFailed(_ errors: [Error], at remainingInput: Any) -> Self {
    .manyFailed(errors, .init(remainingInput: remainingInput, debugDescription: ""))
  }

  @usableFromInline
  static func wrap(_ error: Error, at remainingInput: Any) -> Self {
    error as? ParsingError
      ?? .failed(
        "",
        .init(
          remainingInput: remainingInput,
          debugDescription: formatError(error),
          underlyingError: error
        )
      )
  }

  @usableFromInline
  func flattened() -> Self {
    func flatten(_ depth: Int = 0) -> (Error) -> [(depth: Int, error: Error)] {
      { error in
        switch error {
        case let ParsingError.manyFailed(errors, _):
          return errors.flatMap(flatten(depth + 1))
        default:
          return [(depth, error)]
        }
      }
    }

    switch self {
    case .failed:
      return self
    case let .manyFailed(errors, context):
      return .manyFailed(
        errors.flatMap(flatten())
          .sorted {
            switch ($0.error, $1.error) {
            case let (lhs as ParsingError, rhs as ParsingError):
              return lhs.context > rhs.context
            default:
              return $0.depth > $1.depth
            }
          }
          .map { $0.error },
        context
      )
    }
  }

  @usableFromInline
  var context: Context {
    switch self {
    case let .failed(_, context), let .manyFailed(_, context):
      return context
    }
  }

  @usableFromInline
  struct Context {
    @usableFromInline
    var debugDescription: String

    @usableFromInline
    var originalInput: Any

    @usableFromInline
    var remainingInput: Any

    @usableFromInline
    var underlyingError: Error?

    @usableFromInline
    init(
      originalInput: Any,
      remainingInput: Any,
      debugDescription: String,
      underlyingError: Error? = nil
    ) {
      self.originalInput = originalInput
      self.remainingInput = remainingInput
      self.debugDescription = debugDescription
      self.underlyingError = underlyingError
    }

    @usableFromInline
    init(
      remainingInput: Any,
      debugDescription: String,
      underlyingError: Error? = nil
    ) {
      self.originalInput = remainingInput
      self.remainingInput = remainingInput
      self.debugDescription = debugDescription
      self.underlyingError = underlyingError
    }
  }
}

extension ParsingError: CustomDebugStringConvertible {
  @usableFromInline
  var debugDescription: String {
    switch self.flattened() {
    case let .failed(label, context):
      return format(labels: [label], context: context)

    case let .manyFailed(errors, context) where errors.isEmpty:
      return format(labels: [""], context: context)

    case let .manyFailed(errors, _):
      return debugDescription(for: errors)
    }
  }

  fileprivate func debugDescription(for errors: [Error]) -> String {
    func failed(_ error: Error) -> (String, Context)? {
      guard
        let error = error as? ParsingError,
        case .failed(let label, let context) = error
      else { return nil }
      return (label, context)
    }

    var count = 0
    var description = ""

    func append(_ s: String) {
      count += 1
      if !description.isEmpty {
        description.append("\n\n")
      }
      description.append(s)
    }

    var errors = errors[...]
    while let error = errors.popFirst() {
      guard case .some((let firstLabel, let firstContext)) = failed(error) else {
        append(formatError(error))
        continue
      }

      var labels = [firstLabel]
      while case .some((let label, let context)) = errors.first.flatMap({ failed($0) }),
        firstContext.canGroup(with: context)
      {
        errors.removeFirst()
        labels.append(label)
      }

      append(format(labels: labels, context: firstContext))
    }

    if count != 1 {
      description = """
        error: multiple failures occurred

        \(description)
        """
    }

    return description
  }
}

extension ParsingError.Context {
  fileprivate func canGroup(with other: Self) -> Bool {
    func areSame(_ lhs: Any, _ rhs: Any) -> Bool {
      switch (normalize(lhs), normalize(rhs)) {
      case let (lhs as Substring, rhs as Substring):
        return lhs.startIndex == rhs.startIndex && lhs.endIndex == rhs.endIndex
      case let (lhs as Slice<[Substring]>, rhs as Slice<[Substring]>):
        return zip(lhs, rhs).allSatisfy { l, r in
          l.startIndex == r.startIndex && l.endIndex == r.endIndex
        }
      default:
        return false
      }
    }

    return
      (areSame(self.remainingInput, other.remainingInput)
      && areSame(self.originalInput, other.originalInput)
      && self.underlyingError == nil && other.underlyingError == nil)
  }
}

extension Array where Element == (label: String, context: ParsingError.Context) {
  fileprivate func allSame(_ keyPath: KeyPath<ParsingError.Context, Any>) -> Bool {
    guard let first = self.first else { return true }
    guard let firstValue = first.context[keyPath: keyPath] as? AnyHashable else { return false }
    return self.dropFirst().allSatisfy {
      guard let value = $0.context[keyPath: keyPath] as? AnyHashable else { return false }
      return value == firstValue
    }
  }
}

@usableFromInline
func format(labels: [String], context: ParsingError.Context) -> String {
  func formatHelp<Input>(from originalInput: Input, to remainingInput: Input) -> String {
    switch (normalize(originalInput), normalize(remainingInput)) {
    case let (originalInput as Substring, remainingInput as Substring):
      let substring =
        originalInput.startIndex == remainingInput.startIndex
        ? originalInput
        : originalInput.base[originalInput.startIndex..<remainingInput.startIndex]

      let position = substring.base[..<substring.startIndex].reduce(
        into: (0, 0)
      ) { (position: inout (line: Int, column: Int), character: Character) in
        if character.isNewline {
          position.line += 1
          position.column = 0
        } else {
          position.column += 1
        }
      }

      let through = substring.reduce(
        into: position
      ) { (position: inout (line: Int, column: Int), character: Character) in
        if character.isNewline {
          position.line += 1
          position.column = 0
        } else {
          position.column += 1
        }
      }

      let offset = min(position.column, 20)
      let selectedLine = substring.base[
        substring.base.index(substring.startIndex, offsetBy: -offset)...
      ]
      .prefix { !$0.isNewline }
      let isStartTruncated = offset != position.column
      var truncatedLine = selectedLine.prefix(79 - 4 - (isStartTruncated ? 1 : 0))
      let isEndTruncated = truncatedLine.endIndex != selectedLine.endIndex
      for index in truncatedLine.indices.reversed() {
        guard truncatedLine[index].isWhitespace
        else { break }
        truncatedLine.replaceSubrange(index...index, with: "␣")
      }

      let diagnostic =
        ("\(isStartTruncated ? "…" : "")\(truncatedLine)\(isEndTruncated ? "…" : "")\n"
          + labels.map { label in
            """
            \(String(repeating: " ", count: offset + (isStartTruncated ? 1 : 0)))\
            \(String(repeating: "^", count: max(1, substring.count)))\
            \(label.isEmpty ? "" : " \(label)")
            """
          }.joined(separator: "\n"))

      return formatError(
        summary: context.debugDescription,
        location: """
          input:\(position.line + 1):\(position.column + 1)\
          \(
            through.line == position.line
              ? (through.column <= position.column + 1 ? "" : "-\(through.column)")
              : "-\(through.line + 1):\(through.column + 1)")
          """,
        prefix: "\(position.line + 1)",
        diagnostic: diagnostic
      )

    case let (originalInput as Slice<[Substring]>, remainingInput as Slice<[Substring]>):
      let slice =
        originalInput.startIndex == remainingInput.startIndex
        ? originalInput
        : Slice(
          base: originalInput.base,
          bounds: originalInput.startIndex..<remainingInput.startIndex
        )

      let expectation: String
      if let error = context.underlyingError as? ParsingError,
        case let .failed(elementLabel, elementContext) = error,
        let originalInput = normalize(elementContext.originalInput) as? Substring,
        let remainingInput = normalize(elementContext.remainingInput) as? Substring
      {
        let substring =
          originalInput.startIndex == remainingInput.startIndex
          ? originalInput
          : originalInput.base[originalInput.startIndex..<remainingInput.startIndex]
        let indent = String(
          repeating: " ",
          count: substring.distance(
            from: substring.base.startIndex,
            to: substring.startIndex
          )
        )
        expectation = """
           \(indent)\(String(repeating: "^", count: max(1, substring.count)))\
          \(elementLabel.isEmpty ? "" : " \(elementLabel)")
          """
      } else {
        let count = slice.map(formatValue).joined(separator: ", ").count
        expectation = labels.map { label in
          """
          \(String(repeating: "^", count: max(1, count)))\(label.isEmpty ? "" : " \(label)")
          """
        }.joined(separator: "\n")
      }

      let indent = slice.base[..<slice.startIndex].map { "\(formatValue($0.base)), " }.joined()
      return formatError(
        summary: context.debugDescription,
        location: "input[\(slice.startIndex)]",
        prefix: "\(slice.startIndex)",
        diagnostic: """
          \(slice.base)
          \(String(repeating: " ", count: indent.count + 1))\(expectation)
          """
      )

    default:
      return "error: \(context.debugDescription)"
    }
  }

  return formatHelp(from: context.originalInput, to: context.remainingInput)
}

private func formatError(_ error: Error) -> String {
  switch error {
  case let error as ParsingError:
    return error.debugDescription

  case let error as LocalizedError:
    return error.localizedDescription

  default:
    return "\(error)"
  }
}

@usableFromInline
func formatValue<Input>(
  _ input: Input
) -> String {
  switch input {
  case let input as String:
    return input.debugDescription

  case let input as String.UnicodeScalarView:
    return String(input).debugDescription

  case let input as String.UTF8View:
    return String(input).debugDescription

  case let input as Substring:
    return input.debugDescription

  case let input as Substring.UnicodeScalarView:
    return Substring(input).debugDescription

  case let input as Substring.UTF8View:
    return Substring(input).debugDescription

  default:
    return "\(input)"
  }
}

private func formatError(
  summary: String,
  location: String,
  prefix: String,
  diagnostic: String
) -> String {
  let indent = String(repeating: " ", count: prefix.count)
  var diagnostic =
    diagnostic
    .split(separator: "\n", omittingEmptySubsequences: false)
    .map { "\(indent) |\($0.isEmpty ? "" : " \($0)")" }
    .joined(separator: "\n")
  diagnostic.replaceSubrange(..<indent.endIndex, with: prefix)
  return """
    error: \(summary)
    \(indent)--> \(location)
    \(diagnostic)
    """
}

extension ParsingError.Context {
  fileprivate static func > (lhs: Self, rhs: Self) -> Bool {
    switch (normalize(lhs.remainingInput), normalize(rhs.remainingInput)) {
    case let (lhsInput as Substring, rhsInput as Substring):
      return lhsInput.endIndex > rhsInput.endIndex

    case let (lhsInput as Slice<[Substring]>, rhsInput as Slice<[Substring]>):
      guard lhsInput.endIndex != rhsInput.endIndex else {
        switch (lhs.underlyingError, rhs.underlyingError) {
        case let (lhs as ParsingError, rhs as ParsingError):
          return lhs.context > rhs.context
        case (is ParsingError, _):
          return true
        default:
          return false
        }
      }
      return lhsInput.endIndex > rhsInput.endIndex

    default:
      return false
    }
  }
}

private func normalize(_ input: Any) -> Any {
  // TODO: Use `_openExistential` for `C: Collection where C == C.SubSequence` for index juggling?
  switch input {
  case let input as Substring:
    // NB: We want to ensure we are sliced at a character boundary and not a scalar boundary.
    let startIndex =
      input.startIndex == input.base.endIndex
      ? input.startIndex
      : input.base.indices.last { $0 <= input.startIndex } ?? input.startIndex
    let endIndex = input.endIndex == input.base.endIndex ? startIndex : input.endIndex

    return input.base[startIndex..<endIndex]

  case let input as Substring.UnicodeScalarView:
    return normalize(Substring(input))

  case let input as Substring.UTF8View:
    return normalize(Substring(input))

  case let input as Slice<[Substring]>:
    return input.endIndex == input.base.endIndex ? input[..<input.startIndex] : input

  default:
    return input
  }
}
