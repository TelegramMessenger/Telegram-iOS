import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit
import MtProtoKit
import CryptoUtils
import ManagedFile

private typealias SignalKitTimer = SwiftSignalKit.Timer


private struct UploadPart {
    let fileId: Int64
    let index: Int
    let data: Data
    let bigTotalParts: Int?
    let bigPart: Bool
}

private func md5(_ data: Data) -> Data {
    return data.withUnsafeBytes { rawBytes -> Data in
        let bytes = rawBytes.baseAddress!
        return CryptoMD5(bytes, Int32(data.count))
    }
}

private final class MultipartUploadState {
    let aesKey: Data
    var aesIv: Data
    var effectiveSize: Int64 = 0
    
    init(encryptionKey: SecretFileEncryptionKey?) {
        if let encryptionKey = encryptionKey {
            self.aesKey = encryptionKey.aesKey
            self.aesIv = encryptionKey.aesIv
        } else {
            self.aesKey = Data()
            self.aesIv = Data()
        }
    }
    
    func transformHeader(data: Data) -> Data {
        assert(self.aesKey.isEmpty)
        self.effectiveSize += Int64(data.count)
        return data
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
            let encryptedDataCount = encryptedData.count
            encryptedData.withUnsafeMutableBytes { rawBytes -> Void in
                let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                if paddingSize != 0 {
                    arc4random_buf(bytes.advanced(by: encryptedDataCount - paddingSize), paddingSize)
                }
                self.aesIv.withUnsafeMutableBytes { rawIv -> Void in
                    let iv = rawIv.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    MTAesEncryptBytesInplaceAndModifyIv(bytes, encryptedDataCount, self.aesKey, iv)
                }
            }
            self.effectiveSize += Int64(encryptedData.count)
            return encryptedData
        } else {
            self.effectiveSize += Int64(data.count)
            return data
        }
    }
    
    func finalize() -> Int64 {
        return self.effectiveSize
    }
}

private struct MultipartIntermediateResult {
    let id: Int64
    let partCount: Int32
    let md5Digest: String
    let size: Int64
    let bigTotalParts: Int?
}

private enum MultipartUploadData {
    case resourceData(MediaResourceData)
    case data(Data)
    
    var size: Int64 {
        switch self {
        case let .resourceData(data):
            return data.size
        case let .data(data):
            return Int64(data.count)
        }
    }
    var complete: Bool {
        switch self {
        case let .resourceData(data):
            return data.complete
        case .data:
            return true
        }
    }
}

private enum HeaderPartState {
    case notStarted
    case uploading
    case ready
}

private final class MultipartUploadManager {
    let parallelParts: Int
    var defaultPartSize: Int64
    var bigTotalParts: Int?
    var bigParts: Bool
    private let forceNoBigParts: Bool
    private let useLargerParts: Bool
    
    let queue = Queue()
    let fileId: Int64
    
    let dataSignal: Signal<MultipartUploadData, NoError>
    
    var committedOffset: Int64
    let uploadPart: (UploadPart) -> Signal<Void, UploadPartError>
    let progress: (Float) -> Void
    let completed: (MultipartIntermediateResult?) -> Void
    
    var uploadingParts: [Int64: (Int64, Disposable)] = [:]
    var uploadedParts: [Int64: Int64] = [:]
    
    let dataDisposable = MetaDisposable()
    var resourceData: MultipartUploadData?
    
    var headerPartState: HeaderPartState
    
    let state: MultipartUploadState
    
    init(headerSize: Int32, data: Signal<MultipartUploadData, NoError>, encryptionKey: SecretFileEncryptionKey?, hintFileSize: Int64?, hintFileIsLarge: Bool, forceNoBigParts: Bool, useLargerParts: Bool, increaseParallelParts: Bool, uploadPart: @escaping (UploadPart) -> Signal<Void, UploadPartError>, progress: @escaping (Float) -> Void, completed: @escaping (MultipartIntermediateResult?) -> Void) {
        self.dataSignal = data
        
        var fileId: Int64 = 0
        arc4random_buf(&fileId, 8)
        self.fileId = fileId
        
        if increaseParallelParts {
            self.parallelParts = 30
        } else {
            self.parallelParts = 3
        }
        
        self.forceNoBigParts = forceNoBigParts
        self.useLargerParts = useLargerParts
        
        self.state = MultipartUploadState(encryptionKey: encryptionKey)
        
        self.committedOffset = 0
        self.uploadPart = uploadPart
        self.progress = progress
        self.completed = completed
        
        if headerSize == 0 {
            self.headerPartState = .ready
        } else {
            self.headerPartState = .notStarted
        }
        
        if let hintFileSize = hintFileSize, hintFileSize > 10 * 1024 * 1024, !forceNoBigParts {
            self.defaultPartSize = 512 * 1024
            self.bigTotalParts = Int((hintFileSize / self.defaultPartSize) + (hintFileSize % self.defaultPartSize == 0 ? 0 : 1))
            self.bigParts = true
        } else if hintFileIsLarge, !forceNoBigParts {
            self.defaultPartSize = 512 * 1024
            self.bigTotalParts = nil
            self.bigParts = true
        } else if useLargerParts {
            self.bigParts = false
            self.defaultPartSize = 256 * 1024
            self.bigTotalParts = nil
        } else {
            self.bigParts = false
            self.defaultPartSize = 16 * 1024
            self.bigTotalParts = nil
        }
    }
    
    func start() {
        self.queue.async {
            self.dataDisposable.set((self.dataSignal
            |> deliverOn(self.queue)).start(next: { [weak self] data in
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
        if let resourceData = self.resourceData, resourceData.complete && resourceData.size != 0 {
            if self.committedOffset == 0 && self.uploadedParts.isEmpty && self.uploadingParts.isEmpty {
                if resourceData.size > 10 * 1024 * 1024, !self.forceNoBigParts {
                    self.defaultPartSize = 512 * 1024
                    self.bigTotalParts = Int(resourceData.size / self.defaultPartSize) + (resourceData.size % self.defaultPartSize == 0 ? 0 : 1)
                    self.bigParts = true
                } else {
                    self.bigParts = false
                    if self.useLargerParts {
                        self.defaultPartSize = 256 * 1024
                    } else {
                        self.defaultPartSize = 16 * 1024
                    }
                    self.bigTotalParts = nil
                }
            }
        }
        
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
            switch self.headerPartState {
                case .ready:
                    let effectiveSize = self.state.finalize()
                    let effectivePartCount = Int32(effectiveSize / self.defaultPartSize + (effectiveSize % self.defaultPartSize == 0 ? 0 : 1))
                    var currentBigTotalParts = self.bigTotalParts
                    if self.bigParts {
                        currentBigTotalParts = Int(resourceData.size / self.defaultPartSize) + (resourceData.size % self.defaultPartSize == 0 ? 0 : 1)
                    }
                    self.completed(MultipartIntermediateResult(id: self.fileId, partCount: effectivePartCount, md5Digest: "", size: resourceData.size, bigTotalParts: currentBigTotalParts))
                case .notStarted:
                    let partOffset: Int64 = 0
                    let partSize = min(resourceData.size - partOffset, self.defaultPartSize)
                    let partIndex = Int(partOffset / self.defaultPartSize)
                    let fileData: Data?
                    switch resourceData {
                        case let .resourceData(data):
                            fileData = try? Data(contentsOf: URL(fileURLWithPath: data.path), options: [.alwaysMapped])
                        case let .data(data):
                            fileData = data
                    }
                    if let fileData = fileData {
                        let partData = self.state.transformHeader(data: fileData.subdata(in: Int(partOffset) ..< Int(partOffset + partSize)))
                        var currentBigTotalParts: Int? = nil
                        if self.bigParts {
                            let totalParts = (resourceData.size / self.defaultPartSize) + (resourceData.size % self.defaultPartSize == 0 ? 0 : 1)
                            currentBigTotalParts = Int(totalParts)
                        }
                        self.headerPartState = .uploading
                        let part = self.uploadPart(UploadPart(fileId: self.fileId, index: partIndex, data: partData, bigTotalParts: currentBigTotalParts, bigPart: self.bigParts))
                        |> deliverOn(self.queue)
                        self.uploadingParts[0] = (partSize, part.start(error: { [weak self] _ in
                            self?.completed(nil)
                        }, completed: { [weak self] in
                            if let strongSelf = self {
                                let _ = strongSelf.uploadingParts.removeValue(forKey: 0)
                                strongSelf.headerPartState = .ready
                                strongSelf.checkState()
                            }
                        }))
                    }
                case .uploading:
                    break
            }
        } else if let resourceData = self.resourceData, self.state.aesKey.isEmpty || resourceData.complete {
            while uploadingParts.count < self.parallelParts {
                switch self.headerPartState {
                    case .notStarted:
                        if self.committedOffset == 0, !resourceData.complete {
                            self.committedOffset += self.defaultPartSize
                        }
                    case .ready, .uploading:
                        break
                }
                
                var nextOffset = self.committedOffset
                for (offset, (size, _)) in self.uploadingParts {
                    nextOffset = max(nextOffset, offset + size)
                }
                for (offset, partSize) in self.uploadedParts {
                    nextOffset = max(nextOffset, offset + partSize)
                }
                
                let partOffset = nextOffset
                let partSize = min(resourceData.size - partOffset, self.defaultPartSize)
                
                if nextOffset < resourceData.size && partSize > 0 && (resourceData.complete || partSize == self.defaultPartSize) {
                    let partIndex = Int(partOffset / self.defaultPartSize)
                    let partData: Data?
                    switch resourceData {
                        case let .resourceData(data):
                            if let file = ManagedFile(queue: nil, path: data.path, mode: .read) {
                                file.seek(position: Int64(partOffset))
                                let data = file.readData(count: Int(partSize))
                                if data.count == partSize {
                                    partData = data
                                } else {
                                    partData = nil
                                }
                            } else {
                                partData = nil
                            }
                        case let .data(data):
                            if data.count >= partOffset + partSize {
                                partData = data.subdata(in: Int(partOffset) ..< Int(partOffset + partSize))
                            } else {
                                partData = nil
                            }
                    }
                    if let partData = partData {
                        let partData = self.state.transform(data: partData)
                        var currentBigTotalParts = self.bigTotalParts
                        if self.bigParts && resourceData.complete && partOffset + partSize == resourceData.size {
                            currentBigTotalParts = Int(resourceData.size / self.defaultPartSize) + (resourceData.size % self.defaultPartSize == 0 ? 0 : 1)
                        }
                        let part = self.uploadPart(UploadPart(fileId: self.fileId, index: partIndex, data: partData, bigTotalParts: currentBigTotalParts, bigPart: self.bigParts))
                        |> deliverOn(self.queue)
                        if partIndex == 0 {
                            switch self.headerPartState {
                                case .notStarted:
                                    self.headerPartState = .uploading
                                case .ready, .uploading:
                                    break
                            }
                        }
                        self.uploadingParts[nextOffset] = (partSize, part.start(error: { [weak self] _ in
                            self?.completed(nil)
                        }, completed: { [weak self] in
                            if let strongSelf = self {
                                let _ = strongSelf.uploadingParts.removeValue(forKey: nextOffset)
                                strongSelf.uploadedParts[partOffset] = partSize
                                if partIndex == 0 {
                                    strongSelf.headerPartState = .ready
                                }
                                strongSelf.checkState()
                            }
                        }))
                    } else {
                        self.completed(nil)
                    }
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
    case inputSecretFile(Api.InputEncryptedFile, Int64, SecretFileEncryptionKey)
}

public enum MultipartUploadSource {
    case resource(MediaResourceReference)
    case data(Data)
    case custom(Signal<MediaResourceData, NoError>)
    case tempFile(TempBoxFile)
}

enum MultipartUploadError {
    case generic
}

func multipartUpload(network: Network, postbox: Postbox, source: MultipartUploadSource, encrypt: Bool, tag: MediaResourceFetchTag?, hintFileSize: Int64?, hintFileIsLarge: Bool, forceNoBigParts: Bool, useLargerParts: Bool = false, increaseParallelParts: Bool = false, useMultiplexedRequests: Bool = true, useCompression: Bool = false) -> Signal<MultipartUploadResult, MultipartUploadError> {
    enum UploadInterface {
        case download(Download)
        case multiplexed(manager: MultiplexedRequestManager, datacenterId: Int, consumerId: Int64)
    }
    
    let uploadInterface: Signal<UploadInterface, NoError>
    if useMultiplexedRequests {
        uploadInterface = .single(.multiplexed(manager: network.multiplexedRequestManager, datacenterId: network.datacenterId, consumerId: Int64.random(in: Int64.min ... Int64.max)))
    } else {
        uploadInterface = network.upload(tag: tag)
        |> map { download -> UploadInterface in
            return .download(download)
        }
    }
    
    return uploadInterface
    |> mapToSignalPromotingError { uploadInterface -> Signal<MultipartUploadResult, MultipartUploadError> in
        return Signal { subscriber in
            var encryptionKey: SecretFileEncryptionKey?
            if encrypt {
                var aesKey = Data()
                aesKey.count = 32
                var aesIv = Data()
                aesIv.count = 32
                aesKey.withUnsafeMutableBytes { rawBytes -> Void in
                    let bytes = rawBytes.baseAddress!
                    arc4random_buf(bytes, 32)
                }
                aesIv.withUnsafeMutableBytes { rawBytes -> Void in
                    let bytes = rawBytes.baseAddress!
                    arc4random_buf(bytes, 32)
                }
                encryptionKey = SecretFileEncryptionKey(aesKey: aesKey, aesIv: aesIv)
            }
            
            let dataSignal: Signal<MultipartUploadData, NoError>
            let headerSize: Int32
            let fetchedResource: Signal<Void, FetchResourceError>
            switch source {
                case let .resource(resource):
                    dataSignal = postbox.mediaBox.resourceData(resource.resource, option: .incremental(waitUntilFetchStatus: true)) |> map { MultipartUploadData.resourceData($0) }
                    headerSize = resource.resource.headerSize
                    fetchedResource = fetchedMediaResource(mediaBox: postbox.mediaBox, reference: resource)
                    |> map { _ in }
                case let .tempFile(file):
                    if let size = fileSize(file.path) {
                        dataSignal = .single(.resourceData(MediaResourceData(path: file.path, offset: 0, size: size, complete: true)))
                        headerSize = 0
                        fetchedResource = .complete()
                    } else {
                        subscriber.putError(.generic)
                        return EmptyDisposable
                    }
                case let .data(data):
                    dataSignal = .single(.data(data))
                    headerSize = 0
                    fetchedResource = .complete()
                case let .custom(signal):
                    headerSize = 1024
                    dataSignal = signal
                    |> map { data in
                        print("**data \(data) \(data.complete)")
                        return MultipartUploadData.resourceData(data)
                    }
                    fetchedResource = .complete()
            }
            
            let manager = MultipartUploadManager(headerSize: headerSize, data: dataSignal, encryptionKey: encryptionKey, hintFileSize: hintFileSize, hintFileIsLarge: hintFileIsLarge, forceNoBigParts: forceNoBigParts, useLargerParts: useLargerParts, increaseParallelParts: increaseParallelParts, uploadPart: { part in
                switch uploadInterface {
                case let .download(download):
                    return download.uploadPart(fileId: part.fileId, index: part.index, data: part.data, asBigPart: part.bigPart, bigTotalParts: part.bigTotalParts, useCompression: useCompression)
                case let .multiplexed(multiplexed, datacenterId, consumerId):
                    return Download.uploadPart(multiplexedManager: multiplexed, datacenterId: datacenterId, consumerId: consumerId, tag: nil, fileId: part.fileId, index: part.index, data: part.data, asBigPart: part.bigPart, bigTotalParts: part.bigTotalParts, useCompression: useCompression)
                }
            }, progress: { progress in
                subscriber.putNext(.progress(progress))
            }, completed: { result in
                if let result = result {
                    if let encryptionKey = encryptionKey {
                        let keyDigest = md5(encryptionKey.aesKey + encryptionKey.aesIv)
                        var fingerprint: Int32 = 0
                        keyDigest.withUnsafeBytes { rawBytes -> Void in
                            let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                            
                            withUnsafeMutableBytes(of: &fingerprint, { ptr -> Void in
                                let uintPtr = ptr.baseAddress!.assumingMemoryBound(to: UInt8.self)
                                uintPtr[0] = bytes[0] ^ bytes[4]
                                uintPtr[1] = bytes[1] ^ bytes[5]
                                uintPtr[2] = bytes[2] ^ bytes[6]
                                uintPtr[3] = bytes[3] ^ bytes[7]
                            })
                        }
                        if let _ = result.bigTotalParts {
                            let inputFile = Api.InputEncryptedFile.inputEncryptedFileBigUploaded(id: result.id, parts: result.partCount, keyFingerprint: fingerprint)
                            subscriber.putNext(.inputSecretFile(inputFile, result.size, encryptionKey))
                        } else {
                            let inputFile = Api.InputEncryptedFile.inputEncryptedFileUploaded(id: result.id, parts: result.partCount, md5Checksum: result.md5Digest, keyFingerprint: fingerprint)
                            subscriber.putNext(.inputSecretFile(inputFile, result.size, encryptionKey))
                        }
                    } else {
                        if let _ = result.bigTotalParts {
                            let inputFile = Api.InputFile.inputFileBig(id: result.id, parts: result.partCount, name: "file.jpg")
                            subscriber.putNext(.inputFile(inputFile))
                        } else {
                            let inputFile = Api.InputFile.inputFile(id: result.id, parts: result.partCount, name: "file.jpg", md5Checksum: result.md5Digest)
                            subscriber.putNext(.inputFile(inputFile))
                        }
                    }
                    subscriber.putCompletion()
                } else {
                    subscriber.putError(.generic)
                }
            })

            manager.start()
            
            let fetchedResourceDisposable = fetchedResource.start(error: { _ in
                subscriber.putError(.generic)
            })
            
            return ActionDisposable {
                manager.cancel()
                fetchedResourceDisposable.dispose()
            }
        }
    }
}
