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
        let recents = mediaPickerGridAssetsConfiguration(subjectCollectionId: nil, selectedCollectionId: nil, isFiltered: false)
        XCTAssertEqual(recents, MediaPickerGridAssetsConfiguration(key: "", isReversed: true, isLibrary: true, scrollsToEnd: false))

        let menuAlbum = mediaPickerGridAssetsConfiguration(subjectCollectionId: nil, selectedCollectionId: "album", isFiltered: false)
        XCTAssertEqual(menuAlbum, MediaPickerGridAssetsConfiguration(key: "album", isReversed: true, isLibrary: false, scrollsToEnd: false))

        let pushedAlbum = mediaPickerGridAssetsConfiguration(subjectCollectionId: "album", selectedCollectionId: nil, isFiltered: false)
        XCTAssertEqual(pushedAlbum, MediaPickerGridAssetsConfiguration(key: "album", isReversed: false, isLibrary: false, scrollsToEnd: true))
    }

    func testFetchIndexMapping() {
        XCTAssertEqual((0 ..< 4).map { mediaPickerGridFetchIndex(gridIndex: $0, count: 4, isReversed: true) }, [3, 2, 1, 0])
        XCTAssertEqual((0 ..< 4).map { mediaPickerGridFetchIndex(gridIndex: $0, count: 4, isReversed: false) }, [0, 1, 2, 3])
    }

    func testChatAttachmentDefaultAssetsPredicate() {
        XCTAssertTrue(mediaPickerIsChatAttachmentDefaultAssets(isAssets: true, isDefaultMode: true, forCollage: false))
        XCTAssertFalse(mediaPickerIsChatAttachmentDefaultAssets(isAssets: true, isDefaultMode: true, forCollage: true))
        XCTAssertFalse(mediaPickerIsChatAttachmentDefaultAssets(isAssets: true, isDefaultMode: false, forCollage: false))
        XCTAssertFalse(mediaPickerIsChatAttachmentDefaultAssets(isAssets: false, isDefaultMode: true, forCollage: false))
    }

    func testInstallAndTeardownDecision() {
        let recents = mediaPickerGridAssetsConfiguration(subjectCollectionId: nil, selectedCollectionId: nil, isFiltered: false)
        let album = mediaPickerGridAssetsConfiguration(subjectCollectionId: nil, selectedCollectionId: "album", isFiltered: false)
        XCTAssertTrue(mediaPickerGridNeedsInstall(current: nil, hasGrid: false, new: recents))
        XCTAssertFalse(mediaPickerGridNeedsInstall(current: recents, hasGrid: true, new: recents))
        XCTAssertTrue(mediaPickerGridNeedsInstall(current: recents, hasGrid: true, new: album))
        XCTAssertTrue(mediaPickerGridNeedsInstall(current: recents, hasGrid: false, new: recents))
    }

    func testAlbumSwitchKeepsTheLevel() {
        XCTAssertEqual(mediaPickerGridInitialLevelColumns(carriedColumns: nil, isLandscape: false), 3)
        XCTAssertEqual(mediaPickerGridInitialLevelColumns(carriedColumns: nil, isLandscape: true), 5)
        XCTAssertEqual(mediaPickerGridInitialLevelColumns(carriedColumns: 15, isLandscape: false), 15)
        XCTAssertEqual(mediaPickerGridInitialLevelColumns(carriedColumns: 1, isLandscape: true), 1)
    }

    func testRouting() {
        XCTAssertTrue(mediaPickerUsesMediaGrid(isEnabled: true))
        XCTAssertFalse(mediaPickerUsesMediaGrid(isEnabled: false))
    }

    func testFilteredRecentsNeverDriveTheFiller() {
        let filtered = mediaPickerGridAssetsConfiguration(subjectCollectionId: nil, selectedCollectionId: nil, isFiltered: true)
        XCTAssertEqual(filtered, MediaPickerGridAssetsConfiguration(key: "", isReversed: true, isLibrary: false, scrollsToEnd: false))
        let filteredAlbum = mediaPickerGridAssetsConfiguration(subjectCollectionId: "album", selectedCollectionId: nil, isFiltered: true)
        XCTAssertEqual(filteredAlbum, MediaPickerGridAssetsConfiguration(key: "album", isReversed: false, isLibrary: false, scrollsToEnd: true))
    }

    func testModeKind() {
        XCTAssertEqual(mediaPickerGridModeKind(isAssets: true, isDefaultMode: true, isStoryMode: false, forCollage: false), .chatAttachment)
        XCTAssertEqual(mediaPickerGridModeKind(isAssets: true, isDefaultMode: true, isStoryMode: false, forCollage: true), .other)
        XCTAssertEqual(mediaPickerGridModeKind(isAssets: true, isDefaultMode: false, isStoryMode: true, forCollage: false), .story)
        XCTAssertEqual(mediaPickerGridModeKind(isAssets: true, isDefaultMode: false, isStoryMode: true, forCollage: true), .story)
        XCTAssertEqual(mediaPickerGridModeKind(isAssets: true, isDefaultMode: false, isStoryMode: false, forCollage: false), .other)
        XCTAssertEqual(mediaPickerGridModeKind(isAssets: false, isDefaultMode: false, isStoryMode: false, forCollage: false), .other)
    }

    func testZoomOnlyInTheChatAttachmentMenu() {
        let attachment = mediaPickerGridModeConfiguration(.chatAttachment)
        XCTAssertTrue(attachment.isZoomEnabled)
        XCTAssertEqual(attachment.cellAspect, 1.0)
        XCTAssertFalse(attachment.fitsLandscapeImages)
        XCTAssertFalse(attachment.tracksDownloads)
        XCTAssertEqual(attachment.cameraColumns, [3])

        let story = mediaPickerGridModeConfiguration(.story)
        XCTAssertFalse(story.isZoomEnabled)
        XCTAssertEqual(story.cellAspect, 1.227)
        XCTAssertTrue(story.fitsLandscapeImages)
        XCTAssertTrue(story.tracksDownloads)
        XCTAssertEqual(story.cameraColumns, [3, 5])

        let other = mediaPickerGridModeConfiguration(.other)
        XCTAssertFalse(other.isZoomEnabled)
        XCTAssertEqual(other.cellAspect, 1.0)
        XCTAssertFalse(other.fitsLandscapeImages)
        XCTAssertTrue(other.tracksDownloads)
        XCTAssertEqual(other.cameraColumns, [3, 5])
    }

    func testSelection() {
        XCTAssertTrue(mediaPickerGridAllowsSelection(isMultipleSelectionMode: true, explicitMultipleSelection: false))
        XCTAssertFalse(mediaPickerGridAllowsSelection(isMultipleSelectionMode: false, explicitMultipleSelection: false))
        XCTAssertTrue(mediaPickerGridAllowsSelection(isMultipleSelectionMode: false, explicitMultipleSelection: true))
    }

    func testStoryFitsOnlyLandscapeImages() {
        XCTAssertTrue(mediaPickerGridFitsImage(fitsLandscapeImages: true, pixelWidth: 4032, pixelHeight: 3024))
        XCTAssertFalse(mediaPickerGridFitsImage(fitsLandscapeImages: true, pixelWidth: 3024, pixelHeight: 4032))
        XCTAssertFalse(mediaPickerGridFitsImage(fitsLandscapeImages: true, pixelWidth: 1000, pixelHeight: 1000))
        XCTAssertFalse(mediaPickerGridFitsImage(fitsLandscapeImages: false, pixelWidth: 4032, pixelHeight: 3024))
    }

    func testSlotMapping() {
        XCTAssertNil(mediaPickerGridSlot(index: -1, extraCount: 2, assetCount: 3))
        XCTAssertEqual(mediaPickerGridSlot(index: 0, extraCount: 2, assetCount: 3), .extra(0))
        XCTAssertEqual(mediaPickerGridSlot(index: 1, extraCount: 2, assetCount: 3), .extra(1))
        XCTAssertEqual(mediaPickerGridSlot(index: 2, extraCount: 2, assetCount: 3), .asset(0))
        XCTAssertEqual(mediaPickerGridSlot(index: 4, extraCount: 2, assetCount: 3), .asset(2))
        XCTAssertNil(mediaPickerGridSlot(index: 5, extraCount: 2, assetCount: 3))
        XCTAssertEqual(mediaPickerGridSlot(index: 0, extraCount: 0, assetCount: 3), .asset(0))
        XCTAssertEqual(mediaPickerGridSlot(index: 2, extraCount: 3, assetCount: 0), .extra(2))
        XCTAssertNil(mediaPickerGridSlot(index: 3, extraCount: 3, assetCount: 0))
    }

    func testAssetChangesShiftPastTheExtras() {
        var indices = IndexSet()
        indices.insert(integersIn: 0 ..< 3)
        indices.insert(7)
        XCTAssertEqual(Array(mediaPickerGridShifted(indices, by: 2)), [2, 3, 4, 9])
        XCTAssertEqual(mediaPickerGridShifted(indices, by: 0), indices)
        XCTAssertEqual(mediaPickerGridShifted(IndexSet(), by: 4), IndexSet())
    }

    func testThumbnailRangesAndCachingIndicesMapToAssets() {
        XCTAssertEqual(mediaPickerGridAssetRanges([0 ..< 6, 10 ..< 12, 40 ..< 50], extraCount: 2, assetCount: 20), [0 ..< 4, 8 ..< 10])
        XCTAssertEqual(mediaPickerGridAssetRanges([0 ..< 2], extraCount: 2, assetCount: 20), [])
        XCTAssertEqual(mediaPickerGridAssetRanges([5 ..< 9, 0 ..< 3], extraCount: 0, assetCount: 7), [5 ..< 7, 0 ..< 3])
        XCTAssertEqual(mediaPickerGridAssetIndices([0, 1, 2, 5, 30], extraCount: 2, assetCount: 10), [0, 3])
    }

    func testExtrasChangeReplacesThePrefix() {
        let change = mediaPickerGridPrefixChange(oldCount: 2, newCount: 1)
        XCTAssertEqual(Array(change.removed), [0, 1])
        XCTAssertEqual(Array(change.inserted), [0])
        let empty = mediaPickerGridPrefixChange(oldCount: 0, newCount: 0)
        XCTAssertTrue(empty.removed.isEmpty && empty.inserted.isEmpty)
    }

    func testDraftDecorations() {
        let photo = mediaPickerGridDraftDecorations(isCompact: false, isVideo: false, duration: nil, draftLabel: "Draft")
        XCTAssertEqual(photo.draftLabel, "Draft")
        XCTAssertNil(photo.check)
        XCTAssertNil(photo.typeIcon)
        XCTAssertNil(photo.durationText)
        XCTAssertFalse(photo.showsRightShadow)

        let video = mediaPickerGridDraftDecorations(isCompact: false, isVideo: true, duration: 65.0, draftLabel: "Draft")
        XCTAssertEqual(video.typeIcon, .video)
        XCTAssertEqual(video.durationText, "1:05")
        XCTAssertTrue(video.showsRightShadow)
        XCTAssertFalse(video.showsLeftShadow)

        XCTAssertEqual(mediaPickerGridDraftDecorations(isCompact: true, isVideo: true, duration: 65.0, draftLabel: "Draft"), .none)
    }

    func testMediaDecorationsCarryOnlyTheCheckAndTheSpoiler() {
        let selection = MediaPickerGridSelectionInfo(isSelected: true, number: 1, count: 1)
        let decorations = mediaPickerGridMediaDecorations(isCompact: false, isSelectable: true, selection: selection, edit: MediaPickerGridEditInfo(hasSpoiler: true))
        XCTAssertEqual(decorations.check, selection)
        XCTAssertNil(decorations.typeIcon)
        XCTAssertNil(decorations.durationText)
        XCTAssertNil(decorations.draftLabel)
        XCTAssertTrue(decorations.showsSpoilerOverlay)
        XCTAssertNil(mediaPickerGridMediaDecorations(isCompact: false, isSelectable: false, selection: selection, edit: MediaPickerGridEditInfo()).check)
    }
}
