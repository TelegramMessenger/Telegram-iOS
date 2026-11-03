import Foundation
import UIKit
import AsyncDisplayKit

/// Above both sliding screens during a push or pop: the renderer's backdrop, the two lifted bar contents (bottom,
/// then top), the renderer's row. Takes no touches.
///
/// As in UIKit, each bar's content rides its own screen while the glass stays put: a lifted content follows its
/// screen's frame, in a clip that matches UIKit's matching views (the bottom bar is cut where the top screen covers it,
/// the top bar is held to its own screen). The renderer's backdrop and glass do not move. A transition running on the
/// render server reaches the clips as keyframes sampled from its timeline; a dragging finger sets them per frame.
final class NavigationBarTransitionLayer: ASDisplayNode {
    private final class Lifted {
        weak var source: NavigationBarTransitionSource?
        let info: NavigationBarTransitionTakeViewInfo
        weak var screenView: UIView?
        /// The content's frame in its screen.
        var frame: CGRect
        let clipView: UIView

        init(source: NavigationBarTransitionSource, info: NavigationBarTransitionTakeViewInfo, screenView: UIView) {
            self.source = source
            self.info = info
            self.screenView = screenView
            self.frame = info.containingView.convert(info.containingView.bounds, to: screenView)
            self.clipView = UIView()
            self.clipView.clipsToBounds = true
            self.clipView.isUserInteractionEnabled = false
        }

        /// The screen's frame in the container's (and so the layer's) coordinates: its model frame, which a dragging
        /// finger sets per frame (a baked transition hands the layer its sampled frames instead).
        var screenFrame: CGRect {
            return self.screenView?.frame ?? CGRect()
        }
    }

    private let renderer: NavigationBarTransitionRenderer
    /// False in an expansion: nothing slides, so each bar keeps its whole width.
    private let clipsToScreens: Bool
    private let bottom: Lifted
    private let top: Lifted
    /// The fraction on screen.
    private var fraction: CGFloat = 0.0
    /// The linger's own cap: 1.5 s of animation time on a clock of its own, ended by Core Animation's completion (so at
    /// once if the layer leaves the screen).
    private var lingerCap: NavigationAnimationClock?

    init(renderer: NavigationBarTransitionRenderer, bottom: (NavigationBarTransitionSource, NavigationBarTransitionTakeViewInfo, UIView), top: (NavigationBarTransitionSource, NavigationBarTransitionTakeViewInfo, UIView), clipsToScreens: Bool = true) {
        self.renderer = renderer
        self.clipsToScreens = clipsToScreens
        self.bottom = Lifted(source: bottom.0, info: bottom.1, screenView: bottom.2)
        self.top = Lifted(source: top.0, info: top.1, screenView: top.2)
        super.init()
        self.isUserInteractionEnabled = false
        self.view.addSubview(renderer.backdropView)
        for lifted in [self.bottom, self.top] {
            self.view.addSubview(lifted.clipView)
            lifted.clipView.addSubview(lifted.info.contentView)
            lifted.source?.transitionContentFrameUpdated = { [weak self, weak lifted] frame in
                guard let self, let lifted, let screenView = lifted.screenView else {
                    return
                }
                lifted.frame = lifted.info.containingView.convert(frame, to: screenView)
                if let timeline = self.timeline, let timing = timeline.reinstallTiming() {
                    // On the running phase: the moved content and the renderer's glass (whose frames are this
                    // content's) re-installed from now's samples.
                    self.install(timeline: timeline, timing: timing)
                    self.renderer.animate(size: self.bounds.size, timeline: timeline.withTiming(timing), bottomFrame: self.bottom.frame, topFrame: self.top.frame)
                } else {
                    self.apply(fraction: self.fraction)
                }
            }
        }
        self.applyLiftedLayout(self.liftedLayout(topScreen: self.top.screenFrame, bottomScreen: self.bottom.screenFrame))
        self.view.addSubview(renderer.rowView)
    }

    private var timeline: NavigationTransitionTimeline?

    func update(fraction: CGFloat, transition: ContainedViewLayoutTransition) {
        self.timeline = nil
        self.apply(fraction: fraction)
    }

    /// The transition runs on the render server along `timeline`: each lifted content's clip and frame get keyframes
    /// that follow its screen's sampled frames, and the renderer gets the timeline.
    func animate(timeline: NavigationTransitionTimeline) {
        self.timeline = timeline
        self.install(timeline: timeline, timing: timeline.timing)
        let fraction = timeline.fractions.last ?? self.fraction
        self.fraction = fraction
        self.bottom.source?.updateTransition(role: .bottom, fraction: fraction, transition: .immediate)
        self.top.source?.updateTransition(role: .top, fraction: fraction, transition: .immediate)
        self.renderer.animate(size: self.bounds.size, timeline: timeline, bottomFrame: self.bottom.frame, topFrame: self.top.frame)
    }

    var isAnimating: Bool {
        return self.timeline?.reinstallTiming() != nil
    }

    private func install(timeline: NavigationTransitionTimeline, timing: NavigationKeyframeTiming) {
        let layouts = zip(timeline.topFrames, timeline.bottomFrames).map { self.liftedLayout(topScreen: $0, bottomScreen: $1) }
        guard let final = layouts.last else {
            return
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.applyLiftedLayout(final)
        CATransaction.commit()
        let prefix = navigationBarTransitionKeyframeKeyPrefix
        for (index, lifted) in [self.bottom, self.top].enumerated() {
            let clips = layouts.map { $0[index].clip }
            let contents = layouts.map { $0[index].content }
            addNavigationKeyframes(to: lifted.clipView.layer, key: prefix + "position", keyPath: "position", values: clips.map { NSValue(cgPoint: CGPoint(x: $0.midX, y: $0.midY)) }, timing: timing)
            addNavigationKeyframes(to: lifted.clipView.layer, key: prefix + "bounds", keyPath: "bounds", values: clips.map { NSValue(cgRect: CGRect(origin: CGPoint(), size: $0.size)) }, timing: timing)
            addNavigationKeyframes(to: lifted.info.contentView.layer, key: prefix + "position", keyPath: "position", values: contents.map { NSValue(cgPoint: CGPoint(x: $0.midX, y: $0.midY)) }, timing: timing)
        }
    }

    func beginTransition(isInteractive: Bool, toTop: Bool) {
        self.renderer.beginTransition(isInteractive: isInteractive, toTop: toTop)
    }

    func endInteraction(towardTop: Bool) {
        self.renderer.endInteraction(towardTop: towardTop)
    }

    func beginInteraction() {
        self.renderer.beginInteraction()
    }

    /// Where each lifted content goes with its screen at these frames, in UIKit's matching-view clip: the top bar held
    /// to its own screen, the bottom bar to the part of its screen the top screen does not cover. Index 0 is the bottom
    /// bar, 1 the top one; the content's frame is in its clip.
    private func liftedLayout(topScreen: CGRect, bottomScreen: CGRect) -> [(clip: CGRect, content: CGRect)] {
        if !self.clipsToScreens {
            // An expansion: nothing slides, so each bar keeps its whole width where its screen is.
            let height = max(self.bounds.height, self.bottom.frame.maxY, self.top.frame.maxY)
            return [self.bottom, self.top].map { lifted in
                let clip = CGRect(x: 0.0, y: 0.0, width: self.bounds.width, height: height)
                return (clip, lifted.frame)
            }
        }
        let height = max(self.bounds.height, self.bottom.frame.maxY, self.top.frame.maxY)
        let topRange = (minX: topScreen.minX, maxX: topScreen.minX + topScreen.width)
        var bottomRange = (minX: bottomScreen.minX, maxX: bottomScreen.minX + bottomScreen.width)
        if topRange.minX >= bottomRange.minX {
            bottomRange.maxX = min(bottomRange.maxX, topRange.minX)
        } else {
            bottomRange.minX = max(bottomRange.minX, topRange.maxX)
        }
        var result: [(clip: CGRect, content: CGRect)] = []
        for (lifted, screen, range) in [(self.bottom, bottomScreen, bottomRange), (self.top, topScreen, topRange)] {
            let clipFrame = CGRect(x: range.minX, y: 0.0, width: max(0.0, range.maxX - range.minX), height: height)
            result.append((clipFrame, lifted.frame.offsetBy(dx: screen.minX - clipFrame.minX, dy: screen.minY)))
        }
        return result
    }

    private func applyLiftedLayout(_ layout: [(clip: CGRect, content: CGRect)]) {
        for (index, lifted) in [self.bottom, self.top].enumerated() {
            lifted.clipView.frame = layout[index].clip
            lifted.info.contentView.frame = layout[index].content
        }
    }

    private func apply(fraction: CGFloat) {
        self.fraction = fraction
        self.applyLiftedLayout(self.liftedLayout(topScreen: self.top.screenFrame, bottomScreen: self.bottom.screenFrame))
        self.bottom.source?.updateTransition(role: .bottom, fraction: fraction, transition: .immediate)
        self.top.source?.updateTransition(role: .top, fraction: fraction, transition: .immediate)
        self.renderer.update(size: self.bounds.size, fraction: fraction, bottomFrame: self.bottom.frame, topFrame: self.top.frame, transition: .immediate)
    }

    /// The bar the transition ended on, holding its own glass while the renderer's glass finishes above it.
    private weak var lingeringSource: NavigationBarTransitionSource?
    private(set) var isLingering = false
    /// Called once a linger ends (the glass settled, the bar was touched or changed, or it was ended from outside).
    var lingerEnded: (() -> Void)?
    /// Run when the linger ends, right after the bar takes its glass back (an expansion hands over what the lingering
    /// glass leaves out); also if the layer goes without ending its linger.
    private var lingerHandovers: [() -> Void] = []

    func addLingerHandover(_ handover: @escaping () -> Void) {
        self.lingerHandovers.append(handover)
    }

    deinit {
        let handovers = self.lingerHandovers
        if !handovers.isEmpty {
            let run = {
                handovers.forEach { $0() }
            }
            if Thread.isMainThread {
                run()
            } else {
                DispatchQueue.main.async(execute: run)
            }
        }
    }

    /// Ends the transition's bar part: both contents go back to their bars. UIKit's capsules run on their own clock and
    /// outlive the screens' transition, so when `lingering` is allowed and the renderer's glass is still animating, the
    /// glass stays above the bar the transition ended on until it settles, that bar holding its own glass hidden
    /// meanwhile; returns true then, and the layer removes itself when the linger ends.
    func putBack(lingering: Bool) -> Bool {
        // Where the transition ends: its timeline's last sample while it runs on the render server.
        let fraction = self.timeline?.fractions.last ?? self.fraction
        let destination = fraction >= 0.5 ? self.top : self.bottom
        guard lingering, self.renderer.isGlassAnimating, let source = destination.source else {
            self.putBack()
            return false
        }
        // Hold first, so that the bar's own glass never shows in between.
        guard source.holdGlass(true, interrupted: { [weak self] in
            self?.endLingering()
        }) else {
            self.putBack()
            return false
        }
        self.lingeringSource = source
        self.isLingering = true
        self.putBackContents()
        // A bar that lays itself out while put back (the chat-list header applies the scroll it held) can find its
        // content changed and interrupt the hold it was just given; the linger then ended before it began.
        guard self.isLingering else {
            return false
        }
        self.renderer.backdropView.removeFromSuperview()
        self.renderer.glassSettled = { [weak self] in
            self?.endLingering()
        }
        // A safety net: the glass settles well within this.
        let lingerCap = NavigationAnimationClock(hostView: self.view)
        lingerCap.ended = { [weak self] in
            self?.endLingering()
        }
        self.lingerCap = lingerCap
        let _ = lingerCap.start(duration: 1.5, continuing: false)
        return true
    }

    /// The renderer's glass hands over to the bar it lingered above.
    func endLingering() {
        guard self.isLingering else {
            return
        }
        self.isLingering = false
        self.lingerCap?.stop()
        self.lingerCap = nil
        self.renderer.glassSettled = nil
        self.renderer.rowView.removeFromSuperview()
        self.renderer.end()
        let source = self.lingeringSource
        self.lingeringSource = nil
        let _ = source?.holdGlass(false, interrupted: nil)
        let handovers = self.lingerHandovers
        self.lingerHandovers = []
        handovers.forEach { $0() }
        self.removeFromSupernode()
        let lingerEnded = self.lingerEnded
        self.lingerEnded = nil
        lingerEnded?()
    }

    /// Whether the glass lingers above `source`'s bar.
    func isLingering(above source: NavigationBarTransitionSource?) -> Bool {
        guard self.isLingering, let source, let lingeringSource = self.lingeringSource else {
            return false
        }
        return source === lingeringSource
    }

    /// Ends the roles and returns both contents to their bars, before the transition's completion runs.
    func putBack() {
        self.putBackContents()
        self.renderer.backdropView.removeFromSuperview()
        self.renderer.rowView.removeFromSuperview()
        self.renderer.end()
    }

    private func putBackContents() {
        self.timeline = nil
        for lifted in [self.bottom, self.top] {
            lifted.clipView.removeFromSuperview()
            guard let source = lifted.source else {
                lifted.info.contentView.removeFromSuperview()
                continue
            }
            source.transitionContentFrameUpdated = nil
            source.updateTransition(role: nil, fraction: 0.0, transition: .immediate)
            source.putBack()
        }
    }
}
