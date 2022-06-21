import Foundation
import Postbox
import TelegramApi


func dimensionsForFileAttributes(_ attributes: [TelegramMediaFileAttribute]) -> PixelDimensions? {
    for attribute in attributes {
        switch attribute {
            case let .Video(_, size, _):
                return size
            case let .ImageSize(size):
                return size
            default:
                break
        }
    }
    return nil
}

func durationForFileAttributes(_ attributes: [TelegramMediaFileAttribute]) -> Int32? {
    for attribute in attributes {
        switch attribute {
            case let .Video(duration, _, _):
                return Int32(duration)
            case let .Audio(_, duration, _, _, _):
                return Int32(duration)
            default:
                break
        }
    }
    return nil
}

public extension TelegramMediaFile {
    var dimensions: PixelDimensions? {
        if let value = dimensionsForFileAttributes(self.attributes) {
            return value
        } else if self.isAnimatedSticker {
            return PixelDimensions(width: 512, height: 512)
        } else {
            return nil
        }
    }
    
    var duration: Int32? {
        return durationForFileAttributes(self.attributes)
    }
}

extension StickerPackReference {
    init?(apiInputSet: Api.InputStickerSet) {
        switch apiInputSet {
            case .inputStickerSetEmpty:
                return nil
            case let .inputStickerSetID(id, accessHash):
                self = .id(id: id, accessHash: accessHash)
            case let .inputStickerSetShortName(shortName):
                self = .name(shortName)
            case .inputStickerSetAnimatedEmoji:
                self = .animatedEmoji
            case let .inputStickerSetDice(emoticon):
                self = .dice(emoticon)
            case .inputStickerSetAnimatedEmojiAnimations:
                self = .animatedEmojiAnimations
        }
    }
}

extension StickerMaskCoords {
    init(apiMaskCoords: Api.MaskCoords) {
        switch apiMaskCoords {
            case let .maskCoords(n, x, y, zoom):
                self.init(n: n, x: x, y: y, zoom: zoom)
        }
    }
}

func telegramMediaFileAttributesFromApiAttributes(_ attributes: [Api.DocumentAttribute]) -> [TelegramMediaFileAttribute] {
    var result: [TelegramMediaFileAttribute] = []
    for attribute in attributes {
        switch attribute {
            case let .documentAttributeFilename(fileName):
                result.append(.FileName(fileName: fileName))
            case let .documentAttributeSticker(_, alt, stickerSet, maskCoords):
                result.append(.Sticker(displayText: alt, packReference: StickerPackReference(apiInputSet: stickerSet), maskData: maskCoords.flatMap(StickerMaskCoords.init)))
            case .documentAttributeHasStickers:
                result.append(.HasLinkedStickers)
            case let .documentAttributeImageSize(w, h):
                result.append(.ImageSize(size: PixelDimensions(width: w, height: h)))
            case .documentAttributeAnimated:
                result.append(.Animated)
            case let .documentAttributeVideo(flags, duration, w, h):
                var videoFlags = TelegramMediaVideoFlags()
                if (flags & (1 << 0)) != 0 {
                    videoFlags.insert(.instantRoundVideo)
                }
                if (flags & (1 << 1)) != 0 {
                    videoFlags.insert(.supportsStreaming)
                }
                result.append(.Video(duration: Int(duration), size: PixelDimensions(width: w, height: h), flags: videoFlags))
            case let .documentAttributeAudio(flags, duration, title, performer, waveform):
                let isVoice = (flags & (1 << 10)) != 0
                let waveformBuffer: Data? = waveform?.makeData()
                result.append(.Audio(isVoice: isVoice, duration: Int(duration), title: title, performer: performer, waveform: waveformBuffer))
        }
    }
    return result
}

public func fileNameFromFileAttributes(_ attributes: [TelegramMediaFileAttribute]) -> String? {
    for attribute in attributes {
        if case let .FileName(value) = attribute {
            return value
        }
    }
    return nil
}

func telegramMediaFileThumbnailRepresentationsFromApiSizes(datacenterId: Int32, documentId: Int64, accessHash: Int64, fileReference: Data?, sizes: [Api.PhotoSize]) -> (immediateThumbnail: Data?, representations:  [TelegramMediaImageRepresentation]) {
    var immediateThumbnailData: Data?
    var representations: [TelegramMediaImageRepresentation] = []
    for size in sizes {
        switch size {
            case let .photoCachedSize(type, w, h, _):
                let resource = CloudDocumentSizeMediaResource(datacenterId: datacenterId, documentId: documentId, accessHash: accessHash, sizeSpec: type, fileReference: fileReference)
                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: resource, progressiveSizes: [], immediateThumbnailData: nil))
            case let .photoSize(type, w, h, _):
                let resource = CloudDocumentSizeMediaResource(datacenterId: datacenterId, documentId: documentId, accessHash: accessHash, sizeSpec: type, fileReference: fileReference)
                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: resource, progressiveSizes: [], immediateThumbnailData: nil))
            case let .photoSizeProgressive(type, w, h, sizes):
                let resource = CloudDocumentSizeMediaResource(datacenterId: datacenterId, documentId: documentId, accessHash: accessHash, sizeSpec: type, fileReference: fileReference)
                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: w, height: h), resource: resource, progressiveSizes: sizes, immediateThumbnailData: nil))
            case let .photoPathSize(_, data):
                immediateThumbnailData = data.makeData()
            case let .photoStrippedSize(_, data):
                immediateThumbnailData = data.makeData()
            case .photoSizeEmpty:
                break
        }
    }
    return (immediateThumbnailData, representations)
}

func telegramMediaFileFromApiDocument(_ document: Api.Document) -> TelegramMediaFile? {
    switch document {
        case let .document(_, id, accessHash, fileReference, _, mimeType, size, thumbs, videoThumbs, dcId, attributes):
            var parsedAttributes = telegramMediaFileAttributesFromApiAttributes(attributes)
            parsedAttributes.append(.hintIsValidated)
            
            let (immediateThumbnail, previewRepresentations) = telegramMediaFileThumbnailRepresentationsFromApiSizes(datacenterId: dcId, documentId: id, accessHash: accessHash, fileReference: fileReference.makeData(), sizes: thumbs ?? [])
            
            var videoThumbnails: [TelegramMediaFile.VideoThumbnail] = []
            if let videoThumbs = videoThumbs {
                for thumb in videoThumbs {
                    switch thumb {
                    case let .videoSize(_, type, w, h, _, _):
                        let resource: TelegramMediaResource
                        resource = CloudDocumentSizeMediaResource(datacenterId: dcId, documentId: id, accessHash: accessHash, sizeSpec: type, fileReference: fileReference.makeData())
                        
                        videoThumbnails.append(TelegramMediaFile.VideoThumbnail(
                            dimensions: PixelDimensions(width: w, height: h),
                            resource: resource))
                    }
                }
            }
            
            return TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: id), partialReference: nil, resource: CloudDocumentMediaResource(datacenterId: Int(dcId), fileId: id, accessHash: accessHash, size: Int(size), fileReference: fileReference.makeData(), fileName: fileNameFromFileAttributes(parsedAttributes)), previewRepresentations: previewRepresentations, videoThumbnails: videoThumbnails, immediateThumbnailData: immediateThumbnail, mimeType: mimeType, size: Int(size), attributes: parsedAttributes)
        case .documentEmpty:
            return nil
    }
}
