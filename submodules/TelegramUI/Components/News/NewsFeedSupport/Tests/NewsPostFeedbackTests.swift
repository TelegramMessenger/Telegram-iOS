import XCTest
import CoreGraphics
import TelegramCore
@testable import NewsFeedSupport

final class NewsPostFeedbackTests: XCTestCase {
    private let channelA = EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(1))
    private let channelB = EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(2))
    private let p1 = AnyHashable("p1")
    private let p2 = AnyHashable("p2")
    private let p3 = AnyHashable("p3")

    // MARK: rows

    func testAnUntouchedPostShowsAsAPost() {
        let state = NewsPostFeedbackState()
        XCTAssertEqual(state.row(post: self.p1, channel: self.channelA), .post(fading: false))
        XCTAssertTrue(state.isShown(post: self.p1, channel: self.channelA))
    }

    // Not Interested: the content fades in place, then the panel takes its place.
    func testNotInterestedFadesThePostThenShowsThePanel() {
        var state = NewsPostFeedbackState()
        XCTAssertTrue(state.beginNotInterested(self.p1))
        XCTAssertEqual(state.row(post: self.p1, channel: self.channelA), .post(fading: true))
        XCTAssertTrue(state.showPanel(self.p1))
        XCTAssertEqual(state.row(post: self.p1, channel: self.channelA), .panel(.asking, fading: false))
        XCTAssertTrue(state.hasPanel(self.p1))
    }

    func testASecondNotInterestedOnTheSamePostIsRefused() {
        var state = NewsPostFeedbackState()
        XCTAssertTrue(state.beginNotInterested(self.p1))
        XCTAssertFalse(state.beginNotInterested(self.p1))
        XCTAssertTrue(state.showPanel(self.p1))
        XCTAssertFalse(state.beginNotInterested(self.p1))
    }

    // Undo: the panel fades, then the post is back as it was.
    func testUndoBringsThePostBack() {
        var state = NewsPostFeedbackState()
        _ = state.beginNotInterested(self.p1)
        _ = state.showPanel(self.p1)
        XCTAssertTrue(state.beginUndo(self.p1))
        XCTAssertEqual(state.row(post: self.p1, channel: self.channelA), .panel(.asking, fading: true))
        XCTAssertTrue(state.finishUndo(self.p1, channel: self.channelA))
        XCTAssertEqual(state.row(post: self.p1, channel: self.channelA), .post(fading: false))
        XCTAssertEqual(state, NewsPostFeedbackState())
    }

    func testUndoAndChooseOnlyWhileAsking() {
        var state = NewsPostFeedbackState()
        XCTAssertFalse(state.beginUndo(self.p1))
        XCTAssertFalse(state.choose(self.p1, channel: self.channelA, choice: .fewerLikeThis, others: []))
        _ = state.beginNotInterested(self.p1)
        _ = state.showPanel(self.p1)
        XCTAssertTrue(state.choose(self.p1, channel: self.channelA, choice: .fewerLikeThis, others: []))
        XCTAssertFalse(state.beginUndo(self.p1))
        XCTAssertFalse(state.choose(self.p1, channel: self.channelA, choice: .hideChannel, others: []))
    }

    // "Like this": the panel confirms and leaves; only that post stays hidden.
    func testFewerLikeThisHidesOnlyThePost() {
        var state = NewsPostFeedbackState()
        _ = state.beginNotInterested(self.p1)
        _ = state.showPanel(self.p1)
        _ = state.choose(self.p1, channel: self.channelA, choice: .fewerLikeThis, others: [])
        XCTAssertEqual(state.row(post: self.p1, channel: self.channelA), .panel(.done(.fewerLikeThis), fading: false))
        XCTAssertTrue(state.beginPanelLeave(self.p1))
        XCTAssertTrue(state.finishPanelLeave(self.p1))
        XCTAssertEqual(state.row(post: self.p1, channel: self.channelA), .hidden)
        XCTAssertEqual(state.row(post: self.p2, channel: self.channelA), .post(fading: false))
    }

    // A channel choice: the channel's other posts stay until their own fade, then the channel is hidden.
    func testAChannelChoiceFadesTheOtherPostsThenHidesTheChannel() {
        var state = NewsPostFeedbackState()
        _ = state.beginNotInterested(self.p1)
        _ = state.showPanel(self.p1)
        XCTAssertTrue(state.choose(self.p1, channel: self.channelA, choice: .hideChannel, others: [self.p2]))
        XCTAssertEqual(state.row(post: self.p2, channel: self.channelA), .post(fading: false))
        XCTAssertEqual(state.row(post: self.p3, channel: self.channelA), .hidden)
        XCTAssertTrue(state.beginLingeringFade(self.p2))
        XCTAssertEqual(state.row(post: self.p2, channel: self.channelA), .post(fading: true))
        XCTAssertTrue(state.finishLingeringFade(self.p2))
        XCTAssertEqual(state.row(post: self.p2, channel: self.channelA), .hidden)
        XCTAssertEqual(state.row(post: self.p3, channel: self.channelB), .post(fading: false))
    }

    func testRemoveFromNewsHidesTheChannelToo() {
        XCTAssertTrue(NewsPostFeedbackChoice.removeChannelFromNews.hidesChannel)
        XCTAssertTrue(NewsPostFeedbackChoice.hideChannel.hidesChannel)
        XCTAssertFalse(NewsPostFeedbackChoice.fewerLikeThis.hidesChannel)
    }

    // A lingering post cannot start its own Not Interested: it is already on its way out.
    func testALingeringPostRefusesNotInterested() {
        var state = NewsPostFeedbackState()
        _ = state.beginNotInterested(self.p1)
        _ = state.showPanel(self.p1)
        _ = state.choose(self.p1, channel: self.channelA, choice: .hideChannel, others: [self.p2])
        XCTAssertFalse(state.beginNotInterested(self.p2))
    }

    // Review Focus 2: another post of the channel already has a panel; hiding the channel leaves that panel.
    func testAPanelSurvivesItsChannelBeingHidden() {
        var state = NewsPostFeedbackState()
        _ = state.beginNotInterested(self.p1)
        _ = state.showPanel(self.p1)
        _ = state.beginNotInterested(self.p2)
        _ = state.showPanel(self.p2)
        _ = state.choose(self.p1, channel: self.channelA, choice: .hideChannel, others: [])
        XCTAssertEqual(state.row(post: self.p2, channel: self.channelA), .panel(.asking, fading: false))
    }

    // Stale timer steps do nothing (Review Focus 1).
    func testStepsThatNoLongerApplyAreRefused() {
        var state = NewsPostFeedbackState()
        XCTAssertFalse(state.showPanel(self.p1))
        XCTAssertFalse(state.finishUndo(self.p1, channel: self.channelA))
        XCTAssertFalse(state.beginLingeringFade(self.p1))
        XCTAssertFalse(state.finishLingeringFade(self.p1))
        XCTAssertFalse(state.beginPanelLeave(self.p1))
        XCTAssertFalse(state.finishPanelLeave(self.p1))
        _ = state.beginNotInterested(self.p1)
        _ = state.showPanel(self.p1)
        // Leaving is only for a confirmed panel.
        XCTAssertFalse(state.beginPanelLeave(self.p1))
    }

    // MARK: others

    func testOthersAreTheChannelsShownPostsInListOrder() {
        var state = NewsPostFeedbackState()
        let p4 = AnyHashable("p4")
        _ = state.beginNotInterested(p4)
        _ = state.showPanel(p4)
        let posts: [(post: AnyHashable, channel: EnginePeer.Id)] = [(self.p3, self.channelA), (self.p1, self.channelA), (self.p2, self.channelB), (p4, self.channelA)]
        XCTAssertEqual(state.others(of: self.p1, channel: self.channelA, in: posts, visible: [self.p1, self.p2, self.p3, p4]), [self.p3])
    }

    // Final review: a channel can have dozens of posts in the feed; only the ones on screen fade one by one, the rest
    // are hidden at once with the channel, so the confirmation does not hang while unseen posts fade.
    func testOthersAreOnlyTheChannelsPostsOnScreen() {
        let state = NewsPostFeedbackState()
        let p4 = AnyHashable("p4")
        let posts: [(post: AnyHashable, channel: EnginePeer.Id)] = [(self.p2, self.channelA), (self.p1, self.channelA), (self.p3, self.channelA), (p4, self.channelA)]
        XCTAssertEqual(state.others(of: self.p1, channel: self.channelA, in: posts, visible: [self.p1, self.p3]), [self.p3])
        XCTAssertEqual(state.others(of: self.p1, channel: self.channelA, in: posts, visible: []), [])
    }

    // MARK: deferred review fixes

    // Undo always brings its post back, even when another panel's choice hid the channel meanwhile.
    func testUndoKeepsThePostWhenItsChannelWasHiddenMeanwhile() {
        var state = NewsPostFeedbackState()
        _ = state.beginNotInterested(self.p1)
        _ = state.showPanel(self.p1)
        _ = state.beginNotInterested(self.p2)
        _ = state.showPanel(self.p2)
        _ = state.choose(self.p2, channel: self.channelA, choice: .hideChannel, others: [])
        XCTAssertTrue(state.beginUndo(self.p1))
        XCTAssertTrue(state.finishUndo(self.p1, channel: self.channelA))
        XCTAssertEqual(state.row(post: self.p1, channel: self.channelA), .post(fading: false))
        XCTAssertEqual(state.row(post: self.p3, channel: self.channelA), .hidden)
    }

    // Undo before the channel is hidden records nothing: hiding the channel later takes the post with it.
    func testAPostUndoneBeforeItsChannelIsHiddenGoesWithIt() {
        var state = NewsPostFeedbackState()
        _ = state.beginNotInterested(self.p1)
        _ = state.showPanel(self.p1)
        _ = state.beginUndo(self.p1)
        _ = state.finishUndo(self.p1, channel: self.channelA)
        _ = state.beginNotInterested(self.p2)
        _ = state.showPanel(self.p2)
        _ = state.choose(self.p2, channel: self.channelA, choice: .hideChannel, others: [self.p1])
        _ = state.beginLingeringFade(self.p1)
        _ = state.finishLingeringFade(self.p1)
        XCTAssertEqual(state.row(post: self.p1, channel: self.channelA), .hidden)
    }

    // A post restored by Undo can still be hidden again by its own panel.
    func testARestoredPostCanBeHiddenAgain() {
        var state = NewsPostFeedbackState()
        _ = state.beginNotInterested(self.p1)
        _ = state.showPanel(self.p1)
        _ = state.beginUndo(self.p1)
        _ = state.finishUndo(self.p1, channel: self.channelA)
        _ = state.beginNotInterested(self.p1)
        _ = state.showPanel(self.p1)
        _ = state.choose(self.p1, channel: self.channelA, choice: .fewerLikeThis, others: [])
        _ = state.beginPanelLeave(self.p1)
        _ = state.finishPanelLeave(self.p1)
        XCTAssertEqual(state.row(post: self.p1, channel: self.channelA), .hidden)
    }

    // A post fading for its own panel is not one of the channel's others: it gets its panel, not a lingering fade.
    func testOthersSkipAPostFadingForItsOwnPanel() {
        var state = NewsPostFeedbackState()
        _ = state.beginNotInterested(self.p2)
        let posts: [(post: AnyHashable, channel: EnginePeer.Id)] = [(self.p1, self.channelA), (self.p2, self.channelA), (self.p3, self.channelA)]
        XCTAssertEqual(state.others(of: self.p1, channel: self.channelA, in: posts, visible: [self.p1, self.p2, self.p3]), [self.p3])
    }

    // Rows on their way out (lingering, or fading) are inert: no swipe, no tap.
    func testLeavingPostsAreTheLingeringAndTheFadingOnes() {
        var state = NewsPostFeedbackState()
        XCTAssertFalse(state.isLeaving(self.p1))
        _ = state.beginNotInterested(self.p1)
        XCTAssertTrue(state.isLeaving(self.p1))
        _ = state.showPanel(self.p1)
        XCTAssertFalse(state.isLeaving(self.p1))
        _ = state.choose(self.p1, channel: self.channelA, choice: .hideChannel, others: [self.p2])
        XCTAssertTrue(state.isLeaving(self.p2))
        _ = state.beginLingeringFade(self.p2)
        XCTAssertTrue(state.isLeaving(self.p2))
        _ = state.finishLingeringFade(self.p2)
        XCTAssertFalse(state.isLeaving(self.p2))
    }

    // Appear times matter only within the appear window; older ones are dropped.
    func testAppearTimesArePrunedPastTheWindow() {
        let pruned = NewsFeedbackTiming.pruned([self.p1: 10.0, self.p2: 10.25, self.p3: 9.0], now: 10.3)
        XCTAssertEqual(pruned, [self.p2: 10.25])
    }

    // MARK: tabs

    func testTabsKeepSeparateStates() {
        var forYou = NewsPostFeedbackState()
        let added = NewsPostFeedbackState()
        _ = forYou.beginNotInterested(self.p1)
        _ = forYou.showPanel(self.p1)
        _ = forYou.choose(self.p1, channel: self.channelA, choice: .hideChannel, others: [])
        XCTAssertEqual(forYou.row(post: self.p2, channel: self.channelA), .hidden)
        XCTAssertEqual(added.row(post: self.p2, channel: self.channelA), .post(fading: false))
    }

    // MARK: timings

    func testTimingsAreTheMockups() {
        XCTAssertEqual(NewsFeedbackTiming.fadeOut, 0.16, accuracy: 0.0001)
        XCTAssertEqual(NewsFeedbackTiming.appearDelay, 0.08, accuracy: 0.0001)
        XCTAssertEqual(NewsFeedbackTiming.othersFadeDelay(index: 0), 0.45, accuracy: 0.0001)
        XCTAssertEqual(NewsFeedbackTiming.othersFadeDelay(index: 2), 0.69, accuracy: 0.0001)
        XCTAssertEqual(NewsFeedbackTiming.panelLeaveDelay(othersCount: 0), 1.7, accuracy: 0.0001)
        XCTAssertEqual(NewsFeedbackTiming.panelLeaveDelay(othersCount: 10), 2.25, accuracy: 0.0001)
    }

    func testAppearPlaysOnlyRightAfterItsTime() {
        XCTAssertTrue(NewsFeedbackTiming.playsAppear(appearTime: 10.0, now: 10.1))
        XCTAssertFalse(NewsFeedbackTiming.playsAppear(appearTime: 10.0, now: 10.4))
        XCTAssertFalse(NewsFeedbackTiming.playsAppear(appearTime: nil, now: 10.0))
    }

    func testSpringsAreTheMockups() {
        XCTAssertEqual(NewsSpring.rows, NewsSpring(duration: 0.4, bounce: 0.0))
        XCTAssertEqual(NewsSpring.lens, NewsSpring(duration: 0.5, bounce: 0.3))
    }
}
