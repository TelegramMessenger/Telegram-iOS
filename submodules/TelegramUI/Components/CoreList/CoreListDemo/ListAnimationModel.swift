import Foundation
import CoreGraphics
import QuartzCore

enum ListAnimationOwner: Hashable {
    case viewport
    case live(AnyHashable)
    case exit(UInt64)
    case transient(UInt64)
    case ghostBlock(UInt64)
    /// A live attachment run, keyed by its serial. Distinct from `.live` because a run is not a row:
    /// its key is a serial the list mints, not a collection identity.
    case attachment(UInt64)

    var isLive: Bool {
        if case .live = self { return true }
        return false
    }

    var isGhostBlock: Bool {
        if case .ghostBlock = self { return true }
        return false
    }

    var isAttachment: Bool {
        if case .attachment = self { return true }
        return false
    }

    /// Owners presenting a live on-screen element with the FULL property set — a row or an attachment
    /// run. `.viewport`, `.ghostBlock`, `.exit` and `.transient` each own a narrower set, which is
    /// what the model's live-element entry points are guarding against. Written as an exhaustive
    /// switch so a future case has to state which side it is on.
    var ownsLiveElement: Bool {
        switch self {
        case .live, .attachment: return true
        case .viewport, .exit, .transient, .ghostBlock: return false
        }
    }

    /// Whether a PASS is the only thing that writes this owner's layer position — the precondition for
    /// `presented − model` to mean "the additive track's contribution" and therefore the precondition
    /// for `ListAnimationController.capturePresentedPositionOffsets` to sample it at all.
    ///
    /// A row qualifies: `render()` writes container-local frames, which are offset-independent, so the
    /// renders that run outside a pass (a scroll rebalance) rewrite a surviving row's base with the
    /// value it already had. Nothing else qualifies:
    ///
    /// - `.attachment` — `renderAttachments()` rewrites every attachment's frame on EVERY render, and
    ///   it must: a parked attachment stays parked on screen only by moving its base with the content.
    ///   So between two frames `presentation()` lags the model by one frame of base movement. Reading
    ///   that lag as a contribution made a parked date pill snap 57.66pt at the touch-up of an
    ///   interactive keyboard dismissal — its layer showed `model=573.00 presented=515.33` with no
    ///   animation on it at all. See `AttachmentResumeBaseTests`.
    /// - `.exit`, `.transient`, `.ghostBlock` — `shiftExitOverlayChildren` adds a coordinate rebase to
    ///   every overlay child's `position.y`, and it runs from `render()`, which a scroll rebalance
    ///   reaches without a pass. Same hazard, same exclusion; no defect has been observed there, but
    ///   the property this samples is not true of them either.
    /// - `.viewport` — excluded one level up, by property: see the provider in
    ///   `ListAnimationController.init`.
    ///
    /// Note that "committed" is not the bar and could not be: a base written last turn may not have
    /// been PRESENTED yet when this turn samples, so a per-frame-written base can never be differenced
    /// against `presentation()` at all.
    var hasPassWrittenPositionBase: Bool {
        switch self {
        case .live: return true
        case .attachment, .viewport, .exit, .transient, .ghostBlock: return false
        }
    }
}

enum ListAnimatedProperty: Hashable {
    case viewportOffset
    case positionX
    case positionY
    case width
    case height
    case opacity
}

extension ListAnimatedProperty {
    /// Whether this property's track carries an OFFSET that decays to zero, rather than an absolute
    /// value.
    ///
    /// The single source of truth: `CoreAnimationCompiler.isAdditive` delegates here, and
    /// `ListAnimationModel.resumeValue` uses it to convert a presented value into the track's space.
    /// Two switches that must agree is precisely the shape of defect this seam was added to fix, so
    /// there is one — and `PresentationResumeSamplingTests` asserts the delegation still holds.
    var isAdditiveTrack: Bool {
        switch self {
        case .viewportOffset, .positionX, .positionY: return true
        case .width, .height, .opacity: return false
        }
    }
}

struct ListAnimationTrack: Equatable {
    let generation: UInt64
    let from: CGFloat
    let to: CGFloat
    let startTime: TimeInterval
    let duration: TimeInterval
    let curve: CoreListTransition.Animation.Curve
    /// Resolved from the LOGICAL duration by the transition that produced this track. This track's
    /// own `duration` is already Slow-Animation-scaled and must never be used to re-resolve it.
    let springKind: CoreListSpringKind
    /// The Slow-Animations factor already folded into `duration`. The emitter divides it back out so
    /// the animation carries a logical duration and `speed = 1/factor`, matching `CAAnimationUtils`;
    /// the model itself keeps reasoning on the scaled clock.
    let durationFactor: Double

    init(generation: UInt64,
         from: CGFloat,
         to: CGFloat,
         startTime: TimeInterval,
         duration: TimeInterval,
         curve: CoreListTransition.Animation.Curve = .easeInOut,
         springKind: CoreListSpringKind = .adjustedBezier,
         durationFactor: Double = 1) {
        self.generation = generation
        self.from = from
        self.to = to
        self.startTime = startTime
        self.duration = duration
        self.curve = curve
        self.springKind = springKind
        self.durationFactor = durationFactor
    }

    func value(at time: TimeInterval) -> CGFloat {
        guard duration > 0 else { return to }
        let x = min(max((time - startTime) / duration, 0), 1)
        // A system spring is not a unit bezier; it is evaluated by the same CASpringAnimation Core
        // Animation will render, so the model and the screen cannot disagree. `nil` means the
        // private evaluator is unavailable, in which case both the model and the emitter fall back
        // to the adjusted bezier — degraded together rather than disagreeing.
        let eased = coreListSpringValue(kind: springKind, phase: CGFloat(x))
            ?? curve.solve(at: CGFloat(x))
        return from + (to - from) * eased
    }

    func isComplete(at time: TimeInterval) -> Bool {
        duration <= 0 || time >= startTime + duration
    }

    /// True when the animation compiled from this track cannot produce an `animationDidStop`.
    ///
    /// Core Animation does not run an animation whose `fromValue` equals its `toValue`: it changes
    /// nothing, so the render server has nothing to schedule and never reports a stop. The track is
    /// still a real analytic track with a real deadline — several of them exist ONLY to own that
    /// deadline (see `beginExit(fadesOut: false)`) — so the controller drives their completion from
    /// the model instead. Same epsilon as `ListAnimationModel.positionEpsilon`, and deliberately not
    /// read from it: this is a property of the EMITTED animation, not of the model's no-op policy.
    var deliversNoCoreAnimationCompletion: Bool {
        abs(to - from) <= 1e-6
    }
}

enum ListAnimationMutation: Equatable {
    case unchanged
    case immediate(value: CGFloat)
    case started(ListAnimationTrack)
}

struct ListAnimationExit: Equatable {
    let owner: ListAnimationOwner
    let positionX: CGFloat
    let positionY: CGFloat
    let width: CGFloat
    let height: CGFloat
    let opacityMutation: ListAnimationMutation
}

final class ListAnimationModel {
    private struct OwnerState {
        var viewportOffset: CGFloat
        var positionOffsetX: CGFloat
        var positionOffsetY: CGFloat
        var width: CGFloat
        var height: CGFloat
        var opacity: CGFloat
        var tracks: [ListAnimatedProperty: ListAnimationTrack]
    }

    private let positionEpsilon: CGFloat
    private var nextGeneration: UInt64 = 0
    private var nextExitSerial: UInt64 = 0
    private var nextTransientSerial: UInt64 = 0
    private var states: [ListAnimationOwner: OwnerState] = [:]

    /// Supplies the value a layer is CURRENTLY RENDERING for a property, or nil when there is no
    /// binding, no layer, or no presentation layer.
    ///
    /// Installed by `ListAnimationController`, which is the only half of that pair that knows about
    /// layers — so the Core Animation dependency stops there and this stays a plain function of its
    /// inputs. Nil in windowless tests, which is what keeps their analytic assertions exact.
    var presentedValueProvider: ((ListAnimationOwner, ListAnimatedProperty) -> CGFloat?)?

    var ownerCount: Int { states.count }

    init(positionEpsilon: CGFloat = 1e-6) {
        self.positionEpsilon = positionEpsilon
    }

    func seedViewport() {
        states[.viewport] = OwnerState(viewportOffset: 0,
                                       positionOffsetX: 0,
                                       positionOffsetY: 0,
                                       width: 0,
                                       height: 0,
                                       opacity: 1,
                                       tracks: [:])
    }

    func seedLive(owner: ListAnimationOwner,
                  positionOffset: CGFloat,
                  opacity: CGFloat,
                  height: CGFloat = 0) {
        seedLive(owner: owner,
                 positionOffsetX: 0,
                 positionOffsetY: positionOffset,
                 opacity: opacity,
                 width: 0,
                 height: height)
    }

    func seedLive(owner: ListAnimationOwner,
                  positionOffsetX: CGFloat,
                  positionOffsetY: CGFloat,
                  opacity: CGFloat,
                  width: CGFloat,
                  height: CGFloat) {
        precondition(owner.ownsLiveElement)
        states[owner] = OwnerState(viewportOffset: 0,
                                   positionOffsetX: positionOffsetX,
                                   positionOffsetY: positionOffsetY,
                                   width: width,
                                   height: height,
                                   opacity: opacity,
                                   tracks: [:])
    }

    func seedGhostBlock(owner: ListAnimationOwner) {
        precondition(owner.isGhostBlock)
        states[owner] = OwnerState(viewportOffset: 0,
                                   positionOffsetX: 0,
                                   positionOffsetY: 0,
                                   width: 0,
                                   height: 0,
                                   opacity: 1,
                                   tracks: [:])
    }

    func transitionViewport(oldSettledOffset: CGFloat,
                            newSettledOffset: CGFloat,
                            at time: TimeInterval,
                            transition: CoreListTransition) -> ListAnimationMutation {
        if states[.viewport] == nil { seedViewport() }
        guard abs(newSettledOffset - oldSettledOffset) > positionEpsilon else {
            return .unchanged
        }
        let correction = resumeValue(for: .viewport,
                                     property: .viewportOffset,
                                     at: time) ?? 0
        return replace(owner: .viewport,
                       property: .viewportOffset,
                       from: oldSettledOffset + correction - newSettledOffset,
                       to: 0,
                       at: time,
                       transition: transition)
    }

    func transitionPosition(owner: ListAnimationOwner,
                            oldSettledY: CGFloat,
                            newSettledY: CGFloat,
                            at time: TimeInterval,
                            transition: CoreListTransition) -> ListAnimationMutation {
        precondition(owner.ownsLiveElement)
        ensureLive(owner)
        return transitionPositionOffset(owner: owner,
                                        oldSettledY: oldSettledY,
                                        newSettledY: newSettledY,
                                        at: time,
                                        transition: transition)
    }

    func transitionPositionX(owner: ListAnimationOwner,
                             oldSettledX: CGFloat,
                             newSettledX: CGFloat,
                             at time: TimeInterval,
                             transition: CoreListTransition) -> ListAnimationMutation {
        if owner.isLive { ensureLive(owner) }
        guard states[owner] != nil else { return .unchanged }
        guard abs(newSettledX - oldSettledX) > positionEpsilon else { return .unchanged }
        let currentOffset = resumeValue(for: owner, property: .positionX, at: time) ?? 0
        return replace(owner: owner,
                       property: .positionX,
                       from: oldSettledX + currentOffset - newSettledX,
                       to: 0,
                       at: time,
                       transition: transition)
    }

    func transitionGhostBlock(owner: ListAnimationOwner,
                              oldSettledY: CGFloat,
                              newSettledY: CGFloat,
                              at time: TimeInterval,
                              transition: CoreListTransition) -> ListAnimationMutation {
        precondition(owner.isGhostBlock)
        if states[owner] == nil { seedGhostBlock(owner: owner) }
        return transitionPositionOffset(owner: owner,
                                        oldSettledY: oldSettledY,
                                        newSettledY: newSettledY,
                                        at: time,
                                        transition: transition)
    }

    private func transitionPositionOffset(owner: ListAnimationOwner,
                                          oldSettledY: CGFloat,
                                          newSettledY: CGFloat,
                                          at time: TimeInterval,
                                          transition: CoreListTransition) -> ListAnimationMutation {
        guard abs(newSettledY - oldSettledY) > positionEpsilon else { return .unchanged }
        // `currentOffset` is the track's own quantity — the additive contribution decaying to zero,
        // relative to the OLD settled position — so it composes with `oldSettledY` and nothing needs
        // converting or threading.
        //
        // It is therefore ANALYTIC, and `resumeValue` declines to sample `.positionY` for exactly that
        // reason: a presented sample can only be expressed against the layer's model value, which
        // `render()` has already moved to the NEW settled position by the time this runs, so adding it
        // to `oldSettledY` counts the pass's displacement twice. Three versions of this have now been
        // wrong, all by mixing spaces or bases inside one subtraction; see the provider in
        // `ListAnimationController.init`.
        let currentOffset = resumeValue(for: owner, property: .positionY, at: time) ?? 0
        let currentVisibleY = oldSettledY + currentOffset
        return replace(owner: owner,
                       property: .positionY,
                       from: currentVisibleY - newSettledY,
                       to: 0,
                       at: time,
                       transition: transition)
    }

    func transitionHeight(owner: ListAnimationOwner,
                          oldSettledHeight: CGFloat,
                          newSettledHeight: CGFloat,
                          at time: TimeInterval,
                          transition: CoreListTransition) -> ListAnimationMutation {
        precondition(owner.ownsLiveElement)
        ensureLive(owner, height: oldSettledHeight)
        guard abs(newSettledHeight - oldSettledHeight) > positionEpsilon else {
            return .unchanged
        }
        let currentHeight = resumeValue(for: owner, property: .height, at: time)
            ?? oldSettledHeight
        return replace(owner: owner, property: .height,
                       from: currentHeight, to: newSettledHeight,
                       at: time, transition: transition)
    }

    func transitionWidth(owner: ListAnimationOwner,
                         oldSettledWidth: CGFloat,
                         newSettledWidth: CGFloat,
                         at time: TimeInterval,
                         transition: CoreListTransition) -> ListAnimationMutation {
        if owner.isLive { ensureLive(owner, width: oldSettledWidth) }
        guard states[owner] != nil else { return .unchanged }
        guard abs(newSettledWidth - oldSettledWidth) > positionEpsilon else {
            return .unchanged
        }
        let currentWidth = resumeValue(for: owner, property: .width, at: time)
            ?? oldSettledWidth
        return replace(owner: owner,
                       property: .width,
                       from: currentWidth,
                       to: newSettledWidth,
                       at: time,
                       transition: transition)
    }

    func transitionOpacity(owner: ListAnimationOwner,
                           to target: CGFloat,
                           at time: TimeInterval,
                           transition: CoreListTransition) -> ListAnimationMutation {
        guard let state = states[owner] else { return .unchanged }
        guard state.opacity != target else { return .unchanged }
        let from = resumeValue(for: owner, property: .opacity, at: time) ?? state.opacity
        return replace(owner: owner, property: .opacity, from: from, to: target,
                       at: time, transition: transition)
    }

    func beginInsertion(owner: ListAnimationOwner,
                        width: CGFloat,
                        height: CGFloat,
                        at time: TimeInterval,
                        transition: CoreListTransition) -> ListAnimationMutation {
        precondition(owner.ownsLiveElement)
        seedLive(owner: owner,
                 positionOffsetX: 0,
                 positionOffsetY: 0,
                 opacity: 0,
                 width: width,
                 height: height)
        return replace(owner: owner, property: .opacity, from: 0, to: 1,
                       at: time, transition: transition)
    }

    /// `ownsLiveElement`: an attachment run departs on exactly the same terms as a row.
    /// `beginTransient` deliberately keeps `isLive` — transients are a crossing-carry mechanism
    /// attachments do not participate in.
    func beginExit(from owner: ListAnimationOwner,
                   at time: TimeInterval,
                   transition: CoreListTransition,
                   fadesOut: Bool = true) -> ListAnimationExit {
        precondition(owner.ownsLiveElement)
        ensureLive(owner)

        let positionX = value(for: owner, property: .positionX, at: time) ?? 0
        let positionY = value(for: owner, property: .positionY, at: time) ?? 0
        let width = value(for: owner, property: .width, at: time) ?? 0
        let height = value(for: owner, property: .height, at: time) ?? 0
        let opacity = value(for: owner, property: .opacity, at: time) ?? 1
        states.removeValue(forKey: owner)

        nextExitSerial += 1
        let exitOwner = ListAnimationOwner.exit(nextExitSerial)
        states[exitOwner] = OwnerState(viewportOffset: 0,
                                       positionOffsetX: positionX,
                                       positionOffsetY: positionY,
                                       width: width,
                                       height: height,
                                       opacity: opacity,
                                       tracks: [:])
        // A non-fading exit still installs a real opacity track, deliberately: `replace` does not
        // early-out on an equal endpoint, so the track keeps the pass duration and therefore the
        // completion deadline that tears the ghost member down. Routing this through the guarded
        // equal-target helper above would return `.unchanged`, which `apply` short-circuits without
        // running cleanup — leaking every member into the overlay forever.
        let mutation = replace(owner: exitOwner, property: .opacity,
                               from: opacity, to: fadesOut ? 0 : opacity,
                               at: time, transition: transition)
        return ListAnimationExit(owner: exitOwner,
                                 positionX: positionX,
                                 positionY: positionY,
                                 width: width,
                                 height: height,
                                 opacityMutation: mutation)
    }

    /// Moves an exit's teardown deadline onto `transition`: its opacity track restarts from the current
    /// value toward the target it already has. That track is what tears the member down (see
    /// `beginExit`), so this is how a detached member is kept alive by a later pass. Like `beginExit` it
    /// never early-outs on an equal endpoint — returning `.unchanged` would leave the old deadline.
    func retimeExit(owner: ListAnimationOwner,
                    at time: TimeInterval,
                    transition: CoreListTransition) -> ListAnimationMutation {
        guard case .exit = owner, let state = states[owner] else { return .unchanged }
        let from = resumeValue(for: owner, property: .opacity, at: time) ?? state.opacity
        return replace(owner: owner, property: .opacity, from: from, to: state.opacity,
                       at: time, transition: transition)
    }

    func beginTransient(from owner: ListAnimationOwner,
                        at time: TimeInterval) -> ListAnimationOwner {
        precondition(owner.isLive)
        ensureLive(owner)

        let positionX = value(for: owner, property: .positionX, at: time) ?? 0
        let positionY = value(for: owner, property: .positionY, at: time) ?? 0
        let width = value(for: owner, property: .width, at: time) ?? 0
        let height = value(for: owner, property: .height, at: time) ?? 0
        let opacity = value(for: owner, property: .opacity, at: time) ?? 1
        nextTransientSerial += 1
        let transientOwner = ListAnimationOwner.transient(nextTransientSerial)
        states[transientOwner] = OwnerState(viewportOffset: 0,
                                            positionOffsetX: positionX,
                                            positionOffsetY: positionY,
                                            width: width,
                                            height: height,
                                            opacity: opacity,
                                            tracks: [:])
        return transientOwner
    }

    func track(for owner: ListAnimationOwner,
               property: ListAnimatedProperty) -> ListAnimationTrack? {
        states[owner]?.tracks[property]
    }

    /// The value a new animation for `property` should start FROM.
    ///
    /// Deliberately a different method from `value(for:property:at:)`, which answers "where will this
    /// be when settled" and must stay analytic — window building, `bottomEdgePinSlack`, the `finalize`
    /// deadline and the controller's own queries all depend on that. Hooking the provider onto
    /// `value(...)` itself would silently convert every one of them into presented reads, which is the
    /// one thing this change must not do. The distinct name makes that structural instead of a comment
    /// someone has to notice.
    ///
    /// The provider returns values already in the TRACK's space, so there is no conversion here — and
    /// the provider only answers for ABSOLUTE properties, which is what makes that true for free. No
    /// additive property is sampled: its contribution can only be recovered as `presented - the base
    /// the render tree was committed against`, and by the time a transition installs, the pass has
    /// already overwritten that base with the new settled one. See the provider in
    /// `ListAnimationController.init` for the full argument and for the defect it shipped.
    func resumeValue(for owner: ListAnimationOwner,
                     property: ListAnimatedProperty,
                     at time: TimeInterval) -> CGFloat? {
        if let presented = presentedValueProvider?(owner, property) {
            return presented
        }
        return value(for: owner, property: property, at: time)
    }

    func value(for owner: ListAnimationOwner,
               property: ListAnimatedProperty,
               at time: TimeInterval) -> CGFloat? {
        guard let state = states[owner] else { return nil }
        if let track = state.tracks[property] {
            return track.value(at: time)
        }
        switch property {
        case .viewportOffset: return state.viewportOffset
        case .positionX: return state.positionOffsetX
        case .positionY: return state.positionOffsetY
        case .width: return state.width
        case .height: return state.height
        case .opacity: return state.opacity
        }
    }

    @discardableResult
    func complete(owner: ListAnimationOwner,
                  property: ListAnimatedProperty,
                  generation: UInt64,
                  at time: TimeInterval) -> Bool {
        guard let track = states[owner]?.tracks[property],
              track.generation == generation,
              track.isComplete(at: time)
        else { return false }
        states[owner]?.tracks.removeValue(forKey: property)
        return true
    }

    func reap(at time: TimeInterval) {
        let completed = states.flatMap { owner, state in
            state.tracks.compactMap { property, track in
                track.isComplete(at: time) ? (owner, property, track.generation) : nil
            }
        }
        for (owner, property, generation) in completed {
            _ = complete(owner: owner, property: property,
                         generation: generation, at: time)
        }
    }

    func reap(owner: ListAnimationOwner, at time: TimeInterval) {
        guard let state = states[owner] else { return }
        let completed = state.tracks.compactMap { property, track in
            track.isComplete(at: time) ? (property, track.generation) : nil
        }
        for (property, generation) in completed {
            _ = complete(owner: owner, property: property,
                         generation: generation, at: time)
        }
    }

    func contains(_ owner: ListAnimationOwner) -> Bool {
        states[owner] != nil
    }

    func remove(_ owner: ListAnimationOwner) {
        states.removeValue(forKey: owner)
    }

    @discardableResult
    func settle(owner: ListAnimationOwner,
                property: ListAnimatedProperty) -> Bool {
        guard states[owner] != nil else { return false }
        let removed = states[owner]?.tracks.removeValue(forKey: property) != nil
        if property == .viewportOffset {
            states[owner]?.viewportOffset = 0
        } else if property == .positionX {
            states[owner]?.positionOffsetX = 0
        } else if property == .positionY {
            states[owner]?.positionOffsetY = 0
        }
        return removed
    }

    @discardableResult
    func reconcileHeightForRebind(owner: ListAnimationOwner,
                                  freshSettledHeight: CGFloat) -> Bool {
        guard let state = states[owner],
              abs(state.height - freshSettledHeight) > positionEpsilon
        else { return false }
        states[owner]?.height = freshSettledHeight
        states[owner]?.tracks.removeValue(forKey: .height)
        return true
    }

    @discardableResult
    func reconcileWidthForRebind(owner: ListAnimationOwner,
                                 freshSettledWidth: CGFloat) -> Bool {
        guard let state = states[owner],
              abs(state.width - freshSettledWidth) > positionEpsilon
        else { return false }
        states[owner]?.width = freshSettledWidth
        states[owner]?.tracks.removeValue(forKey: .width)
        return true
    }

    func reset() {
        states.removeAll()
    }

    private func ensureLive(_ owner: ListAnimationOwner,
                            width: CGFloat = 0,
                            height: CGFloat = 0) {
        guard states[owner] == nil else { return }
        states[owner] = OwnerState(viewportOffset: 0,
                                   positionOffsetX: 0,
                                   positionOffsetY: 0,
                                   width: width,
                                   height: height,
                                   opacity: 1,
                                   tracks: [:])
    }

    private func replace(owner: ListAnimationOwner,
                         property: ListAnimatedProperty,
                         from: CGFloat,
                         to: CGFloat,
                         at time: TimeInterval,
                         transition: CoreListTransition) -> ListAnimationMutation {
        nextGeneration += 1
        setStoredValue(to, for: owner, property: property)

        // Destructuring rather than reading `.duration`/`.curve` separately: the same check that
        // rules out an immediate settle is what proves the curve is present.
        guard case let .curve(duration, curve) = transition.animation, duration > 0 else {
            states[owner]?.tracks.removeValue(forKey: property)
            return .immediate(value: to)
        }

        let track = ListAnimationTrack(generation: nextGeneration,
                                       from: from,
                                       to: to,
                                       startTime: time,
                                       duration: duration,
                                       curve: curve,
                                       springKind: transition.springKind,
                                       durationFactor: transition.appliedDurationFactor)
        states[owner]?.tracks[property] = track
        return .started(track)
    }

    private func setStoredValue(_ value: CGFloat,
                                for owner: ListAnimationOwner,
                                property: ListAnimatedProperty) {
        switch property {
        case .viewportOffset: states[owner]?.viewportOffset = value
        case .positionX: states[owner]?.positionOffsetX = value
        case .positionY: states[owner]?.positionOffsetY = value
        case .width: states[owner]?.width = value
        case .height: states[owner]?.height = value
        case .opacity: states[owner]?.opacity = value
        }
    }
}
