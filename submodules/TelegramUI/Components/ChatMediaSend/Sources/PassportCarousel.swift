import Foundation
import UIKit
import AVFoundation
import SwiftSignalKit
import AccountContext

public struct PassportCarouselPolicy: Equatable {
    public let hasCameraCell: Bool
    public let photoOnly: Bool
    public let allowsSelection: Bool
    public let selectionLimit: Int
    public let onlyCrop: Bool
    public let doneTitleKey: String
    public let hasICloudRow: Bool

    public init(hasCameraCell: Bool, photoOnly: Bool, allowsSelection: Bool, selectionLimit: Int, onlyCrop: Bool, doneTitleKey: String, hasICloudRow: Bool) {
        self.hasCameraCell = hasCameraCell
        self.photoOnly = photoOnly
        self.allowsSelection = allowsSelection
        self.selectionLimit = selectionLimit
        self.onlyCrop = onlyCrop
        self.doneTitleKey = doneTitleKey
        self.hasICloudRow = hasICloudRow
    }
}

public func passportCarouselPolicy(intent: PassportCaptureIntent) -> PassportCarouselPolicy {
    return PassportCarouselPolicy(
        hasCameraCell: true,
        photoOnly: true,
        allowsSelection: intent == .multiple,
        selectionLimit: passportSelectionLimit,
        onlyCrop: true,
        doneTitleKey: "Common.Done",
        hasICloudRow: intent != .selfie
    )
}

public let passportCarouselDisplayedAssetLimit = 500

public func passportCarouselAssetIndices(fetchCount: Int) -> [Int] {
    guard fetchCount > 0 else {
        return []
    }
    return (0 ..< min(fetchCount, passportCarouselDisplayedAssetLimit)).map { fetchCount - 1 - $0 }
}

public let passportCarouselCellSize = CGSize(width: 84.0, height: 84.0)
public let passportCarouselEdgeInset: CGFloat = 8.0
public let passportCarouselZoomedHeight: CGFloat = 198.0
public let passportCarouselZoomedMaxWidth: CGFloat = 250.0
public let passportCarouselCameraFrame = CGRect(origin: CGPoint(x: passportCarouselEdgeInset, y: passportCarouselEdgeInset), size: passportCarouselCellSize)

public func passportCarouselHeight(zoomed: Bool) -> CGFloat {
    return (zoomed ? passportCarouselZoomedHeight : passportCarouselCellSize.height) + passportCarouselEdgeInset * 2.0
}

public func passportCarouselLeadingInset(zoomed: Bool, hasCamera: Bool) -> CGFloat {
    if hasCamera && !zoomed {
        return passportCarouselEdgeInset * 2.0 + passportCarouselCellSize.width
    }
    return passportCarouselEdgeInset
}

public func passportCarouselItemSize(zoomed: Bool, assetPixelSize: CGSize) -> CGSize {
    guard zoomed else {
        return passportCarouselCellSize
    }
    let width = max(1.0, assetPixelSize.width)
    let height = max(1.0, assetPixelSize.height)
    return CGSize(width: min(passportCarouselZoomedMaxWidth, ceil(width * passportCarouselZoomedHeight / height)), height: passportCarouselZoomedHeight)
}

public enum PassportCarouselCameraState: Equatable {
    case live
    case requestAccess
    case placeholder
}

public func passportCarouselCameraState(authorization: AVAuthorizationStatus) -> PassportCarouselCameraState {
    switch authorization {
    case .authorized:
        return .live
    case .notDetermined:
        return .requestAccess
    default:
        return .placeholder
    }
}
