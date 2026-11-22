# Backtracking

Learn what backtracking is, how it affects the performance of your parsers, and how to avoid it when
unnecessary.

## Overview

Backtracking is the process of restoring an input to its original value when parsing fails. While it
can be very useful, backtracking can lead to more complicated parser logic than necessary, and
backtracking too often can lead to performance issues. For this reason, most parsers are not
required to backtrack, and can therefore fail _and_ still consume from the input.

The primary way to make use of backtracking in your parsers is through the ``OneOf`` parser, which
tries many parsers on an input and chooses the first that succeeds. This allows you to try many
parsers on the same input, regardless of how much each parser consumes:

```swift
enum Currency { case eur, gbp, usd }

let currency = OneOf {
  "€".map { Currency.eur }
  "£".map { Currency.gbp }
  "$".map { Currency.usd }
}
```

## When to backtrack in your parsers?

If you only use the parsers and operators that ship with this library, and in particular you do not
create custom conformances to the ``Parser`` protocol, then you never need to worry about explicitly
backtracking your input because it will be handled for you automatically. The primary way to allow
for backtracking is via the ``OneOf`` parser, but there are a few other parsers that also backtrack
internally.

One such example is the ``Optionally`` parser, which transforms any parser into one that cannot fail
by catching any thrown errors and returning `nil`:

```swift
let parser = Parse {
  "Hello,"
  Optionally { " "; Bool.parser() }
  " world!"
}

try parser.parse("Hello, world!")      // nil
try parser.parse("Hello, true world!") // true
```

If the parser captured inside ``Optionally`` fails then it backtracks the input to its state before
the parser ran. In particular, if the `Bool.parser()` fails then it will make sure to undo
consuming the leading space " " so that later parsers can try.

Another example of a parser that internally backtracks is the ``Parser/replaceError(with:)``
operator, which coalesces any error thrown by a parser into a default output value:

```swift
let parser = Parse {
  "Hello,"
  Optionally { " "; Bool.parser() }
    .replaceError(with: false)
  " world!"
}

try parser.parse("Hello, world!")      // false
try parser.parse("Hello, true world!") // true
```

It backtracks the input to its original value when the parser fails so that later parsers can try.

The only time you need to worry about explicitly backtracking input is when making your own
``Parser`` conformances. As a general rule of thumb, if your parser recovers from all failures
in the `parse` method then it should backtrack the input to its state before the error was thrown.
This is exactly how ``OneOf``, ``Optionally`` and ``Parser/replaceError(with:)`` work.

## Performance

If used naively, backtracking can lead to less performant parsing code. For example, if we wanted to
parse two integers from a string that were separated by either a dash "-" or slash "/", then we
could write this as:

```swift
OneOf {
  Parse { Int.parser(); "-"; Int.parser() } // 1️⃣
  Parse { Int.parser(); "/"; Int.parser() } // 2️⃣
}
```

However, parsing slash-separated integers is not going to be performant because it will first run
the entire 1️⃣ parser until it fails, then backtrack to the beginning, and run the 2️⃣ parser. In
particular, the first integer will get parsed twice, unnecessarily repeating that work.

On the  other hand, we can factor out the common work of the parser and localize the backtracking
``OneOf`` work to make a much more performant parser:

```swift
Parse {
  Int.parser()
  OneOf { "-"; "/" }
  Int.parser()
}
```

We can even write a benchmark to measure the performance difference:

```swift
let first = OneOf {
  Parse { Int.parser(); "-"; Int.parser() }
  Parse { Int.parser(); "/"; Int.parser() }
}
benchmark("First") {
  precondition(try! first.parse("100/200") == (100, 200))
}
let second = Parse {
  Int.parser()
  OneOf { "-"; "/" }
  Int.parser()
}
benchmark("Second") {
  precondition(try! second.parse("100/200") == (100, 200))
}
```

Running this produces the following results:

```
name   time        std        iterations
----------------------------------------
First  1500.000 ns ±  19.75 %     856753
Second  917.000 ns ±  15.89 %    1000000
```

The second parser takes only 60% of the time to run that the first parser does.
