import Foundation
import UIKit
import Display
import CoreLocation
import Photos
import Postbox
import TelegramCore
import AccountContext
import MediaEditor
import DrawingUI

extension MediaEditorScreenImpl {
    func isEligibleForDraft() -> Bool {
        guard !self.isEditingStory else {
            return false
        }
        if case .avatarEditor = self.mode {
            return false
        }
        if case .coverEditor = self.mode {
            return false
        }
        if case .multiple = self.node.actualSubject {
            return false
        }
        guard let mediaEditor = self.node.mediaEditor else {
            return false
        }
        let entities = self.node.entitiesView.entities.filter { !($0 is DrawingMediaEntity) }
        let codableEntities = DrawingEntitiesView.encodeEntities(entities, entitiesView: self.node.entitiesView)
        mediaEditor.setDrawingAndEntities(data: nil, image: mediaEditor.values.drawing, entities: codableEntities)
        
        let filteredEntities = self.node.entitiesView.entities.filter { entity in
            if entity is DrawingMediaEntity {
                return false
            } else if let entity = entity as? DrawingStickerEntity {
                switch entity.content {
                case .message, .gift:
                    return false
                default:
                    break
                }
            }
            return true
        }
        
        let values = mediaEditor.values
        let filteredValues = values.withUpdatedEntities([])
        let caption = self.node.getCaption()
        
        if let subject = self.node.subject {
            switch subject {
            case .asset:
                if !values.hasChanges && caption.string.isEmpty {
                    return false
                }
            case .message, .gift:
                if !filteredValues.hasChanges && filteredEntities.isEmpty && caption.string.isEmpty {
                    return false
                }
            case .empty:
                if !self.node.hasAnyChanges && !self.node.drawingView.internalState.canUndo {
                    return false
                }
            case .videoCollage:
                return false
            default:
                break
            }
        }
        return true
    }
    
    func saveDraft(id: Int64?, isEdit: Bool = false, completion: ((MediaEditorDraft) -> Void)? = nil) {
        guard case .storyEditor = self.mode, let subject = self.node.subject, let actualSubject = self.node.actualSubject, let mediaEditor = self.node.mediaEditor else {
            return
        }
        
        try? FileManager.default.createDirectory(atPath: draftPath(engine: self.context.engine), withIntermediateDirectories: true)
        
        let values = mediaEditor.values
        let privacy = self.state.privacy
        let forwardSource = self.forwardSource
        let caption = self.node.getCaption()
        let duration = mediaEditor.duration ?? 0.0
        
        let currentTimestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
        var timestamp: Int32
        var location: CLLocationCoordinate2D?
        let expiresOn: Int32
        if case let .draft(draft, _) = actualSubject {
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
            if !isEdit {
                mediaEditor.seek(0.0, andPlay: false)
            }
            
            makeEditorImageComposition(
                context: self.node.ciContext,
                postbox: self.context.account.postbox,
                inputImage: resultImage,
                dimensions: storyDimensions,
                values: values,
                time: .zero,
                textScale: 2.0,
                completion: { resultImage in
                guard let resultImage else {
                    return
                }
                enum MediaInput {
                    case image(image: UIImage, dimensions: PixelDimensions)
                    case video(path: String, dimensions: PixelDimensions, duration: Double)
                    
                    var isVideo: Bool {
                        switch self {
                        case .video:
                            return true
                        case .image:
                            return false
                        }
                    }
                    
                    var dimensions: PixelDimensions {
                        switch self {
                        case let .image(_, dimensions):
                            return dimensions
                        case let .video(_, dimensions, _):
                            return dimensions
                        }
                    }
                    
                    var duration: Double? {
                        switch self {
                        case .image:
                            return nil
                        case let .video(_, _, duration):
                            return duration
                        }
                    }
                    
                    var fileExtension: String {
                        switch self {
                        case .image:
                            return "jpg"
                        case .video:
                            return "mp4"
                        }
                    }
                }
                
                let context = self.context
                func innerSaveDraft(media: MediaInput, save: Bool = true) -> MediaEditorDraft? {
                    let fittedSize = resultImage.size.aspectFitted(CGSize(width: 128.0, height: 128.0))
                    guard let thumbnailImage = generateScaledImage(image: resultImage, size: fittedSize) else {
                        return nil
                    }
                    let path = "\(Int64.random(in: .min ... .max)).\(media.fileExtension)"
                    let draft = MediaEditorDraft(
                        path: path,
                        isVideo: media.isVideo,
                        thumbnail: thumbnailImage,
                        dimensions: media.dimensions,
                        duration: media.duration,
                        values: values,
                        caption: caption,
                        privacy: privacy,
                        forwardInfo: forwardSource.flatMap { StoryId(peerId: $0.0.id, id: $0.1.id) },
                        timestamp: timestamp,
                        location: location,
                        expiresOn: expiresOn
                    )
                    switch media {
                    case let .image(image, _):
                        if let data = image.jpegData(compressionQuality: 0.87) {
                            try? data.write(to: URL(fileURLWithPath: draft.fullPath(engine: context.engine)))
                        }
                    case let .video(path, _, _):
                        try? FileManager.default.copyItem(atPath: path, toPath: draft.fullPath(engine: context.engine))
                    }
                    if save {
                        if let id {
                            saveStorySource(engine: context.engine, item: draft, peerId: context.account.peerId, id: id)
                        } else {
                            addStoryDraft(engine: context.engine, item: draft)
                        }
                    }
                    return draft
                }
                
                switch subject {
                case .empty:
                    break
                case let .image(image, dimensions, _, _, _):
                    if let draft = innerSaveDraft(media: .image(image: image, dimensions: dimensions)) {
                        completion?(draft)
                    }
                case let .video(path, _, _, _, _, dimensions, _, _, _, _):
                    if let draft = innerSaveDraft(media: .video(path: path, dimensions: dimensions, duration: duration)) {
                        completion?(draft)
                    }
                case let .videoCollage(items):
                    let _ = items
                case let .asset(asset):
                    if asset.mediaType == .video {
                        PHImageManager.default().requestAVAsset(forVideo: asset, options: nil) { avAsset, _, _ in
                            if let urlAsset = avAsset as? AVURLAsset {
                                if let draft = innerSaveDraft(media: .video(path: urlAsset.url.relativePath, dimensions: PixelDimensions(width: Int32(asset.pixelWidth), height: Int32(asset.pixelHeight)), duration: duration)) {
                                    completion?(draft)
                                }
                            }
                        }
                    } else {
                        let options = PHImageRequestOptions()
                        options.deliveryMode = .highQualityFormat
                        PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options) { image, _ in
                            if let image {
                                if let draft = innerSaveDraft(media: .image(image: image, dimensions: PixelDimensions(image.size))) {
                                    completion?(draft)
                                }
                            }
                        }
                    }
                case let .draft(draft, _):
                    if draft.isVideo {
                        if let draft = innerSaveDraft(media: .video(path: draft.fullPath(engine: context.engine), dimensions: draft.dimensions, duration: draft.duration ?? 0.0)) {
                            completion?(draft)
                        }
                    } else if let image = UIImage(contentsOfFile: draft.fullPath(engine: context.engine)) {
                        if let draft = innerSaveDraft(media: .image(image: image, dimensions: draft.dimensions)) {
                            completion?(draft)
                        }
                    }
                case .message, .gift:
                    if let pixel = generateSingleColorImage(size: CGSize(width: 1, height: 1), color: .black) {
                        if let draft = innerSaveDraft(media: .image(image: pixel, dimensions: PixelDimensions(width: 1080, height: 1920))) {
                            completion?(draft)
                        }
                    }
                case .sticker:
                    break
                case .multiple:
                    break
                }
                
                if case let .draft(draft, _) = actualSubject {
                    removeStoryDraft(engine: self.context.engine, path: draft.path, delete: false)
                }
            })
        }
    }
}
