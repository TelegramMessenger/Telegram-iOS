# UUID

A parser that consumes a `UUID` value from the beginning of a string.

For example:

```swift
try Parse {
  UUID.parser()
  ","
  Bool.parser()
}
.parse("deadbeef-dead-beef-dead-beefdeadbeef,true")
// (DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF, true)
```
