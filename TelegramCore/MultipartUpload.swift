import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif
import TelegramCorePrivateModule

#if os(macOS)
    private typealias SignalKitTimer = SwiftSignalKitMac.Timer
#else
    private typealias SignalKitTimer = SwiftSignalKit.Timer
#endif

private struct UploadPart {
    let fileId: Int64
    let index: Int
    let data: Data
}

private func md5(_ data : Data) -> Data {
    var res = Data()
    res.count = Int(CC_MD5_DIGEST_LENGTH)
    res.withUnsafeMutableBytes { mutableBytes -> Void in
        data.withUnsafeBytes { bytes -> Void in
            CC_MD5(bytes, CC_LONG(data.count), mutableBytes)
        }
    }
    return res
}

private final class MultipartUploadManager {
    let parallelParts: Int = 3
    let defaultPartSize = 32 * 1024
    
    let queue = Queue()
    let fileId: Int64
    
    let dataSignal: Signal<MediaResourceData, NoError>
    
    var committedOffset: Int
    let uploadPart: (UploadPart) -> Signal<Void, NoError>
    let progress: (Float) -> Void
    let completed: (Api.InputFile) -> Void
    
    var uploadingParts: [Int: (Int, Disposable)] = [:]
    var uploadedParts: [Int: Int] = [:]
    
    let dataDisposable = MetaDisposable()
    var resourceData: MediaResourceData?
    
    init(data: Signal<MediaResourceData, NoError>, uploadPart: @escaping (UploadPart) -> Signal<Void, NoError>, progress: @escaping (Float) -> Void, completed: @escaping (Api.InputFile) -> Void) {
        self.dataSignal = data
        
        var fileId: Int64 = 0
        arc4random_buf(&fileId, 8)
        self.fileId = fileId
        
        self.committedOffset = 0
        self.uploadPart = uploadPart
        self.progress = progress
        self.completed = completed
    }
    
    func start() {
        self.queue.async {
            self.dataDisposable.set((self.dataSignal |> deliverOn(self.queue)).start(next: { [weak self] data in
                if let strongSelf = self {
                    strongSelf.resourceData = data
                    strongSelf.checkState()
                }
            }))
        }
    }
    
    func cancel() {
        self.queue.async {
            for (_, (_, disposable)) in self.uploadingParts {
                disposable.dispose()
            }
        }
    }
    
    func checkState() {
        var updatedCommittedOffset = false
        for offset in self.uploadedParts.keys.sorted() {
            if offset == self.committedOffset {
                let partSize = self.uploadedParts[offset]!
                self.committedOffset += partSize
                updatedCommittedOffset = true
                let _ = self.uploadedParts.removeValue(forKey: offset)
            }
        }
        if updatedCommittedOffset {
            if let resourceData = self.resourceData, resourceData.complete && resourceData.size != 0 {
                self.progress(Float(self.committedOffset) / Float(resourceData.size))
            }
        }
        
        if let resourceData = self.resourceData, resourceData.complete, self.committedOffset >= resourceData.size {
            let fileData = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.alwaysMapped])
            let hashData = md5(fileData!)
            let hashString = hashData.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> String in
                let hexString = NSMutableString()
                for i in 0 ..< hashData.count {
                    let byteValue = UInt(bytes.advanced(by: i).pointee)
                    hexString.appendFormat("%02x", byteValue)
                }
                return hexString as String
            }
            let inputFile = Api.InputFile.inputFile(id: self.fileId, parts: Int32(resourceData.size / self.defaultPartSize + (resourceData.size % self.defaultPartSize == 0 ? 0 : 1)), name: "file.jpg", md5Checksum: hashString)
            self.completed(inputFile)
        } else {
            while uploadingParts.count < self.parallelParts {
                var nextOffset = self.committedOffset
                for (offset, (size, _)) in self.uploadingParts {
                    nextOffset = max(nextOffset, offset + size)
                }
                for (offset, partSize) in self.uploadedParts {
                    nextOffset = max(nextOffset, offset + partSize)
                }
                
                if let resourceData = self.resourceData, nextOffset < resourceData.size, (resourceData.complete || nextOffset % 1024 == 0) {
                    let partOffset = nextOffset
                    let partSize = min(resourceData.size - partOffset, self.defaultPartSize)
                    let partIndex = partOffset / self.defaultPartSize
                    let fileData = try? Data(contentsOf: URL(fileURLWithPath: resourceData.path), options: [.alwaysMapped])
                    let partData = fileData?.subdata(in: partOffset ..< (partOffset + partSize))
                    let part = self.uploadPart(UploadPart(fileId: self.fileId, index: partIndex, data: partData!))
                        |> deliverOn(self.queue)
                    self.uploadingParts[nextOffset] = (partSize, part.start(completed: { [weak self] in
                        if let strongSelf = self {
                            let _ = strongSelf.uploadingParts.removeValue(forKey: nextOffset)
                            strongSelf.uploadedParts[partOffset] = partSize
                            strongSelf.checkState()
                        }
                    }))
                } else {
                    break
                }
            }
        }
    }
}

enum MultipartUploadResult {
    case progress(Float)
    case inputFile(Api.InputFile)
}

func multipartUpload(network: Network, postbox: Postbox, resource: MediaResource) -> Signal<MultipartUploadResult, NoError> {
    return network.download(datacenterId: network.datacenterId)
        |> mapToSignal { download -> Signal<MultipartUploadResult, NoError> in
            return Signal { subscriber in
                let resourceData = postbox.mediaBox.resourceData(resource, complete: true)
                
                let manager = MultipartUploadManager(data: resourceData, uploadPart: { part in
                    return download.uploadPart(fileId: part.fileId, index: part.index, data: part.data)
                }, progress: { progress in
                    subscriber.putNext(.progress(progress))
                }, completed: { inputFile in
                    subscriber.putNext(.inputFile(inputFile))
                    subscriber.putCompletion()
                })

                manager.start()
                
                let fetchedResource = postbox.mediaBox.fetchedResource(resource).start()
                
                return ActionDisposable {
                    manager.cancel()
                    fetchedResource.dispose()
                }
            }
    }
}
