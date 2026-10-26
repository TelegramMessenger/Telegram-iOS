#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextInputDecUpstream

/// Settle (surface-gate spec §3.2): after the controller's edit, in order — declare the blocks it
/// minted, fix author-line presence, register the replay snapshot, re-adopt typing attributes. Every
/// edit issued here is top-level; the controller is idle.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {
    internal func settleAfterEdit() {
        isSettling = true
        defer { isSettling = false }
        declareFreshBlocks()
        settleOrphanedSecondaryLines()
        settleDetailsWithoutTitle()
        settleDetailsWithoutBody()
        settleLanguageLinePresence()
        settleAuthorLinePresence()
        settleLineBreaksInOneLineFields()
        // Integrity FIRST: an atom whose attachment is gone is no longer a media block, and
        // presence must not hand it a caption line on the way past.
        settleMediaAtomIntegrity()
        settleButtonRowAtomIntegrity()
        settleCaptionLinePresence()
        normalisePresentation()
        engine.tgid_readoptEmptyBlockTypingAttributes()
        freshSinceSettle.removeAll()
        rolesBeforeEdit = nil
        structureTouchedThisEdit = false
        // The edit has fully landed, so this is the state a LATER edit returns to.
        commitUndoSnapshotAfterSettle()
        verifyPresentationIsDerived("settle")
    }

    /// A details whose span no longer holds its TITLE line is dissolved: its `.details` ancestor is
    /// taken out of every role that still carries it, so its remaining children become children of
    /// whatever held the details. A details always has exactly one title line (R7-details); a range
    /// that deletes it from outside — a paragraph through the title into the body, or through an
    /// outer details' title into a NESTED one's — used to leave the model a details with an empty
    /// title the engine had no line for, and every position after it disagreed (composer harness,
    /// 2026-09-24, fuzz seed 38; the single-paragraph body only "dissolved cleanly" because its one
    /// child merged into the survivor). Dissolving, not re-minting an empty title: the user's range
    /// took the title text, the same outcome the into-the-body case already had.
    internal func settleDetailsWithoutTitle() {
        var titled: Set<BlockID> = []
        var present: Set<BlockID> = []
        for role in currentRoles {
            if role.secondaryKind == .detailsTitle { titled.insert(role.containerID) }
            for ancestor in role.ancestry {
                if case .details = ancestor { present.insert(ancestor.id) }
            }
        }
        let untitled = present.subtracting(titled)
        guard !untitled.isEmpty else { return }
        let plan = currentRoles.map { role -> EngineBlockRole in
            var role = role
            role.ancestry.removeAll { untitled.contains($0.id) }
            return role
        }
        adoptRolePlan(plan)
    }

    /// An EXPANDED details whose span holds its title and nothing else gets one empty body
    /// paragraph under the title — the shape a document set renders for a details with no children
    /// (`engineRepresentation`), so the edit path and the set path agree about one document. A range
    /// from the title into a one-paragraph body keeps the TITLE as the survivor (the start's role)
    /// and merges the body's remainder into it, which left a details with no body in the engine and
    /// the model; a draft round trip (get → set → get) then grew an empty body line (composer
    /// harness p15, fuzz seed 11, `HarnessDetailsBodyCrossDeleteTests`). A FOLDED details is left
    /// alone: its body rides in the shape, and its title is legitimately its only engine block. The
    /// selection is saved and restored across the insert, which lands at the title's end.
    internal func settleDetailsWithoutBody() {
        // An IME owns the text until it commits, which settles again — as for the author line.
        guard engine.markedTextRange == nil else { return }
        var guardCount = 0
        while guardCount <= currentRoles.count, let title = currentRoles.indices.first(where: { index in
            let role = currentRoles[index]
            guard role.secondaryKind == .detailsTitle,
                  let details = role.ancestry.last?.details, details.id == role.containerID,
                  details.expanded else { return false }
            let next = index + 1
            return next >= currentRoles.count || !currentRoles[next].isWithin(details.id)
        }) {
            guardCount += 1
            let selection = engineSelectedRange
            let end = flatOffset(ofRoleAt: title) + flatLength(ofRoleAt: title)
            var plan = currentRoles
            plan.insert(freshBodyRole(within: currentRoles[title].ancestry), at: title + 1)
            replaceFlat(NSRange(location: end, length: 0), with: "\n", adopting: plan)
            let map: (Int) -> Int = { $0 <= end ? $0 : $0 + 1 }
            let start = map(selection.location)
            engineSelectedRange = NSRange(location: start, length: max(0, map(NSMaxRange(selection)) - start))
        }
    }

    /// The fresh standalone blocks, by rule of what precedes them: after a quote child, a child (no
    /// edit); after an author line or a media caption, a body paragraph, restyled (the split gave it
    /// the line's face); after a media atom, spec §6.3 — joined to the caption's start for a
    /// captioned kind, a body paragraph otherwise. Task 7 of the surface-gate plan adds the
    /// rejoins for what only a bypass path can split.
    internal func declareFreshBlocks() {
        let identifiers = engine.tgid_blockIdentifiers
        let fresh = Set(identifiers.indices.filter { freshSinceSettle.contains(identifiers[$0]) })
        guard !fresh.isEmpty, currentRoles.count == identifiers.count else { return }
        var plan = currentRoles
        var rejoins: [Int] = []
        // Where each rejoined block ends up: the block its run of rejoins starts from. A bypass that
        // splits one line into THREE mints two fresh blocks, and the second's neighbour above is the
        // first — itself fresh, standalone and about to be rejoined, so read as a body paragraph
        // it declared nothing and the last line and the tail after it left the container.
        // Measured (composer harness, 2026-09-22): a plain paste of `a\nb\nc` into a code body gave
        // `[code "let a\u{2028}b"] [p "c x = 1"]`, and in a pull quote the ejected tail kept the
        // quote's italic. So a fresh block's "previous" is the one its predecessor rejoins into.
        var rejoinTarget: [Int: Int] = [:]
        var declared = false
        for index in fresh.sorted() where index > 0 {
            guard case let .standalone(block) = plan[index].position else { continue }
            let previousIndex = rejoinTarget[index - 1] ?? index - 1
            let previous = plan[previousIndex]
            if previous.secondaryKind == .blockQuoteAuthor {
                // The Return-in-author exit: a body paragraph in the quote's PARENT (§7.1).
                plan[index] = freshBodyRole(within: Array(previous.ancestry.dropLast()))
                declared = true
            } else if previous.secondaryKind == .pullQuoteAuthor || previous.secondaryKind == .mediaCaption {
                // Body, not the line's face, at the line's own depth: `normalisePresentation` re-derives it.
                plan[index] = freshBodyRole(within: previous.ancestry)
                declared = true
            } else if previous.shape.media != nil {
                if blockCarriesMediaAttachment(index), !blockCarriesMediaAttachment(index - 1) {
                    // A bypass split at the atom's LEADING stop: the controller kept the atom's
                    // identity — and so its ROLE — on the block ABOVE while the attachment travelled
                    // to the fresh block below. The fresh block is the real atom, so the two roles
                    // swap. Left alone, the role-holding block has no attachment at all and
                    // `settleMediaAtomIntegrity` reads the unit as destroyed: the media is lost.
                    // Integrity then lifts the text above the atom, as it does for a single line.
                    plan[index - 1] = freshBodyRole(within: previous.ancestry)
                    plan[index] = previous
                    declared = true
                } else if flatLength(ofRoleAt: index) == 0 || !(previous.shape.media?.isCaptionless ?? true) {
                    // A bypass split at the atom's TRAILING stop. It rejoins whenever the atom is
                    // captioned (spec §6.3: the text belongs at the caption's start, and
                    // `settleMediaAtomIntegrity` moves the rejoined tail there in this same pass) or
                    // the fresh block is empty. Declaring it a body paragraph instead would put a
                    // paragraph BETWEEN the atom and its caption, and the adjacency-based
                    // `settleCaptionLinePresence` would then mint a SECOND caption line under the
                    // atom — two engine blocks sharing one `captionLineID`.
                    rejoins.append(index)
                } else {
                    // A caption-less kind: a body paragraph below, as §6.3 says.
                    plan[index] = freshBodyRole(within: previous.ancestry)
                    declared = true
                }
            } else if previous.owningTable != nil || previous.secondaryKind == .codeLanguage || isLeafBody(previous.shape) {
                rejoins.append(index)
                rejoinTarget[index] = previousIndex
            } else if !previous.ancestry.isEmpty {
                // After a quote's child: a sibling at the same depth (today's "after a quote child,
                // a child", now for every kind of child).
                plan[index] = .standalone(block, within: previous.ancestry)
                declared = true
            }
        }
        if declared { adoptRolePlan(plan) }
        // Only a bypass path (dictation, an IME commit) splits these; the gate transforms a surface
        // newline. Rejoined with the separator the gate would have forwarded: a line separator
        // inside a cell or a leaf body, nothing inside a language line. Last to first, so the
        // offsets of the ones still to do are untouched.
        // The edit carries its plan: the roles minus the rejoined one, adopted in the merge's own
        // notification. (Taken after the merge, the index was past the end whenever the rejoined
        // block was the last — the crash measured on device, 2026-09-04.)
        for index in rejoins.sorted().reversed() {
            var rejoined = currentRoles
            rejoined.remove(at: index)
            // The separator is the TARGET's: a chain into a language line joins with nothing.
            let previous = currentRoles[rejoinTarget[index] ?? index - 1]
            let separator = flatOffset(ofRoleAt: index) - 1
            replaceFlat(NSRange(location: separator, length: 1),
                        with: previous.secondaryKind == .codeLanguage || previous.shape.media != nil
                            ? "" : EngineDocumentBridge.lineSeparator,
                        adopting: rejoined)
        }
    }

    /// A container's second line whose container has lost its PRIMARY region is a body paragraph.
    ///
    /// A deletion across a whole container leaves the engine one block with the first block's
    /// identity — for a code block that is its language line, which sits above the code. No rule
    /// declared that survivor, so the roles held a language line with no code, the band drew for it,
    /// the regroup produced no block at all, and every command that looks for a primary region found
    /// nothing: select all and Backspace over a code block kept its language field and background,
    /// and nothing could remove them (measured on device, 2026-09-04). Legacy leaves one empty body
    /// paragraph. A line's text is restyled to body: a language line's semibold would otherwise stay.
    ///
    /// Repeated until nothing is orphaned: removing one orphan can orphan its container's line in
    /// turn. A replacement from a pull quote's author into a quoted pull quote's author left the
    /// inner pull quote nothing but its author line, which this removed — and that line had been
    /// what kept the enclosing quote holding a child, so the quote was left with only its own author
    /// line: a quote with no children in the model and an empty line on screen (composer harness,
    /// 2026-09-23, fuzz seed 18, `HarnessNestedOrphanedLineTests`). Bounded by the role count.
    internal func settleOrphanedSecondaryLines() {
        var passes = 0
        while passes <= currentRoles.count, settleOrphanedSecondaryLinesOnce() {
            passes += 1
        }
    }

    /// One pass of `settleOrphanedSecondaryLines`; true when it changed anything.
    private func settleOrphanedSecondaryLinesOnce() -> Bool {
        var plan = currentRoles
        var orphaned: [Int] = []
        // One walk for every ancestor's span: a nested quote carries an author-line role, so asking
        // `contents(of:around:)` per line paid a full span walk per quote (the scaling test's
        // depth-squared cost, `HarnessNestedQuoteKeystrokeScalingTests`).
        let ancestorSpans = ancestorFirstRunSpans()
        for (index, role) in currentRoles.enumerated() where role.secondaryKind != nil {
            let container = role.containerID
            let hasPrimary: Bool
            // A line owned by an ANCESTOR container — a quote's author, a details' title — has no
            // sibling primary sharing its `containerID`: that container's primaries are its CHILDREN,
            // which carry their own container ids. Its life is its SPAN's.
            //
            // Keyed on `.blockQuoteAuthor` alone, as it was, a details' title took the leaf branch,
            // found no primary with the details' id, and was declared an orphan and rewritten to a
            // body paragraph — on EVERY settle, so any edit anywhere in the document silently
            // destroyed every title in it. The strings never moved, which is what made it read as a
            // gate bug rather than a settle one.
            if role.isOwnedByAnAncestorContainer {
                // A details' TITLE is content, so it keeps its container alive — and a FOLDED details
                // has NOTHING ELSE, which is §7.1's whole invariant: its body is in the shape. Asking
                // for a primary alone declared every folded title an orphan and rewrote it to a body
                // paragraph, dropping the `.details` ancestor and with it `foldedChildren`, the one
                // copy of the body.
                //
                // Counted here rather than special-cased on `!expanded`, because the span being asked
                // about is not always the title's OWN container: a details holding a folded details,
                // or a quote whose only child is one, asks this question about the PARENT, whose span
                // then holds nothing but that folded title. Exempting only the folded details' own
                // title left both of those destroying the outer container on the next keystroke.
                //
                // No fold test could see any of it: a fold goes through the document setter, whose
                // edit `isApplyingHostDocument` swallows, so settle never runs during one.
                if let span = ancestorSpans[container], span.contains(index) {
                    hasPrimary = contents(of: container, span: span).holdsContent
                } else {
                    hasPrimary = contents(of: container, around: index).holdsContent
                }
            } else {
                hasPrimary = currentRoles.contains { $0.containerID == container && $0.secondaryKind == nil }
            }
            if !hasPrimary {
                let ancestry = role.isOwnedByAnAncestorContainer ? Array(role.ancestry.dropLast()) : role.ancestry
                plan[index] = freshBodyRole(within: ancestry)
                orphaned.append(index)
            }
        }
        guard !orphaned.isEmpty else { return false }
        // An author line WITH TEXT keeps its quote: the quote gets one empty body line above it (the
        // shape a document set renders for an authored quote with no children) and the author stays
        // the author. Rewritten to a body paragraph, as it was, any range that merged a quote's lone
        // child into the block above — Backspace, Cut, typing or a composition over it, at any depth —
        // sent the attribution as a line of message text (composer harness p22,
        // `HarnessAuthoredQuoteWideRangeTests`). This is the rule for EVERY entry point, so it lives
        // here, after the edit, and not in one verb's rule table (the p21 `authoredQuoteWall` covered
        // only the one-character break). The quote goes with its author only when a range covers the
        // quote (`containerIsCovered`, which also widens the copy, so Cut + Paste keeps the author).
        // An IME owns the text until it commits, which settles again — as `settleDetailsWithoutBody`.
        // Mid-composition such a line is left as it is (and not rewritten either).
        let authored = orphaned.filter { orphanedAuthorLineKeepsItsQuote(at: $0) }
        if let last = authored.last {
            if engine.markedTextRange == nil {
                mintEmptyPrimary(beforeAuthorLineAt: last)
                return true
            }
            for index in authored { plan[index] = currentRoles[index] }
            orphaned.removeAll { authored.contains($0) }
            guard !orphaned.isEmpty else { return false }
        }
        // An EMPTY author line goes with its container instead: there is nothing in it to keep, and
        // as a body paragraph it is a blank line the user never typed, which is sent. A replacement
        // from a paragraph into a block quote merges the quote's only child into the paragraph and
        // leaves the quote nothing but its author line — measured (composer harness, 2026-09-23):
        // `[p "First paragraph."] [quote "Second paragraph."]`, select 5..<25, Backspace →
        // `[p "Firstaragraph."] [p ""]`; legacy leaves no blank line. A line with text still becomes
        // a paragraph, and the last block of the document is never removed.
        let emptyAuthorLines = orphaned.filter { index in
            let kind = currentRoles[index].secondaryKind
            return (kind == .blockQuoteAuthor || kind == .pullQuoteAuthor) && flatLength(ofRoleAt: index) == 0
        }
        adoptRolePlan(plan)
        for index in emptyAuthorLines.reversed() where currentRoles.count > 1 {
            var remaining = currentRoles
            remaining.remove(at: index)
            let line = flatRange(ofRoleAt: index)
            // With the separator BEFORE it, which belongs to the line; the first block takes the one after.
            let range = index > 0 ? NSRange(location: line.location - 1, length: line.length + 1)
                                  : NSRange(location: line.location, length: line.length + 1)
            // The selection is mapped through the removal, as `settle(_:)` does for an author line it
            // removes: the controller parks its caret at the END of the edit it issues, so without
            // this a caret the user's replacement left at 5 landed after the last character.
            // Measured (composer harness, 2026-09-23, `HarnessQuoteCrossDeleteCaretTests`): select
            // 5..<25 across `[p "First paragraph."] [quote "Second paragraph."]`, type X then Q →
            // `FirstXaragraph.Q`. A position past the removed span shifts back by its length; one
            // inside it (the line is empty, so only its separator) collapses to the span's start.
            let selection = engineSelectedRange
            let map: (Int) -> Int = { offset in
                if offset <= range.location { return offset }
                if offset >= NSMaxRange(range) { return offset - range.length }
                return range.location
            }
            replaceFlat(range, with: "", adopting: remaining)
            let start = map(selection.location)
            let end = map(NSMaxRange(selection))
            engineSelectedRange = NSRange(location: start, length: max(0, end - start))
        }
        return true
    }

    /// Whether the orphaned line at `index` is a quote's or pull quote's author line with text, which
    /// keeps its container (p22).
    private func orphanedAuthorLineKeepsItsQuote(at index: Int) -> Bool {
        let kind = currentRoles[index].secondaryKind
        guard kind == .blockQuoteAuthor || kind == .pullQuoteAuthor else { return false }
        return flatLength(ofRoleAt: index) > 0
    }

    /// Gives the author line at `index` an empty primary line of its container directly above it: a
    /// child paragraph of a block quote, an empty body of a pull quote. The selection is mapped
    /// across the inserted break, which lands at the author line's START: a caret in the author stays
    /// in it, one before it stays where it was.
    private func mintEmptyPrimary(beforeAuthorLineAt index: Int) {
        let role = currentRoles[index]
        let primary: EngineBlockRole
        switch role.position {
        case let .secondary(owner: .block(shape), _, kind: .pullQuoteAuthor):
            primary = .standalone(shape, within: role.ancestry)
        default:
            // A block quote's author is owned by the quote, which is the LAST ancestor: a fresh
            // paragraph within the same ancestry is the quote's child.
            primary = freshBodyRole(within: role.ancestry)
        }
        var plan = currentRoles
        plan.insert(primary, at: index)
        let start = flatOffset(ofRoleAt: index)
        let selection = engineSelectedRange
        replaceFlat(NSRange(location: start, length: 0), with: "\n", adopting: plan)
        let map: (Int) -> Int = { $0 < start ? $0 : $0 + 1 }
        let location = map(selection.location)
        engineSelectedRange = NSRange(location: location, length: max(0, map(NSMaxRange(selection)) - location))
    }

    // MARK: - Presentation

    /// Presentation is derived from the role and the model, never carried by the text
    /// (structure-only roles design §9). Every block the edit touched, or whose role changed, is
    /// rendered again through the bridge as a document set would render it, and the bridge's
    /// attributes are applied where they differ, in the keystroke's undo group. Text merged into a
    /// cell takes the cell's face, an author tail split off by a Return takes body, text typed with
    /// stale typing attributes is corrected — one pass in place of a restyle per case (the merge
    /// into a cell kept the body face: device, 2026-09-04).
    ///
    /// The block offsets are walked once and every block's edits land as ONE attribute edit
    /// (`applyPresentationEdits`): per block `flatOffset(ofRoleAt:)` and one merge per run made a pass
    /// over N touched blocks O(N²) (`HarnessPresentationPassScalingTests`).
    internal func normalisePresentation() {
        defer { touchedSinceSettle.removeAll() }
        let identifiers = engine.tgid_blockIdentifiers
        let blocks = engine.attributedBlocks
        guard identifiers.count == currentRoles.count, blocks.count == identifiers.count else { return }
        var edits: [PresentationEdit] = []
        var start = 0
        for (index, identifier) in identifiers.enumerated() {
            if touchedSinceSettle.contains(identifier) {
                normalisePresentation(ofBlockAt: index, current: blocks[index], start: start, into: &edits)
            }
            start += blocks[index].length + 1
        }
        applyPresentationEdits(edits)
    }

    /// An attribute edit a presentation pass derived: `apply` over `range` (canonical), `remove` there.
    internal typealias PresentationEdit = (range: NSRange, apply: [NSAttributedString.Key: Any], remove: [NSAttributedString.Key])

    /// Lands a pass's edits as ONE attribute edit, in order. One `tgid_mergeAttributes` per edit is one
    /// storage edit each — a re-projection of the whole document and a canvas pass over every block —
    /// so a pass over N blocks was O(N²): a theme change over 240 paragraphs took 8.4 s
    /// (`HarnessPresentationPassScalingTests`).
    internal func applyPresentationEdits(_ edits: [PresentationEdit]) {
        guard !edits.isEmpty else { return }
        engine.tgid_mergeAttributeEdits(inCanonicalRanges: edits.map { NSValue(range: $0.range) },
                                        attributes: edits.map { $0.apply },
                                        removingKeys: edits.map { $0.remove })
    }

    /// The same derivation for the blocks `range` touches, for a HOST COMMAND that rewrites
    /// attributes without an edit settle would see (an inline format applied through
    /// `transformInlineAttributes`). The command decides the model; what it draws is then the role's
    /// rendering of that model, not the command's own guess at a face — which is how Monospace
    /// toggled off left the base-font key behind, and how a pull quote's code run came out italic.
    internal func normalisePresentation(ofBlocksTouching range: NSRange) {
        let identifiers = engine.tgid_blockIdentifiers
        for index in touchedBlockIndices(for: range) where index < identifiers.count {
            touchedSinceSettle.insert(identifiers[index])
        }
        normalisePresentation()
    }

    /// The derivation, applied to the ATTACHMENT characters of the blocks `range` touches and to
    /// nothing else — for an inline command the engine performs over a range that may hold atoms
    /// (`toggleInlineTraitKeepingAtomsDerived`, `applySpoiler`). An atom's presentation is its role's
    /// and its model's alone; the text around it keeps whatever the command decided, exactly as
    /// before, so this cannot move any text's face.
    ///
    /// ONE attribute edit for every atom the range touches, keyed by the attachment OBJECT (each atom
    /// character carries its own), not one `tgid_mergeAttributes` per atom: each of those rebuilt the
    /// engine's canonical projection of the whole document, so Select All ▸ Bold over a paragraph of
    /// N custom emoji cost O(N²) — 4.4 s at N = 200 — and 80 media blocks likewise (composer harness
    /// p15, `HarnessAtomFormatScalingTests`).
    internal func rederiveAtomPresentation(touching range: NSRange) {
        let blocks = engine.attributedBlocks
        var blockStarts: [Int] = []
        blockStarts.reserveCapacity(blocks.count)
        var position = 0
        for block in blocks {
            blockStarts.append(position)
            position += block.length + 1
        }
        var edits: [ObjectIdentifier: (apply: [NSAttributedString.Key: Any], remove: [NSAttributedString.Key])] = [:]
        var span: NSRange?
        for index in touchedBlockIndices(for: range) where index < blocks.count && index < currentRoles.count {
            let current = blocks[index]
            guard current.length > 0 else { continue }
            var atoms: [(range: NSRange, attachment: NSTextAttachment)] = []
            current.enumerateAttribute(.attachment, in: NSRange(location: 0, length: current.length), options: []) { value, run, _ in
                if let attachment = value as? NSTextAttachment { atoms.append((run, attachment)) }
            }
            guard !atoms.isEmpty else { continue }
            let rendered = bridge.render(role: currentRoles[index], from: current)
            guard rendered.string == current.string else { continue }
            // From one prefix walk, not `flatOffset(ofRoleAt:)` per block, which re-sums the blocks
            // before it: O(N²) over N media blocks.
            let start = blockStarts[index]
            for atom in atoms {
                // An atom is one character, so its rendering is one set of attributes.
                let wanted = rendered.attributes(at: atom.range.location, effectiveRange: nil)
                let existing = current.attributes(at: atom.range.location, effectiveRange: nil)
                var apply: [NSAttributedString.Key: Any] = [:]
                var remove: [NSAttributedString.Key] = []
                for key in Self.presentationKeys + Self.inlineTraitMarkerKeys {
                    let want = wanted[key] as AnyObject?
                    let have = existing[key] as AnyObject?
                    if let want {
                        if have == nil || !want.isEqual(have) { apply[key] = want }
                    } else if have != nil {
                        remove.append(key)
                    }
                }
                guard !apply.isEmpty || !remove.isEmpty else { continue }
                edits[ObjectIdentifier(atom.attachment)] = (apply, remove)
                let flat = NSRange(location: start + atom.range.location, length: atom.range.length)
                span = span.map { NSUnionRange($0, flat) } ?? flat
            }
        }
        guard let span, !edits.isEmpty else { return }
        engine.tgid_transformAttributes(inCanonicalRange: span) { existing in
            guard let attachment = existing[.attachment] as? NSTextAttachment,
                  let edit = edits[ObjectIdentifier(attachment)] else { return existing }
            var merged = existing
            for key in edit.remove { merged.removeValue(forKey: key) }
            merged.merge(edit.apply) { _, new in new }
            return merged
        }
    }

    /// The engine's own trait markers — what its trait pass derives a face from and its toolbar
    /// reads. Re-derived on an ATOM alongside the presentation keys: the engine's toggle stamps them
    /// there, and a marker left behind re-derives the toggled face (and the verifier restores it
    /// through `withCarriedTraitsOnFallbackFaces`) however the face itself was corrected.
    internal static let inlineTraitMarkerKeys: [NSAttributedString.Key] = [
        .IDInlineTextBoldAttributeName, .IDInlineTextItalicAttributeName,
        .IDInlineTextUnderlineAttributeName, .IDInlineTextStrikethroughAttributeName,
    ]

    /// The keys the bridge renders — what a document set decides. The engine's own keys stay.
    internal static let presentationKeys: [NSAttributedString.Key] = [
        .font, .paragraphStyle, .foregroundColor, .backgroundColor, .underlineStyle, .strikethroughStyle,
        .link, .baselineOffset, .rtBold, .rtInlineCode, .rtSpoiler,
        NSAttributedString.Key.IDInlineTextBaseFontAttributeName,
    ]

    private func normalisePresentation(ofBlockAt index: Int, current: NSAttributedString, start: Int,
                                       into edits: inout [PresentationEdit]) {
        guard current.length > 0 else { return }
        let rendered = bridge.render(role: currentRoles[index], from: current)
        // Characters are never presentation: a rendering that would change them is not applied.
        guard rendered.string == current.string else { return }
        // A code block's language line holds a plain string: no trait marker there is user state, so
        // the markers are derived from the role like the presentation keys. Left alone, an italic
        // marker that arrived with moved or pasted text made the engine's trait pass draw the italic
        // face again after the font was corrected (composer harness p18, fuzz seed 53,
        // `HarnessCodeLanguageMoveFormattingTests`). A code BODY is the same (p20): its model is plain
        // text (`EngineDocumentBridge.plainCodeRuns`), so a bold or italic marker that arrived with a
        // paste or a move is presentation to re-derive, not the user's. Everywhere else a marker is
        // the user's.
        var markersArePresentation = currentRoles[index].secondaryKind == .codeLanguage
        if case .standalone(.code) = currentRoles[index].position { markersArePresentation = true }
        let keys = markersArePresentation
            ? Self.presentationKeys + Self.inlineTraitMarkerKeys
            : Self.presentationKeys
        rendered.enumerateAttributes(in: NSRange(location: 0, length: rendered.length)) { wanted, run, _ in
            current.enumerateAttributes(in: run) { existing, sub, _ in
                var apply: [NSAttributedString.Key: Any] = [:]
                var remove: [NSAttributedString.Key] = []
                for key in keys {
                    let want = wanted[key] as AnyObject?
                    let have = existing[key] as AnyObject?
                    if let want {
                        if have == nil || !want.isEqual(have) { apply[key] = want }
                    } else if have != nil {
                        remove.append(key)
                    }
                }
                if !apply.isEmpty || !remove.isEmpty {
                    edits.append((NSRange(location: start + sub.location, length: sub.length), apply, remove))
                }
            }
        }
    }

    // MARK: - The invariant, stated as a check

    /// Presentation is derived from the role. This asserts that at the one moment it must be true —
    /// the end of settle, when everything has landed — by asking the bridge what each block SHOULD
    /// render as and comparing.
    ///
    /// It exists because the invariant was being upheld by convention rather than by construction:
    /// `adoptRolePlan` changes a role and leaves the derived presentation behind, so every caller had
    /// to remember to re-derive, and the ones that got away with it did so for four different
    /// incidental reasons (the block was empty and rendered by the providers; the changed field did
    /// not affect the style; the block happened to be touched by the edit anyway). The first call
    /// site where none of those applied shipped a list whose bullet outdented and whose text did not.
    ///
    /// Off unless `RTE_VERIFY_PRESENTATION` is set, because it renders every block: it is a
    /// development instrument, not a per-keystroke cost.
    /// On in DEBUG, where the cost of rendering every block at the end of a settle buys the
    /// invariant being checked continuously by every test that touches the editor. Compiled out of
    /// release entirely.
    #if DEBUG
    internal static var verifiesDerivedPresentation = true
    #else
    internal static let verifiesDerivedPresentation = false
    #endif

    internal static let isRunningTests = NSClassFromString("XCTestCase") != nil

    internal static let announceVerificationOnce: Void = {
        NSLog("RTEVERIFY derived-presentation verification is ON")
    }()

    /// The presentation keys at `index` whose value differs from what the bridge would render.
    /// Empty blocks are excluded: their attributes come from the empty-line providers, which read
    /// the role live, so there is nothing to go stale.
    internal func presentationDrift(atBlock index: Int) -> [String] {
        let blocks = engine.attributedBlocks
        guard index < blocks.count, index < currentRoles.count else { return [] }
        // The stored faces read as the read-back reads them (`withCarriedTraitsOnFallbackFaces`): a
        // SUBSTITUTED face as the traits the run is meant to carry — its base face's ambient ones
        // and the user's markers — so an italic emoji drawn in a face without italic, or an author
        // line's emoji without the line's bold, is font fixing, not drift.
        let current = EngineDocumentBridge.withCarriedTraitsOnFallbackFaces(blocks[index])
        guard current.length > 0 else { return [] }
        let rendered = bridge.render(role: currentRoles[index], from: current)
        guard rendered.string == current.string else { return [] }
        var drift: Set<String> = []
        rendered.enumerateAttributes(in: NSRange(location: 0, length: rendered.length)) { wanted, run, _ in
            current.enumerateAttributes(in: run) { existing, _, _ in
                for key in Self.presentationKeys {
                    let want = wanted[key] as AnyObject?
                    let have = existing[key] as AnyObject?
                    if Self.presentationAgrees(key: key, wanted: want, have: have) { continue }
                    drift.insert(key.rawValue)
                }
            }
        }
        return drift.sorted()
    }

    /// The model-unrepresentable fields (`EngineDocumentBridge.modelUnrepresentableFields`) the block at
    /// `index` holds — a non-trapping companion to `presentationDrift(atBlock:)` for a host whose sink is
    /// the chat composer's model (the composer harness's fuzz asks it after every step).
    internal func modelUnrepresentableFields(atBlock index: Int) -> [String] {
        let blocks = engine.attributedBlocks
        guard index < blocks.count, index < currentRoles.count, blocks[index].length > 0 else { return [] }
        return bridge.modelUnrepresentableFields(role: currentRoles[index], from: blocks[index])
    }

    /// Whether a rendered value and a stored one describe the same presentation.
    ///
    /// Identity is too strict for `.font`, and that is not a loophole — it is this package's own
    /// rule. `NSTextStorage` font-fixing substitutes a SCRIPT font into storage when the style's
    /// font cannot render the glyphs (CJK, Arabic, Hebrew), so the family legitimately differs from
    /// anything the bridge would render; the package treats font family as display-only and
    /// deliberately does not round-trip it. What must still agree is what the style actually
    /// decides: the size and the traits. Comparing identity instead reported the CJK marked-text
    /// test as drift three times, which is a false positive on exactly the case the rule exists for.
    internal static func presentationAgrees(key: NSAttributedString.Key,
                                            wanted: AnyObject?, have: AnyObject?) -> Bool {
        if wanted == nil && have == nil { return true }
        // A zero underline or strikethrough style draws nothing, exactly as an absent one does. The
        // typed-text policy writes `.underlineStyle = 0` to stop a link's styling continuing into
        // what is typed after it, and that stored zero read as drift against a rendering that has
        // no key at all (fuzz seeds 13, 21).
        if key == .underlineStyle || key == .strikethroughStyle {
            return ((wanted as? Int) ?? 0) == ((have as? Int) ?? 0)
        }
        if key == .font, let wanted = wanted as? UIFont, let have = have as? UIFont {
            // Size, and only the traits the MODEL carries. A substituted font brings its own
            // incidental bits along — the CJK fallback reports 1<<14, which is neither bold nor
            // italic and nothing this editor models — so comparing the whole trait set reports a
            // substitution as drift just as surely as comparing the family does.
            let modelled: UIFontDescriptor.SymbolicTraits = [.traitBold, .traitItalic]
            return abs(wanted.pointSize - have.pointSize) < 0.01
                && wanted.fontDescriptor.symbolicTraits.intersection(modelled)
                    == have.fontDescriptor.symbolicTraits.intersection(modelled)
        }
        return wanted?.isEqual(have) ?? false
    }

    /// The pools that do not hold what the roles say they should (completeness spec §2.2), as
    /// readable findings. Pure: a test asserts on this, and the wrapper below is what traps — the
    /// same split `presentationDrift(atBlock:)` / `verifyPresentationIsDerived` uses.
    internal func derivedViewShortfall() -> [String] {
        let expected = EngineDerivedViewExpectation(roles: currentRoles)
        var findings: [String] = []
        func check(_ label: String, _ wanted: Set<BlockID>, _ held: Set<BlockID>) {
            for id in wanted.subtracting(held).sorted(by: { $0.rawValue < $1.rawValue }) {
                findings.append("\(label) missing for \(id.rawValue)")
            }
        }
        check("grid", expected.tables, Set(tableGrids.keys))
        check("table chrome", expected.tables, Set(tableChromeViews.keys))
        check("table placement", expected.tables, Set(tablePlacements.keys))
        check("chevron", expected.detailsChevrons, Set(detailsChevronViews.keys))
        check("decoration", expected.decorations, Set(containerDecorationViews.keys))
        check("list marker", expected.listMarkers, Set(listMarkerViews.keys))
        check("button row", expected.buttonRows, Set(buttonRowViews.keys))
        check("collapsed quote", expected.collapsedQuotes, Set(collapsedQuoteViews.keys))
        // The REVERSE direction, and the first consumer of it. Only one table has structural chrome
        // at a time and the roles cannot say which, so "every table has one" is false by
        // construction; what IS checkable is that no pooled view outlives its table.
        for id in Set(tableStructuralChromeViews.keys).subtracting(expected.structuralChrome)
            .sorted(by: { $0.rawValue < $1.rawValue }) {
            findings.append("structural chrome outlived table \(id.rawValue)")
        }
        // The REVERSE direction too, and for the same reason: "is this quote collapsible" is a
        // MEASURED fact the roles cannot answer, so "every quote has a glyph" is false by
        // construction. What IS checkable is that no pooled glyph outlives its quote.
        let quoteIDs = Set(currentRoles.flatMap { role in role.ancestry.compactMap { $0.quote?.id } })
        for id in Set(quoteCollapseGlyphViews.keys).subtracting(quoteIDs)
            .sorted(by: { $0.rawValue < $1.rawValue }) {
            findings.append("collapse glyph outlived quote \(id.rawValue)")
        }
        return findings
    }

    /// Placement only, for the ENGINE's own passes — a run's horizontal scroll dirties the engine and
    /// marks nothing else, so the pass that moves a table's cells is one the host's `layoutSubviews`
    /// never sees. Existence is deliberately NOT checked here: the engine lays out before the host
    /// has ever placed a view for a freshly set document, and "not created yet" is not a defect.
    ///
    /// Skipped while the host is marked for layout: a pending pass is about to re-place everything,
    /// so anything stale at this moment is stale by design. What remains is the case worth trapping —
    /// nothing pending, and a view no longer where the geometry puts it.
    internal func verifyDerivedViewPlacement() {
        guard Self.verifiesDerivedPresentation, bounds.width > 0 else { return }
        guard !layer.needsLayout(), engine.markedTextRange == nil else { return }
        derivedViewPlacementVerificationCount += 1
        let drift = derivedViewPlacementDrift()
        guard !drift.isEmpty else { return }
        let detail = drift.joined(separator: "; ")
        NSLog("RTEDRIFT placement %@", detail)
        if Self.isRunningTests {
            assertionFailure("RichTextEngineEditor: a derived view is not where the geometry puts "
                             + "it: \(detail). The pass that places it did not run for this layout.")
        }
    }

    /// Presentation is derived from the role, and so is everything DRAWN from it. This is the other
    /// half: `verifyPresentationIsDerived` asserts a block's attributes match its role and says
    /// nothing about whether the block appears at all. A table was once in the document, in the
    /// roles, and drawn nowhere — no grid, no chrome, no cells — and nothing anywhere reported it.
    ///
    /// Run per LAYOUT rather than per settle, deliberately (§2.5). The presentation check runs from
    /// settle and from the restore path, so a mutation reaching neither is unchecked — which is how
    /// an undo left every restored block wearing the presentation it had before. Every path that
    /// changes roles is followed by a layout, whatever route it took.
    ///
    /// On pool KEYS, never on visibility (§2.3): a media host is HIDDEN when culled off-screen, not
    /// removed, so hidden is not missing.
    internal func verifyDerivedViewsAreComplete() {
        guard Self.verifiesDerivedPresentation, bounds.width > 0 else { return }
        // Test seam. A check nothing invokes is the exact defect this instrument was written for —
        // the details chevron had a hit-test rule, a passing test for it, and no caller — so the
        // WIRING is pinned as well as the rule.
        derivedViewVerificationCount += 1
        guard engine.markedTextRange == nil else { return }
        Self.announceVerificationOnce
        // Existence AND placement. The first asks whether the roles' views are there; the second
        // whether they are where this pass's geometry says — which is the question every table
        // defect on this branch turned out to be.
        let shortfall = derivedViewShortfall() + derivedViewPlacementDrift()
        guard !shortfall.isEmpty else { return }
        let detail = shortfall.joined(separator: "; ")
        // Logged BEFORE the trap, so the detail survives it in a test run.
        NSLog("RTEDRIFT views %@", detail)
        if Self.isRunningTests {
            assertionFailure("RichTextEngineEditor: the roles say these must be drawn and they are "
                             + "not: \(detail). A view is derived from the role, like presentation.")
        }
    }

    internal func verifyPresentationIsDerived(_ stage: String) {
        guard Self.verifiesDerivedPresentation else { return }
        // Not during an IME composition. The storage legitimately holds attributes the bridge does
        // not model then — the composition underline, and the script font TextKit substituted for
        // glyphs the style font cannot draw — and the text is not committed, so there is nothing
        // for a role to be the authority on yet.
        guard engine.markedTextRange == nil else { return }
        // Proves the instrument is live: a run with no `RTEDRIFT` lines and no `RTEVERIFY` line
        // measured nothing at all, which is not the same as measuring no drift.
        Self.announceVerificationOnce

        for index in currentRoles.indices {
            let drift = presentationDrift(atBlock: index)
            guard !drift.isEmpty else { continue }
            let keys = drift.joined(separator: ",")
            // Logged BEFORE the trap, so the detail survives it in a test run.
            NSLog("RTEDRIFT %@ block %ld role=%@ keys=%@", stage, index,
                  String(describing: currentRoles[index]).prefix(60).description, keys)
            // Fatal in a TEST, where an unnoticed violation is the whole problem; a log in the
            // app, where it is not. A debug build is what runs on the simulator during manual
            // testing, so trapping here would turn a slightly-wrong indent into a crash mid-typing
            // — a worse failure than the one being guarded against, and one this guard would be
            // causing rather than catching.
            if Self.isRunningTests {
                assertionFailure("RichTextEngineEditor: block \(index)'s presentation does not match "
                                 + "its role (\(keys)). Presentation is derived from the role — "
                                 + "something changed a role without letting settle re-derive it.")
            }
        }
    }

    /// Every line break a ONE-LINE field (a language, a details title, an author) holds becomes a space —
    /// `EngineDocumentBridge.oneLineText`, the field's rule on every door. The gate applies it to what it
    /// sees; this catches what it cannot: a composition's commit (an IME owns marked text and the gate is
    /// not asked while it is marked), a cross-block replacement whose text lands in the field, and any
    /// path added later. Held raw, a `U+2028` read back as "\n" and the next render split the line (composer
    /// harness p23, `HarnessNewlineInOneLineFieldCrashTests`). Waits for a composition to commit, like
    /// every settle step that edits text. The selection is carried across each replacement.
    internal func settleLineBreaksInOneLineFields() {
        guard engine.markedTextRange == nil else { return }
        let blocks = engine.attributedBlocks
        guard blocks.count == currentRoles.count else { return }
        var replacements: [NSRange] = []
        var start = 0
        for (index, block) in blocks.enumerated() {
            defer { start += block.length + 1 }
            guard currentRoles[index].isOneLineField else { continue }
            let text = block.string as NSString
            var location = 0
            while location < text.length {
                // A run of whitespace holding a line break, as `oneLineText` collapses it.
                var end = location
                var holdsBreak = false
                while end < text.length {
                    let range = text.rangeOfComposedCharacterSequence(at: end)
                    let character = Character(text.substring(with: range))
                    guard character.isWhitespace else { break }
                    if character.isNewline { holdsBreak = true }
                    end = NSMaxRange(range)
                }
                if end > location {
                    if holdsBreak { replacements.append(NSRange(location: start + location, length: end - location)) }
                    location = end
                } else {
                    location = NSMaxRange(text.rangeOfComposedCharacterSequence(at: location))
                }
            }
        }
        guard !replacements.isEmpty else { return }
        var selection = engineSelectedRange
        for range in replacements.reversed() {
            replaceFlat(range, with: " ")
            let delta = 1 - range.length
            func map(_ offset: Int) -> Int {
                if offset >= NSMaxRange(range) { return offset + delta }
                if offset > range.location { return range.location + 1 }
                return offset
            }
            let location = map(selection.location)
            selection = NSRange(location: location, length: max(0, map(NSMaxRange(selection)) - location))
        }
        engineSelectedRange = selection
    }

    /// A code body without its language line above it gets one, empty. The line is unconditional
    /// (`engineRepresentation` emits it for every code block); a replacement across blocks whose end
    /// keeps part of a code body drops the line as a block between the endpoints, and the language
    /// text it held was inside the selection. The caret is saved and restored across the insert.
    internal func settleLanguageLinePresence() {
        var guardCount = 0
        while guardCount < currentRoles.count, let body = currentRoles.indices.first(where: { index in
            guard case .standalone(.code) = currentRoles[index].position else { return false }
            // The language line is part of the code block's OWN unit: a leaf-container question.
            guard case let .sameLeafContainer(above) = neighbour(before: index) else { return true }
            return currentRoles[above].secondaryKind != .codeLanguage
        }) {
            guardCount += 1
            guard case let .standalone(shape) = currentRoles[body].position else { return }
            let caret = engineSelectedRange.location
            let start = flatOffset(ofRoleAt: body)
            var plan = currentRoles
            plan.insert(.secondary(owner: .block(shape), line: BlockID("\(shape.id.rawValue)#language"),
                                   kind: .codeLanguage, within: currentRoles[body].ancestry), at: body)
            replaceFlat(NSRange(location: start, length: 0), with: "\n", adopting: plan)
            engineSelectedRange = NSRange(location: caret >= start ? caret + 1 : caret, length: 0)
        }
    }

    /// Appear: an empty block after the container's last block, declared its author line. Go: the
    /// line and the separator before it deleted; a caret that was in it lands in the container's
    /// primary region. The caret is saved before the edit and restored after: a top-level insert
    /// at the caret would otherwise carry it into the new line.
    internal func settleAuthorLinePresence() {
        // An IME owns the text until it commits. The first candidate composed into an empty quote
        // gives the quote content, and minting its author line under the live marked range moved
        // text the next candidate replaces: the commit kept the first candidate in front ("aあり"
        // for "あり"; composer harness, 2026-09-24, fuzz seed 29, `HarnessCompositionUndoStepTests`).
        // The line waits for the commit, which settles again (`settleAfterCompositionCommit`).
        guard engine.markedTextRange == nil else { return }
        // Every quote whose line is wrong, not the first: typing into an empty quote inside an empty
        // quote gives BOTH their lines in one keystroke. Bounded by the number of containers.
        var guardCount = 0
        while guardCount <= currentRoles.count, let presence = authorLinePresenceThatIsWrong() {
            guardCount += 1
            settle(presence)
        }
    }

    private func settle(_ presence: AuthorLinePresence) {
        let lastOwned = presence.span.upperBound
        let isLine: (Int) -> Bool = { self.currentRoles[$0].isOwnedLine(presence.kind, of: presence.owner.id) }
        let hasLine = presence.span.contains(where: isLine)
        let caret = engineSelectedRange.location
        if !hasLine {
            let end = flatOffset(ofRoleAt: lastOwned) + flatLength(ofRoleAt: lastOwned)
            var plan = currentRoles
            plan.insert(.secondary(owner: presence.owner, line: BlockID("\(presence.owner.id.rawValue)#author"),
                                   kind: presence.kind, within: presence.ancestry), at: lastOwned + 1)
            replaceFlat(NSRange(location: end, length: 0), with: "\n", adopting: plan)
            engineSelectedRange = NSRange(location: caret <= end ? caret : caret + 1, length: 0)
        } else {
            guard isLine(lastOwned) else { return }
            let range = flatRange(ofRoleAt: lastOwned)
            var plan = currentRoles
            plan.remove(at: lastOwned)
            replaceFlat(NSRange(location: range.location - 1, length: range.length + 1), with: "", adopting: plan)
            // `range.location - 1` is the SEPARATOR before the line, and a caret there belongs to the
            // block ABOVE, not to the line being removed — the two offsets coincide whenever that
            // block is empty. Tested with `>=`, emptying the last child of a quote whose cells were
            // also empty read as "the caret is in the author line" and threw it away (device, K3
            // 2026-09-08): a table's cells, the paragraph and the author line all sat one offset
            // apart, so deleting the last character moved the caret into the first cell.
            if caret >= range.location {
                // Where the line's text would have flowed: the END of the LAST primary block the
                // quote holds. The span's FIRST primary is the first CELL when the quote opens with
                // a table, which is the far side of the whole grid from the line being removed.
                let primary = lastPrimaryRole(in: presence.span) ?? presence.span.lowerBound
                engineSelectedRange = NSRange(location: flatOffset(ofRoleAt: primary) + flatLength(ofRoleAt: primary), length: 0)
            } else {
                engineSelectedRange = NSRange(location: min(caret, range.location - 1), length: 0)
            }
        }
    }
}
#endif
