//
//  ViewController.swift
//  CoreListDemo
//
//  Created by Isaac on 21/03/2026.
//

import UIKit

final class ViewController: UIViewController {
    private let autoLoadResponseScheduler: AutoLoadResponseScheduling
    private lazy var listView: CoreVirtualListView = {
        let engine = PhysicsScrollEngine()
        engine.decelerationMode = .keyframe
        return CoreVirtualListView(engine: engine)
    }()
    private let engineControl = UISegmentedControl(items: ["UIScrollView", "Physics·step", "Physics·keyframe"])
    /// Flips `PhysicsScrollEngine.pinsMaximumRefreshRate` so a device session can A/B the rigid
    /// 120Hz request against an adaptive one on the SAME gesture, without a rebuild. Demo-only.
    private let rateControl = UISegmentedControl(items: ["120 all", "anim120·link60", "120 adaptive"])
    private let topBar = UIStackView()
    private let jumpButton = UIButton(type: .system)
    private let topButton = UIButton(type: .system)
    private let growButton = UIButton(type: .system)
    private let chaosButton = UIButton(type: .system)
    private let autoLoadButton = UIButton(type: .system)
    private let moveButton = UIButton(type: .system)
    private let sizeSwapButton = UIButton(type: .system)
    private let sizeSwapDelayedButton = UIButton(type: .system)
    private let insetButton = UIButton(type: .system)
    private let mixedVerticalJumpButton = UIButton(type: .system)
    private let mixedHorizontalReplaceButton = UIButton(type: .system)
    private let mixedSizeSwapButton = UIButton(type: .system)
    private let mixedHorizontalSizeFiveButton = UIButton(type: .system)
    private let groupsButton = UIButton(type: .system)
    /// Run length for the demo's attachment groups; cycled by `cycleGroupSize`.
    private var groupSize = 6
    private let listOuterBoundsOverlay: UIView = {
        let view = UIView()
        view.accessibilityIdentifier = "ListOuterBoundsOverlay"
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.layer.borderColor = UIColor.systemBlue.cgColor
        view.layer.borderWidth = 2
        return view
    }()
    private let insetRectOverlay: UIView = {
        let view = UIView()
        view.accessibilityIdentifier = "InsetRectOverlay"
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.layer.borderColor = UIColor.systemRed.cgColor
        view.layer.borderWidth = 2
        return view
    }()
    private let insetRectAnimator = InsetRectOverlayAnimator()
    private let infoLabel = UILabel()
    private var chromeInsets: UIEdgeInsets = .zero
    private var testInsets: UIEdgeInsets = .zero
    private var effectiveInsets: UIEdgeInsets {
        UIEdgeInsets(top: chromeInsets.top + testInsets.top,
                     left: chromeInsets.left + testInsets.left,
                     bottom: chromeInsets.bottom + testInsets.bottom,
                     right: chromeInsets.right + testInsets.right)
    }
    private var mixedFiveIdentities: Set<AnyHashable> = []
    /// While non-nil, fires `chaosTick` on an interval — random insert or delete via applyChanges.
    /// Toggled by `chaosButton`. Demo affordance for stressing 4c mid-flight (the user picks the
    /// `.keyframe` engine, flicks, then hits Chaos to verify the flight survives applyChanges).
    private var chaosTimer: Timer?
    private static let autoLoadResponseDelay: TimeInterval = 0.2
    private var autoLoadEnabled = false
    private var queuedAutoLoadEdges: Set<CoreListLoadedEdge> = []
    private var inFlightAutoLoadEdges: Set<CoreListLoadedEdge> = []
    private var autoLoadRequestFormationScheduled = false
    private var autoLoadGeneration = 0

    init(
        autoLoadResponseScheduler: AutoLoadResponseScheduling =
            MainQueueAutoLoadResponseScheduler()
    ) {
        self.autoLoadResponseScheduler = autoLoadResponseScheduler
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        autoLoadResponseScheduler = MainQueueAutoLoadResponseScheduler()
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        // Debug-only physics tracing, enabled from the DEMO so the shipping app stays inert (this file
        // is excluded from the Bazel CoreList library). Writes Documents/flight-trace.txt per flight.
        FlightTrace.isEnabled = true

        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        topBar.axis = .vertical
        topBar.alignment = .fill
        topBar.spacing = 8

        topButton.setTitle("Top", for: .normal)
        topButton.addTarget(self, action: #selector(scrollToTop), for: .touchUpInside)

        jumpButton.setTitle("Jump to 40", for: .normal)
        jumpButton.addTarget(self, action: #selector(jumpToForty), for: .touchUpInside)

        let plus1 = UIButton(type: .system)
        plus1.setTitle("+1", for: .normal)
        plus1.addTarget(self, action: #selector(insertOne), for: .touchUpInside)

        let minus1 = UIButton(type: .system)
        minus1.setTitle("-1", for: .normal)
        minus1.addTarget(self, action: #selector(deleteOne), for: .touchUpInside)

        let plus5 = UIButton(type: .system)
        plus5.setTitle("+5", for: .normal)
        plus5.addTarget(self, action: #selector(insertFive), for: .touchUpInside)

        let minus5 = UIButton(type: .system)
        minus5.setTitle("-5", for: .normal)
        minus5.addTarget(self, action: #selector(deleteFive), for: .touchUpInside)

        // Insert at the first position, or delete the first or last item. Scroll to that edge first
        // to inspect the granular survivor movement and the final edge alignment.
        let plusTop = UIButton(type: .system)
        plusTop.setTitle("+top", for: .normal)
        plusTop.addTarget(self, action: #selector(insertTop), for: .touchUpInside)

        let minusTop = UIButton(type: .system)
        minusTop.setTitle("-top", for: .normal)
        minusTop.addTarget(self, action: #selector(deleteTop), for: .touchUpInside)

        let minusBottom = UIButton(type: .system)
        minusBottom.setTitle("-bottom", for: .normal)
        minusBottom.addTarget(self, action: #selector(deleteBottom), for: .touchUpInside)

        let loadFive = UIButton(type: .system)
        loadFive.setTitle("Load +5", for: .normal)
        loadFive.addTarget(self, action: #selector(loadFiveAtTop), for: .touchUpInside)

        let unloadFive = UIButton(type: .system)
        unloadFive.setTitle("Load -5", for: .normal)
        unloadFive.addTarget(self, action: #selector(unloadFiveAtTop), for: .touchUpInside)

        insetButton.setTitle("Inset +300", for: .normal)
        insetButton.addTarget(self, action: #selector(toggleTopInset), for: .touchUpInside)

        groupsButton.setTitle("Groups", for: .normal)
        groupsButton.addTarget(self, action: #selector(cycleGroupSize), for: .touchUpInside)

        // Replacement affordances: "Del/Add" swaps identities in one transaction; the delayed
        // variant starts the insertion while the departure fade and survivor motion are active.
        let delAddButton = UIButton(type: .system)
        delAddButton.setTitle("Del/Add", for: .normal)
        delAddButton.addTarget(self, action: #selector(delAdd), for: .touchUpInside)

        let delAddDelayedButton = UIButton(type: .system)
        delAddDelayedButton.setTitle("Del/Add+0.1s", for: .normal)
        delAddDelayedButton.addTarget(self, action: #selector(delAddDelayed), for: .touchUpInside)

        // "Grow" exercises immediate self-update geometry composed with any affected active position
        // property. "Chaos" produces mixed insert/delete passes, including during deceleration.
        growButton.setTitle("Grow", for: .normal)
        growButton.addTarget(self, action: #selector(growCenter), for: .touchUpInside)

        chaosButton.setTitle("Chaos", for: .normal)
        chaosButton.addTarget(self, action: #selector(toggleChaos), for: .touchUpInside)

        autoLoadButton.setTitle("Auto Load", for: .normal)
        autoLoadButton.addTarget(self, action: #selector(toggleAutoLoad), for: .touchUpInside)

        // Same-identity reorder: the reused views animate only their changed position property.
        moveButton.setTitle("Swap 2↔5", for: .normal)
        moveButton.addTarget(self, action: #selector(moveSwap), for: .touchUpInside)

        // Same swap plus content reconciliation. Size geometry applies immediately while affected
        // position properties follow the granular transition rule.
        sizeSwapButton.setTitle("Swap 2-5+size", for: .normal)
        sizeSwapButton.addTarget(self, action: #selector(moveSwapWithSize), for: .touchUpInside)

        // The size-only follow-up writes geometry immediately. Changed affected position tracks retarget
        // continuously; unchanged and unrelated tracks retain their identity, phase, and deadline.
        sizeSwapDelayedButton.setTitle("Swap 2-5, +size 0.1s", for: .normal)
        sizeSwapDelayedButton.addTarget(self, action: #selector(moveSwapThenSizeDelayed), for: .touchUpInside)

        mixedVerticalJumpButton.addTarget(
            self, action: #selector(mixedVerticalInsetJump), for: .touchUpInside
        )
        mixedHorizontalReplaceButton.addTarget(
            self, action: #selector(mixedHorizontalInsetDelAdd), for: .touchUpInside
        )
        mixedSizeSwapButton.addTarget(
            self, action: #selector(mixedFirstSizeSwap), for: .touchUpInside
        )
        mixedHorizontalSizeFiveButton.addTarget(
            self, action: #selector(mixedHorizontalSizeFive), for: .touchUpInside
        )

        engineControl.selectedSegmentIndex = 2
        engineControl.addTarget(self, action: #selector(engineChanged), for: .valueChanged)
        rateControl.selectedSegmentIndex = 0
        rateControl.addTarget(self, action: #selector(rateChanged), for: .valueChanged)

        infoLabel.text = "Virtual list demo"
        infoLabel.font = .systemFont(ofSize: 13, weight: .medium)
        infoLabel.textColor = .secondaryLabel

        // Row 1: data-editing actions (left) + status label (right), pushed apart by a spacer.
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let actionsRow = UIStackView(arrangedSubviews: [topButton, jumpButton, plus1, minus1, plus5, minus5, spacer, infoLabel])
        actionsRow.axis = .horizontal
        actionsRow.spacing = 12
        actionsRow.alignment = .center

        // Row 2: manual checkpoint affordances on their own row so they don't crowd row 1. The
        // trailing spacer keeps the buttons left-aligned (they hug their intrinsic content).
        let testSpacer = UIView()
        testSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let testRow = UIStackView(arrangedSubviews: [
            growButton, chaosButton, autoLoadButton, moveButton, sizeSwapButton,
            sizeSwapDelayedButton, testSpacer,
        ])
        testRow.axis = .horizontal
        testRow.spacing = 12
        testRow.alignment = .center

        // Row 3: edge-mutation affordances (the panel outgrew two rows) — left-aligned via a spacer.
        let edgeSpacer = UIView()
        edgeSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let edgeRow = UIStackView(arrangedSubviews: [
            plusTop, minusTop, minusBottom, loadFive, unloadFive, insetButton,
            delAddButton, delAddDelayedButton, edgeSpacer,
        ])
        edgeRow.axis = .horizontal
        edgeRow.spacing = 12
        edgeRow.alignment = .center

        let mixedSpacer1 = UIView()
        mixedSpacer1.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let mixedRow1 = UIStackView(arrangedSubviews: [
            mixedVerticalJumpButton, mixedHorizontalReplaceButton, mixedSpacer1,
        ])
        mixedRow1.axis = .horizontal
        mixedRow1.spacing = 12
        mixedRow1.alignment = .center

        let mixedSpacer2 = UIView()
        mixedSpacer2.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let mixedRow2 = UIStackView(arrangedSubviews: [
            mixedSizeSwapButton, mixedHorizontalSizeFiveButton, groupsButton, mixedSpacer2,
        ])
        mixedRow2.axis = .horizontal
        mixedRow2.spacing = 12
        mixedRow2.alignment = .center

        topBar.addArrangedSubview(actionsRow)
        topBar.addArrangedSubview(testRow)
        topBar.addArrangedSubview(edgeRow)
        topBar.addArrangedSubview(mixedRow1)
        topBar.addArrangedSubview(mixedRow2)
        topBar.addArrangedSubview(engineControl)
        topBar.addArrangedSubview(rateControl)

        listView.preloadMargin = 200
        bindAutoLoading(to: listView)
        listView.items = DemoListItem.makeItems(nestedScrollerEvery: 5)
        refreshMixedControlTitles()

        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(listView)
        view.addSubview(listOuterBoundsOverlay)
        view.addSubview(insetRectOverlay)
        view.addSubview(topBar)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    // The list has no autolayout constraints. It receives the controller's full bounds; the controller
    // expresses its chrome as content insets, keeping parent-space geometry out of the list model.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        chromeInsets = UIEdgeInsets(top: topBar.frame.maxY + 12,
                                    left: 0,
                                    bottom: view.safeAreaInsets.bottom,
                                    right: 0)
        let newSize = view.bounds.size
        let insets = effectiveInsets
        listView.frame = view.bounds
        listOuterBoundsOverlay.frame = view.bounds
        insetRectOverlay.frame = view.bounds.inset(by: insets)

        guard listView.logicalSize != newSize
                || listView.viewportGeometry.insets != insets else { return }
        listView.applyChanges(newSize: newSize,
                              newInsets: insets,
                              transition: .easeInOut(duration: 0))
    }

    /// Takes effect on the NEXT flight — an in-flight animation keeps the range it was emitted with.
    @objc private func rateChanged() {
        switch rateControl.selectedSegmentIndex {
        case 0:     // shipped: animation AND sampling link pinned to the max rate
            PhysicsScrollEngine.pinsMaximumRefreshRate = true
            PhysicsScrollEngine.pinsSamplingLinkRate = true
        case 1:     // keep the animation's rate guarantee, halve the main-thread row work
            PhysicsScrollEngine.pinsMaximumRefreshRate = true
            PhysicsScrollEngine.pinsSamplingLinkRate = false
        default:    // neither pinned — the original adaptive request
            PhysicsScrollEngine.pinsMaximumRefreshRate = false
            PhysicsScrollEngine.pinsSamplingLinkRate = false
        }
    }

    @objc private func engineChanged() {
        let engine: ScrollEngine
        switch engineControl.selectedSegmentIndex {
        case 1:
            let physics = PhysicsScrollEngine(); physics.decelerationMode = .stepped; engine = physics
        case 2:
            let physics = PhysicsScrollEngine(); physics.decelerationMode = .keyframe; engine = physics
        default:
            engine = UIKitScrollEngine()
        }
        rebuildList(engine: engine)
    }

    /// Swap the scroll engine by rebuilding the list view in place (a demo affordance — it resets
    /// scroll position and reloads the items, which is fine for A/B feel).
    private func rebuildList(engine: ScrollEngine) {
        (listView.engine as? PhysicsScrollEngine)?.tearDown()
        listView.removeFromSuperview()
        let newList = CoreVirtualListView(frame: view.bounds, engine: engine)
        newList.preloadMargin = 200
        bindAutoLoading(to: newList)
        newList.applyChanges(newSize: view.bounds.size,
                             newInsets: effectiveInsets,
                             transition: .easeInOut(duration: 0))
        newList.items = DemoListItem.makeItems(nestedScrollerEvery: 5)
        if autoLoadEnabled {
            enqueueAutoLoad(edges: newList.reachedLoadedEdges)
        }
        listView = newList
        mixedFiveIdentities.removeAll()
        refreshMixedControlTitles()
        view.insertSubview(newList, belowSubview: listOuterBoundsOverlay)
        view.setNeedsLayout()
    }

    /// Cycles the run length 6 → 3 → 12 → 6. Halving SPLITS every run — each piece keeps or loses the
    /// header per the witness rule. Doubling MERGES pairs — one serial survives, the other departs.
    @objc private func cycleGroupSize() {
        groupSize = groupSize == 6 ? 3 : (groupSize == 3 ? 12 : 6)
        let regrouped = listView.items.enumerated().compactMap { index, item -> DemoListItem? in
            guard let demo = item as? DemoListItem else { return nil }
            return DemoListItem(id: demo.id,
                                title: demo.title,
                                detail: demo.detail,
                                accentColor: demo.accentColor,
                                minHeight: demo.minHeight,
                                groupIndex: index / max(1, groupSize))
        }
        listView.applyChanges(items: regrouped, transition: .easeInOut(duration: 0.35))
    }

    @objc private func toggleTopInset() {
        testInsets.top = testInsets.top == 0 ? 300 : 0
        let insets = effectiveInsets
        listView.applyChanges(newInsets: insets,
                              transition: .easeInOut(duration: 0.5))
        insetRectAnimator.transition(
            view: insetRectOverlay,
            to: view.bounds.inset(by: insets),
            transition: .easeInOut(duration: 0.5)
        )
        refreshMixedControlTitles()
    }

    @objc private func jumpToForty() {
        listView.applyChanges(scrollTo: .init(index: 40, pointOffset: 0), transition: .easeInOut(duration: 0.3))
    }

    @objc private func scrollToTop() {
        listView.applyChanges(scrollTo: .init(index: 0, pointOffset: 0), transition: .easeInOut(duration: 0.3))
    }

    @objc private func insertOne() { insert(count: 1) }
    @objc private func deleteOne() { delete(count: 1) }
    @objc private func insertFive() { insert(count: 5) }
    @objc private func deleteFive() { delete(count: 5) }

    /// Replace a row at `min(5, count - 1)` in one transaction. The old incarnation fades in the
    /// exit overlay while the new identity fades in at its final full-height frame.
    @objc private func delAdd() {
        var items = listView.items
        guard !items.isEmpty else { return }
        let slot = min(5, items.count - 1)
        items[slot] = makeInsertedItem(groupIndex: groupIndex(at: slot, in: items))
        listView.applyChanges(items: items, transition: .easeInOut(duration: 0.3))
    }

    /// Delete, then insert 0.1s into the 0.3s transaction. Repeated taps exercise overlapping exit,
    /// insertion-opacity, and survivor-position tracks without restarting unchanged properties.
    @objc private func delAddDelayed() {
        deleteOne()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.insertOne()
        }
    }

    /// Insert one fresh item at the FIRST position to exercise top-edge insertion geometry.
    @objc private func insertTop() {
        var items = listView.items
        items.insert(makeInsertedItem(groupIndex: groupIndex(at: 0, in: items)), at: 0)
        listView.applyChanges(items: items, transition: .easeInOut(duration: 0.3))
        refreshMixedControlTitles()
    }

    /// Delete the FIRST item — a pure delete (not a scrollTo), so the edge under-fill settle applies.
    /// Scroll to the top first to watch the remaining rows rise flush to the top edge.
    @objc private func deleteTop() {
        var items = listView.items
        guard !items.isEmpty else { return }
        items.removeFirst()
        listView.applyChanges(items: items, transition: .easeInOut(duration: 0.3))
        refreshMixedControlTitles()
    }

    /// Delete the LAST item. Scroll to the bottom first to watch the content settle down flush to
    /// the bottom edge (instead of leaving dead space below the new last row).
    @objc private func deleteBottom() {
        var items = listView.items
        guard !items.isEmpty else { return }
        items.removeLast()
        listView.applyChanges(items: items, transition: .easeInOut(duration: 0.3))
    }

    @objc private func loadFiveAtTop() {
        var items = listView.items
        let topGroup = groupIndex(at: 0, in: items)
        let loaded = (0..<5).map { _ in makeInsertedItem(groupIndex: topGroup) }
        items.insert(contentsOf: loaded, at: 0)
        listView.applyChanges(
            items: items,
            anchorMode: .preserveVisibleContent,
            transition: .easeInOut(duration: 0.3)
        )
    }

    @objc private func unloadFiveAtTop() {
        var items = listView.items
        let removeCount = min(5, max(0, items.count - 1))
        guard removeCount > 0 else { return }
        items.removeFirst(removeCount)
        listView.applyChanges(
            items: items,
            anchorMode: .preserveVisibleContent,
            transition: .easeInOut(duration: 0.3)
        )
    }

    private func bindAutoLoading(to list: CoreVirtualListView) {
        list.onLoadedEdgeReached = { [weak self] edge in
            self?.enqueueAutoLoad(edges: [edge])
        }
    }

    @objc private func toggleAutoLoad() {
        autoLoadEnabled.toggle()
        autoLoadButton.setTitle(autoLoadEnabled ? "Stop Load" : "Auto Load", for: .normal)
        if autoLoadEnabled {
            enqueueAutoLoad(edges: listView.reachedLoadedEdges)
        } else {
            autoLoadGeneration &+= 1
            queuedAutoLoadEdges.removeAll()
            inFlightAutoLoadEdges.removeAll()
        }
    }

    private func enqueueAutoLoad(edges: Set<CoreListLoadedEdge>) {
        guard autoLoadEnabled, !edges.isEmpty else { return }
        let accepted = edges
            .subtracting(queuedAutoLoadEdges)
            .subtracting(inFlightAutoLoadEdges)
        guard !accepted.isEmpty else { return }

        queuedAutoLoadEdges.formUnion(accepted)
        guard !autoLoadRequestFormationScheduled else { return }
        autoLoadRequestFormationScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.formPendingAutoLoadRequest()
        }
    }

    private func formPendingAutoLoadRequest() {
        autoLoadRequestFormationScheduled = false
        guard autoLoadEnabled else {
            queuedAutoLoadEdges.removeAll()
            return
        }
        let edges = queuedAutoLoadEdges
        queuedAutoLoadEdges.removeAll()
        guard !edges.isEmpty else { return }

        inFlightAutoLoadEdges.formUnion(edges)
        let generation = autoLoadGeneration
        autoLoadResponseScheduler.schedule(
            after: Self.autoLoadResponseDelay
        ) { [weak self] in
            self?.applyAutoLoadResponse(edges: edges, generation: generation)
        }
    }

    private func applyAutoLoadResponse(
        edges: Set<CoreListLoadedEdge>,
        generation: Int
    ) {
        guard autoLoadEnabled, autoLoadGeneration == generation else { return }
        inFlightAutoLoadEdges.subtract(edges)

        var items = listView.items
        if edges.contains(.top) {
            let g = groupIndex(at: 0, in: items)
            items.insert(contentsOf: (0..<5).map { _ in makeInsertedItem(groupIndex: g) }, at: 0)
        }
        if edges.contains(.bottom) {
            let g = groupIndex(at: items.count - 1, in: items)
            items.append(contentsOf: (0..<5).map { _ in makeInsertedItem(groupIndex: g) })
        }
        listView.applyChanges(
            items: items,
            anchorMode: .preserveVisibleContent,
            transition: .easeInOut(duration: 0)
        )
        enqueueAutoLoad(edges: listView.reachedLoadedEdges)
    }

    private func insert(count: Int) {
        var items = listView.items
        let position = min(5, items.count)
        for i in 0..<count {
            items.insert(makeInsertedItem(groupIndex: groupIndex(at: position + i, in: items)),
                         at: position + i)
        }
        listView.applyChanges(items: items, transition: .easeInOut(duration: 0.3))
    }

    /// Fresh identity + visibly distinct content for both ordinary inserts and same-slot replacements.
    ///
    /// `groupIndex` matters: the demo derives attachment KEYS from it, so a row that defaults to
    /// group 0 while landing in the middle of another group's run SPLITS that run and drops a stray
    /// one-row run between the halves. The non-witness half then gets a fresh serial and a fresh
    /// view, which is exactly what "the header snapped" looks like. Callers pass the group of the
    /// row the insertion lands next to, so the new row JOINS that run instead of breaking it.
    private func makeInsertedItem(groupIndex: Int) -> DemoListItem {
        let number = Int.random(in: 1...9999)
        return DemoListItem(id: UUID(), title: "Inserted \(number)",
                            detail: "Created via applyChanges.", accentColor: .systemPink,
                            groupIndex: groupIndex)
    }

    /// The group of the row currently at `position`, clamped — the group an insertion there should
    /// join.
    private func groupIndex(at position: Int, in items: [CoreListItem]) -> Int {
        guard !items.isEmpty else { return 0 }
        let clamped = min(max(position, 0), items.count - 1)
        return (items[clamped] as? DemoListItem)?.groupIndex ?? 0
    }

    private func delete(count: Int) {
        var items = listView.items
        let start = min(5, items.count)
        let removeCount = min(count, items.count - start)
        guard removeCount > 0 else { return }
        items.removeSubrange(start..<(start + removeCount))
        listView.applyChanges(items: items, transition: .easeInOut(duration: 0.3))
    }

    /// Swap the second and fifth items while preserving both identities and views. Each changed
    /// position retargets from its analytic current value; neither row fades.
    @objc private func moveSwap() {
        var items = listView.items
        guard items.count >= 5 else { return }
        items.swapAt(1, 4)
        listView.applyChanges(items: items, transition: .easeInOut(duration: 0.3))
    }

    /// Like `moveSwap`, but also changes the two rows' minimum heights in the same pass. The reused
    /// views move on granular position tracks while their reconciled size geometry updates immediately.
    /// Rebuild a `DemoListItem` with the same identity/content but a new `minHeight` floor.
    private func demoItem(_ item: CoreListItem, minHeight: CGFloat) -> CoreListItem {
        guard let d = item as? DemoListItem else { return item }
        // Preserve groupIndex: rebuilding without it silently re-keys the row to group 0, which
        // splits whatever run it belonged to.
        return DemoListItem(id: d.id, title: d.title, detail: d.detail, accentColor: d.accentColor,
                            minHeight: minHeight, groupIndex: d.groupIndex)
    }

    private func applyMixedChanges(
        items: [CoreListItem]? = nil,
        testInsets updatedTestInsets: UIEdgeInsets? = nil,
        scrollTo: CoreListScrollTarget? = nil
    ) {
        if let updatedTestInsets {
            testInsets = updatedTestInsets
        }
        let transition = CoreListTransition.easeInOut(duration: 0.5)
        let insets = updatedTestInsets == nil ? nil : effectiveInsets
        listView.applyChanges(items: items,
                              newInsets: insets,
                              scrollTo: scrollTo,
                              transition: transition)
        if let insets {
            insetRectAnimator.transition(
                view: insetRectOverlay,
                to: view.bounds.inset(by: insets),
                transition: transition
            )
        }
        refreshMixedControlTitles()
    }

    private func refreshMixedControlTitles() {
        mixedVerticalJumpButton.setTitle(
            testInsets.top == 0 ? "V+300 + Jump40" : "V-300 + Jump40",
            for: .normal
        )
        mixedHorizontalReplaceButton.setTitle(
            testInsets.left == 0 && testInsets.right == 0
                ? "H+40/50 + Del/Add"
                : "H-40/50 + Del/Add",
            for: .normal
        )
        let firstHeight = (listView.items.first as? DemoListItem)?.minHeight ?? 0
        mixedSizeSwapButton.setTitle(
            firstHeight >= 200 ? "Size0 + Swap" : "Size200 + Swap",
            for: .normal
        )
        let currentIDs = Set(listView.items.map(\.identity))
        let hasTrackedFive = !currentIDs.intersection(mixedFiveIdentities).isEmpty
        if !hasTrackedFive {
            mixedFiveIdentities.removeAll()
        }
        mixedHorizontalSizeFiveButton.setTitle(
            hasTrackedFive ? "H-Size-5" : "H+Size+5",
            for: .normal
        )
        insetButton.setTitle(testInsets.top == 0 ? "Inset +300" : "Inset -300",
                             for: .normal)
    }

    @objc private func mixedVerticalInsetJump() {
        var insets = testInsets
        insets.top = insets.top == 0 ? 300 : 0
        applyMixedChanges(testInsets: insets,
                          scrollTo: .init(index: 40, pointOffset: 0))
    }

    @objc private func mixedHorizontalInsetDelAdd() {
        var items = listView.items
        guard !items.isEmpty else { return }
        let slot = min(5, items.count - 1)
        items[slot] = makeInsertedItem(groupIndex: groupIndex(at: slot, in: items))
        var insets = testInsets
        if insets.left == 0 && insets.right == 0 {
            insets.left = 40
            insets.right = 50
        } else {
            insets.left = 0
            insets.right = 0
        }
        applyMixedChanges(items: items, testInsets: insets)
    }

    @objc private func mixedFirstSizeSwap() {
        var items = listView.items
        guard items.count >= 5,
              let first = items.first as? DemoListItem else { return }
        items[0] = demoItem(items[0], minHeight: first.minHeight >= 200 ? 0 : 200)
        items.swapAt(1, 4)
        applyMixedChanges(items: items)
    }

    @objc private func mixedHorizontalSizeFive() {
        var items = listView.items
        var insets = testInsets
        let currentIDs = Set(items.map(\.identity))
        let survivingTracked = currentIDs.intersection(mixedFiveIdentities)

        if survivingTracked.isEmpty {
            mixedFiveIdentities.removeAll()
            guard !items.isEmpty else { return }
            items[0] = demoItem(items[0], minHeight: 200)
            let insertGroup = groupIndex(at: 0, in: items)
            let inserted = (0..<5).map { _ in makeInsertedItem(groupIndex: insertGroup) }
            mixedFiveIdentities = Set(inserted.map(\.identity))
            items.insert(contentsOf: inserted, at: min(5, items.count))
            insets.left = 40
            insets.right = 50
        } else {
            items.removeAll { mixedFiveIdentities.contains($0.identity) }
            mixedFiveIdentities.removeAll()
            if !items.isEmpty {
                items[0] = demoItem(items[0], minHeight: 0)
            }
            insets.left = 0
            insets.right = 0
        }

        applyMixedChanges(items: items, testInsets: insets)
    }

    @objc private func moveSwapWithSize() {
        var items = listView.items
        guard items.count > 5 else { return }
        items.swapAt(1, 4)   // same swap as moveSwap (array indices 1 and 4 = "rows 2 and 5")
        // The row now at the TOP slot (index 1) grows to a 100pt floor; the one now at the BOTTOM slot
        // (index 4) returns to its natural size (minHeight 0). 100 is clearly above the natural ~75pt —
        // repeatable every press. Same UUIDs produce moves; size geometry is written immediately and
        // affected position properties follow the granular transition rule.
        items[1] = demoItem(items[1], minHeight: 100)
        items[4] = demoItem(items[4], minHeight: 0)
        listView.applyChanges(items: items, transition: .easeInOut(duration: 0.3))
    }

    /// Start a move, then apply a size-only update 0.1s later. Changed affected position tracks are
    /// replaced continuously; unchanged and unrelated tracks retain identity, phase, and deadline.
    @objc private func moveSwapThenSizeDelayed() {
        var items = listView.items
        guard items.count > 5 else { return }
        items.swapAt(1, 4)                                            // pass 1: the move only (no size change)
        listView.applyChanges(items: items, transition: .easeInOut(duration: 0.3))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            var items = self.listView.items                          // pass 2 (mid-flight): the size only
            guard items.count > 5 else { return }
            items[1] = self.demoItem(items[1], minHeight: 100)
            items[4] = self.demoItem(items[4], minHeight: 0)
            self.listView.applyChanges(items: items, transition: .easeInOut(duration: 0.3))
        }
    }

    // MARK: - Manual checkpoint affordances

    /// Grow the center-most loaded row through the normal dirty-flush path. Geometry updates immediately;
    /// an affected active position property retargets continuously while unrelated tracks stay untouched.
    @objc private func growCenter() {
        guard !listView.activeWindow.items.isEmpty else { return }
        let viewportMidY = listView.bounds.height / 2
        let absoluteBase = listView.containerOriginY - listView.activeWindow.minY
        let scrollY = listView.engine.offset
        // Visible Y of an item's midpoint = absoluteBase + frame.midY − engine.offset (the standard
        // §3 screen-Y formula in `CoreVirtualListView` and the test harness).
        let centerItem = listView.activeWindow.items.min { a, b in
            let aMid = absoluteBase + a.frame.midY - scrollY
            let bMid = absoluteBase + b.frame.midY - scrollY
            return abs(aMid - viewportMidY) < abs(bMid - viewportMidY)
        }
        guard let row = centerItem?.view as? DemoListItemView else { return }
        row.grow(by: 100)
    }

    /// Toggle the chaos timer. When on, fires `chaosTick` every 250ms (random insert or delete
    /// via applyChanges). When off, invalidates the timer. Updates the button title to reflect state.
    @objc private func toggleChaos() {
        if let t = chaosTimer {
            t.invalidate()
            chaosTimer = nil
            chaosButton.setTitle("Chaos", for: .normal)
        } else {
            chaosButton.setTitle("Stop", for: .normal)
            chaosTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                self?.chaosTick()
            }
        }
    }

    /// One chaos step: 50/50 insert/delete at a random position **inside the loaded window** so
    /// the mutation is in (or near) the visible viewport — `activeWindow` already includes the
    /// preload margin around the visible area, so its index range is "around and inside the
    /// visible area". Insert generates a new DemoListItem with a random accent color. Delete is
    /// gated to keep ≥10 items (so chaos never empties the list).
    private func chaosTick() {
        var items = listView.items
        guard !listView.activeWindow.items.isEmpty else { return }   // nothing loaded → skip
        let windowStart = listView.activeWindow.startIndex
        let windowEnd = listView.activeWindow.endIndex
        let doInsert = items.count < 10 || Bool.random()   // floor: never below 10
        if doInsert {
            // Insert position is in [windowStart, windowEnd+1] — that lands the new row inside
            // the loaded window (or as a new last row in the window).
            let position = Int.random(in: windowStart...(windowEnd + 1))
            let accents: [UIColor] = [.systemBlue, .systemGreen, .systemOrange,
                                       .systemRed, .systemTeal, .systemIndigo, .systemPink]
            let item = DemoListItem(id: UUID(),
                                    title: "Chaos \(Int.random(in: 1000...9999))",
                                    detail: "Inserted by chaos.",
                                    accentColor: accents.randomElement()!,
                                    // Join the run it lands in; a defaulted group 0 would split it.
                                    groupIndex: groupIndex(at: position, in: items))
            items.insert(item, at: position)
        } else {
            // Delete a row in [windowStart, windowEnd]. Don't delete if the loaded window has
            // shrunk to nothing (defensive — guard above should prevent this).
            guard windowStart <= windowEnd else { return }
            let position = Int.random(in: windowStart...windowEnd)
            items.remove(at: position)
        }
        listView.applyChanges(items: items, transition: .easeInOut(duration: 0.3))
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Stop chaos if the user tabs away (Physics demo tab) — the timer would otherwise keep
        // mutating the items array off-screen.
        if chaosTimer != nil { toggleChaos() }
    }
}
