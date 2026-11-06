# Validation scope

- Tested implementation base: `5c20d095d1abe58fef9ced1a823c9b1fd3bc61a0`, Telegram 13.0.1, build 100044, Xcode 27.0, iPhone 18 Pro/iOS 27.0.
- Fresh run:97 unique AllMention XCTest methods,11 classes and 4 targets, 97 passed,0 failures,0 skips, result cache disabled. `results.json` lists every method; `test-plan.json` matches them to source.
- Full native application target on that tested base: passed. The18-second demo shows native permissions, suggestion, sending and the full effect. Mock state survived a normal relaunch.
- Proposed upstream base: `279f89e4d4f63f17227bf877dc3d8990f22ecd58`, Telegram 13.1.2, Xcode 27.1 required.
- Port validation: clean-index application and whitespace checks, Swift syntax parsing of all 79 feature Swift files, syntax of 19 strings files, decoding of both TGS assets and private preference-ID uniqueness passed.
- The upstream port has not been fully built/type-checked or regression-tested with Xcode 27.1. The97-test result belongs to the tested implementation base, not to that unbuilt port.
- Real account/server delivery, APNs, concurrent remote users, multi-device synchronization, physical-device frame pacing and manual VoiceOver speech/gestures are outside the offline demonstration.

All people and conversation data in the video are fictional. No API credentials, signing files, account stores, app binaries or build caches are part of the PR.
