import UIKit

/// Hosts attachment views. It spans the whole content area (`frame = container.frame`) and is the
/// TOPMOST sibling in `contentHost`, so its hit-test rule decides whether anything below it can be
/// touched at all.
///
/// `point(inside:with:)` is therefore a strict PASSTHROUGH: the container claims a point only when one
/// of its own attachments would take it, and never merely because the point is within its bounds. It
/// does not call `super`, and that omission is the entire contract — `super` is true across the full
/// content area, so keeping it made `hitTest` return the container for every point not on an
/// attachment, and the chat's message bubbles received no touches at all. (Scrolling still worked,
/// which is what makes this easy to miss: the pan recognizer lives on an ancestor, and ancestors see
/// touches regardless of which view hit-testing settles on.)
///
/// Scanning subviews rather than deferring to bounds also serves the reason this override exists in
/// the first place: a solved attachment can sit slightly outside the window extent when a run is
/// shorter than its attachment. `clipsToBounds = false` still RENDERS it, but UIKit hit-testing clips
/// to bounds and would silently swallow its taps. A subview scan covers points inside AND outside the
/// container's bounds, so it subsumes what `super` was doing for the only case that wanted it.
///
/// The three subview tests mirror UIKit's own hit-testing criteria (`isHidden`,
/// `isUserInteractionEnabled`, effectively-invisible `alpha`). They must stay in sync with it: a point
/// this method claims but `hitTest` then declines to route into any subview resolves to the container
/// itself — the same swallowed touch, in a narrower case. That is why `alpha` is checked here even
/// though nothing currently fades an interactive attachment.
final class AttachmentContainerView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return subviews.contains { subview in
            !subview.isHidden
                && subview.isUserInteractionEnabled
                && subview.alpha > 0.01
                && subview.point(inside: convert(point, to: subview), with: event)
        }
    }
}

extension CoreVirtualListView {
    /// A run that left the live set, with the view it owned.
    struct AttachmentDeparture {
        let run: AttachmentRuns.PriorRun
        let view: UIView & CoreListAttachedItemView
    }

    /// Drops every pending departure with no fade — unbind, remove the view. This is the
    /// `rebalanceActiveWindow` path: a run scrolling out of the loaded window vanishes exactly as a
    /// row does there.
    func drainAttachmentDeparturesSilently() {
        for departure in pendingAttachmentDepartures {
            dropAttachmentSilently(departure)
        }
        pendingAttachmentDepartures.removeAll()
    }

    func dropAttachmentSilently(_ departure: AttachmentDeparture) {
        animationController.unbind(owner: .attachment(departure.run.serial),
                                   layer: departure.view.layer)
        departure.view.onContentDidChange = nil
        departure.view.removeFromSuperview()
    }

    /// Splits pending departures by WHAT LEFT.
    ///
    /// The question is whether the RUN still exists in the collection, which is not the same as
    /// whether its rows do. A run is silent — it left only the loaded window, by scrolling or by the
    /// window shrinking — iff some surviving member still publishes its key. Otherwise the run is
    /// gone from the collection and the departure is genuine.
    ///
    /// Testing row survival alone gets the merge-loser case exactly backwards: when two runs merge,
    /// every row of the losing run survives and only its KEY disappears from them, so a
    /// survival-of-rows test would call that a window exit and drop the header without a fade.
    func classifyAttachmentDepartures(newItems: [CoreListItem])
        -> (silent: [AttachmentDeparture], genuine: [AttachmentDeparture]) {
        var indexByIdentity: [AnyHashable: Int] = [:]
        indexByIdentity.reserveCapacity(newItems.count)
        for (index, item) in newItems.enumerated() {
            indexByIdentity[item.identity] = index
        }

        var silent: [AttachmentDeparture] = []
        var genuine: [AttachmentDeparture] = []
        for departure in pendingAttachmentDepartures {
            let runStillExists = departure.run.memberIdentities.contains { identity in
                guard let index = indexByIdentity[identity] else { return false }
                return newItems[index].attachedItems[departure.run.key] != nil
            }
            if runStillExists {
                silent.append(departure)
            } else {
                genuine.append(departure)
            }
        }
        return (silent, genuine)
    }

    /// Moves each genuine departure into the exit overlay at the position it last occupied and fades
    /// it out. `exitOverlay` children are positioned in CONTENT space, the same convention
    /// `makeGhostBlock` uses for its wrappers.
    func fadeDepartingAttachments(_ departures: [AttachmentDeparture],
                                  oldState: [UInt64: SettledAttachment],
                                  transition: CoreListTransition,
                                  transactionTime: TimeInterval,
                                  fadesOut: Bool) {
        for departure in departures {
            let serial = departure.run.serial
            guard let old = oldState[serial] else {
                // No sampled geometry to fade from — drop it rather than animate from nowhere.
                dropAttachmentSilently(departure)
                continue
            }
            let view = departure.view
            view.onContentDidChange = nil
            view.layer.anchorPoint = CGPoint(x: 0, y: 0)
            view.frame = CGRect(x: old.contentX,
                                y: old.contentY + old.positionOffset,
                                width: old.size.width,
                                height: old.size.height)
            exitOverlay.addSubview(view)
            fadingAttachmentViews.add(view)
            animationController.makeExit(
                owner: .attachment(serial),
                layer: view.layer,
                contentY: old.contentY + old.positionOffset,
                transition: transition,
                transactionTime: transactionTime,
                fadesOut: fadesOut
            ) { [weak self, weak view] in
                guard let view else { return }
                self?.fadingAttachmentViews.remove(view)
                view.removeFromSuperview()
            }
        }
    }

    /// Resolves every attachment run intersecting `window`, reusing views from `sourceWindow` where
    /// the witness rule inherits a serial, and finalises each run's band from its loaded members.
    ///
    /// Called at the END of window construction. A run whose head is loaded has already been
    /// measured during stacking (its reserve changes row frames); this pass resolves everything,
    /// which is not redundant: an OVERLAY attachment also needs a measured height for the solve, and
    /// a run whose head is off-window is never encountered while stacking.
    func resolveAttachments(in window: inout Window, sourceWindow: Window?) {
        guard !window.items.isEmpty else {
            window.attachments = []
            return
        }

        let loadedRange = window.startIndex..<(window.endIndex + 1)
        let pending = AttachmentRuns.pendingRuns(in: items, loadedRange: loadedRange)

        let prior: [AttachmentRuns.PriorRun] = (sourceWindow?.attachments ?? []).map { attachment in
            AttachmentRuns.PriorRun(
                key: attachment.key,
                serial: attachment.serial,
                memberIdentities: attachment.memberRange.compactMap { index in
                    priorItems.indices.contains(index) ? priorItems[index].identity : nil
                },
                edge: attachment.edge
            )
        }

        let (assigned, departed) = AttachmentRuns.assignSerials(
            pending: pending,
            newIdentities: items.map(\.identity),
            prior: prior,
            nextSerial: &nextAttachmentSerial
        )

        var viewBySerial: [UInt64: UIView & CoreListAttachedItemView] = [:]
        for attachment in sourceWindow?.attachments ?? [] {
            viewBySerial[attachment.serial] = attachment.view
        }

        var resolved: [Window.Attachment] = []
        resolved.reserveCapacity(assigned.count)

        for run in assigned {
            let view: UIView & CoreListAttachedItemView
            var isFreshView = false
            if let reused = viewBySerial[run.serial] {
                view = reused
                // Content equality is compared against the RUN REPRESENTATIVE, independently of the
                // row's own `isEqual`: an avatar whose story ring changed must reconfigure even when
                // the row it hangs off did not.
                let previous = appliedAttachmentDescriptors[run.serial]
                if previous == nil || !previous!.isEqual(to: run.representative) {
                    run.representative.apply(to: view, transition: currentPassTransition)
                    reconciledAttachmentSerials.insert(run.serial)
                }
            } else {
                view = run.representative.view()
                isFreshView = true
            }
            appliedAttachmentDescriptors[run.serial] = run.representative
            bindAttachmentSelfUpdate(view: view, serial: run.serial)

            let height = view.update(width: contentWidth,
                                     transition: attachmentMeasureTransition(serial: run.serial,
                                                                             isFreshView: isFreshView))

            let members = window.items.filter { run.memberRange.contains($0.index) }
            let bandTop = members.map(\.frame.minY).min() ?? 0
            // `updateItemHeaders`' per-item `itemMaxY` (Display/Source/ListView.swift:4274-4279),
            // which trims the run's far bound by the member's own inset unless the header sticks over
            // insets. Taken as a max over trimmed member bounds rather than ListViewImpl's "whatever
            // the last member computed": the two agree whenever a trim is smaller than the row it
            // trims (always, since the trim IS part of that row), and the max cannot invert the band.
            let bandBottom = run.representative.spansMemberInsets
                ? (members.map(\.frame.maxY).max() ?? 0)
                : (members.map { $0.frame.maxY - $0.view.attachmentBandTrim }.max() ?? 0)

            resolved.append(Window.Attachment(key: run.key,
                                              serial: run.serial,
                                              view: view,
                                              memberRange: run.memberRange,
                                              measuredHeight: height,
                                              placement: run.representative.placement,
                                              edge: run.representative.edge,
                                              isFloating: run.representative.isFloating,
                                              startsCollectionRun: run.pending.startsCollectionRun,
                                              endsCollectionRun: run.pending.endsCollectionRun,
                                              stackingGroup: run.representative.stackingGroup,
                                              stackingYield: run.representative.stackingYield,
                                              bandTop: bandTop,
                                              bandBottom: bandBottom))
        }

        for run in departed {
            appliedAttachmentDescriptors.removeValue(forKey: run.serial)
        }

        // A serial that no new run claimed leaves the live set. RECORD it and decide nothing: this
        // runs from both `buildWindow` and `rebalanceActiveWindow`, and only the enclosing pass knows
        // whether the run left the loaded window (silent) or the collection (a genuine departure).
        let survivingSerials = Set(resolved.map(\.serial))
        let priorBySerial = Dictionary(uniqueKeysWithValues: prior.map { ($0.serial, $0) })
        for attachment in sourceWindow?.attachments ?? []
        where !survivingSerials.contains(attachment.serial) {
            guard let priorRun = priorBySerial[attachment.serial] else { continue }
            pendingAttachmentDepartures.append(
                AttachmentDeparture(run: priorRun, view: attachment.view))
        }

        window.attachments = resolved
    }

    /// The transition an attachment is measured with — the same two cases a row gets from
    /// `measureTransition(forItemAt:view:)`: non-immediate when the attachment has to RE-LAY-OUT and
    /// has a prior layout to animate from, meaning its own content was reconciled OR the pass changed
    /// `contentWidth` and it is being re-measured at a new width.
    ///
    /// The width case is if anything more visible here than for rows: a chat date pill CENTRES itself
    /// in `contentWidth`, so a side inset moves it across the screen. Measuring `.immediate` there
    /// snapped the pill while every row animated.
    ///
    /// `isFreshView` outranks the width case — a view created in this pass has no prior layout to
    /// animate from. It is passed in rather than tracked in a set (as rows do with
    /// `freshViewsThisPass`) because an attachment's only creation site sits a few lines above its
    /// only measure.
    private func attachmentMeasureTransition(serial: UInt64, isFreshView: Bool) -> CoreListTransition {
        if isFreshView { return .immediate }
        if contentWidthChangedInPass { return currentPassTransition }
        return reconciledAttachmentSerials.contains(serial) ? currentPassTransition : .immediate
    }

    /// Routes an attachment's self-update into the same coalesced dirty flush rows use. Every pass
    /// re-measures every loaded attachment, so this only has to TRIGGER a pass — there is no
    /// per-attachment dirty set to maintain.
    func bindAttachmentSelfUpdate(view: UIView & CoreListAttachedItemView, serial: UInt64) {
        view.onContentDidChange = { [weak self] animated in
            self?.markAttachmentsDirty(animated: animated)
        }
    }

    /// Animation key for an attachment's flight track. Distinct from every `ListAnimationController`
    /// key, because the controller must remain free to replace its own position track independently.
    static let attachmentFlightKey = "coreListAttachmentFlight"

    /// Installs — or removes — the baked flight track on every loaded attachment.
    ///
    /// Called at the end of `renderAttachments`, so it re-derives whenever the window, the bands or
    /// the flight itself change. Re-deriving on a rebake is not a special case: `onFlightChanged`
    /// fires for a re-emit exactly as it does for a launch.
    func installAttachmentFlightTracks(window: Window) {
        guard let flight = activeScrollFlight, flight.trajectory.duration > 0 else {
            for attachment in window.attachments {
                attachment.view.layer.removeAnimation(forKey: Self.attachmentFlightKey)
            }
            return
        }

        for attachment in window.attachments {
            let composed = attachmentMap(attachment, window: window)
                .composedKeyframe(trajectory: flight.trajectory,
                                  coordinateShift: flight.coordinateShift)
            // A rigid attachment rides the content translation and needs no track of its own.
            guard composed.values.contains(where: { abs($0) > 1e-9 }) else {
                attachment.view.layer.removeAnimation(forKey: Self.attachmentFlightKey)
                continue
            }
            let animation = CAKeyframeAnimation(keyPath: "position.y")
            animation.isAdditive = true
            // `.linear` for the same reason `Trajectory.boundsOriginKeyframeAnimation` uses it: the
            // vertices are baked at 120/s, and `.discrete` playback beats on a display running below
            // that. Linear interpolation is rate-agnostic, and the per-frame solve interpolates the
            // same way, so sampler and render agree.
            animation.calculationMode = .linear
            animation.values = composed.values.map { NSNumber(value: Double($0)) }
            animation.keyTimes = composed.keyTimes.map { NSNumber(value: $0) }
            animation.duration = flight.trajectory.duration
            animation.beginTime = flight.beginTime
            animation.preferHighRefreshRate()
            attachment.view.layer.add(animation, forKey: Self.attachmentFlightKey)
        }
    }

    /// The offset attachments solve at.
    ///
    /// During a baked flight this is the flight's DESTINATION, mirroring `PhysicsScrollEngine`, which
    /// parks `host.bounds.origin.y` at `trajectory.finalOffset` and adds an additive keyframe over it.
    /// Solving at the live offset instead would move the base per frame WHILE the composed animation
    /// displaced it, roughly doubling the header's travel.
    var attachmentSolveOffset: CGFloat {
        // `settledOffset`, NOT `trajectory.finalOffset`: the trajectory's offsets are in the base it
        // was baked in, and window rebalancing re-bases the container mid-flight. Parking against the
        // raw final offset leaves attachments positioned where the flight WOULD have landed before
        // the re-base — measured drifting to 1330pt stale over one fling.
        activeScrollFlight?.settledOffset ?? engine.offset
    }

    /// Solves every loaded attachment and writes its settled frame. Pure function of the settled
    /// window and the solve offset, so running it twice in one turn is a no-op.
    func renderAttachments() {
        let window = activeWindow
        attachmentContainer.frame = container.frame

        let live = Set(window.attachments.map { ObjectIdentifier($0.view) })
        for subview in attachmentContainer.subviews
        where !live.contains(ObjectIdentifier(subview)) {
            subview.removeFromSuperview()
        }

        guard !window.items.isEmpty else { return }

        let offset = attachmentSolveOffset
        // Row → the attachments hanging off it this frame. Accumulated during the solve because `y`
        // below is the attachment's position in WINDOW space, the same space `item.frame` is in, so the
        // intersection is a subtraction rather than a view-tree conversion.
        var boundAttachments: [ObjectIdentifier: [UIView & CoreListAttachedItemView]] = [:]
        for (index, attachment) in window.attachments.enumerated() {
            let map = attachmentMap(attachment, window: window)
            let y = map.y(atOffset: offset)
            if let owner = attachmentOwner(attachment, solvedY: y, window: window) {
                boundAttachments[ObjectIdentifier(owner), default: []].append(attachment.view)
            }
            attachment.view.frame = CGRect(x: viewportInsets.left,
                                           y: y - window.minY,
                                           width: contentWidth,
                                           height: attachment.measuredHeight)
            // Sibling order IS z-order, and it must follow the attachment sort rather than the order
            // views happened to be created in. Appending only the new ones would leave a yielding
            // attachment ABOVE the group it defers to whenever the two runs enter the loaded window
            // in different passes, which is the common case — `pendingRuns` sinks the yielder, but a
            // view that outlives the pass that created it never revisits its position.
            //
            // Every subview here is a live attachment view: the loop above removed the rest.
            let siblings = attachmentContainer.subviews
            if index >= siblings.count || siblings[index] !== attachment.view {
                attachmentContainer.insertSubview(attachment.view, at: index)
            }
            // The frame solves at `attachmentSolveOffset` — the flight's DESTINATION while one is
            // playing, because an additive CAKeyframeAnimation supplies the displacement and moving
            // the model base under it would double the travel. The stick distance must solve at the
            // LIVE offset instead: nothing on the render server carries it, so the value has to
            // describe where the attachment IS. The two agree by construction — the baked track is
            // this same `y(atOffset:)` sampled along the trajectory — and there are frames to
            // deliver on, because the flight sampler calls `onScroll` per frame
            // (PhysicsScrollEngine.swift:297) and `handleUserScroll` calls this method
            // unconditionally.
            attachment.view.stickDistanceUpdated(map.stickDistance(atOffset: engine.offset))
            // Seed HERE rather than in the animation transaction, because attachments are also
            // created by `rebuildFromScratch` and `rebalanceActiveWindow`, neither of which runs that
            // transaction. Seeding only there left the model with no width/height for those owners,
            // so the next pass transitioned a changed extent FROM zero. `seedAttachment` no-ops when
            // the owner already has state, so this is safe on every frame.
            animationController.seedAttachment(owner: .attachment(attachment.serial),
                                               layer: attachment.view.layer)
        }

        // Every loaded row, not just the bound ones: a row that just LOST its attachment has to hear
        // that, and it is the empty case that says so.
        for item in window.items {
            item.view.attachedItemsUpdated(boundAttachments[ObjectIdentifier(item.view)] ?? [])
        }

        installAttachmentFlightTracks(window: window)
    }

    /// The member row an attachment currently hangs off: the one it overlaps most, and nil when it
    /// overlaps none. `Display/Source/ListView.swift:4203-4221` verbatim, including the guard that a
    /// zero-height intersection binds nothing.
    ///
    /// Restricted to the run's members, which is what makes the search well-posed rather than merely
    /// cheaper: a floating attachment parked at its band edge sits flush against the NEXT run, so
    /// "the row I overlap most" over ALL rows could name a row this attachment does not belong to.
    private func attachmentOwner(_ attachment: Window.Attachment,
                                 solvedY: CGFloat,
                                 window: Window) -> (UIView & CoreListItemView)? {
        let rect = CGRect(x: 0.0, y: solvedY, width: contentWidth, height: attachment.measuredHeight)
        var best: (intersection: CGFloat, view: UIView & CoreListItemView)?
        for item in window.items where attachment.memberRange.contains(item.index) {
            let intersection = item.frame.intersection(rect).height
            if best == nil || intersection > best!.intersection {
                best = (intersection, item.view)
            }
        }
        guard let best, best.intersection > 0.0 else { return nil }
        return best.view
    }

    /// Geometry is passed in rather than read from `self` because the pass needs to solve the OLD
    /// state against the OLD container origin, insets, logical height and offset. Reading current
    /// geometry here would solve the old state against new values — the same class of error as
    /// solving against a pre-pass offset.
    func attachmentMap(_ attachment: Window.Attachment,
                       window: Window,
                       containerOriginY: CGFloat,
                       insets: UIEdgeInsets,
                       logicalHeight: CGFloat) -> AttachmentOffsetMap {
        let reserveTop = attachment.placement == .reservesSpace
            && attachment.edge == .top
            && attachment.startsCollectionRun
            ? attachment.measuredHeight : 0
        let reserveBottom = attachment.placement == .reservesSpace
            && attachment.edge == .bottom
            && attachment.endsCollectionRun
            ? attachment.measuredHeight : 0
        let anchor = attachment.edge == .top
            ? insets.top
            : logicalHeight - insets.bottom - attachment.measuredHeight
        var yield: (partners: [AttachmentOffsetMap], gap: CGFloat)?
        if let declared = attachment.stackingYield {
            // The partners are the OTHER attachments tagged into the named group. Built here rather
            // than cached because a map is a value derived from THIS pass's band geometry.
            //
            // The recursion terminates on the one-level rule: a partner is a group member, and a
            // group member does not itself yield (asserted in `AttachmentOffsetMap.y(atOffset:)`).
            let partners = window.attachments
                .filter { $0.stackingGroup == declared.group && $0.serial != attachment.serial }
                .map { attachmentMap($0,
                                     window: window,
                                     containerOriginY: containerOriginY,
                                     insets: insets,
                                     logicalHeight: logicalHeight) }
            if !partners.isEmpty {
                yield = (partners: partners, gap: declared.gap)
            }
        }
        return AttachmentOffsetMap(bandTop: attachment.bandTop - reserveTop,
                                   bandBottom: attachment.bandBottom + reserveBottom,
                                   height: attachment.measuredHeight,
                                   anchor: anchor,
                                   contentBase: containerOriginY - window.minY,
                                   edge: attachment.edge,
                                   isFloating: attachment.isFloating,
                                   yield: yield)
    }

    /// Current-geometry convenience for the render and query paths.
    func attachmentMap(_ attachment: Window.Attachment, window: Window) -> AttachmentOffsetMap {
        attachmentMap(attachment,
                      window: window,
                      containerOriginY: containerOriginY,
                      insets: viewportInsets,
                      logicalHeight: logicalSize.height)
    }

    /// Space reserved above and below the row at `index`, measured at `width`.
    ///
    /// Local by construction: a run starts at `index` iff `items[index - 1]` does not continue it, so
    /// no window and no global scan are needed — which is what makes this callable from the middle of
    /// row stacking, where the reserve changes the very frames being computed.
    func reservedHeights(atIndex index: Int,
                         width: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        guard items.indices.contains(index) else { return (0, 0) }
        var top: CGFloat = 0
        var bottom: CGFloat = 0
        var reservingTopKeys = 0
        var reservingBottomKeys = 0

        // A single-row range still classifies boundaries correctly: `pendingRuns` consults
        // `index - 1` and `index + 1` in the full collection regardless of the range it was given.
        for run in AttachmentRuns.pendingRuns(in: items, loadedRange: index..<(index + 1))
        where run.placement == .reservesSpace {
            let startsHere = run.edge == .top && run.startsCollectionRun
            let endsHere = run.edge == .bottom && run.endsCollectionRun
            guard startsHere || endsHere else { continue }

            let height = measuredAttachmentHeight(for: run, width: width)
            if startsHere {
                top += height
                reservingTopKeys += 1
            } else {
                bottom += height
                reservingBottomKeys += 1
            }
        }

        assert(reservingTopKeys <= 1 && reservingBottomKeys <= 1,
               "at most one space-reserving attachment per edge per run boundary: two would need a "
                 + "stacking order and AnyHashable supplies none")
        return (top, bottom)
    }

    /// Measures a reserving run during stacking, to learn how much space to reserve for it.
    ///
    /// Measures a THROWAWAY view, never the live one. This used to reuse the previous window's view
    /// for the same key — the stated reason being that the height would then match what
    /// `resolveAttachments` settles on — and that reuse was the bug: `update(width:transition:)` both
    /// measures AND lays out, so probing a live view laid it out at the target with `.immediate`. The
    /// real measure that followed then found every setter already at its target and, because
    /// transition setters early-out on an equal target, animated nothing. Reserving attachments could
    /// not animate their internals at all, for a width change or a content change.
    ///
    /// A throwaway restores the invariant that a live view is laid out exactly ONCE per pass, and it
    /// does not cost accuracy — it arguably gains some. The height is a pure function of the current
    /// descriptor, and a throwaway is built from `run.representative`, i.e. exactly the descriptor
    /// `resolveAttachments` is about to `apply(to:)` the live view. The old reuse measured the live
    /// view BEFORE that apply, so a run whose content changed reserved space for its previous
    /// content. This is also the path the no-existing-view case already took, so it is one trusted
    /// path replacing two rather than a new one.
    ///
    /// Cost is one view construction per reserving run per pass — zero for a list with no
    /// `.reservesSpace` attachments, which includes the chat backend (`.overlay` throughout). The
    /// throwaway is never parented, never bound via `bindAttachmentSelfUpdate`, and is released
    /// immediately.
    private func measuredAttachmentHeight(for run: AttachmentRuns.PendingRun,
                                          width: CGFloat) -> CGFloat {
        run.representative.view().update(width: width, transition: .immediate)
    }

    /// One attachment's settled presentation at a moment in a pass. `contentY` uses the same
    /// convention `settledState` uses for a row — `containerOriginY + localY` — so an attachment's
    /// position track is an additive correction on exactly the same terms.
    struct SettledAttachment {
        let serial: UInt64
        let view: UIView & CoreListAttachedItemView
        let contentX: CGFloat
        let contentY: CGFloat
        /// The same position in SCREEN space — `contentY` minus the offset this snapshot was taken
        /// at. Position tracks compare THIS, not `contentY`.
        ///
        /// A pass can rebase the coordinate system underneath a settled attachment: dropping out of
        /// "top loaded" moves the list onto the engine's private ~10,000,000-point virtual canvas, so
        /// `containerOriginY` and `offset` both jump by millions while nothing moves on screen.
        /// Comparing `contentY` across that boundary produces a multi-million-point track on every
        /// attachment. Rows avoid it by routing their endpoints through `transitionCoordinates`,
        /// which maps old coordinates into the new base; screen space is base-independent by
        /// construction, which is the same guarantee without the bookkeeping.
        let screenY: CGFloat
        let size: CGSize
        let positionOffset: CGFloat
    }

    /// `offset` is the SETTLED engine offset — the solve is settled geometry and must use it.
    /// `viewportCorrection` is the additive displacement the shared viewport track is applying on top
    /// of that, and it is subtracted from `screenY` so the comparison is relative to the RENDERED
    /// viewport. Without it, a programmatic scroll's displacement lands in both the viewport track and
    /// each attachment's own track: the two cancel at t=0 and every floating attachment sits at its
    /// destination while the content is still travelling.
    func settledAttachmentState(_ window: Window,
                                containerOriginY: CGFloat,
                                insets: UIEdgeInsets,
                                logicalHeight: CGFloat,
                                offset: CGFloat,
                                viewportCorrection: CGFloat,
                                at time: TimeInterval) -> [UInt64: SettledAttachment] {
        Dictionary(uniqueKeysWithValues: window.attachments.map { attachment in
            let map = attachmentMap(attachment,
                                    window: window,
                                    containerOriginY: containerOriginY,
                                    insets: insets,
                                    logicalHeight: logicalHeight)
            let localY = map.y(atOffset: offset) - window.minY
            return (
                attachment.serial,
                SettledAttachment(
                    serial: attachment.serial,
                    view: attachment.view,
                    contentX: insets.left,
                    contentY: containerOriginY + localY,
                    screenY: containerOriginY + localY - offset - viewportCorrection,
                    size: CGSize(width: contentWidthFor(insets: insets,
                                                        logicalWidth: logicalSize.width),
                                 height: attachment.measuredHeight),
                    positionOffset: animationController.positionOffset(
                        owner: .attachment(attachment.serial), at: time) ?? 0
                )
            )
        })
    }

    /// Content width for a given inset set — the pass needs the OLD width when snapshotting old
    /// state, and `contentWidth` reads current geometry.
    private func contentWidthFor(insets: UIEdgeInsets, logicalWidth: CGFloat) -> CGFloat {
        max(0, logicalWidth - insets.left - insets.right)
    }

    /// Transitions every surviving attachment's changed settled geometry, on the same rules rows
    /// obey: an unchanged value within `1e-6` is an exact no-op preserving generation, phase, curve
    /// and deadline; a changed one replaces only that property from its analytic current value.
    func transitionAttachments(old: [UInt64: SettledAttachment],
                               new: [UInt64: SettledAttachment],
                               transition: CoreListTransition,
                               transactionTime: TimeInterval,
                               fadesInSerials: Set<UInt64>) {
        for (serial, newState) in new {
            let owner = ListAnimationOwner.attachment(serial)
            guard let oldState = old[serial] else {
                // A serial with no old state is either genuinely new or newly loaded; `renderAttachments`
                // has already seeded it. Only the former fades.
                if fadesInSerials.contains(serial) {
                    animationController.insert(owner: owner,
                                               layer: newState.view.layer,
                                               transition: transition,
                                               transactionTime: transactionTime)
                }
                continue
            }
            // `oldSettledY` is the ANALYTIC CURRENT position, not the old settled endpoint — that is
            // what guarantees C0 continuity when a pass interrupts a running track, and it is exactly
            // what the row path passes.
            // SCREEN space, not content space: a coordinate rebase (dropping out of "top loaded"
            // moves the list onto the engine's virtual canvas) shifts contentY by millions while
            // nothing moves on screen. Screen positions are base-independent, so a pure rebase is an
            // exact no-op here and a genuine move still starts a track. This is the same frame the
            // row path uses — `transitionCoordinates` returns `contentY - offset`.
            //
            // Pass the old SETTLED position, NOT the presented one. The model computes
            // `currentVisibleY = oldSettledY + currentOffset` itself (`transitionPositionOffset`), so
            // adding the live correction here counts it twice: under overlapping passes the track's
            // `from` grows as `delta + 2 × correction` and roughly doubles per pass — 95, 274, 613,
            // 1252, 2458 — which reads as a violent snap. It also breaks the unchanged-detection,
            // since a parked attachment with a live correction would compare unequal and animate.
            animationController.transitionPosition(
                owner: owner,
                layer: newState.view.layer,
                oldSettledY: oldState.screenY,
                newSettledY: newState.screenY,
                transition: transition,
                transactionTime: transactionTime
            )
            animationController.transitionPositionX(
                owner: owner,
                layer: newState.view.layer,
                oldSettledX: oldState.contentX,
                newSettledX: newState.contentX,
                transition: transition,
                transactionTime: transactionTime
            )
            animationController.transitionWidth(
                owner: owner,
                layer: newState.view.layer,
                oldSettledWidth: oldState.size.width,
                newSettledWidth: newState.size.width,
                transition: transition,
                transactionTime: transactionTime
            )
            animationController.transitionHeight(
                owner: owner,
                layer: newState.view.layer,
                oldSettledHeight: oldState.size.height,
                newSettledHeight: newState.size.height,
                transition: transition,
                transactionTime: transactionTime
            )
        }
    }

    /// Which fresh serials fade in.
    ///
    /// A fresh serial already means "no old run of this key overlapped these rows" — the witness rule
    /// guarantees it — so freshness ALONE does not separate new content from newly loaded content.
    /// The run must additionally contain a genuine insert or a reconciled member.
    func fadingInAttachmentSerials(window: Window,
                                   existingSerials: Set<UInt64>,
                                   insertedIdentities: Set<AnyHashable>,
                                   reconciledIdentities: Set<AnyHashable>) -> Set<UInt64> {
        var result: Set<UInt64> = []
        for attachment in window.attachments where !existingSerials.contains(attachment.serial) {
            let members = attachment.memberRange.compactMap { index -> AnyHashable? in
                items.indices.contains(index) ? items[index].identity : nil
            }
            let isNewContent = members.contains { insertedIdentities.contains($0) }
                || members.contains { reconciledIdentities.contains($0) }
            if isNewContent { result.insert(attachment.serial) }
        }
        return result
    }

    /// Screen y of a loaded attachment. Test/host affordance; mirrors how a row's screen position is
    /// derived rather than stored.
    func attachmentScreenY(serial: UInt64) -> CGFloat? {
        let window = activeWindow
        guard let attachment = window.attachments.first(where: { $0.serial == serial })
        else { return nil }
        return attachmentMap(attachment, window: window).y(atOffset: engine.offset)
            + containerOriginY - window.minY - engine.offset
    }
}
