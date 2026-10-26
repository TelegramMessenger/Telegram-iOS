# Verification Stabilization Report

## Outcome

The continuation pass is green on the pinned iOS 26.5 simulator
(`FA6F7462-AA97-42FE-9E57-8DA0593CE756`, build `23F73`). It repaired the
staged spelling-readiness contract, stabilized the empty-document typing and
host-lifecycle contracts, and added an explicit stock/custom mixed-BiDi launch
boundary. It did not withdraw `customRenderController`.

The broad evidence is:

| Gate | Result | Artifact |
| --- | ---: | --- |
| staged stock spelling readiness | ready on attempt 1 | `.verification-stabilization-continuation-spelling/spelling-preflight-attempt-1/classification.json` |
| spelling family | 5 passed, 0 failed/skipped | `.verification-stabilization-continuation-spelling/spelling-family/result-metadata.json` |
| complete unit target | 967 passed, 0 failed/skipped | `.verification-stabilization-continuation-all-units-final.xcresult` |
| combined selection consumers, confirmation | 15 passed, 0 failed/skipped | `.verification-stabilization-continuation-consumers-final.xcresult` |
| fast semantic suite | 269 passed, 0 failed/skipped | `.verification-stabilization-continuation-fast-final/summary.json` |
| callback-authority units | 113 passed, 0 failed/skipped | `.verification-stabilization-continuation-authority.xcresult` |
| callback-authority UI batches | 2 passed, 0 failed/skipped | `.verification-stabilization-continuation-authority-ui.xcresult` |
| optimized Release | build succeeded | `.verification-stabilization-continuation-release-derived-final` |

Every simulator XCTest invocation was serialized through the repository lock
and used `-parallel-testing-enabled NO`. No simulator was created, cloned,
erased, or rebooted, and no keyboard-learning database was modified.

## Stock spelling readiness and recovery accounting

The strict coordinator contract now matches the staged stock stimulus:
`wrng` at canonical range `{10,4}`. The retired `mispelled/{0,9}` observation
is explicitly rejected. The ready observation reported:

- `currentPrimaryLanguage == inputPrimaryLanguage == en-US`;
- continuous checking enabled;
- a temporary spelling annotation;
- marker pixel count `79` in the staged ROI;
- elapsed time `0.526` seconds.

The coordinator classified the first preflight attempt as `ready`, then ran
the exact five-method spelling family. Recovery accounting is therefore one
preflight attempt, zero service restarts, and zero semantic retries. No custom
spelling implementation or synthesized underline was added.

## Non-spelling repairs

Configured typing defaults previously stopped at the document defaults while
an already-created empty layout block retained stale attributes. Default
mutation now produces a real `IDBlockDocumentChange`, updates affected empty
blocks and the revision, notifies observers, and is reconciled by
`IDBlockTextView` before the text-attribute transform. The existing contract
that a `nil` document change does not overwrite derived content remains intact.
Replacement also removes keys inherited from the preceding defaults while
preserving separator attributes whose values were block-specific overrides.

The stock oracle source audit found private input-mode selection through
Objective-C messaging. The oracle now chooses an English-US mode only through
public `UITextInputMode.activeInputModes` and retains `reloadInputViews`.
The 269-test fast semantic suite passed after this removal.

The regular-iPad regression was made order-sensitive: it constructs and fully
tears down a compact host before creating a regular host with explicit trait
overrides. The regular editor remains reachable and preserves the existing
height contract.

## Mixed-BiDi and host lifecycle boundary

The demo and stock oracle now publish the same ten-field geometry boundary:
bundle identifier, launch arguments, locale identifier, primary language,
first-responder state, selection, affinity, base writing direction, scenario,
and role. UI tests terminate both app hosts at setup, teardown, and every
launch helper boundary.

The first large-document-plus-BiDi combined attempt reported one range
mismatch before enhanced range diagnostics were installed. The exact BiDi
test then passed in isolation, the same two-test predecessor order passed, and
two subsequent full 15-consumer runs passed. No caret-navigation production
code was changed; the evidence supports transient host state as the failure,
and the new boundary makes a recurrence diagnosable rather than silently
retrying it.

## Callback-authority correction

The first authority command used two stale plan selectors ending in
`CompiledWithdrawal`. It executed all 113 selected unit tests but discovered
zero UI methods, so it was not counted as UI evidence. The executable plan was
corrected to the implemented `ReducedPrivateSurface` names and both actual UI
batches were rebuilt and executed successfully. No zero-test result is treated
as a pass in the final accounting.

## Release and private inventory

The optimized simulator binary contains exactly this block-host method among
the five selection-container candidates:

```text
-[IDBlockTextView(PrivateInteractionCallbacks) selectionContainerView]
```

It does not contain the other four category methods and contains no
`ID_WITHDRAW_`, `IDInteractionWithdrawnCallbackName`, or temporary-runner
string. The protected inventories are `127` production capability members,
`53` production reference-only members, and `24` test-only members.

Recorded Git object hashes are:

```text
d2143fb0a8d056793885a4a1ea117d93a83fff59  UIKitBehaviorContracts-iOS26.5.json
bca0b918c3d6f490772834379244a78f682d94c0  UIKitBehaviorTestOnlyContracts-iOS26.5.json
2224141b035c9ce344df8ff1021f53254a2722b5  IDBlockTextView+PrivateInteractionCallbacks.m
1e8932f895b1b34deaf62c282c979d30396f97e9  IDPrivateUIKit.h
99aeb4631c5cfaacb6e241b302fc7b65ea411e58  IDPrivateUIKit.m
1bd772ce241f64dbf012ad3d03b31a6950c0ed0a  IDPrivateUIKit+RichTextLayout.h
6195c21d8ee6293946de7e44d67edd27aae3c375  IDPrivateUIKit+RichTextLayout.m
86e2ace9c8a385d5f2009897b9dc0dfb61abbfc3  IDPrivateUIKit+TextLayoutCanvas.h
76fdd6e28dfbfa3e43fcd847e08dcefb217bf8a3  IDPrivateUIKit+TextLayoutCanvas.m
```

The production contract hash, and therefore its production and reference-only
surface, remains at the protected baseline. The current `IDPrivateUIKit.m`
hash includes the already-in-progress text-input-traits bridge; this
continuation did not expand that manifest.

## Generation and worktree hygiene

Two consecutive `xcodegen generate` runs produced project SHA-256
`0d899d8134f9dcd59fa86ce98314a752602cdd8b1839e82651df3d20a14ff462`.
The tracked project was clean before and after generation. `git diff --check`
passed and the index remained empty.

The shared exploration tree still contains extensive pre-existing tracked and
untracked work (1,856 porcelain entries at the final audit). Nothing was
cleaned, reset, staged, or committed by this pass.

## Remaining risks

- Private UIKit authorization remains specific to iOS 26.5/23F73; every new
  driver or runtime needs fresh ABI and behavioral characterization.
- The combined consumer gate is intentionally high fidelity and takes about
  seven minutes even with host isolation; it should remain a broad gate rather
  than the inner development loop.
- Public English-US input-mode selection passed the current semantic suite but
  remains dependent on installed system modes and must stay covered by the
  readiness coordinator.
- `customRenderController` still exists on `IDBlockTextView` and in the static
  interaction-host ABI even though the implementation returns `nil`.

## Next reduction

The next slice is true compile-time withdrawal of
`-[IDBlockTextView customRenderController]`, not runtime masking. It must keep
`_convertPointFromRenderSpace:` as an identity callback during initial
characterization, compare method absence and touch/loupe/floating/scroll
behavior against stock, and remove the matching interaction-host ABI entry
only after the absence build is green. The separate design is
`docs/superpowers/specs/2026-08-07-block-custom-render-controller-withdrawal-design.md`.
