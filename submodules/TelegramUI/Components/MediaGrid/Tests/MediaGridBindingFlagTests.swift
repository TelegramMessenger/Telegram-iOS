import XCTest
@testable import MediaGrid

private final class BindingRecordingCellLayer: MediaGridCellLayer {
    var onContentChange: ((String, Bool) -> Void)?

    override func setThumbnail(_ thumbnail: MediaGridThumbnail, cellAspect: CGFloat) {
        super.setThumbnail(thumbnail, cellAspect: cellAspect)
        self.onContentChange?("thumbnail", self.isBinding)
    }

    override func setImage(_ image: UIImage?) {
        super.setImage(image)
        if image != nil {
            self.onContentChange?("image", self.isBinding)
        }
    }
}

final class MediaGridBindingFlagTests: XCTestCase {
    private var changes: [(kind: String, isBinding: Bool)] = []

    private func makeView(dataSource: TestDataSource) -> MediaGridView {
        let view = MediaGridView(dataSource: dataSource, cellFactory: { [weak self] in
            let cell = BindingRecordingCellLayer()
            cell.onContentChange = { kind, isBinding in
                self?.changes.append((kind, isBinding))
            }
            return cell
        })
        view.motionClock = { 0.0 }
        view.scaleOverride = 3.0
        view.frame = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 852.0)
        view.layoutIfNeeded()
        return view
    }

    override func tearDown() {
        self.changes = []
        super.tearDown()
    }

    func testThumbnailSetWhileBindingIsMarkedBinding() {
        let dataSource = TestDataSource(count: 1_000)
        dataSource.providesThumbnails = true
        dataSource.holdsDeliveries = true
        _ = self.makeView(dataSource: dataSource)
        let thumbnails = self.changes.filter { $0.kind == "thumbnail" }
        XCTAssertFalse(thumbnails.isEmpty)
        XCTAssertTrue(thumbnails.allSatisfy { $0.isBinding })
    }

    func testLateThumbnailIsNotMarkedBinding() {
        let dataSource = TestDataSource(count: 1_000)
        dataSource.providesThumbnails = true
        dataSource.holdsDeliveries = true
        var available = false
        dataSource.thumbnailAvailable = { _ in available }
        let view = self.makeView(dataSource: dataSource)
        XCTAssertTrue(self.changes.isEmpty)
        available = true
        view.thumbnailsDidChange(indices: nil)
        XCTAssertFalse(self.changes.isEmpty)
        XCTAssertTrue(self.changes.allSatisfy { $0.kind == "thumbnail" && !$0.isBinding })
    }

    func testSynchronousImageIsBindingAndLateImageIsNot() {
        let dataSource = TestDataSource(count: 1_000)
        dataSource.imageForIndex = { TestDataSource.distinctImage($0, side: 400.0) }
        _ = self.makeView(dataSource: dataSource)
        let synchronous = self.changes.filter { $0.kind == "image" }
        XCTAssertFalse(synchronous.isEmpty)
        XCTAssertTrue(synchronous.allSatisfy { $0.isBinding })

        self.changes = []
        let heldDataSource = TestDataSource(count: 1_000)
        heldDataSource.holdsDeliveries = true
        heldDataSource.imageForIndex = { TestDataSource.distinctImage($0, side: 400.0) }
        let view = self.makeView(dataSource: heldDataSource)
        XCTAssertTrue(self.changes.isEmpty)
        heldDataSource.flushHeldDeliveries()
        withExtendedLifetime(view) {}
        XCTAssertFalse(self.changes.isEmpty)
        XCTAssertTrue(self.changes.allSatisfy { $0.kind == "image" && !$0.isBinding })
    }

    func testImageRequestTimeIsStampedWhenRequested() {
        let dataSource = TestDataSource(count: 1_000)
        dataSource.holdsDeliveries = true
        let before = CACurrentMediaTime()
        let view = self.makeView(dataSource: dataSource)
        let cells = view.activeLayoutLayer.visibleCells.values
        XCTAssertFalse(cells.isEmpty)
        XCTAssertTrue(cells.allSatisfy { $0.imageRequestTime >= before })
    }
}
