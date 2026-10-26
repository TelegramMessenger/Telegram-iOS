import Foundation
import QuartzCore
import SwiftSignalKit
import Display
import TelegramCore
import NewsFeedSupport
import NewsFeedComponents

/// One tab's "Post hidden" flow (spec §2): local and in memory, nothing sent or stored. It runs the mockup's steps on
/// main-queue timers; each step re-checks the state, so a step that no longer applies does nothing.
final class NewsPostFeedbackController {
    let tab: NewsPostFeedbackPanelComponent.Tab
    private(set) var state = NewsPostFeedbackState()
    /// When Undo brought each post back, and when each panel went in: rows created right after play their appear.
    private(set) var postAppearTimes: [AnyHashable: Double] = [:]
    private(set) var panelAppearTimes: [AnyHashable: Double] = [:]
    /// Rebuild the tab's list. `rowsChanged`: rows went in or out, so the pass runs on `NewsSpring.rows`.
    var updated: ((_ rowsChanged: Bool) -> Void)?
    /// The tab's posts in list order, with their channels: a channel choice's other posts come from them.
    var currentPosts: (() -> [(post: AnyHashable, channel: EnginePeer.Id)])?
    /// The tab's rows on screen now: only those of a hidden channel's posts fade one by one.
    var visiblePosts: (() -> Set<AnyHashable>)?
    private let haptic = HapticFeedback()

    init(tab: NewsPostFeedbackPanelComponent.Tab) {
        self.tab = tab
    }

    /// The post fades, then the panel takes its place.
    func notInterested(post: AnyHashable) {
        guard self.state.beginNotInterested(post) else {
            return
        }
        self.haptic.impact(.light)
        self.updated?(false)
        Queue.mainQueue().after(NewsFeedbackTiming.fadeOut, { [weak self] in
            guard let self, self.state.showPanel(post) else {
                return
            }
            let now = CACurrentMediaTime()
            self.panelAppearTimes = NewsFeedbackTiming.pruned(self.panelAppearTimes, now: now)
            self.panelAppearTimes[post] = now
            self.updated?(true)
        })
    }

    /// The panel fades, then the post comes back, even if another panel's choice hid its channel meanwhile.
    func undo(post: AnyHashable, channel: EnginePeer.Id) {
        guard self.state.beginUndo(post) else {
            return
        }
        self.haptic.tap()
        self.updated?(false)
        Queue.mainQueue().after(NewsFeedbackTiming.fadeOut, { [weak self] in
            guard let self, self.state.finishUndo(post, channel: channel) else {
                return
            }
            let now = CACurrentMediaTime()
            self.postAppearTimes = NewsFeedbackTiming.pruned(self.postAppearTimes, now: now)
            self.postAppearTimes[post] = now
            self.updated?(true)
        })
    }

    /// The panel confirms; a channel choice's other posts fade out one by one; then the panel leaves.
    func choose(post: AnyHashable, channel: EnginePeer.Id, choice: NewsPostFeedbackChoice) {
        let others = choice.hidesChannel ? self.state.others(of: post, channel: channel, in: self.currentPosts?() ?? [], visible: self.visiblePosts?() ?? []) : []
        guard self.state.choose(post, channel: channel, choice: choice, others: others) else {
            return
        }
        self.haptic.success()
        self.updated?(false)
        for (index, other) in others.enumerated() {
            Queue.mainQueue().after(NewsFeedbackTiming.othersFadeDelay(index: index), { [weak self] in
                guard let self, self.state.beginLingeringFade(other) else {
                    return
                }
                self.updated?(false)
                Queue.mainQueue().after(NewsFeedbackTiming.fadeOut, { [weak self] in
                    guard let self, self.state.finishLingeringFade(other) else {
                        return
                    }
                    self.updated?(true)
                })
            })
        }
        Queue.mainQueue().after(NewsFeedbackTiming.panelLeaveDelay(othersCount: others.count), { [weak self] in
            guard let self, self.state.beginPanelLeave(post) else {
                return
            }
            self.updated?(false)
            Queue.mainQueue().after(NewsFeedbackTiming.fadeOut, { [weak self] in
                guard let self, self.state.finishPanelLeave(post) else {
                    return
                }
                self.updated?(true)
            })
        })
    }
}
