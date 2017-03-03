import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif
import TelegramCorePrivateModule

#if os(macOS)
    private typealias SignalKitTimer = SwiftSignalKitMac.Timer
#else
    private typealias SignalKitTimer = SwiftSignalKit.Timer
#endif

public final class SecretFileEncryptionKey: Coding, Equatable {
    public let aesKey: Data
    public let aesIv: Data
    
    public init(aesKey: Data, aesIv: Data) {
        self.aesKey = aesKey
        self.aesIv = aesIv
    }
    
    public init(decoder: Decoder) {
        self.aesKey = decoder.decodeBytesForKey("k")!.makeData()
        self.aesIv = decoder.decodeBytesForKey("i")!.makeData()
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeBytes(MemoryBuffer(data: self.aesKey), forKey: "k")
        encoder.encodeBytes(MemoryBuffer(data: self.aesIv), forKey: "i")
    }
    
    public static func ==(lhs: SecretFileEncryptionKey, rhs: SecretFileEncryptionKey) -> Bool {
        return lhs.aesKey == rhs.aesKey && lhs.aesIv == rhs.aesIv
    }
}

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

private final class MultipartUploadState {
    let aesKey: Data
    var aesIv: Data
    var md5Context = CC_MD5_CTX()
    var effectiveSize: Int = 0
    
    init(encryptionKey: SecretFileEncryptionKey?) {
        if let encryptionKey = encryptionKey {
            self.aesKey = encryptionKey.aesKey
            self.aesIv = encryptionKey.aesIv
        } else {
            self.aesKey = Data()
            self.aesIv = Data()
        }
        CC_MD5_Init(&self.md5Context)
    }
    
    func transform(data: Data) -> Data {
        if self.aesKey.count != 0 {
            var encryptedData = data
            var paddingSize = 0
            while (encryptedData.count + paddingSize) % 16 != 0 {
                paddingSize += 1
            }
            if paddingSize != 0 {
                encryptedData.count = encryptedData.count + paddingSize
            }
            encryptedData.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
                if paddingSize != 0 {
                    arc4random_buf(bytes.advanced(by: encryptedData.count - paddingSize), paddingSize)
                }
                self.aesIv.withUnsafeMutableBytes { (iv: UnsafeMutablePointer<UInt8>) -> Void in
                    MTAesEncryptBytesInplaceAndModifyIv(bytes, encryptedData.count, self.aesKey, iv)
                }
                CC_MD5_Update(&self.md5Context, bytes, UInt32(encryptedData.count))
            }
            effectiveSize += encryptedData.count
            return encryptedData
        } else {
            data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
                CC_MD5_Update(&self.md5Context, bytes, UInt32(data.count))
            }
            effectiveSize += data.count
            return data
        }
    }
    
    func finalize() -> (md5Digest: String, effectiveSize: Int) {
        var res = Data()
        res.count = Int(CC_MD5_DIGEST_LENGTH)
        res.withUnsafeMutableBytes { mutableBytes -> Void in
            CC_MD5_Final(mutableBytes, &self.md5Context)
        }
        let hashString = res.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> String in
            let hexString = NSMutableString()
            for i in 0 ..< res.count {
                let byteValue = UInt(bytes.advanced(by: i).pointee)
                hexString.appendFormat("%02x", byteValue)
            }
            return hexString as String
        }
        return (hashString, self.effectiveSize)
    }
}

private struct MultipartIntermediateResult {
    let id: Int64
    let partCount: Int32
    let md5Digest: String
    let size: Int32
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
    let completed: (MultipartIntermediateResult) -> Void
    
    var uploadingParts: [Int: (Int, Disposable)] = [:]
    var uploadedParts: [Int: Int] = [:]
    
    let dataDisposable = MetaDisposable()
    var resourceData: MediaResourceData?
    
    let state: MultipartUploadState
    
    init(data: Signal<MediaResourceData, NoError>, encryptionKey: SecretFileEncryptionKey?, uploadPart: @escaping (UploadPart) -> Signal<Void, NoError>, progress: @escaping (Float) -> Void, completed: @escaping (MultipartIntermediateResult) -> Void) {
        self.dataSignal = data
        
        var fileId: Int64 = 0
        arc4random_buf(&fileId, 8)
        self.fileId = fileId
        
        self.state = MultipartUploadState(encryptionKey: encryptionKey)
        
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
            let (md5Digest, effectiveSize) = self.state.finalize()
            self.completed(MultipartIntermediateResult(id: self.fileId, partCount: Int32(effectiveSize / self.defaultPartSize + (effectiveSize % self.defaultPartSize == 0 ? 0 : 1)), md5Digest: md5Digest, size: Int32(resourceData.size)))
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
                    let partData = self.state.transform(data: fileData!.subdata(in: partOffset ..< (partOffset + partSize)))
                    let part = self.uploadPart(UploadPart(fileId: self.fileId, index: partIndex, data: partData))
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
    case inputSecretFile(Api.InputEncryptedFile, Int32, SecretFileEncryptionKey)
}

func multipartUpload(network: Network, postbox: Postbox, resource: MediaResource, encrypt: Bool) -> Signal<MultipartUploadResult, NoError> {
    return network.download(datacenterId: network.datacenterId)
        |> mapToSignal { download -> Signal<MultipartUploadResult, NoError> in
            return Signal { subscriber in
                var encryptionKey: SecretFileEncryptionKey?
                if encrypt {
                    var aesKey = Data()
                    aesKey.count = 32
                    var aesIv = Data()
                    aesIv.count = 32
                    aesKey.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
                        arc4random_buf(bytes, 32)
                    }
                    aesIv.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
                        arc4random_buf(bytes, 32)
                    }
                    encryptionKey = SecretFileEncryptionKey(aesKey: aesKey, aesIv: aesIv)
                }
                
                let resourceData = postbox.mediaBox.resourceData(resource, option: .incremental(waitUntilFetchStatus: false))
                
                let manager = MultipartUploadManager(data: resourceData, encryptionKey: encryptionKey, uploadPart: { part in
                    return download.uploadPart(fileId: part.fileId, index: part.index, data: part.data)
                }, progress: { progress in
                    subscriber.putNext(.progress(progress))
                }, completed: { result in
                    if let encryptionKey = encryptionKey {
                        let keyDigest = md5(encryptionKey.aesKey + encryptionKey.aesIv)
                        var fingerprint: Int32 = 0
                        keyDigest.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
                            withUnsafeMutableBytes(of: &fingerprint, { ptr -> Void in
                                let uintPtr = ptr.baseAddress!.assumingMemoryBound(to: UInt8.self)
                                uintPtr[0] = bytes[0] ^ bytes[4]
                                uintPtr[1] = bytes[1] ^ bytes[5]
                                uintPtr[2] = bytes[2] ^ bytes[6]
                                uintPtr[3] = bytes[3] ^ bytes[7]
                            })
                        }
                        let inputFile = Api.InputEncryptedFile.inputEncryptedFileUploaded(id: result.id, parts: result.partCount, md5Checksum: result.md5Digest, keyFingerprint: fingerprint)
                        subscriber.putNext(.inputSecretFile(inputFile, result.size, encryptionKey))
                    } else {
                        let inputFile = Api.InputFile.inputFile(id: result.id, parts: result.partCount, name: "file.jpg", md5Checksum: result.md5Digest)
                        subscriber.putNext(.inputFile(inputFile))
                    }
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
