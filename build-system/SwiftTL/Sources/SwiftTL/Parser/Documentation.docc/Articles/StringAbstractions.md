# String Abstractions

Learn how to write parsers on different levels of string abstractions, giving you the ability to
trade performance for correctness where needed.

## Levels of abstraction

The parsers in the library do not work on `String`s directly, and instead operate on _views_ into a
string, such as `Substring`, `UnicodeScalarView` and `UTF8View`. Each of these types represents a
particular kind of "view" into some subset of a string, which means they are cheap to copy around,
and it makes consuming elements from the beginning and end of the string very efficient since only
their start and end index need to be mutated to point to different parts of the string.

However, there are tradeoffs to using each type:

  * `Substring`, like `String`, is a collection of `Character`s, which are extended grapheme
    clusters that most closely represents a single visual character one can see on the screen. This
    type is easy to use and hides a lot of the complexities of UTF8 from you (such as multiple byte
    sequences that represent the same visual character), and as such it is less efficient to use.
    Its elements are variable width, which means scanning its elements is an O(n) operation.

  * `UnicodeScalarView` is a collection of unicode scalars represented by the `Unicode.Scalar` type.
    Unicode scalars are 21-bit, and so not variable width like `Substring`, which makes scanning
    `UnicodeScalarView`s more efficient, but at the cost of some additional complexity in the API.

    For example, complex elements that can be represented by a single `Character`, such as "🇺🇸",
    are represented by multiple `Unicode.Scalar` elements, "🇺" and "🇸". When put together they
    form the single extended grapheme cluster of the flag character.

    Further, some `Character`s have multiple representations as collections of unicode scalars. For
    example, an "e" with an accute accent only has one visual representation, yet there are two
    different sequences of unicode scalars that can represent that character:

    ```swift
    Array("é".unicodeScalars) // [233]
    Array("é".unicodeScalars) // [101, 769]
    ```

    You can't tell from looking at the character, but the first "é" is a single unicode scalar
    called a "LATIN SMALL LETTER E WITH ACUTE" and the second "é" is two scalars, one just a plain
    "e" and the second a "COMBINING ACUTE ACCENT". Importantly, these two accented e's are equal as
    `Character`s but unequal as `UnicodeScalarView`s:

    ```swift
    let e1 = "\u{00E9}"
    let e2 = "e\u{0301}"
    e1 == e2 // true
    e1.unicodeScalars.elementsEqual(e2.unicodeScalars) // false
    ```

    So, when parsing on the level of `UnicodeScalarView` you have to be aware of these subtleties in
    order to form a correct parser.

  * `UTF8View` is a collection of `Unicode.UTF8.CodeUnit`s, which is just a typealias for `UInt8`,
    _i.e._, a single byte. This is an even lower-level representation of strings than
    `UnicodeScalarView`, and scanning these collections is quite efficient, but at the cost of even
    more complexity.

    For example, the non-ASCII characters described above have an even more complex representation
    has UTF8 bytes:

    ```swift
    Array("é".utf8) // [195, 169]
    Array("é".utf8) // [101, 204, 129]
    Array("🇺🇸".utf8) // [240, 159, 135, 186, 240, 159, 135, 184]
    ```

  * There's even `ArraySlice<UInt8>`, which is just a raw collection of bytes. This can be even more
    efficient to parse than `UTF8View` because it does not require representing a valid UTF-8
    string, but then you have no guarantees that you can losslessly convert it back into a `String`.

## Mixing and matching abstraction levels

It is possible to plug together parsers that work on different abstraction levels so that you can
decide where you want to trade correctness for performance and vice-versa.

For example, suppose you have an enum representing a few cities that you want to parse a string
into:

```swift
enum City {
  case losAngeles
  case newYork
  case sanJose
}

let city = OneOf {
  "Los Angeles".map { City.losAngeles }
  "New York".map { City.newYork }
  "San José".map { City.sanJose }
}
```

For the most part this parser could work on the level of UTF-8 because it is mostly dealing with
plain ASCII characters for which there are not multiple ways of representing the same visual
character. The only exception is "San José", which has an accented "e" that can be represented
by two different sequences of bytes.

The `Substring` abstraction is hiding those details from us because this parser will happily parse
both representations of "San José" from a string:

```swift
city.parse("San Jos\u{00E9}")  // ✅
city.parse("San Jose\u{0301}") // ✅
```

But, if we naively convert this parser to work on the level of `UTF8View`:

```swift
let city = OneOf {
  "Los Angeles".utf8.map { City.losAngeles }
  "New York".utf8.map { City.newYork }
  "San José".utf8.map { City.sanJose }
}
```

We have accidentally introduced a bug into the parser in which it recognizes one version of
"San José", but not the other:

```swift
city.parse("San Jos\u{00E9}".utf8)  // ✅
city.parse("San Jose\u{0301}".utf8) // ❌
```

One way to fix this would be to add another case to the `OneOf` for this alternate representation
of "San José":

```swift
let city = OneOf {
  "Los Angeles".utf8.map { City.losAngeles }
  "New York".utf8.map { City.newYork }
  "San Jos\u{00E9}".utf8.map { City.sanJose }
  "San Jose\u{0301}".utf8.map { City.sanJose }
}

city.parse("San Jos\u{00E9}".utf8)  // ✅
city.parse("San Jose\u{0301}".utf8) // ✅
```

This does work, but you are now responsible for understanding the ins and outs of UTF-8
normalization. UTF-8 is incredibly complex and Swift does a lot of work to hide that complexity
from you.

However, there's no need to parse everything on the level of `Substring` just because this one
parser needs to. We can parse everything on the level of `UTF8View` and then parse just "San José"
on the level of `Substring`. We do this by using the ``FromSubstring`` parser, which allows us to
temporarily leave the `UTF8View` world to work in the `Substring` world:

```swift
let city = OneOf {
  "Los Angeles".utf8.map { City.losAngeles }
  "New York".utf8.map { City.newYork }
  FromSubstring { "San José" }.map { City.sanJose }
}

city.parse("San Jos\u{00E9}".utf8)  // ✅
city.parse("San Jose\u{0301}".utf8) // ✅
```

This will run the "San José" parser on the level of `Substring`, meaning it will handle all the
complexities of UTF8 normalization so that we don't have to think about it.

If we want to be _really_ pedantic we can even decide to parse only the "é" character on the
level of `Substring` and leave everything else to `UTF8View`:

```swift
let city = OneOf {
  "Los Angeles".utf8.map { City.losAngeles }
  "New York".utf8.map { City.newYork }
  Parse {
    "San Jos".utf8
    FromSubstring { "é" }
  }
  .map { City.sanJose }
}

city.parse("San Jos\u{00E9}".utf8)  // ✅
city.parse("San Jose\u{0301}".utf8) // ✅
```

We don't necessarily recommend being this pedantic in general, at least not without benchmarking to
make sure it is worth it. But it does demonstrate how you can be very precise with which abstraction
levels you want to work on.
