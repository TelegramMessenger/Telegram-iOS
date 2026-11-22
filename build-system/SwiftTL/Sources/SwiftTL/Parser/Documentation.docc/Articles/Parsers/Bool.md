# Bool

A parser that consumes a Boolean value from the beginning of a string.

This parser only recognizes the literal `"true"` and `"false"` sequence of characters:

```swift
// Parses "true":
var input = "true Hello"[...]
try Bool.parser().parse(&input)  // true
input                            // " Hello"

// Parses "false":
input = "false Hello"[...]
try Bool.parser().parse(&input)  // false
input                            // " Hello"

// Otherwise fails:
input = "1 Hello"[...]
try Bool.parser().parse(&input)

// error: unexpected input
//  --> input:1:1
// 1 | 1 Hello
//     ^ expected "true" or "false"
```

The `Bool.parser()` method is overloaded to work on a variety of string representations in order
to be as efficient as possible, including `Substring`, `UTF8View`, and more general collections of
UTF-8 code units (see <doc:StringAbstractions> for more info).

Typically Swift can choose the correct overload by using type inference based on what other parsers
you are combining `Bool.parser()` with. For example, if you use `Bool.parser()` with a
`Substring` parser, say the literal `","` parser (see <doc:String> for more information), Swift
will choose the overload that works on substrings:

```swift
let parser = Parse {
  Bool.parser()
  ","
  Bool.parser()
}

try parser.parse("true,false") // (true, false)
```

On the other hand, if `Bool.parser()` is used in a context where the input type cannot be inferred,
then you will get an compiler error:

```swift
let parser = Parse {
  Bool.parser()
  Bool.parser() // 🛑 Ambiguous use of 'parser(of:)'
}

try parser.parse("truefalse")
```

To fix this you can force one of the boolean parsers to be the `Substring` parser, and then the
other will figure it out via type inference:

```swift
let parser = Parse {
  Bool.parser(of: Substring.self)
  Bool.parser() // ✅
}

try parser.parse("truefalse")
```
