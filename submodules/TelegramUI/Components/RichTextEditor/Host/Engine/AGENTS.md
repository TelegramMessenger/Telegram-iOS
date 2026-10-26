# Repository instructions

## Xcode simulator testing

- Always disable parallel simulator testing.
- Every `xcodebuild test` command targeting an iOS Simulator must include
  `-parallel-testing-enabled NO`.
- Do not run overlapping XCTest processes against the same simulator.
- Keep Xcode scheme test parallelization disabled when running tests from the
  Xcode UI.
