import Foundation
import UIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import Display

public struct SecureIdLocalImageResourceId {
    public let id: Int64
    
    public var uniqueId: String {
        return "secure-id-local-\(self.id)"
    }
    
    public var hashValue: Int {
        return self.id.hashValue
    }
}

public class SecureIdLocalImageResource: TelegramMediaResource {
    public let localId: Int64
    public let source: TelegramMediaResource
    
    public var size: Int64? {
        return nil
    }
    
    public init(localId: Int64, source: TelegramMediaResource) {
        self.localId = localId
        self.source = source
    }
    
    public required init(decoder: PostboxDecoder) {
        self.localId = decoder.decodeInt64ForKey("i", orElse: 0)
        self.source = decoder.decodeObjectForKey("s") as! TelegramMediaResource
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.localId, forKey: "i")
        encoder.encodeObject(self.source, forKey: "s")
    }
    
    public var id: MediaResourceId {
        return MediaResourceId(SecureIdLocalImageResourceId(id: self.localId).uniqueId)
    }
    
    public func isEqual(to: MediaResource) -> Bool {
        if let to = to as? SecureIdLocalImageResource {
            return self.localId == to.localId && self.source.isEqual(to:to.source)
        } else {
            return false
        }
    }
}

private final class Buffer {
    var data = Data()
}

public func fetchSecureIdLocalImageResource(postbox: Postbox, resource: SecureIdLocalImageResource) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        guard let fetchResource = postbox.mediaBox.fetchResource else {
            return EmptyDisposable
        }
        
        subscriber.putNext(.reset)
        
        let fetch = fetchResource(resource.source, .single([(0 ..< Int64.max, .default)]), nil)
        let buffer = Atomic<Buffer>(value: Buffer())
        let disposable = fetch.start(next: { result in
            switch result {
                case .reset:
                    let _ = buffer.with { buffer in
                        buffer.data.count = 0
                    }
                case .resourceSizeUpdated:
                    break
                case .progressUpdated:
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
                case let .copyLocalItem(item):
                    let tempFile = TempBox.shared.tempFile(fileName: "file")
                    if item.copyTo(url: URL(fileURLWithPath: tempFile.path)) {
                        if let data = try? Data(contentsOf: URL(fileURLWithPath: tempFile.path)) {
                            let _ = buffer.with { buffer in
                                buffer.data = data
                            }
                        }
                    }
                    TempBox.shared.dispose(tempFile)
                case let .replaceHeader(data, range):
                    let _ = buffer.with { buffer in
                        if buffer.data.count < range.count {
                            buffer.data.count = range.count
                        }
                        buffer.data.withUnsafeMutableBytes { buffer -> Void in
                            guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                                return
                            }
                            data.copyBytes(to: bytes, from: Int(range.lowerBound) ..< Int(range.upperBound))
                        }
                    }
                case let .dataPart(resourceOffset, data, range, _):
                    let _ = buffer.with { buffer in
                        if buffer.data.count < Int(resourceOffset) + range.count {
                            buffer.data.count = Int(resourceOffset) + range.count
                        }
                        buffer.data.withUnsafeMutableBytes { buffer -> Void in
                            guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                                return
                            }
                            data.copyBytes(to: bytes.advanced(by: Int(resourceOffset)), from: Int(range.lowerBound) ..< Int(range.upperBound))
                        }
                    }
            }
        }, completed: {
            let image = buffer.with { buffer -> UIImage? in
                return UIImage(data: buffer.data)
            }
            if let image = image {
                if let scaledImage = generateImage(image.size.fitted(CGSize(width: 2048.0, height: 2048.0)), contextGenerator: { size, context in
                    context.setBlendMode(.copy)
                    context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
                }, scale: 1.0), let scaledData = scaledImage.jpegData(compressionQuality: 0.6) {
                    subscriber.putNext(.dataPart(resourceOffset: 0, data: scaledData, range: 0 ..< Int64(scaledData.count), complete: true))
                    subscriber.putCompletion()
                }
            }
        })
        
        return ActionDisposable {
            disposable.dispose()
        }
    }
}
