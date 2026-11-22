import XCTest
import Postbox
@testable import TelegramCore

/// `CachedChannelData.ActiveCall.isStream` tells a live stream (no microphone, broadcast playback) from a video chat.
/// It must survive the cached data being stored and read back, or every relaunch sees a stream as a video chat.
final class CachedActiveCallCodingTests: XCTestCase {
    private func roundTrip(_ call: CachedChannelData.ActiveCall) -> CachedChannelData.ActiveCall {
        let encoder = PostboxEncoder()
        call.encode(encoder)
        return CachedChannelData.ActiveCall(decoder: PostboxDecoder(buffer: MemoryBuffer(data: encoder.makeData())))
    }

    private func activeCall(isStream: Bool?) -> CachedChannelData.ActiveCall {
        return CachedChannelData.ActiveCall(id: 1, accessHash: 2, title: "Live", scheduleTimestamp: nil, subscribedToScheduled: false, isStream: isStream)
    }

    func testStreamRoundTrips() {
        XCTAssertEqual(self.roundTrip(self.activeCall(isStream: true)).isStream, true)
    }

    func testVideoChatRoundTrips() {
        XCTAssertEqual(self.roundTrip(self.activeCall(isStream: false)).isStream, false)
    }

    func testUnknownRoundTrips() {
        XCTAssertNil(self.roundTrip(self.activeCall(isStream: nil)).isStream)
    }

    func testWholeCallRoundTrips() {
        let call = CachedChannelData.ActiveCall(id: 7, accessHash: 8, title: "Title", scheduleTimestamp: 100, subscribedToScheduled: true, isStream: true)
        XCTAssertEqual(self.roundTrip(call), call)
    }

    // The call the chat's banner joins is read from the whole cached data, not from the call alone.
    func testCachedChannelDataKeepsTheStream() {
        let cachedData = CachedChannelData().withUpdatedActiveCall(self.activeCall(isStream: true))
        let encoder = PostboxEncoder()
        cachedData.encode(encoder)
        let decoded = CachedChannelData(decoder: PostboxDecoder(buffer: MemoryBuffer(data: encoder.makeData())))
        XCTAssertEqual(decoded.activeCall?.isStream, true)
    }

    // A full peer names its call by id alone: what is cached about that call is kept.
    func testFullPeerCallKeepsTheSameCallsKind() {
        let previous = CachedChannelData.ActiveCall(id: 1, accessHash: 2, title: "Live", scheduleTimestamp: nil, subscribedToScheduled: true, isStream: true)
        let call = CachedChannelData.ActiveCall(fullPeerCallId: 1, accessHash: 2, previous: previous)
        XCTAssertEqual(call, previous)
    }

    // A stream that ended and a video chat that started: the new call's kind is unknown, not the stream's.
    func testFullPeerCallDropsAnotherCallsKind() {
        let previous = self.activeCall(isStream: true)
        let call = CachedChannelData.ActiveCall(fullPeerCallId: 3, accessHash: 4, previous: previous)
        XCTAssertEqual(call.id, 3)
        XCTAssertEqual(call.accessHash, 4)
        XCTAssertNil(call.isStream)
    }

    func testFullPeerCallWithoutAPreviousCall() {
        let call = CachedChannelData.ActiveCall(fullPeerCallId: 3, accessHash: 4, previous: nil)
        XCTAssertNil(call.isStream)
        XCTAssertNil(call.title)
        XCTAssertFalse(call.subscribedToScheduled)
    }
}
