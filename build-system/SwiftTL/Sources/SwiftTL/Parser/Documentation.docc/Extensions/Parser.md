# ``Parsing/Parser``

## Topics

### Diving deeper

* <doc:GettingStarted>
* <doc:Design>
* <doc:StringAbstractions>
* <doc:ErrorMessages>
* <doc:Backtracking>

### Running a parser

All of the ways to run a parser on an input.

- ``parse(_:)-717qw``
- ``parse(_:)-6h1d0``
- ``parse(_:)-2wzcq``

### Common parsers

Some of the most commonly used parsers in the library. Use these parsers with operators in order
to build complex parsers from simpler pieces.

- <doc:Int>
- <doc:String>
- <doc:Bool>
- <doc:Float>
- <doc:CharacterSet>
- <doc:UUID>
- <doc:CaseIterable>
- ``Parse``
- ``OneOf``
- ``Many``
- ``Prefix``
- ``PrefixThrough``
- ``PrefixUpTo``
- ``Optionally``
- ``Always``
- ``End``
- ``Rest``
- ``Fail``
- ``FromSubstring``
- ``FromUTF8View``
- ``FromUnicodeScalarView``
- ``First``
- ``Skip``
- ``Lazy``
- ``Newline``
- ``Whitespace``
- ``AnyParser``
- ``Peek``
- ``Not``
- ``StartsWith``
- ``Stream``

### Parser operators

- ``map(_:)``
- ``flatMap(_:)``
- ``compactMap(_:)``
- ``filter(_:)``
- ``pipe(_:)``
- ``pullback(_:)``
- ``replaceError(with:)``
- ``eraseToAnyParser()``
- ``pipe(_:)``
