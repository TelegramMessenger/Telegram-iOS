# Design

Learn how the library is designed, including its use of protocols, result builders and operators.

## Protocol

The design of the library is largely inspired by the Swift standard library and Apple's Combine
framework. A parser is represented as a protocol that many types conform to, and then parser
transformations (also known as "combinators") are methods that return concrete types conforming to
the parser protocol.

For example, to parse all the characters from the beginning of a substring until you encounter a
comma you can use the `Prefix` parser:

```swift
let parser = Prefix { $0 != "," }

var input = "Hello,World"[...]
try parser.parse(&input)  // "Hello"
input                     // ",World"
```

The type of this parser is:

```swift
Prefix<Substring>
```

We can `.map` on this parser in order to transform its output, which in this case is the string
"Hello":

```swift
let parser = Prefix { $0 != "," }
.map { $0 + "!!!" }

var input = "Hello,World"[...]
try parser.parse(&input)  // "Hello!!!"
input                     // ",World"
```

The type of this parser is now:

```swift
Parsers.Map<Prefix<Substring>, Substring>
```

Notice that the type of the parser encodes the operations that we performed. This adds a bit of
complexity when using these types, but comes with some performance benefits because Swift can
usually inline and optimize away the creation of those nested types.

## Result Builders

The library takes advantage of Swift's `@resultBuilder` feature to make constructing complex parsers
as fluent as possible, and should be reminiscent of how views are constructed in SwiftUI. The main
entry point into building a parser is the `Parse` builder:

```swift
Parse {

}
```

In this builder block you can specify parsers that will be run one after another. For example, if
you wanted to parse an integer, then a comma, and then a boolean from a string, you can simply do:

```swift
Parse {
  Int.parser()
  ","
  Bool.parser()
}
```

Note that the `String` type conforms to the ``Parser`` protocol, and represents a parser that
consumes that exact string from the beginning of an input if it matches, and otherwise fails.

Many of the parsers and operators that come with the library are configured with parser builders
to maximize readability of the parsers. For example, to parse accounting syntax of numbers, where
parenthesized numbers are negative, we can use the ``OneOf`` parser builder:

```swift
let digits = Prefix { $0 >= "0" && $0 <= "9" }.compactMap(Int.init)

let accountingNumber = OneOf {
  digits

  Parse {
    "("; digits; ")"
  }
  .map { -$0 }
}

try accountingNumber.parse("100")    // 100
try accountingNumber.parse("(100)")  // -100
```

## Operators

Parser operators (also called "combinators") are methods defined on the ``Parser`` protocol that
return a parser. For example, the ``Parser/map(_:)`` operator is a method that returns something
called a ``Parsers/Map``:

```swift
extension Parser {
  public func map<NewOutput>(
    _ transform: @escaping (Output) -> NewOutput
  ) -> Parsers.Map<Self, NewOutput> {
    .init(upstream: self, transform: transform)
  }
}
```

And ``Parsers/Map`` is a dedicated type that implements the logic of the map operation. In
particular, in runs the upstream parser and then transforms its output:

```swift
extension Parsers {
  public struct Map<Upstream: Parser, NewOutput>: Parser {
    public let upstream: Upstream
    public let transform: (Upstream.Output) -> NewOutput

    public func parse(_ input: inout Upstream.Input) rethrows -> NewOutput {
      self.transform(try self.upstream.parse(&input))
    }
  }
}
```

Types that conform to the ``Parser`` protocol but are not constructed directly, and instead are
constructed via operators, are housed in the ``Parsers`` type. It's just an empty enum that
serves as a namespace for such parsers.
