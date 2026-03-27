# Error messages

Learn how the library reports parsing errors and how to integrate your own custom error messages
into parsers.

## Overview

When a parser fails it throws an error containing information about what went wrong. The actual
error thrown by the parsers shipped with this library is internal, and so it should be considered
opaque. To get a human-readable debug description of the error message you can stringify the error.
For  example, the following `UInt8` parser fails to parse a string that would cause it to overflow:

```swift
do {
  var input = "1234 Hello"[...]
  let number = try UInt8.parser().parse(&input))
} catch {
  print(error)

  // error: failed to process "UInt8"
  //  --> input:1:1-4
  // 1 | 1234 Hello
  //   | ^^^^ overflowed 255
}
```

When the ``OneOf`` parser is used and fails, there are multiple errors that can be shown. ``OneOf``
prioritizes the error messages based on which parser got the furthest along. For example, consider
a parser that can parse accounting style of numbers, i.e. plain numbers are considered positive
and numbers in parentheses are considered negative:

```swift
let digits = Prefix { $0 >= "0" && $0 <= "9" }.compactMap(Int.init)

let accountingNumber = OneOf {
  digits

  Parse {
    "("; digits; ")"
  }
  .map { -$0 }
}

try accountingNumber.parse("100")   // 100
try accountingNumber.parse("(100)") // -100
```

If we try parsing something erroneous, such as "(100]", we get multiple error messages, but the
second parser's error shows first since it was able to get the furthest:

```swift
do {
  try accountingNumber.parse("(100]")
} catch {
  print(error)

  // error: multiple failures occurred
  //
  // error: unexpected input
  //  --> input:1:5
  // 1 | (100]
  //   |     ^ expected ")"
  //
  // error: unexpected input
  //  --> input:1:1
  // 1 | (100]
  //   | ^ expected integer
}
```

## Improving error messages

The quality of error messages emitted by a parser can depend on the manner in which the parser was
constructed. Some parser operators are powerful and convenient, but can cause the quality of error
messaging to degrade.

For example, we could construct a parser that consumes a single uncommented line from an input
(_i.e._, a line that does not begin with "//") by using ``Parser/compactMap(_:)`` to check the line
for a  prefix:

```swift
let uncommentedLine = Prefix { $0 != "\n" }
  .compactMap { $0.starts(with: "//") ? nil : $0 }

try uncommentedLine.parse("// let x = 1")

// error: failed to process "Substring" from "// let x = 1"
//  --> input:1:1-12
// 1 | // let x = 1
//   | ^^^^^^^^^^^^
```

However, when this parser fails it can only highlight the entire line as having a problem because
it cannot know that the only thing that failed was that the first two characters were slashes.

We can rewrite this parser in a different, but equivalent, way by using the ``Not`` parser to first
confirm that the line does not begin with "//", and then consume the entire line:

```swift
let uncommentedLine = Parse {
  Not { "//" }
  Prefix { $0 != "\n" }
}

try uncommentedLine.parse("// let x = 1")

// error: unexpected input
//  --> input:1:1-2
// 1 | // let x = 1
//   | ^^ expected not to be processed
```

This provides better error messaging because ``Not`` knows exactly what matched that we did not want
to match, and so it can highlight those specific characters.

When using the `Many` parser you can improve error messaging by supplying a "terminator" parser,
which is an optional argument. The terminator parser is run after the element and separator
parsers have consumed as much as they can, and allows you to assert on exactly what is left
afterwards.

For example, if a parser is run on an input that has a typo in the last row of data, and a
terminator is not specified, the parser will succeed without consuming that last row and we won't
know what went wrong:

```swift
struct User {
  var id: Int
  var name: String
  var isAdmin: Bool
}

let user = Parse(User.init(id:name:isAdmin:)) {
  Int.parser()
  ","
  Prefix { $0 != "," }.map(String.init)
  ","
  Bool.parser()
}

let users = Many {
  user
} separator: {
  "\n"
}

var input = """
1,Blob,true
2,Blob Jr.,false
3,Blob Sr.,tru
"""[...]

let output = try users.parse(&input)
output.count // 2
input // "\n3,Blob Sr.,tru"
```

However, by adding a terminator to this `users` parser an error will be throw that points to the
exact spot where the typo occurred:

```swift
let users = Many {
  user
} separator: {
  "\n"
} terminator: {
  End()
}

let output = try users.parse(&input)

// error: unexpected input
//  --> input:3:11
// 3 | 3,Blob Jr,tru
//   |           ^ expected "true" or "false"
```

## Throwing your own errors

Although the error type thrown by the parsers that ship in this library is currently internal, and
so should be thought of as opaque, it is still possible to throw your own errors. Your errors will
automatically be reformatted and contextualized to show exactly where the error occurred.

For example, suppose we wanted a parser that only parsed the digits 0-9 from the beginning of a
string and transformed it into an integer. This is subtly different from `Int.parser()` which
supports negative numbers, exponential formatting, and more.

Constructing a `Digits` parser is easy enough, and we can introduce a custom struct error for
customizing the message displayed:

```swift
struct DigitsError: Error {
  let message = "Expected a prefix of digits 0-9"
}

struct Digits: Parser {
  func parse(_ input: inout Substring) throws -> Int {
    let digits = input.prefix { $0 >= "0" && $0 <= "9" }
    guard let output = Int(digits)
    else {
      throw DigitsError()
    }
    input.removeFirst(digits.count)
    return output
  }
}
```

If we swap out the `Int.parser()` for a `Digits` parser in `user`:

```swift
let user = Parse(User.init) {
  Digits()
  ","
  Prefix { $0 != "," }.map(String.init)
  ","
  Bool.parser()
}
```

And we introduce an incorrect value into the input:

```swift
let input = """
1,Blob,true
-2,Blob Jr.,false
3,Blob Sr.,true
"""[...]
```

Then when running the parser we get a nice error message that shows exactly what went wrong:

```swift
try user.parse(&input)

// error: DigitsError(message: "Expected a prefix of digits 0-9")
//  --> input:2:1
// 2 | -2,Blob Sr,false
//   | ^
```
