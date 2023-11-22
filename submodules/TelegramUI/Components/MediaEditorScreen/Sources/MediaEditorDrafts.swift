import Foundation
import UIKit
import Display
import CoreLocation
import Photos
import TelegramCore
import AccountContext
import MediaEditor
import DrawingUI

extension MediaEditorScreen {
    func isEligibleForDraft() -> Bool {
        if self.isEditingStory {
            return false
        }
        guard let mediaEditor = self.node.mediaEditor else {
            return false
        }
        let entities = self.node.entitiesView.entities.filter { !($0 is DrawingMediaEntity) }
        let codableEntities = DrawingEntitiesView.encodeEntities(entities, entitiesView: self.node.entitiesView)
        mediaEditor.setDrawingAndEntities(data: nil, image: mediaEditor.values.drawing, entities: codableEntities)
        
        let caption = self.getCaption()
        
        if let subject = self.node.subject, case .asset = subject, self.node.mediaEditor?.values.hasChanges == false && caption.string.isEmpty {
            return false
        }
        return true
    }
    
    func saveDraft(id: Int64?) {
        guard let subject = self.node.subject, let mediaEditor = self.node.mediaEditor else {
            return
        }
        try? FileManager.default.createDirectory(atPath: draftPath(engine: self.context.engine), withIntermediateDirectories: true)
        
        let values = mediaEditor.values
        let privacy = self.state.privacy
        let caption = self.getCaption()
        let duration = mediaEditor.duration ?? 0.0
        
        let currentTimestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
        var timestamp: Int32
        var location: CLLocationCoordinate2D?
        let expiresOn: Int32
        if case let .draft(draft, _) = subject {
            timestamp = draft.timestamp
            location = draft.location
            if let _ = id {
                expiresOn = draft.expiresOn ?? currentTimestamp + 3600 * 24 * 7
            } else {
                expiresOn = currentTimestamp + 3600 * 24 * 7
            }
        } else {
            timestamp = currentTimestamp
            if case let .asset(asset) = subject {
                location = asset.location?.coordinate
            }
            if let _ = id {
                expiresOn = currentTimestamp + Int32(self.state.privacy.timeout)
            } else {
                expiresOn = currentTimestamp + 3600 * 24 * 7
            }
        }
        
        if let resultImage = mediaEditor.resultImage {
            mediaEditor.seek(0.0, andPlay: false)
            makeEditorImageComposition(context: self.node.ciContext, postbox: self.context.account.postbox, inputImage: resultImage, dimensions: storyDimensions, values: values, time: .zero, textScale: 2.0, completion: { resultImage in
                guard let resultImage else {
                    return
                }
                let fittedSize = resultImage.size.aspectFitted(CGSize(width: 128.0, height: 128.0))
                
                let context = self.context
                let saveImageDraft: (UIImage, PixelDimensions) -> Void = { image, dimensions in
                    if let thumbnailImage = generateScaledImage(image: resultImage, size: fittedSize) {
                        let path = "\(Int64.random(in: .min ... .max)).jpg"
                        if let data = image.jpegData(compressionQuality: 0.87) {
                            let draft = MediaEditorDraft(path: path, isVideo: false, thumbnail: thumbnailImage, dimensions: dimensions, duration: nil, values: values, caption: caption, privacy: privacy, timestamp: timestamp, location: location, expiresOn: expiresOn)
                            try? data.write(to: URL(fileURLWithPath: draft.fullPath(engine: context.engine)))
                            if let id {
                                saveStorySource(engine: context.engine, item: draft, peerId: context.account.peerId, id: id)
                            } else {
                                addStoryDraft(engine: context.engine, item: draft)
                            }
                        }
                    }
                }
                
                let saveVideoDraft: (String, PixelDimensions, Double) -> Void = { videoPath, dimensions, duration in
                    if let thumbnailImage = generateScaledImage(image: resultImage, size: fittedSize) {
                        let path = "\(Int64.random(in: .min ... .max)).mp4"
                        let draft = MediaEditorDraft(path: path, isVideo: true, thumbnail: thumbnailImage, dimensions: dimensions, duration: duration, values: values, caption: caption, privacy: privacy, timestamp: timestamp, location: location, expiresOn: expiresOn)
                        try? FileManager.default.copyItem(atPath: videoPath, toPath: draft.fullPath(engine: context.engine))
                        if let id {
                            saveStorySource(engine: context.engine, item: draft, peerId: context.account.peerId, id: id)
                        } else {
                            addStoryDraft(engine: context.engine, item: draft)
                        }
                    }
                }
                
                switch subject {
                case let .image(image, dimensions, _, _):
                    saveImageDraft(image, dimensions)
                case let .video(path, _, _, _, _, dimensions, _, _, _):
                    saveVideoDraft(path, dimensions, duration)
                case let .asset(asset):
                    if asset.mediaType == .video {
                        PHImageManager.default().requestAVAsset(forVideo: asset, options: nil) { avAsset, _, _ in
                            if let urlAsset = avAsset as? AVURLAsset {
                                saveVideoDraft(urlAsset.url.relativePath, PixelDimensions(width: Int32(asset.pixelWidth), height: Int32(asset.pixelHeight)), duration)
                            }
                        }
                    } else {
                        let options = PHImageRequestOptions()
                        options.deliveryMode = .highQualityFormat
                        PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options) { image, _ in
                            if let image {
                                saveImageDraft(image, PixelDimensions(image.size))
                            }
                        }
                    }
                case let .draft(draft, _):
                    if draft.isVideo {
                        saveVideoDraft(draft.fullPath(engine: context.engine), draft.dimensions, draft.duration ?? 0.0)
                    } else if let image = UIImage(contentsOfFile: draft.fullPath(engine: context.engine)) {
                        saveImageDraft(image, draft.dimensions)
                    }
                    removeStoryDraft(engine: self.context.engine, path: draft.path, delete: false)
                }
            })
        }
    }
}
