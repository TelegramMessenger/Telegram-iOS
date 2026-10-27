import Foundation
import UIKit
import Photos
import SwiftSignalKit
import LegacyComponents

public func chatMediaFilePreviewInfoString(isVideo: Bool, fileName: String?, fileSize: Int, dimensions: CGSize, formattedFileSize: String) -> String {
    let baseFileName = (fileName ?? "").split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.flatMap(String.init) ?? ""
    let fileExtension = (baseFileName as NSString).pathExtension.uppercased()
    if isVideo {
        var components: [String] = []
        if let fileName, !fileName.isEmpty {
            components.append(fileExtension)
        }
        if fileSize > 0 {
            components.append(formattedFileSize)
        }
        components.append(chatMediaFilePreviewVideoDimensionsString(dimensions))
        return components.joined(separator: " • ")
    }
    let dimensionsString = "\(Int(dimensions.width))x\(Int(dimensions.height))"
    if fileSize > 0 {
        return "\(fileExtension) • \(formattedFileSize) • \(dimensionsString)"
    }
    return dimensionsString
}

private func chatMediaFilePreviewVideoDimensionsString(_ dimensions: CGSize) -> String {
    let shortSide = min(dimensions.width, dimensions.height)
    switch shortSide {
    case 1080.0:
        return "1080p"
    case 720.0:
        return "720p"
    case 480.0:
        return "480p"
    case 360.0:
        return "360p"
    case 240.0:
        return "240p"
    case 144.0:
        return "144p"
    default:
        return "\(Int(dimensions.width))x\(Int(dimensions.height))"
    }
}

extension ChatMediaEditorScreen.Node {
    var tabPolicy: ChatMediaEditorTabPolicy {
        return self.controller?.gallery?.tabPolicy ?? .standard
    }

    var isFilePreview: Bool {
        return self.tabPolicy == .filePreview
    }

    var filePreviewInfoString: String? {
        guard self.isFilePreview, let info = self.filePreviewInfo, info.uniqueId == self.pageModel.currentItem.uniqueId else {
            return nil
        }
        return info.text
    }

    func updateFilePreviewInfo() {
        self.filePreviewInfoDisposable?.dispose()
        self.filePreviewInfoDisposable = nil
        let item = self.pageModel.currentItem
        guard self.isFilePreview, !self.isInvalidated, case let .asset(asset) = item.source, let legacyAsset = TGMediaAsset(phAsset: asset) else {
            return
        }
        let uniqueId = item.uniqueId
        let isVideo = asset.mediaType == .video
        self.filePreviewInfoDisposable = TGMediaAssetImageSignals.fileAttributes(for: legacyAsset)?.start(next: { [weak self] next in
            guard let attributes = next as? TGMediaAssetImageFileAttributes else {
                return
            }
            let fileSize = Int(attributes.fileSize)
            let text = chatMediaFilePreviewInfoString(isVideo: isVideo, fileName: attributes.fileName, fileSize: fileSize, dimensions: attributes.dimensions, formattedFileSize: TGStringUtils.string(forFileSize: Int64(fileSize), precision: 2) ?? "")
            Queue.mainQueue().async {
                guard let self, !self.isInvalidated, self.pageModel.currentItem.uniqueId == uniqueId else {
                    return
                }
                self.filePreviewInfo = (uniqueId, text)
                self.requestLayout(transition: .immediate)
            }
        }, error: { _ in
        }, completed: {
        })
    }
}
