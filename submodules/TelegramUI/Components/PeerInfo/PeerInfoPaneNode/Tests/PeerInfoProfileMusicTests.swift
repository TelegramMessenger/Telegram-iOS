import XCTest
@testable import PeerInfoPaneNode

final class PeerInfoProfileMusicTests: XCTestCase {
    // The list's first track once it has one, loading or not.
    func test_listTrack() {
        XCTAssertEqual(peerInfoProfileMusic(list: (files: [1, 2], isLoading: false), fullUserMusic: 3), 1)
        XCTAssertEqual(peerInfoProfileMusic(list: (files: [1, 2], isLoading: true), fullUserMusic: 3), 1)
    }

    // A list that has not answered yet: the full user's track, so the strip is there from the first layout.
    func test_loadingListFallsBackToFullUser() {
        XCTAssertEqual(peerInfoProfileMusic(list: (files: [Int](), isLoading: true), fullUserMusic: 3), 3)
        XCTAssertNil(peerInfoProfileMusic(list: (files: [Int](), isLoading: true), fullUserMusic: nil))
    }

    // A list that answered empty: none, even while the full user still carries a track.
    func test_answeredEmptyListShowsNone() {
        XCTAssertNil(peerInfoProfileMusic(list: (files: [Int](), isLoading: false), fullUserMusic: 3))
    }

    // No list on the screen: the full user's track.
    func test_noList() {
        XCTAssertEqual(peerInfoProfileMusic(list: nil, fullUserMusic: 3), 3)
        XCTAssertNil(peerInfoProfileMusic(list: nil as (files: [Int], isLoading: Bool)?, fullUserMusic: nil))
    }
}
