# Accessibility changelog

## Unreleased — VoiceOver-fixes

- Added navigable chat history scrolling, localized scroll feedback, and an accessible jump-to-latest control.
- Preserved message focus by stable `MessageId` after history transactions.
- Improved input-field hit testing, frame updates, and focus behavior.
- Unified message renderer labels, values, hints, traits, delivery/playback states, reply semantics, and custom actions.
- Added stable accessibility identifiers for message renderers.
- Improved selection states, disabled-limit explanations, and focus persistence across selection updates.
- Improved Share Extension mode semantics, recipients, search, topics, initial focus, Escape, error handling, and modal containment.
- Improved Peer Info, Gifts, contacts, global search, attachment search, and sticker search semantics and stable focus restoration.
- Added accessible gift context actions and non-drag reorder alternatives.
- Added modal containment, initial focus, Escape, and trigger-focus restoration to shared alerts, action sheets, context, peek, and pinch controllers.
- Added source-contract tests, an iOS accessibility-tree audit, a pull-request checklist, and a documented release gate.
- Added an initial accessibility-tree size budget, XCTest traversal time/memory metrics, and retained `.xcresult` performance evidence.
- Added opt-in populated-chat UI contracts for message names, stable identifiers, frames, and the input field hit target using `VOICEOVER_USE_EXISTING_DATA=1`.
- Expanded source contracts to cover media/reply/delivery/play states, history scrolling, selection limits, Share modes, Gifts actions, Dynamic Type, Reduce Motion, and Reduce Transparency.
- Scaled Rich Message Instant Page typography from the configured chat text size and included that size in the layout cache key.
- Added stable Voice Control targets for interactive Settings disclosure/action rows.
- Added opt-in Settings tree/memory and chat typing accessibility performance scenarios with retained measurements and blocking budgets.
