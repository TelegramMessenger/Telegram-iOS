import Foundation

enum MediaPickerGridCellTypeIcon: Equatable {
    case video
    case slomo
    case timelapse
    case favorite
    case livePhoto
    case livePhotoOff
}

struct MediaPickerGridAssetInfo: Equatable {
    var isGif: Bool
    var isVideo: Bool
    var isSlomo: Bool
    var isTimelapse: Bool
    var duration: TimeInterval
    var isFavorite: Bool
    var isLivePhoto: Bool

    init(isGif: Bool = false, isVideo: Bool = false, isSlomo: Bool = false, isTimelapse: Bool = false, duration: TimeInterval = 0.0, isFavorite: Bool = false, isLivePhoto: Bool = false) {
        self.isGif = isGif
        self.isVideo = isVideo
        self.isSlomo = isSlomo
        self.isTimelapse = isTimelapse
        self.duration = duration
        self.isFavorite = isFavorite
        self.isLivePhoto = isLivePhoto
    }
}

struct MediaPickerGridEditInfo: Equatable {
    var hasSpoiler: Bool
    var price: Int64?
    var isLivePhotoModeOn: Bool?

    init(hasSpoiler: Bool = false, price: Int64? = nil, isLivePhotoModeOn: Bool? = nil) {
        self.hasSpoiler = hasSpoiler
        self.price = price
        self.isLivePhotoModeOn = isLivePhotoModeOn
    }
}

struct MediaPickerGridSelectionInfo: Equatable {
    var isSelected: Bool
    var number: Int?
    var count: Int

    init(isSelected: Bool = false, number: Int? = nil, count: Int = 0) {
        self.isSelected = isSelected
        self.number = number
        self.count = count
    }
}

struct MediaPickerGridCellDecorations: Equatable {
    var check: MediaPickerGridSelectionInfo?
    var durationText: String?
    var typeIcon: MediaPickerGridCellTypeIcon?
    var showsLeftShadow: Bool
    var showsRightShadow: Bool
    var showsSpoilerBlur: Bool
    var showsSpoilerOverlay: Bool
    var showsPrice: Bool
    var price: Int64?

    static let none = MediaPickerGridCellDecorations(check: nil, durationText: nil, typeIcon: nil, showsLeftShadow: false, showsRightShadow: false, showsSpoilerBlur: false, showsSpoilerOverlay: false, showsPrice: false, price: nil)
}

func mediaPickerGridDurationText(_ duration: TimeInterval) -> String {
    let value = Int32(clamping: Int(duration))
    let hours = value / 3600
    let minutes = value / 60 % 60
    let seconds = value % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
        return String(format: "%d:%02d", minutes, seconds)
    }
}

func mediaPickerGridSelectionNumbers(_ identifiers: [String]) -> [String: Int] {
    var result: [String: Int] = [:]
    result.reserveCapacity(identifiers.count)
    for (index, identifier) in identifiers.enumerated() where result[identifier] == nil {
        result[identifier] = index + 1
    }
    return result
}

func mediaPickerGridCellDecorations(isCompact: Bool, isSelectable: Bool, selection: MediaPickerGridSelectionInfo, asset: MediaPickerGridAssetInfo, edit: MediaPickerGridEditInfo, displaysLivePhotoIcon: Bool, isForceLivePhotoEnabled: Bool) -> MediaPickerGridCellDecorations {
    let selectedPrice = selection.isSelected ? edit.price : nil
    let isSingle = selection.count == 1 || selection.number == 1
    let hasSpoilerContent = edit.hasSpoiler || selectedPrice != nil
    if isCompact {
        var result = MediaPickerGridCellDecorations.none
        result.showsSpoilerBlur = hasSpoilerContent
        return result
    }

    var durationText: String?
    var typeIcon: MediaPickerGridCellTypeIcon?
    if asset.isGif {
        durationText = "GIF"
    } else if asset.isVideo {
        if asset.isSlomo {
            typeIcon = .slomo
        } else if asset.isTimelapse {
            typeIcon = .timelapse
        } else {
            typeIcon = .video
        }
        durationText = mediaPickerGridDurationText(asset.duration)
    }
    if asset.isFavorite {
        typeIcon = .favorite
    }
    if asset.isLivePhoto && !asset.isVideo && displaysLivePhotoIcon {
        let isOn = edit.isLivePhotoModeOn == true || isForceLivePhotoEnabled
        typeIcon = isOn ? .livePhoto : .livePhotoOff
    }

    return MediaPickerGridCellDecorations(
        check: isSelectable ? selection : nil,
        durationText: durationText,
        typeIcon: typeIcon,
        showsLeftShadow: typeIcon != nil,
        showsRightShadow: durationText != nil,
        showsSpoilerBlur: hasSpoilerContent,
        showsSpoilerOverlay: hasSpoilerContent,
        showsPrice: selectedPrice != nil,
        price: isSingle ? selectedPrice : nil
    )
}

struct MediaPickerGridAssetsConfiguration: Equatable {
    var key: String
    var isReversed: Bool
    var isLibrary: Bool
    var scrollsToEnd: Bool
}

func mediaPickerGridAssetsConfiguration(subjectCollectionId: String?, selectedCollectionId: String?) -> MediaPickerGridAssetsConfiguration {
    let isReversed = subjectCollectionId == nil
    return MediaPickerGridAssetsConfiguration(
        key: selectedCollectionId ?? subjectCollectionId ?? "",
        isReversed: isReversed,
        isLibrary: isReversed && selectedCollectionId == nil,
        scrollsToEnd: !isReversed
    )
}

func mediaPickerGridFetchIndex(gridIndex: Int, count: Int, isReversed: Bool) -> Int {
    return isReversed ? count - gridIndex - 1 : gridIndex
}

func mediaPickerUsesMediaGrid(isChatAttachmentDefaultAssets: Bool, isEnabled: Bool) -> Bool {
    return isChatAttachmentDefaultAssets && isEnabled
}

func mediaPickerIsChatAttachmentDefaultAssets(isAssets: Bool, isDefaultMode: Bool, forCollage: Bool) -> Bool {
    return isAssets && isDefaultMode && !forCollage
}

func mediaPickerGridNeedsInstall(current: MediaPickerGridAssetsConfiguration?, hasGrid: Bool, new: MediaPickerGridAssetsConfiguration) -> Bool {
    return !hasGrid || current != new
}

func mediaPickerGridInitialLevelColumns(carriedColumns: Int?, isLandscape: Bool) -> Int {
    if let carriedColumns {
        return carriedColumns
    }
    return isLandscape ? 5 : 3
}
