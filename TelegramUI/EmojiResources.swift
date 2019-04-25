import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import Display
import WebP

private var emojiMapping: [String: (UInt8, UInt8, UInt8)] = {
    let path = frameworkBundle.path(forResource: "Emoji", ofType: "mapping")!
    
    var mapping: [String: (UInt8, UInt8, UInt8)] = [:]
    if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
        let buffer = ReadBuffer(data: data)
        var count: Int32 = 0
        buffer.read(&count, offset: 0, length: 4)
        if count > 0 {
            for i in 0 ..< count {
                var length: UInt8 = 0
                buffer.read(&length, offset: 0, length: 1)
                let data = Data(bytes: buffer.memory.assumingMemoryBound(to: UInt8.self).advanced(by: buffer.offset), count: Int(length))
                buffer.skip(Int(length))
                var packId: UInt8 = 0
                buffer.read(&packId, offset: 0, length: 1)
                var stickerId: UInt8 = 0
                buffer.read(&stickerId, offset: 0, length: 1)
                var tileId: UInt8 = 0
                buffer.read(&tileId, offset: 0, length: 1)
                
                if let emoji = String(data: data, encoding: .utf8) {
                    mapping[emoji] = (packId, stickerId, tileId)
                }
            }
        }
    }
    return mapping
}()

private func matchingEmojiEntry(_ emoji: String) -> (UInt8, UInt8, UInt8)? {
    if let entry = emojiMapping[emoji] {
        return entry
    }
    if emoji.unicodeScalars.count > 1 {
        let trimmedEmoji = String(emoji.unicodeScalars.prefix(emoji.unicodeScalars.count - 1))
        if let entry = emojiMapping[trimmedEmoji] {
            return entry
        }
    }
    var special: String?
    if emoji == "\u{01f48f}" {
        special = "👩‍❤️‍💋‍👨"
    } else if emoji == "\u{01f491}" {
        special = "👩‍❤️‍👨"
    } else if emoji == "\u{01f46a}" {
        special = "👨‍👩‍👦"
    }
    if let special = special, let entry = emojiMapping[special] {
        return entry
    }
    return nil
}

func largeEmoji(postbox: Postbox, emoji: String, outline: Bool = true) -> Signal<(TransformImageArguments) -> DrawingContext?, NoError> {
    var dataSignals: [Signal<MediaResourceData, NoError>] = []
    for emoji in emoji.emojis {
        if let entry = matchingEmojiEntry(emoji) {
            let thumbnailResource = EmojiThumbnailResource(emoji: emoji)
            let thumbnailRepresentation = CachedEmojiThumbnailRepresentation(outline: outline)
            
            let spriteResource = EmojiSpriteResource(packId: entry.0, stickerId: entry.1)
            let representation = CachedEmojiRepresentation(tile: entry.2, outline: outline)
            
            let thumbnailSignal = postbox.mediaBox.cachedResourceRepresentation(thumbnailResource, representation: thumbnailRepresentation, complete: true, fetch: true)
            let signal: Signal<MediaResourceData?, NoError> = .single(nil) |> then(postbox.mediaBox.cachedResourceRepresentation(spriteResource, representation: representation, complete: true, fetch: true) |> map(Optional.init))
            
            let dataSignal = combineLatest(thumbnailSignal, signal)
            |> map { thumbnailData, data -> MediaResourceData in
                let resourceData: MediaResourceData?
                if let data = data {
                    resourceData = data
                } else {
                    resourceData = thumbnailData
                }
                return resourceData!
            }
            dataSignals.append(dataSignal)
        }
    }

    return combineLatest(queue: nil, dataSignals)
    |> map { datas in
        return { arguments in
            let context = DrawingContext(size: arguments.drawingSize, clear: true)
            
            var sourceImages: [UIImage] = []
            for resourceData in datas {
                if let data = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: []), let image = UIImage(data: data, scale: UIScreen.main.scale) {
                    sourceImages.append(image)
                }
            }
            
            context.withFlippedContext { c in
                var offset: CGFloat = 12.0
                for image in sourceImages {
                    c.draw(image.cgImage!, in: CGRect(origin: CGPoint(x: offset, y: floor((arguments.drawingSize.height -
                    image.size.height) / 2.0)), size: image.size))
                    offset += 52.0 + 7.0
                }
            }
            
            return context
        }
    }
}

private final class Buffer {
    var data = Data()
}

func fetchEmojiSpriteResource(postbox: Postbox, network: Network, resource: EmojiSpriteResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    let packName = "P\(resource.packId)_by_AEStickerBot"
    
    return loadedStickerPack(postbox: postbox, network: network, reference: .name(packName), forceActualized: false)
    |> introduceError(MediaResourceDataFetchError.self)
    |> mapToSignal { result -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> in
        switch result {
            case let .result(_, items, _):
                if let sticker = items[Int(resource.stickerId)] as? StickerPackItem {
                    return Signal { subscriber in
                        guard let fetchResource = postbox.mediaBox.fetchResource else {
                            return EmptyDisposable
                        }

                        subscriber.putNext(.reset)

                        let fetch = fetchResource(sticker.file.resource, .single([(0 ..< Int.max, .default)]), nil)
                        let buffer = Atomic<Buffer>(value: Buffer())
                        let disposable = fetch.start(next: { result in
                            switch result {
                            case .reset:
                                let _ = buffer.with { buffer in
                                    buffer.data.count = 0
                                }
                            case .resourceSizeUpdated:
                                break
                            case let .moveLocalFile(path):
                                if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                                    let _ = buffer.with { buffer in
                                        buffer.data = data
                                    }
                                    let _ = try? FileManager.default.removeItem(atPath: path)
                                }
                            case let .moveTempFile(file):
                                if let data = try? Data(contentsOf: URL(fileURLWithPath: file.path)) {
                                    let _ = buffer.with { buffer in
                                        buffer.data = data
                                    }
                                }
                                TempBox.shared.dispose(file)
                            case .copyLocalItem:
                                assertionFailure()
                                break
                            case let .replaceHeader(data, range):
                                let _ = buffer.with { buffer in
                                    if buffer.data.count < range.count {
                                        buffer.data.count = range.count
                                    }
                                    buffer.data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
                                        data.copyBytes(to: bytes, from: range)
                                    }
                                }
                            case let .dataPart(resourceOffset, data, range, _):
                                let _ = buffer.with { buffer in
                                    if buffer.data.count < resourceOffset + range.count {
                                        buffer.data.count = resourceOffset + range.count
                                    }
                                    buffer.data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
                                        data.copyBytes(to: bytes.advanced(by: resourceOffset), from: range)
                                    }
                                }
                            }
                        }, completed: {
                            let image = buffer.with { buffer -> UIImage? in
                                return WebP.convert(fromWebP: buffer.data)
                            }
                            if let image = image, let data = UIImagePNGRepresentation(image) {
                                subscriber.putNext(.dataPart(resourceOffset: 0, data: data, range: 0 ..< data.count, complete: true))
                                subscriber.putCompletion()
                            }
                        })

                        return ActionDisposable {
                            disposable.dispose()
                        }
                    }
                } else {
                    return .complete()
                }

            default:
                return .complete()
        }
    }
}
