#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextInputDecUpstream

/// The host commands for media (spec §7): the two inserts and, below, the ••• menu's verbs.
///
/// Every insert is ONE edit through the controller (`replaceFlat(adopting:)` inside
/// `performHostStructuralEdit`), so the controller records it and the replay snapshot restores the
/// roles — deliberately NOT `insertTable`'s document set plus `recordUndoStepForStructuralChange`,
/// which wipes history: a photo attached mid-composition must not discard the typing before it.
/// The attachment cannot travel through a text edit, so the atom's attributes are written right
/// after with `restyleFlat`, in the same undo group.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    public func insertMedia(mediaID: String, naturalSize: CGSize, kind: MediaKind, caption: [TextRun]) {
        insertMediaBlock(MediaBlock(id: BlockID(UUID().uuidString), mediaID: mediaID, kind: kind,
                                    naturalSize: Size2D(width: Double(naturalSize.width), height: Double(naturalSize.height)),
                                    caption: caption))
    }

    /// Legacy's four placements: an empty caret paragraph is replaced; a caret mid-paragraph splits
    /// it; offset 0 inserts before; anything else inserts after. In a quote: a no-op (legacy's v1
    /// rule). Before and after are measured against the whole CONTAINER — a cell, a second line or a
    /// container's body all place the unit outside it, never between its lines. Caret at the caption's start, or
    /// for a caption-less kind at the following body paragraph's start, appending one when the next
    /// block is not a paragraph. Never takes focus.
    internal func insertMediaBlock(_ block: MediaBlock) {
        guard !currentRoles.isEmpty else { return }
        let selection = engineSelectedRange
        if selection.length > 0 {
            // Through the gate's own rule, as legacy applies the selection replace first.
            replaceFlat(selection, with: "")
        }
        // Decided BEFORE the framing, so a refusal fires no settle and no `onChange` at all.
        // (Inside `deliveringOneChangeNotification` the early return still delivered a notification
        // for an edit that never happened.) The selection delete stays first: the spec orders it
        // before the placement rule.
        //
        // A quote is no longer a refusal. Legacy's v1 rule made media inside a quote a no-op and the
        // nesting rung kept it, but the RENDER half landed with that rung, so the only thing left
        // refusing was this guard — and to a user holding a quote the + button simply did nothing
        // (device, K3 2026-09-08). The unit now takes the caret's own ancestry, so it lands as a
        // child of the quote the caret is in, at any depth. A caret in a CELL still places the unit
        // after the whole table, which is the container rule below, not a depth rule.
        guard roleIndex(atFlatOffset: engineSelectedRange.location) != nil else { return }
        let shape = MediaShape(block)
        // The caption's RUNS, rendered as a document set renders them, so bold, a link or a custom
        // emoji in a passed caption survives; the text goes in with the insert and the attributes
        // are restored over it afterwards, exactly as `insertDocument` does.
        let captionRendering = shape.isCaptionless ? nil : bridge.captionLine(runs: block.caption)
        deliveringOneChangeNotification {
            performHostStructuralEdit {
                let caret = engineSelectedRange.location
                guard let index = roleIndex(atFlatOffset: caret) else { return }
                let role = currentRoles[index]

                // The caret's own ancestry on every minted role. A role built at top level would sit
                // visually inside the quote and belong to no quote at all — the regroup would close
                // the quote before it and reopen one after.
                var unitRoles: [EngineBlockRole] = [.standalone(.media(shape), within: role.ancestry)]
                var unitText = "\u{FFFC}"
                if !shape.isCaptionless {
                    unitRoles.append(.secondary(owner: .block(.media(shape)), line: shape.captionLineID,
                                                kind: .mediaCaption, within: role.ancestry))
                    unitText += "\n" + (captionRendering?.string ?? "")
                }
                let placement = planAtomUnitPlacement(unitRoles: unitRoles, unitText: unitText,
                                                      at: index, caret: caret)
                let atomStart = placement.atomStart
                let atomRoleIndex = placement.atomRoleIndex
                replaceFlat(NSRange(location: placement.insertAt, length: 0), with: placement.inserted,
                            adopting: placement.plan)
                // The atom is measured against the line it will sit on, so the indent it subtracts
                // is the caret's depth, not 0 (nesting design §4.4, probe P1).
                restyleFlat(NSRange(location: atomStart, length: 1),
                            with: bridge.mediaAtomAttributes(for: shape, within: role.ancestry))
                if let captionRendering, captionRendering.length > 0 {
                    // The caption line starts one separator past the atom's single character.
                    restoreStyleFlat(NSRange(location: atomStart + 2, length: captionRendering.length),
                                     from: captionRendering)
                }

                if shape.isCaptionless {
                    let atomEnd = atomStart + 1
                    let next = atomRoleIndex + 1
                    // A SIBLING paragraph. Asked as "is there a next role that is a paragraph", a
                    // caption-less atom that is a container's LAST child saw the block FOLLOWING the
                    // container, minted nothing, and left the caret outside the block with nowhere
                    // to type — the same shape as the table's Return exit. THIS ARM IS A FIX, not a
                    // neutral migration; the branch exists to give a caption-less atom somewhere to
                    // type after it, and landing outside the container defeats it.
                    if case let .sibling(sibling) = neighbour(after: atomRoleIndex),
                       case .standalone(.paragraph) = currentRoles[sibling].position {
                        engineSelectedRange = NSRange(location: atomEnd + 1, length: 0)
                    } else {
                        var withTrailing = currentRoles
                        withTrailing.insert(.standalone(.paragraph(ParagraphShape(id: BlockID(UUID().uuidString))),
                                                        within: role.ancestry), at: next)
                        replaceFlat(NSRange(location: atomEnd, length: 0), with: "\n", adopting: withTrailing)
                        engineSelectedRange = NSRange(location: atomEnd + 1, length: 0)
                    }
                } else {
                    engineSelectedRange = NSRange(location: atomStart + 2, length: 0)
                }
            }
        }
        setNeedsLayout()
    }

    /// Where an ATOM UNIT goes, given the caret. Extracted from `insertMediaBlock` so
    /// `insertButtonRow` places identically rather than by a second copy of these five arms.
    ///
    /// Placement is against the whole CONTAINER, never one of its lines. A code block's language
    /// line sits ABOVE its body and a pull quote's author line BELOW it, so a unit placed at
    /// `index`/`index + 1` lands inside the container and breaks it: a unit between a language line
    /// and its code makes the code adjacency-orphaned, `settleLanguageLinePresence` mints it a
    /// SECOND, empty language line, and the merge in `EngineBlockRole.document` takes the LAST line
    /// for the owner — silently dropping the language the user typed. For a paragraph the span is
    /// the block itself, so this is a rule about containers only, and it is the same rule
    /// `insertDocument` follows.
    ///
    /// A caret in a CELL therefore places the unit after the whole TABLE — that same rule, applied
    /// to a cell's container, and not a depth rule.
    internal func planAtomUnitPlacement(unitRoles: [EngineBlockRole], unitText: String,
                                        at index: Int, caret: Int)
        -> (plan: [EngineBlockRole], insertAt: Int, inserted: String, atomStart: Int, atomRoleIndex: Int) {
        let role = currentRoles[index]
        let blockStart = flatOffset(ofRoleAt: index)
        let blockLength = flatLength(ofRoleAt: index)
        let local = caret - blockStart
        let span = containerSpan(containing: index)
        let containerStart = flatOffset(ofRoleAt: span.lowerBound)
        let containerEnd = flatOffset(ofRoleAt: span.upperBound) + flatLength(ofRoleAt: span.upperBound)
        var plan = currentRoles

        if role.owningTable != nil || role.secondaryKind != nil || atomUnitIndex(forRoleAt: index) != nil {
            plan.insert(contentsOf: unitRoles, at: span.upperBound + 1)
            return (plan, containerEnd, "\n" + unitText, containerEnd + 1, span.upperBound + 1)
        }
        if blockLength == 0, role.shape.paragraph != nil {
            plan.replaceSubrange(index...index, with: unitRoles)
            return (plan, blockStart, unitText, blockStart, index)
        }
        if local <= 0 {
            plan.insert(contentsOf: unitRoles, at: span.lowerBound)
            return (plan, containerStart, unitText + "\n", containerStart, span.lowerBound)
        }
        if local >= blockLength || role.shape.paragraph == nil {
            plan.insert(contentsOf: unitRoles, at: span.upperBound + 1)
            return (plan, containerEnd, "\n" + unitText, containerEnd + 1, span.upperBound + 1)
        }
        let paragraph = role.shape.paragraph!
        let tail = EngineBlockRole.standalone(.paragraph(ParagraphShape(
            id: BlockID(UUID().uuidString), style: paragraph.style, paragraph: paragraph.paragraph, list: nil)),
            within: role.ancestry)
        plan.insert(contentsOf: unitRoles + [tail], at: index + 1)
        return (plan, caret, "\n" + unitText + "\n", caret + 1, index + 1)
    }

    /// Splices `document`'s blocks at the caret's block, **at any depth**: an empty caret paragraph
    /// is replaced, anything else gets them after it — never split. Caret at the end of the inserted
    /// content. Each inserted block's attributes are its rendering's, applied after the text edit.
    ///
    /// **The blocks are RENDERED within the caret's ancestry, not built at top level and re-parented.**
    /// That is the whole of the depth fix, and `EngineDocumentBridge.engineRepresentation(for:within:)`
    /// exists for it: a quoted block renders through the quote mapper and is indented, so building it
    /// at top level gives correct structure wrapped around wrong TEXT.
    ///
    /// This used to REFUSE outright whenever the caret was inside any container, carrying the media
    /// spec's §8.5 quote no-op. That reasoning is sound about roles built at TOP LEVEL — they would
    /// split the quote at the regroup — and says nothing about whether the insert should happen; the
    /// ancestry-aware render is what makes it unnecessary. `insertMediaBlock` shed the identical
    /// guard on 2026-09-08 for the identical reason, after a device pass where the + button simply
    /// did nothing to a user holding a quote. Here the silent commands were the article editor's
    /// AI ▸ generate, attaching a file, and the style-paragraph insert.
    ///
    /// A caret in a CELL still places the blocks after the whole table — `containerSpan` groups a
    /// cell with its table, which is the container rule, not a depth rule.
    ///
    /// The inserted blocks' ids must be UNIQUE within the editor: a block id keys the hosted-view
    /// pool (`mediaAtomViews`) and derives a media block's caption line id, so inserting a block
    /// whose id already exists gives two units one hosted view and one caption identity.
    public func insertDocument(_ document: Document) {
        guard !document.blocks.isEmpty, !currentRoles.isEmpty else { return }
        // Resolved BEFORE the framing, so a caret that resolves to nothing fires no settle and no
        // `onChange` at all — `insertMediaBlock`'s ordering, and for its reason.
        guard let caretIndex = roleIndex(atFlatOffset: engineSelectedRange.location) else { return }
        let (rendered, roles) = bridge.engineRepresentation(for: document.blocks,
                                                            within: currentRoles[caretIndex].ancestry)
        guard !rendered.isEmpty else { return }
        deliveringOneChangeNotification {
            performHostStructuralEdit {
                let caret = engineSelectedRange.location
                guard let index = roleIndex(atFlatOffset: caret) else { return }
                let span = containerSpan(containing: index)
                let top = currentRoles[span.lowerBound]
                var plan = currentRoles
                let start: Int
                let inserted: String
                let texts = rendered.map(\.string)
                // No depth test: an empty paragraph inside a quote is consumed exactly as one at
                // top level is, and the guards that remain are the ones that matter — a cell, a
                // container's own line and a non-paragraph shape are all still excluded, so this
                // cannot eat a code body or a details title.
                if span.count == 1, top.owningTable == nil, top.secondaryKind == nil,
                   top.shape.paragraph != nil, flatLength(ofRoleAt: index) == 0 {
                    plan.replaceSubrange(span, with: roles)
                    start = flatOffset(ofRoleAt: index)
                    inserted = texts.joined(separator: "\n")
                } else {
                    let end = flatOffset(ofRoleAt: span.upperBound) + flatLength(ofRoleAt: span.upperBound)
                    plan.insert(contentsOf: roles, at: span.upperBound + 1)
                    start = end
                    inserted = "\n" + texts.joined(separator: "\n")
                }
                replaceFlat(NSRange(location: start, length: 0), with: inserted, adopting: plan)
                var offset = start + (inserted.hasPrefix("\n") ? 1 : 0)
                for block in rendered {
                    if block.length > 0 {
                        restoreStyleFlat(NSRange(location: offset, length: block.length), from: block)
                    }
                    offset += block.length + 1
                }
                engineSelectedRange = NSRange(location: offset - 1, length: 0)
            }
        }
        setNeedsLayout()
    }

    // MARK: - §7.3 the ••• menu

    /// Legacy's `handleMediaControlTapped`, account-free: the request carries closures bound to
    /// THIS block's identity, so a repeated `mediaID` can never act on the wrong occurrence.
    internal func handleMediaControlTapped(blockID: BlockID, kind: RichTextMediaControlKind, itemIndex: Int?,
                                           anchorView: UIView, sourceRect: CGRect) {
        guard let index = mediaAtomIndex(ofBlock: blockID), let shape = mediaShape(atRole: index) else { return }
        let isSpoiler = itemIndex.flatMap { shape.items.indices.contains($0) ? shape.items[$0].isSpoiler : nil }
            ?? (shape.items.first?.isSpoiler ?? false)
        let isPhotoVideo = shape.items.allSatisfy(\.kind.isPhotoOrVideo)
        let request = MediaControlRequest(
            view: anchorView, sourceRect: sourceRect, control: kind,
            mediaID: shape.items.first?.mediaID ?? "", itemIndex: itemIndex,
            delete: { [weak self] in
                if let itemIndex { self?.deleteMediaItem(blockID: blockID, itemIndex: itemIndex) }
                else { self?.deleteMediaBlock(id: blockID) }
            },
            isSpoiler: isSpoiler,
            toggleSpoiler: { [weak self] in self?.toggleMediaSpoiler(blockID: blockID, itemIndex: itemIndex) },
            replace: nil,
            addMore: { [weak self] mediaID, naturalSize, kind in
                self?.addMediaItem(blockID: blockID, mediaID: mediaID, naturalSize: naturalSize, kind: kind)
            },
            toggleLayout: (isPhotoVideo && shape.items.count >= 2)
                ? { [weak self] in self?.toggleMediaDisplayMode(blockID: blockID) } : nil)
        deferredConfiguration.onRequestMediaControl?(request)
    }

    /// The drop edit: the same covered-container rule the second Backspace takes.
    public func deleteMediaBlock(id: BlockID) {
        guard let atom = mediaAtomIndex(ofBlock: id) else { return }
        deliveringOneChangeNotification {
            performHostStructuralEdit {
                _ = replaceAcrossBlocks(NSRange(location: flatOffset(ofRoleAt: atom), length: 1), text: "", first: atom, last: atom)
            }
        }
        setNeedsLayout()
    }

    internal func deleteMediaItem(blockID: BlockID, itemIndex: Int) {
        guard let atom = mediaAtomIndex(ofBlock: blockID), let shape = mediaShape(atRole: atom),
              shape.items.indices.contains(itemIndex) else { return }
        if shape.items.count <= 1 { return deleteMediaBlock(id: blockID) }
        updateMediaShape(blockID: blockID) { $0.items.remove(at: itemIndex) }
    }

    /// An index in range flips that cell; nil or out of range flips the whole block to the
    /// negation of the FIRST item's flag, so a mixed album unifies — legacy's rule.
    internal func toggleMediaSpoiler(blockID: BlockID, itemIndex: Int?) {
        updateMediaShape(blockID: blockID) { shape in
            if let itemIndex, shape.items.indices.contains(itemIndex) {
                shape.items[itemIndex].isSpoiler.toggle()
            } else {
                let value = !(shape.items.first?.isSpoiler ?? false)
                for index in shape.items.indices { shape.items[index].isSpoiler = value }
            }
        }
    }

    /// Photo/video containers only: audio, document and location are permanently single.
    internal func addMediaItem(blockID: BlockID, mediaID: String, naturalSize: CGSize, kind: MediaKind) {
        guard kind.isPhotoOrVideo else { return }
        updateMediaShape(blockID: blockID) { shape in
            guard shape.items.allSatisfy(\.kind.isPhotoOrVideo) else { return }
            shape.items.append(MediaItem(mediaID: mediaID, kind: kind,
                                         naturalSize: Size2D(width: Double(naturalSize.width), height: Double(naturalSize.height))))
        }
    }

    internal func toggleMediaDisplayMode(blockID: BlockID) {
        updateMediaShape(blockID: blockID) { shape in
            guard shape.items.count >= 2 else { return }
            shape.displayMode = shape.displayMode == .mosaic ? .slideshow : .mosaic
        }
    }

    /// A structure-only change, `toggleChecklistItem`'s exact shape: `adoptRolePlan` settles (which
    /// re-renders the atom from its new shape), and the inverse is registered by identity.
    private func updateMediaShape(blockID: BlockID, _ change: (inout MediaShape) -> Void) {
        guard let index = mediaAtomIndex(ofBlock: blockID), let before = mediaShape(atRole: index) else { return }
        var after = before
        change(&after)
        guard after != before else { return }
        applyMediaShape(after, restoring: before, at: index)
    }

    /// The ••• verbs re-shape a medium IN PLACE, so every role they write must keep the ancestry it
    /// already had: a role rebuilt through a factory comes back at top level, which would lift a
    /// quoted medium out of its quote on the next verb with nothing to show for it — the roles are
    /// the only record of the nesting (nesting design §3.1). Hence `replacingShape` and `within`,
    /// never `.standalone(...)`/`.secondary(...)` afresh.
    private func applyMediaShape(_ shape: MediaShape, restoring previous: MediaShape, at index: Int) {
        let undoBefore = currentUndoSnapshot()
        var plan = currentRoles
        let ancestry = currentRoles[index].ancestry
        plan[index] = currentRoles[index].replacingShape(.media(shape))
        if let caption = captionIndex(ofMediaAtomAt: index) {
            plan[caption] = .secondary(owner: .block(.media(shape)), line: shape.captionLineID,
                                       kind: .mediaCaption, within: currentRoles[caption].ancestry)
        }
        let selection = engineSelectedRange
        performHostStructuralChange {
            adoptRolePlan(plan)
            // The atom's attachment carries the shape: re-derived now, not left to the next edit.
            engine.tgid_mergeAttributes(bridge.mediaAtomAttributes(for: shape, within: ancestry), removingKeys: [],
                                        inCanonicalRange: NSRange(location: flatOffset(ofRoleAt: index), length: 1))
            engineSelectedRange = selection
        }
        recordUndoStepForCommand(restoring: undoBefore)
        setNeedsLayout()
    }
}

/// The album kinds. Audio, document and location are permanently single, and three rules here say
/// so — the ••• menu's layout toggle, `addMediaItem`'s guard, and the container it appends into.
internal extension MediaKind {
    var isPhotoOrVideo: Bool { self == .image || self == .video }
}
#endif
