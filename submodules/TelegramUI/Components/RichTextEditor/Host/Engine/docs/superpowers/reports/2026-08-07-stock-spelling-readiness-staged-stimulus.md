# Stock Spelling Readiness Staged Stimulus Report

## Outcome

The stock readiness gate now succeeds through UIKit's native continuous
spelling and marker-rendering pipeline. It departs `mispelled ` to start the
cold asynchronous checker, advances the main run loop within the caller's
existing timeout, then departs and measures `wrng ` at `{10,4}`.

The repair does not query or preheat the checker, synthesize annotations, or
add any production private API.

## TDD evidence

- `.spelling-readiness-staged-contract-red.xcresult`: the new contract failed
  because the prior probe left `mispelled ` and reported `mispelled/{0,9}`.
- `.spelling-readiness-staged-contract-green.xcresult`: the two-word stimulus
  contract passed after the minimal insertion and observation change.
- `.spelling-readiness-staged-geometry-red.xcresult`: the extended contract
  caught the old location-zero geometry assumption. The probe reported the
  second word but sampled document offsets `0...4`.
- `.spelling-readiness-staged-geometry-green.xcresult`: the public
  `firstRectForRange:` geometry for offsets `10...14` matched after converting
  both `wordRange.location` and `NSMaxRange(wordRange)`.

## Live UIKit evidence

The first live run, `.spelling-readiness-staged-live.xcresult`, proved that
UIKit had already attached temporary spelling attributes to `wrng`, but the
incorrect ROI produced zero marker pixels. After the geometry repair,
`.spelling-readiness-staged-live-green.xcresult` passed one test with zero
failures.

Its retained JSON reports:

- status: `ready`;
- current and editor input languages: `en-US`;
- continuous checking: enabled;
- measured word/range: `wrng`, `{10,4}`;
- temporary annotation: observed;
- first rectangle: `{82.3333, 7, 38.3333, 22}`;
- stable red marker pixels: `79`;
- elapsed probe time: `0.524` seconds.

The exported JSON, rendered editor image, and manifest are in
`.spelling-readiness-staged-live-green-attachments/`.

## Regression result

`.spelling-readiness-staged-final.xcresult` ran the complete
`IDSpellingReadinessProbeTests` class, including the previously excluded stock
environmental gate: 22 tests passed, zero failed, and zero skipped. XCTest test
time was 2.419 seconds. The command used `-parallel-testing-enabled NO` and
disabled diagnostics collection.

The final exact-tree verification bundle,
`.spelling-readiness-staged-verification.xcresult`, repeated the complete class:
22 tests passed with zero failures in 2.437 seconds.

## Scope

This pass changes only test support, its XCTest contract, and documentation.
Production editor source and the production private-API surface are unchanged.
