import XCTest

final class MediaPickerGridCellDecorationsTests: XCTestCase {
    private func decorations(isCompact: Bool = false, isSelectable: Bool = true, selection: MediaPickerGridSelectionInfo = MediaPickerGridSelectionInfo(), asset: MediaPickerGridAssetInfo = MediaPickerGridAssetInfo(), edit: MediaPickerGridEditInfo = MediaPickerGridEditInfo(), displaysLivePhotoIcon: Bool = true, isForceLivePhotoEnabled: Bool = false) -> MediaPickerGridCellDecorations {
        return mediaPickerGridCellDecorations(isCompact: isCompact, isSelectable: isSelectable, selection: selection, asset: asset, edit: edit, displaysLivePhotoIcon: displaysLivePhotoIcon, isForceLivePhotoEnabled: isForceLivePhotoEnabled)
    }

    func testSelectionNumbersFollowSelectionOrder() {
        let numbers = mediaPickerGridSelectionNumbers(["c", "a", "b"])
        XCTAssertEqual(numbers, ["c": 1, "a": 2, "b": 3])
        XCTAssertNil(numbers["d"])
        XCTAssertEqual(mediaPickerGridSelectionNumbers([]), [:])
    }

    func testCheckCarriesTheOrderNumber() {
        let selection = MediaPickerGridSelectionInfo(isSelected: true, number: 3, count: 4)
        XCTAssertEqual(self.decorations(selection: selection).check, selection)
        XCTAssertNil(self.decorations(isSelectable: false, selection: selection).check)
        XCTAssertEqual(self.decorations().check, MediaPickerGridSelectionInfo())
    }

    func testDurationFormatting() {
        XCTAssertEqual(mediaPickerGridDurationText(0.0), "0:00")
        XCTAssertEqual(mediaPickerGridDurationText(9.7), "0:09")
        XCTAssertEqual(mediaPickerGridDurationText(75.0), "1:15")
        XCTAssertEqual(mediaPickerGridDurationText(3599.0), "59:59")
        XCTAssertEqual(mediaPickerGridDurationText(3723.0), "1:02:03")
    }

    func testVideoGifAndPhotoBadges() {
        let video = self.decorations(asset: MediaPickerGridAssetInfo(isVideo: true, duration: 65.0))
        XCTAssertEqual(video.durationText, "1:05")
        XCTAssertEqual(video.typeIcon, .video)
        XCTAssertTrue(video.showsLeftShadow)
        XCTAssertTrue(video.showsRightShadow)

        XCTAssertEqual(self.decorations(asset: MediaPickerGridAssetInfo(isVideo: true, isSlomo: true)).typeIcon, .slomo)
        XCTAssertEqual(self.decorations(asset: MediaPickerGridAssetInfo(isVideo: true, isTimelapse: true)).typeIcon, .timelapse)

        let gif = self.decorations(asset: MediaPickerGridAssetInfo(isGif: true))
        XCTAssertEqual(gif.durationText, "GIF")
        XCTAssertNil(gif.typeIcon)
        XCTAssertFalse(gif.showsLeftShadow)
        XCTAssertTrue(gif.showsRightShadow)

        let photo = self.decorations()
        XCTAssertNil(photo.durationText)
        XCTAssertNil(photo.typeIcon)
        XCTAssertFalse(photo.showsLeftShadow)
        XCTAssertFalse(photo.showsRightShadow)

        XCTAssertEqual(self.decorations(asset: MediaPickerGridAssetInfo(isVideo: true, isFavorite: true)).typeIcon, .favorite)
    }

    func testLivePhotoIcon() {
        let live = MediaPickerGridAssetInfo(isFavorite: true, isLivePhoto: true)
        XCTAssertEqual(self.decorations(asset: live).typeIcon, .livePhotoOff)
        XCTAssertEqual(self.decorations(asset: live, edit: MediaPickerGridEditInfo(isLivePhotoModeOn: true)).typeIcon, .livePhoto)
        XCTAssertEqual(self.decorations(asset: live, edit: MediaPickerGridEditInfo(isLivePhotoModeOn: false), isForceLivePhotoEnabled: true).typeIcon, .livePhoto)
        XCTAssertEqual(self.decorations(asset: live, displaysLivePhotoIcon: false).typeIcon, .favorite)
    }

    func testCompactLevelsHideDecorationsButKeepTheSpoilerBlur() {
        let selection = MediaPickerGridSelectionInfo(isSelected: true, number: 1, count: 1)
        let compact = self.decorations(isCompact: true, selection: selection, asset: MediaPickerGridAssetInfo(isVideo: true, duration: 10.0, isFavorite: true), edit: MediaPickerGridEditInfo(hasSpoiler: true, price: 50))
        XCTAssertNil(compact.check)
        XCTAssertNil(compact.durationText)
        XCTAssertNil(compact.typeIcon)
        XCTAssertFalse(compact.showsLeftShadow)
        XCTAssertFalse(compact.showsRightShadow)
        XCTAssertFalse(compact.showsSpoilerOverlay)
        XCTAssertFalse(compact.showsPrice)
        XCTAssertNil(compact.price)
        XCTAssertTrue(compact.showsSpoilerBlur)

        XCTAssertEqual(self.decorations(isCompact: true), .none)
    }

    func testSpoilerOverlayRequest() {
        let spoiler = self.decorations(edit: MediaPickerGridEditInfo(hasSpoiler: true))
        XCTAssertTrue(spoiler.showsSpoilerBlur)
        XCTAssertTrue(spoiler.showsSpoilerOverlay)
        XCTAssertFalse(spoiler.showsPrice)
        XCTAssertNil(spoiler.price)

        let unselectedPrice = self.decorations(edit: MediaPickerGridEditInfo(price: 50))
        XCTAssertFalse(unselectedPrice.showsSpoilerOverlay)
        XCTAssertFalse(unselectedPrice.showsPrice)
        XCTAssertNil(unselectedPrice.price)

        let singlePrice = self.decorations(selection: MediaPickerGridSelectionInfo(isSelected: true, number: 1, count: 2), edit: MediaPickerGridEditInfo(price: 50))
        XCTAssertTrue(singlePrice.showsSpoilerOverlay)
        XCTAssertTrue(singlePrice.showsPrice)
        XCTAssertEqual(singlePrice.price, 50)

        let otherPrice = self.decorations(selection: MediaPickerGridSelectionInfo(isSelected: true, number: 2, count: 2), edit: MediaPickerGridEditInfo(price: 50))
        XCTAssertTrue(otherPrice.showsSpoilerOverlay)
        XCTAssertTrue(otherPrice.showsPrice)
        XCTAssertNil(otherPrice.price)
    }

    func testAssetsConfiguration() {
        let recents = mediaPickerGridAssetsConfiguration(subjectCollectionId: nil, selectedCollectionId: nil)
        XCTAssertEqual(recents, MediaPickerGridAssetsConfiguration(key: "", isReversed: true, isLibrary: true, scrollsToEnd: false))

        let menuAlbum = mediaPickerGridAssetsConfiguration(subjectCollectionId: nil, selectedCollectionId: "album")
        XCTAssertEqual(menuAlbum, MediaPickerGridAssetsConfiguration(key: "album", isReversed: true, isLibrary: false, scrollsToEnd: false))

        let pushedAlbum = mediaPickerGridAssetsConfiguration(subjectCollectionId: "album", selectedCollectionId: nil)
        XCTAssertEqual(pushedAlbum, MediaPickerGridAssetsConfiguration(key: "album", isReversed: false, isLibrary: false, scrollsToEnd: true))
    }

    func testFetchIndexMapping() {
        XCTAssertEqual((0 ..< 4).map { mediaPickerGridFetchIndex(gridIndex: $0, count: 4, isReversed: true) }, [3, 2, 1, 0])
        XCTAssertEqual((0 ..< 4).map { mediaPickerGridFetchIndex(gridIndex: $0, count: 4, isReversed: false) }, [0, 1, 2, 3])
    }

    func testRouting() {
        XCTAssertTrue(mediaPickerUsesMediaGrid(isChatAttachmentDefaultAssets: true, isEnabled: true))
        XCTAssertFalse(mediaPickerUsesMediaGrid(isChatAttachmentDefaultAssets: true, isEnabled: false))
        XCTAssertFalse(mediaPickerUsesMediaGrid(isChatAttachmentDefaultAssets: false, isEnabled: true))
    }
}
