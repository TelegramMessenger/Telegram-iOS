# CaseIterable

A parser that consumes a case-iterable, raw representable value from the beginning of a string.

Given a type that conforms to `CaseIterable` and `RawRepresentable` with a `RawValue` of `String`
or `Int`, we can incrementally parse a value of it.

Notably, raw enumerations that conform to `CaseIterable` meet this criteria, so cases of the
following type can be parsed with no extra work:

```swift
enum Role: String, CaseIterable {
  case admin
  case guest
  case member
}

try Parse {
  Int.parser()
  ","
  Role.parser()
}
.parse("123,member") // (123, .member)
```

This also works with raw enumerations that are backed by integers:

```swift
enum Role: Int, CaseIterable {
  case admin = 1
  case guest = 2
  case member = 3
}

try Parse {
  Int.parser()
  ","
  Role.parser()
}
.parse("123,1") // (123, .admin)
```

The `parser()` method on `CaseIterable` is overloaded to work on a variety of string representations
in order to be as efficient as possible, including `Substring`, `UTF8View`, and more general
collections of UTF-8 code units (see <doc:StringAbstractions> for more info).

Typically Swift can choose the correct overload by using type inference based on what other parsers
you are combining `parser()` with. For example, if you use `Role.parser()` with a
`Substring` parser, like the literal "," parser in the above examples, Swift
will choose the overload that works on substrings.

On the other hand, if `Role.parser()` is used in a context where the input type cannot be inferred,
then you will get an compiler error:

```swift
let parser = Parse {
  Int.parser()
  Role.parser() // 🛑 Ambiguous use of 'parser(of:)'
}

try parser.parse("123member")
```

To fix this you can force one of the parsers to be the `Substring` parser, and then the
other will figure it out via type inference:

```swift
let parser = Parse {
  Int.parser(of: Substring.self)
  Role.parser()
}

try parser.parse("123member") // (123, .member)
