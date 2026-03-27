# ``Parsing``

A library for turning nebulous data into well-structured data, with a focus on composition,
performance, generality, and ergonomics.

## Additional Resources

- [GitHub Repo](https://github.com/pointfreeco/swift-parsing/)
- [Discussions](https://github.com/pointfreeco/swift-parsing/discussions)
- [Point-Free Videos](https://www.pointfree.co/collections/parsing)

## Overview

Parsing with this library is performed by listing out many small parsers that describe how to
incrementally consume small bits from the beginning of an input string. For example, suppose you
have a string that holds some user data that you want to parse into an array of `User`s:

```swift
var input = """
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

A parser can be constructed for transforming the input string into an array of users in succinct
and fluent API:

```swift
let user = Parse(User.init) {
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
} terminator: {
  End()
}

try users.parse(input)  // [User(id: 1, name: "Blob", isAdmin: true), ...]
```

This says that to parse a user we:

* Parse and consume an integer from the beginning of the input
* then a comma
* then everything up to the next comma
* then another comma
* and finally a boolean.

And to parse an entire array of users we:

* Run the `user` parser many times
* between each invocation of `user` we run the separator parser to consume a newline
* and once the `user` and separator parsers have consumed all they can we run the terminator
parser to verify there is no more input to consume.

Further, if the input is malformed, like say we mistyped one of the booleans, then the parser emits
an error that describes exactly what went wrong:

```swift
var input = """
1,Blob,true
2,Blob Jr.,false
3,Blob Sr.,tru
"""

try users.parse(input)

// error: unexpected input
//  --> input:3:11
// 3 | 3,Blob Jr,tru
//   |           ^ expected "true" or "false"
```

That's the basics of parsing a simple string format, but there are a lot more operators and tricks
to learn in order to performantly parse larger inputs.

## Topics

### Articles

* <doc:GettingStarted>
* <doc:Design>
* <doc:StringAbstractions>
* <doc:ErrorMessages>
* <doc:Backtracking>

## See Also

The collecton of videos from [Point-Free](https://www.pointfree.co) that dive deep into the
development of the Parsing library.

* [Point-Free Videos](https://www.pointfree.co/collections/parsing)
