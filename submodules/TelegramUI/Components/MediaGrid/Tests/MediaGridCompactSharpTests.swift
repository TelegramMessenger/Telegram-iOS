import XCTest
@testable import CoreList
@testable import MediaGrid

final class MediaGridCompactSharpTests: XCTestCase {
    private var time: CFTimeInterval = 0.0

    private func makeView(requestsSharp: Bool) -> (MediaGridView, TestDataSource) {
        let dataSource = TestDataSource(count: 100_000)
        dataSource.providesThumbnails = true
        dataSource.holdsDeliveries = true
        let view = MediaGridView(dataSource: dataSource, cellFactory: {
            return MediaGridCellLayer()
        })
        view.motionClock = { [unowned self] in
            return self.time
        }
        view.scaleOverride = 3.0
        view.compactLevelsRequestSharpImages = requestsSharp
        view.frame = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 852.0)
        view.layoutIfNeeded()
        return (view, dataSource)
    }

    private func settle(_ view: MediaGridView) {
        self.time += MediaGridView.motionSettleDelay * 2.0
        view._testSettleMotion()
    }

    private func visibleIndices(_ view: MediaGridView) -> Set<Int> {
        guard let layout = view.gridLayout else {
            return []
        }
        return Set(layout.indexRange(intersecting: CGRect(x: 0.0, y: view.contentOffset, width: view.bounds.width, height: view.bounds.height)))
    }

    func testCompactLevelRequestsSharpWhenEnabled() {
        let (view, dataSource) = self.makeView(requestsSharp: true)
        view.setLevel(.fifteen, animated: false)
        view.setContentOffset(20_000.0)
        self.settle(view)
        let requested = Set(dataSource.requests.map(\.index))
        let visible = self.visibleIndices(view)
        XCTAssertFalse(visible.isEmpty)
        XCTAssertTrue(visible.isSubset(of: requested))
    }

    func testCompactLevelSkipsSharpByDefault() {
        let (view, dataSource) = self.makeView(requestsSharp: false)
        view.setLevel(.fifteen, animated: false)
        let before = dataSource.requests.count
        view.setContentOffset(20_000.0)
        self.settle(view)
        XCTAssertEqual(dataSource.requests.count, before)
    }

    func testCompactPrefetchRunsWhenEnabled() {
        let (view, dataSource) = self.makeView(requestsSharp: true)
        view.setLevel(.fifteen, animated: false)
        let caching = dataSource.startedCachingOrder.count
        view.setContentOffset(20_000.0)
        self.settle(view)
        XCTAssertGreaterThan(dataSource.startedCachingOrder.count, caching)
    }
}
