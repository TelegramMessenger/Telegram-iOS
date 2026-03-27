# Getting Started

Learn how to integrate Parsing into your project and write your first parser.

## Adding Parsing as a dependency

To use the Parsing library in a SwiftPM project, add it to the dependencies of your Package.swift
and specify the `Parsing` product in any targets that need access to the library:

```swift
let package = Package(
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.7.0"),
  ],
  targets: [
    .target(
      name: "<target-name>",
      dependencies: [.product(name: "Parsing", package: "swift-parsing")]
    )
  ]
)
```

## Your first parser

Suppose you have a string that holds some user data that you want to parse into an array of `User`s:

```swift
let input = """
  1,Blob,true
  2,Blob Jr.,false
  3,Blob Sr.,true
  """

struct User {
  var id: Int
  var name: String
  var isAdmin: Bool
}
```

A naive approach to this would be a nested use of `.split(separator:)`, and then a little bit of
extra work to convert strings into integers and booleans:

```swift
let users = input
  .split(separator: "\n")
  .compactMap { row -> User? in
    let fields = row.split(separator: ",")
    guard
      fields.count == 3,
      let id = Int(fields[0]),
      let isAdmin = Bool(String(fields[2]))
    else { return nil }

    return User(id: id, name: String(fields[1]), isAdmin: isAdmin)
  }
```

Not only is this code a little messy, but it is also inefficient since we are allocating arrays for
the `.split` and then just immediately throwing away those values.

It would be more straightforward and efficient to instead describe how to consume bits from the
beginning of the input and convert that into users. This is what this parser library excels at 😄.

We can start by describing what it means to parse a single row, first by parsing an integer off the
front of the string, and then parsing a comma. We can do this by using the ``Parse`` type, which acts
as an entry point into describing a list of parsers that you want to run one after the other to
consume from an input:

```swift
let user = Parse {
  Int.parser()
  ","
}
```

Already this can consume the leading integer and comma from the beginning of the input:

```swift
// Use a mutable substring to verify what is consumed
var input = input[...]

try user.parse(&input)  // 1
input                   // "Blob,true\n2,Blob Jr.,false\n3,Blob Sr.,true"
```

Next we want to take everything up until the next comma for the user's name, and then consume the
comma:

```swift
let user = Parse {
  Int.parser()
  ","
  Prefix { $0 != "," }
  ","
}
```

And then we want to take the boolean at the end of the row for the user's admin status:

```swift
let user = Parse {
  Int.parser()
  ","
  Prefix { $0 != "," }
  ","
  Bool.parser()
}
```

Currently this will parse a tuple `(Int, Substring, Bool)` from the input, and we can `.map` on
that to turn it into a `User`:

```swift
let user = Parse {
  Int.parser()
  ","
  Prefix { $0 != "," }
  ","
  Bool.parser()
}
.map { User(id: $0, name: String($1), isAdmin: $2) }
```

To make the data we are parsing to more prominent, we can instead pass the transform closure as the
first argument to `Parse`:

```swift
let user = Parse {
  User(id: $0, name: String($1), isAdmin: $2)
} with: {
  Int.parser()
  ","
  Prefix { $0 != "," }
  ","
  Bool.parser()
}
```

Or we can pass the `User` initializer to `Parse` in a point-free style by first transforming the
`Prefix` parser's output from a `Substring` to a `String`:

```swift
let user = Parse(User.init(id:name:isAdmin:)) {
  Int.parser()
  ","
  Prefix { $0 != "," }.map(String.init)
  ","
  Bool.parser()
}
```

That is enough to parse a single user from the input string, leaving behind a newline and the final
two users:

```swift
try user.parse(&input) // User(id: 1, name: "Blob", isAdmin: true)
input // "\n2,Blob Jr.,false\n3,Blob Sr.,true"
```

To parse multiple users from the input we can use the `Many` parser to run the user parser many
times:

```swift
let users = Many {
  user
} separator: {
  "\n"
}

try users.parse(&input) // [User(id: 1, name: "Blob", isAdmin: true), ...]
input // ""
```

Now this parser can process an entire document of users, and the code is simpler and more
straightforward than the version that uses `.split` and `.compactMap`.

Even better, it's more performant. We've written [benchmarks][benchmarks-readme] for these two
styles of parsing, and the `.split`-style of parsing is more than twice as slow:

```
name                             time        std        iterations
------------------------------------------------------------------
README Example.Parser: Substring 3426.000 ns ±  63.40 %     385395
README Example.Ad hoc            7631.000 ns ±  47.01 %     169332
```

Further, if you are willing write your parsers against `UTF8View` instead of `Substring`, you can
eke out even more performance, more than doubling the speed:

```
name                             time        std        iterations
------------------------------------------------------------------
README Example.Parser: Substring 3693.000 ns ±  81.76 %     349763
README Example.Parser: UTF8      1272.000 ns ± 128.16 %     999150
README Example.Ad hoc            8504.000 ns ±  59.59 %     151417
```

See the article <doc:StringAbstractions> for more info on how to write parsers against different
string abstraction levels.

We can also compare these times to a tool that Apple's Foundation gives us: `Scanner`. It's a type
that allows you to consume from the beginning of strings in order to produce values, and provides
a nicer API than using `.split`:

```swift
var users: [User] = []
while scanner.currentIndex != input.endIndex {
  guard
    let id = scanner.scanInt(),
    let _ = scanner.scanString(","),
    let name = scanner.scanUpToString(","),
    let _ = scanner.scanString(","),
    let isAdmin = scanner.scanBool()
  else { break }

  users.append(User(id: id, name: name, isAdmin: isAdmin))
  _ = scanner.scanString("\n")
}
```

However, the `Scanner` style of parsing is more than 5 times as slow as the substring parser written
written above, and more than 15 times slower than the UTF-8 parser:

```
name                             time         std        iterations
-------------------------------------------------------------------
README Example.Parser: Substring  3481.000 ns ±  65.04 %     376525
README Example.Parser: UTF8       1207.000 ns ± 110.96 %    1000000
README Example.Ad hoc             8029.000 ns ±  44.44 %     163719
README Example.Scanner           19786.000 ns ±  35.26 %      62125
```

Not only are parsers built with the library more succinct and many times more performant than ad hoc
parsers, but they can also be easier to evolve to accommodate more features. For example, right now
our parser does not work correctly when the user's name contains a comma, such as "Blob, Esq.":

```swift
try user.parse("1,Blob, Esq.,true")

// error: unexpected input
//  --> input:1:8
// 1 | 1,Blob, Esq.,true
//   |        ^ expected "true" or "false"
```

The problem is that we are using the comma as a reserved identifier for delineating between fields,
and so a field cannot contain a comma. We can enhance the CSV format to allow for quoting fields
so that they can contain quotes:

```
1,"Blob, Esq.",true
```

To parse quoted fields we can first try parsing a quote, then everything up to the next quote, and
then the trailing quote:

```swift
let quotedField = Parse {
  "\""
  Prefix { $0 != "\"" }
  "\""
}
```

And then to parse a field, in general, we can first try parsing a quoted field, and if that fails we
will just take everything until the next comma. We can do this using the ``OneOf`` parser, which
allows us to run multiple parsers on the same input, and it will take the first that succeeds:

```swift
let field = OneOf {
  quotedField
  Prefix { $0 != "," }
}
.map(String.init)
```

We can use this parser in the `user` parser, and now it properly handles quoted and non-quoted
fields:

```swift
let user = Parse(User.init) {
  Int.parser()
  ","
  field
  ","
  Bool.parser()
}

try user.parse("1,\"Blob, Esq.\",true") // User(id: 1, name: "Blob, Esq.", admin: true)
```

It was quite straightforward to improve the `user` parser to handle quoted fields. Doing the same
with our ad hoc `split`/`compactMap` parser, and even the `Scanner`-based parser, would be a lot
more difficult.

That's the basics of parsing a simple string format, but there's a lot more operators and tricks to
learn in order to performantly parse larger inputs. View the [benchmarks][benchmarks] for examples
of real-life parsing scenarios.

[benchmarks-readme]: https://github.com/pointfreeco/swift-parsing/blob/main/Sources/swift-parsing-benchmark/ReadmeExample.swift
[benchmarks]: https://github.com/pointfreeco/swift-parsing/tree/main/Sources/swift-parsing-benchmark
