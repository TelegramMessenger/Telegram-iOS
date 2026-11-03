/// A parser that attempts to run a number of parsers till one succeeds.
///
/// Use this parser to list out a number of parsers in a ``OneOfBuilder`` result builder block.
///
/// The following example uses ``OneOf`` to parse an enum value. To do so, it spells out a list of
/// parsers to `OneOf`, one for each case:
///
/// ```swift
/// enum Currency { case eur, gbp, usd }
///
/// let currency = OneOf {
///   "€".map { Currency.eur }
///   "£".map { Currency.gbp }
///   "$".map { Currency.usd }
/// }
/// ```
///
/// This parser fails if every parser inside fails:
///
/// ```swift
/// var input = "London, Hello!"[...]
/// try OneOf { "New York"; "Berlin" }.parse(&input)
///
/// // error: multiple failures occurred
/// //
/// // error: unexpected input
/// //  --> input:1:1
/// // 1 | London, Hello!
/// //   | ^ expected "New York"
/// //   | ^ expected "Berlin"
/// ```
///
/// If you are parsing input that should coalesce into some default, avoid using a final ``Always``
/// parser, and instead opt for a trailing ``replaceError(with:)``, which returns a parser that
/// cannot fail:
///
/// ```swift
/// enum Currency { case eur, gbp, usd, unknown }
///
/// let currency = OneOf {
///   "€".map { Currency.eur }
///   "£".map { Currency.gbp }
///   "$".map { Currency.usd }
/// }
/// .replaceError(with: Currency.unknown)
///
/// currency.parse("$")  // Currency.usd
/// currency.parse("฿")  // Currency.unknown
/// ```
///
/// ## Specificity
///
/// The order of the parsers in the above ``OneOf`` does not matter because each of "€", "£" and "$"
/// are mutually exclusive, i.e. at most one will succeed on any given input.
///
/// However, that is not always true, and when the parsers are not mutually exclusive (i.e. multiple
/// can succeed on a given input) you must order them from most specific to least specific. That is,
/// the first parser should succeed on the fewest number of inputs and the last parser should
/// succeed on the most number of inputs.
///
/// For example, suppose you wanted to parse a simple CSV format into a doubly-nested array of
/// strings, and the fields in the CSV are allowed to contain commas themselves as long as they
/// are quoted:
///
/// ```swift
/// let input = #"""
/// lastName,firstName
/// McBlob,Blob
/// "McBlob, Esq.",Blob Jr.
/// "McBlob, MD",Blob Sr.
/// """#
/// ```
///
/// Here we have a list of last and first names separated by a comma, and some of the last names are
/// quoted because they contain commas.
///
/// In order to safely parse this we must first try parsing a field as a quoted field, and then only
/// if that fails we can parse a plain field that takes everything up until the next comma or
/// newline:
///
/// ```swift
/// let quotedField = Parse {
///   "\""
///   Prefix { $0 != "\"" }
///   "\""
/// }
/// let plainField = Prefix { $0 != "," && $0 != "\n" }
///
/// let field = OneOf {
///   quotedField
///   plainField
/// }
/// ```
///
/// Then we can parse many fields to form an array of fields making up a line, and then parse many
/// lines to make up a full, doubly-nested array for the CSV:
///
/// ```swift
/// let line = Many { field } separator: { "," }
/// let csv = Many { line } separator: { "\n" }
/// ```
///
/// Running this parser on the input shows that it properly isolates each field of the CSV, even
/// fields that are quoted and contain a comma:
///
/// ```swift
/// XCTAssertEqual(
///   try csv.parse(input),
///   [
///     ["lastName", "firstName"],
///     ["McBlob", "Blob"],
///     ["McBlob, Esq.", "Blob Jr."],
///     ["McBlob, MD", "Blob Sr."],
///   ]
/// )
/// // ✅
/// ```
///
/// The reason this parser works is because the `quotedField` and `plainField` parsers are listed in
/// a very specific order inside the `OneOf`:
///
/// ```swift
/// let field = OneOf {
///   quotedField
///   plainField
/// }
/// ```
///
/// The `quotedField` parser is a _more_ specific parser in that it will succeed on fewer inputs
/// than the `plainField` parser does. For example:
///
/// ```swift
/// try quotedField.parse("Blob Jr.") // ❌
/// try plainField.parse("Blob Jr.")  // ✅
/// ```
///
/// Whereas the `plainField` parser will happily succeed on anything the `quotedField` parser will
/// succeed on:
///
/// ```swift
/// try quotedField.parse("\"Blob, Esq\"") // ✅
/// try plainField.parse("\"Blob, Esq\"")  // ✅
/// ```
///
/// For this reason the `quotedField` parser must be listed first so that it can try its logic
/// first, which succeeds less frequently, before then trying the `plainField` parser, which
/// succeeds more often.
///
/// ## Backtracking
///
/// The ``OneOf`` parser is the primary tool for introducing backtracking into your parsers,
/// which means to undo the consumption of a parser when it fails. For more information, see the
/// article <doc:Backtracking>.
public struct OneOf<Parsers>: Parser where Parsers: Parser {
  public let parsers: Parsers

  @inlinable
  public init(@OneOfBuilder _ build: () -> Parsers) {
    self.parsers = build()
  }

  @inlinable
  public func parse(_ input: inout Parsers.Input) rethrows -> Parsers.Output {
    try self.parsers.parse(&input)
  }
}
