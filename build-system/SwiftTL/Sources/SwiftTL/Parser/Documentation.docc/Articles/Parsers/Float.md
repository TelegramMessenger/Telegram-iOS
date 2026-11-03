# Float

A parser that consumes a floating-point number from the beginning of a string.

Supports any type that conforms to `BinaryFloatingPoint` and `LosslessStringConvertible`. This
includes `Double`, `Float`, `Float16`, and `Float80`.

Parses the same format parsed by `LosslessStringConvertible.init(_:)` on `BinaryFloatingPoint`.

```swift
var input = "123.45 Hello world"[...]
try Double.parser().parse(&input)  // 123.45
input // " Hello world"

input = "-123. Hello world"[...]
try Double.parser().parse(&input)  // -123.0
input // " Hello world"


input = "123.123E+2 Hello world"[...]
try Double.parser().parse(&input)  // 12312.3
input // " Hello world"
```

The `parser()` static method is overloaded to work on a variety of string representations in order
to be as efficient as possible, including `Substring`, `UTF8View`, and generally collections of
UTF-8 code units (see <doc:StringAbstractions> for more info).

Typically Swift can choose the correct overload by using type inference based on what other parsers
you are combining `parser()` with. For example, if you use `Double.parser()` with a `Substring`
parser, say the literal `","` parser (see <doc:String> for more information), Swift will choose the
overload that works on substrings:

```swift
let parser = Parse {
  Double.parser()
  ","
  Double.parser()
}

try parser.parse("1,-2") // (1.0, -2.0)
```

On the other hand, if `Double.parser()` is used in a context where the input type cannot be
inferred, then you will get an compiler error:

```swift
let parser = Parse {
  Double.parser()
  Double.parser() // 🛑 Ambiguous use of 'parser(of:)'
}

try parser.parse(".1.2")
```

To fix this you can force one of the double parsers to be the `Substring` parser, and then the
other will figure it out via type inference:

```swift
let parser = Parse {
  Double.parser(of: Substring.self)
  Double.parser() // ✅
}

try parser.parse(".1.2") // (0.1, 0.2)
```
