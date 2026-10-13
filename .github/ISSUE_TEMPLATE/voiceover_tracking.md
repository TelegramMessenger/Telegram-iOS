---
name: VoiceOver release tracking
about: Track VoiceOver verification, regressions, and release evidence
title: "VoiceOver release gate: <version or commit>"
labels: "a11y-voiceover,a11y-regression"
assignees: ""
---

## Scope

- Commit or tag:
- iOS versions:
- Devices and simulators:
- Locales:

## Automated gates

- [ ] VoiceOver source-contract tests pass.
- [ ] iOS 17+ XCTest accessibility-tree audit passes in required app states.
- [ ] Result logs and `.xcresult` are attached.

## Manual VoiceOver gate

- [ ] Chat history traversal and scrolling
- [ ] Jump to latest and input focus
- [ ] Message information, states, and custom actions
- [ ] Instant video and reply voice messages
- [ ] Selection flows and limit errors
- [ ] Share Extension
- [ ] Peer Info, Gifts, contacts, and searches
- [ ] Modal containment, Escape, and trigger-focus restoration
- [ ] Dynamic Type, Reduce Motion, and Voice Control

## Regressions

Link every regression to a dedicated issue and atomic fix commit. Apply the appropriate `a11y-focus`, `a11y-navigation`, `a11y-semantics`, or `a11y-regression` label.

## Release decision

- [ ] No release-blocking accessibility regressions remain.
- Decision and rationale:
