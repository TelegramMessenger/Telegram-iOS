# String

A parser that consumes a string literal from the beginning of a string.

Many of Swift's string types conform to the ``Parser`` protocol, which allows you to use string types
directly in a parser. For example, to parse two integers separated by a comma we can do:

```swift
try Parse {
  Int.parser()
  ","
  Int.parser()
}
.parse("123,456") // (123, 456)
```

The string `","` acts as a parser that consumes a comma from the beginning of an input and fails
if the input does not start with a comma.

Swift's other string representations also conform to ``Parser``, such as `UnicodeScalarView`
and `UTF8View`. This allows you to consume strings from the beginning of an input in a more
efficient manner than is possible with `Substring` (see <doc:StringAbstractions> for more info).

For example, we can conver the above parser to work on the level of `UTF8View`s, which is a
collection of UTF-8 code units:

```swift
try Parse {
  Int.parser()
  ",".utf8
  Int.parser()
}
.parse("123,456") // (123, 456)
```

Here `",".utf8` is a `String.UTF8View`, which conforms to the ``Parser`` protocol. Also, by type
inference, Swift is choosing the overload of `Int.parser()` that now works on `UTF8View`s rather
than `Substring`s. See <doc:Int> for more info.
