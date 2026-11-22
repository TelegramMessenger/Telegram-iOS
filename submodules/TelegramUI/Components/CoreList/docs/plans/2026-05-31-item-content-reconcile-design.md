# Item Content Reconciliation Design

**Status:** IMPLEMENTED / CURRENT

## Goal

When a stable item identity survives an `applyChanges(items:)` pass but its value changes, update
the existing view in place and remeasure it before final window construction. Content changes must
preserve view identity, participate in the same transaction as reorders and other mutations, and
compose through the granular property-animation model.

## Item contract

```swift
protocol CoreListItem: AnyObject {
    var identity: AnyHashable { get }
    func view() -> UIView & CoreListItemView
    func isEqual(to other: CoreListItem) -> Bool
    func apply(to view: UIView & CoreListItemView)
}
```

- `identity` describes stable identity and drives diff matching (survive / insert / delete / move)
  and the uniqueness invariant. It is the single source of identity — the engine compares `identity`
  directly, never a separate identity method.
- `isEqual(to:)` describes value/content equality for an already-identity-matched survivor.
- `apply(to:)` updates item-owned state on a reused view (default: no-op).
- `isEqual(to:)` has **no default**. Equality-by-identity is almost never correct in production, so
  every item states its content equality explicitly; an identity-only item opts in by comparing just
  its identity field(s).

> **History.** This originally had a separate `isEqual` (identity) + `isContentEqual` (content) pair,
> with `isContentEqual` defaulting to `isEqual`. Since every conformer implemented `isEqual` as plain
> identity equality — redundant with `identity` — the pair was collapsed (2026-07): `identity` drives
> matching; the surviving `isEqual` is the content check (formerly `isContentEqual`).

Identity and content equality are intentionally separate concerns. Rebuilding a view for a content-only
change would discard view-owned state and break stable animation ownership; applying unchanged
content on every pass could unnecessarily reset state the item does not own.

## Transaction flow

`CoreVirtualListView.applyChanges` computes the identity diff while the old item values and settled
window are still available. For each loaded survivor or move endpoint whose content differs:

1. reuse the existing physical view;
2. call the new item's `apply(to:)`;
3. measure the updated view at the transaction's final content width;
4. use that measurement while constructing the final settled window.

The content reconcile happens before render, so the final settled geometry already reflects the new
value. No second layout correction or asynchronous remeasurement is needed.

Rows outside the measured loaded window are not instantiated merely to reconcile content. When such
an identity later loads, normal view creation or reuse applies and measures its current item value.

## Geometry and animation

Content reconciliation does not own animation. The transaction writes the final settled frame, then
the existing granular rules compare each loaded survivor's old analytic presentation with its new
settled geometry:

- a changed vertical position starts or replaces only the additive position track;
- a changed width or height starts or replaces only that absolute extent track;
- an unchanged property is an exact no-op;
- a moved identity keeps its stable owner and view while all changed geometry properties compose
  independently;
- an inserted identity starts at complete final geometry and receives only its insertion opacity
  transition.

This makes a content-driven height change equivalent to any other measured height change. It composes
with reorder, viewport geometry, programmatic scrolling, crossing carries, and unrelated active
tracks without a content-specific animation path.

The view's `onContentDidChange` callback remains a separate input for view-initiated changes. It
coalesces dirty indices and re-enters `applyChanges`; item-value reconciliation and view-initiated
remeasurement therefore converge on the same settled-window and animation pipeline.

## View-owned state

`apply(to:)` transfers external item state. The view remains responsible for any internal state not
represented by the item, such as expanded/collapsed interaction state. A matched identity always
keeps its view instance, and `apply(to:)` is called only for a genuine external content change.

`DemoListItem` compares all item-owned fields in `isEqual(to:)` and updates the reused
`DemoListItemView` in `apply(to:)`. `DemoListItemView.update(width:)` then lays out its current
content and returns the measured height.

## Verification contract

The focused content tests cover:

- changed content reconfigures the same physical view;
- unchanged content does not call `apply(to:)`;
- protocol defaults preserve identity-only consumers;
- changed content remeasures at the final width;
- content-driven height changes animate through granular height and position tracks;
- move plus content/size change retains the moving view and composes its independent geometry;
- view-owned expansion survives unrelated item passes.

The implementation authority is `CoreVirtualListView.applyChanges` and the item protocols in
`CoreVirtualListView.swift`; `DemoRow.swift` is the production example consumer.
