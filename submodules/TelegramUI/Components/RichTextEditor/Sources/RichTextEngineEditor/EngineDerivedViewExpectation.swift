#if canImport(UIKit)
import Foundation
import RichTextEditorCore

/// What the current roles say must be DRAWN: one key set per view pool (derived-view completeness
/// spec §2.2).
///
/// Derived from the roles alone, and deliberately NOT from the sync passes that fill those pools.
/// Each sync computes its own `live` set and culls against it, so comparing a pool to that set agrees
/// with the producer by construction — including when the producer is wrong, which is exactly the
/// case this exists to catch: `syncTableChrome`'s `live` set is what omitted a table that was in the
/// document, in the roles, and drawn nowhere. **A check that shares the producer's derivation is not
/// a check** (§2.4) — the same reason `verifyPresentationIsDerived` re-renders every block from its
/// role rather than trusting what the bridge last wrote.
///
/// On KEYS, never on visibility (§2.3): a media host is HIDDEN when culled off-screen, not removed,
/// so the pools hold an entry for every live block either way.
///
/// **This type is a second source of truth about which roles own which views.** A new view pool
/// needs a field here or the check silently under-tests it; that entry is part of adding a pool, and
/// is listed with the other sites a new `EngineAncestor` case touches in the package `CLAUDE.md`.
@available(iOS 18.4, *)
internal struct EngineDerivedViewExpectation {
    /// Keys `tableGrids` AND `tableChromeViews`: a table needs both to appear at all.
    internal var tables: Set<BlockID> = []
    internal var detailsChevrons: Set<BlockID> = []
    internal var decorations: Set<BlockID> = []
    internal var listMarkers: Set<BlockID> = []
    /// Keys `buttonRowViews`. Unlike a media atom — deliberately absent, see below — a row's view is
    /// ENGINE-OWNED: no host provider can decline it and none can answer nil, so a `.buttonRow` role
    /// with no view is unambiguously a defect rather than a legitimate state.
    internal var buttonRows: Set<BlockID> = []
    /// Keys `collapsedQuoteViews`. ENGINE-owned like `buttonRows` and unlike a media atom: no host
    /// provider can decline it and none can answer nil, so a folded quote with no view is
    /// unambiguously a defect rather than a legitimate state.
    internal var collapsedQuotes: Set<BlockID> = []
    /// Keys `tableStructuralChromeViews` — but in the REVERSE direction from every other field here.
    ///
    /// Only ONE table has structural chrome at a time (the caret's, or the committed selection's), and
    /// which one is not visible in the roles — the same shape that keeps media atoms out of this
    /// struct. So this is the set of tables that MAY hold one, and `derivedViewShortfall` asks that no
    /// pooled view names anything else: a chrome view outliving its table is the checkable half, and
    /// "every table has one" would be false by construction.
    internal var structuralChrome: Set<BlockID> = []

    /// **Media atoms are deliberately NOT here**, and that is a finding rather than an omission: the
    /// check reported one on its first run and the reported thing was correct. A media host view is
    /// supplied by the HOST, and `syncMediaViews` legitimately creates none when there is no provider,
    /// when the provider answers nil ("ask again next pass"), or when the attachment frame is not yet
    /// ready. None of those is visible in the roles, so an expectation derived from roles alone can
    /// only guess — and a guess here traps during ordinary typing in a debug build, which is a worse
    /// failure than the one being guarded against and one this check would be causing rather than
    /// catching. The checkable half for media is the REVERSE direction (no pooled view outlives its
    /// atom), which is not this invariant.
    ///
    /// List markers need no such condition: a checklist falls back to Core's own glyph when the host
    /// supplies no checkbox, so a marker view always exists.
    internal init(roles: [EngineBlockRole]) {
        for role in roles {
            // Two sources, mirroring `syncContainerDecorations`: every ancestor draws a band — a
            // quote's fill, a details' hairline — and a leaf container draws its own.
            for ancestor in role.ancestry { decorations.insert(ancestor.id) }
            if ContainerDecorationKind(role) != nil { decorations.insert(role.containerID) }

            if let table = role.owningTable {
                tables.insert(table.id)
                structuralChrome.insert(table.id)
                // A cell owns nothing else: no marker (§2.2's first conditional — a list item in a
                // cell is deliberately unmarked, matching legacy's `stampListMarkers`), no atom, no
                // chevron.
                continue
            }
            if role.secondaryKind == .detailsTitle, let details = role.innermostAncestor?.details,
               details.id == role.containerID {
                detailsChevrons.insert(details.id)
            }
            if role.secondaryKind == nil, role.shape.paragraph?.list != nil {
                listMarkers.insert(role.blockID)
            }
            // After the cell `continue` above, deliberately: a row cannot BE in a cell — the bridge
            // drops it, because a cell is one inline text on the wire — so a cell never expects one.
            if let row = role.shape.buttonRowShape { buttonRows.insert(row.id) }
            if let quote = role.shape.collapsedQuote { collapsedQuotes.insert(quote.id) }
        }
    }
}
#endif
