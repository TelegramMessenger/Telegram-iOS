## Summary

Describe the user-visible change and link the relevant issue.

## Verification

- [ ] The affected target builds successfully.
- [ ] The change was tested on a supported iOS version.
- [ ] `python3 -m unittest discover -s Tests/VoiceOverContracts -p "test_*.py" -v` passes.

## Accessibility

- [ ] Labels describe content without repeating the control role.
- [ ] Values expose selection, delivery, playback, loading, and disabled states.
- [ ] Hints describe the result of activation.
- [ ] VoiceOver focus survives updates by a stable domain identifier.
- [ ] Modal UI contains traversal, supports Escape, and restores trigger focus.
- [ ] Dynamic Type, Reduce Motion, and Voice Control were checked where applicable.
- [ ] Decorative or hidden views are excluded from the accessibility tree.
- [ ] The iOS 17+ XCTest accessibility-tree audit passes.
- [ ] Manual VoiceOver verification evidence is attached, or the reason it is not applicable is documented.
