import Foundation
import UIKit
import Display
import NewsFeedSupport

/// Ticks `NewsRefreshModel` on a shared display link while anything moves, and hands its output to the screen
/// (spec §5.3). Page 0 is For you, 1 is Added.
final class NewsRefreshController {
    private var model = NewsRefreshModel()
    private var link: SharedDisplayLinkDriver.Link?
    private let haptic = HapticFeedback()
    /// Applying the hold makes the list report its offset, which calls back into `tick`.
    private var isTicking = false
    /// The page whose refresh runs; nil while idle.
    private(set) var refreshPage: Int?
    /// Off screen nothing is drawn, so the link pauses; the model is a function of time and resumes where it should.
    var isScreenVisible = true {
        didSet {
            if self.isScreenVisible != oldValue {
                if self.isScreenVisible {
                    self.tick()
                } else {
                    self.link?.isPaused = true
                }
            }
        }
    }

    var selectedPage: (() -> Int)?
    var makeInput: ((Int) -> NewsRefreshInput?)?
    var onBegin: ((Int) -> Void)?
    var onInsertRows: ((Int, Bool) -> Void)?
    var onHold: ((Int, CGFloat) -> Void)?
    var onPose: ((Int, NewsRefreshDropPose) -> Void)?

    deinit {
        self.link?.invalidate()
    }

    /// The list moved: the pull may have begun or changed.
    func listMoved() {
        self.tick()
    }

    func fetchEnded(_ outcome: NewsRefreshOutcome) {
        self.model.fetchEnded(outcome)
        self.tick()
    }

    /// A tab switch or search began.
    func detach() {
        guard let page = self.refreshPage, let input = self.makeInput?(page) else {
            return
        }
        self.model.detach(now: CACurrentMediaTime(), input: input)
        self.tick()
    }

    private func tick() {
        guard !self.isTicking, let page = self.refreshPage ?? self.selectedPage?(), let input = self.makeInput?(page) else {
            return
        }
        self.isTicking = true
        defer {
            self.isTicking = false
        }
        let now = CACurrentMediaTime()
        let events = self.model.step(now: now, input: input)
        // The hold first: a late step that lands and inserts at once must insert into the released list.
        self.onHold?(page, self.model.hold(now: now))
        for event in events {
            switch event {
            case .begin:
                self.refreshPage = page
                self.haptic.impact(.medium, intensity: 0.9)
                self.onBegin?(page)
            case let .insertRows(slides):
                self.onInsertRows?(page, slides)
            }
        }
        self.onPose?(page, self.model.dropPose(now: now, input: input))

        let isLive = self.model.isLive(now: now, gap: input.gap)
        if !isLive, case .idle = self.model.phase, !self.model.isRevealPending {
            self.refreshPage = nil
        }
        if isLive && self.isScreenVisible {
            if self.link == nil {
                self.link = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
                    self?.tick()
                })
            }
            self.link?.isPaused = false
        } else {
            self.link?.isPaused = true
        }
    }
}
