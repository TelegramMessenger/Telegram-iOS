import Foundation
import SwiftSignalKit
import CoreMedia
import ImageIO

private struct PayloadDescription: Codable {
    var id: UInt32
    var timestamp: Int32
}

private struct JoinPayload: Codable {
    var id: UInt32
    var string: String
}

private struct JoinResponsePayload: Codable {
    var id: UInt32
    var string: String
}

private struct KeepaliveInfo: Codable {
    var id: UInt32
    var timestamp: Int32
}

private struct CutoffPayload: Codable {
    var id: UInt32
    var timestamp: Int32
}

private let checkInterval: Double = 0.2
private let keepaliveTimeout: Double = 2.0

private func payloadDescriptionPath(basePath: String) -> String {
    return basePath + "/currentPayloadDescription.json"
}

private func joinPayloadPath(basePath: String) -> String {
    return basePath + "/joinPayload.json"
}

private func joinResponsePayloadPath(basePath: String) -> String {
    return basePath + "/joinResponsePayload.json"
}

private func keepaliveInfoPath(basePath: String) -> String {
    return basePath + "/keepaliveInfo.json"
}

private func cutoffPayloadPath(basePath: String) -> String {
    return basePath + "/cutoffPayload.json"
}

private func broadcastAppSocketPath(basePath: String) -> String {
    return basePath + "/0"
}

private final class FdReadConnection {
    private final class PendingData {
        var data: Data
        var offset: Int = 0

        init(count: Int) {
            self.data = Data(bytesNoCopy: malloc(count)!, count: count, deallocator: .free)
        }
    }

    private let queue: Queue
    let fd: Int32
    private let didRead: ((Data) -> Void)?
    private let channel: DispatchSourceRead

    private var currendData: PendingData?

    init(queue: Queue, fd: Int32, didRead: ((Data) -> Void)?) {
        assert(queue.isCurrent())
        self.queue = queue
        self.fd = fd
        self.didRead = didRead

        self.channel = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue.queue)
        self.channel.setEventHandler(handler: { [weak self] in
            guard let strongSelf = self else {
                return
            }

            while true {
                if let currendData = strongSelf.currendData {
                    let offset = currendData.offset
                    let count = currendData.data.count - offset
                    let bytesRead = currendData.data.withUnsafeMutableBytes { bytes -> Int in
                        return Darwin.read(fd, bytes.baseAddress!.advanced(by: offset), min(8129, count))
                    }
                    if bytesRead <= 0 {
                        break
                    } else {
                        currendData.offset += bytesRead
                        if currendData.offset == currendData.data.count {
                            strongSelf.currendData = nil
                            strongSelf.didRead?(currendData.data)
                        }
                    }
                } else {
                    var length: Int32 = 0
                    let bytesRead = read(fd, &length, 4)
                    if bytesRead < 0 {
                        break
                    } else {
                        assert(bytesRead == 4)
                        if length > 0 {
                            assert(length > 0 && length <= 30 * 1024 * 1024)
                            strongSelf.currendData = PendingData(count: Int(length))
                        }
                    }
                }
            }
        })
        self.channel.resume()
    }

    deinit {
        assert(self.queue.isCurrent())
        self.channel.cancel()
    }
}

private final class FdWriteConnection {
    private final class PendingData {
        let data: Data
        var didWriteHeader: Bool = false
        var offset: Int = 0

        init(data: Data) {
            self.data = data
        }
    }

    private let queue: Queue
    let fd: Int32
    private let channel: DispatchSourceWrite
    private var isResumed = false

    private let bufferSize: Int
    private let buffer: UnsafeMutableRawPointer

    private var currentData: PendingData?
    private var nextDataList: [Data] = []

    init(queue: Queue, fd: Int32) {
        assert(queue.isCurrent())
        self.queue = queue
        self.fd = fd

        self.bufferSize = 8192
        self.buffer = malloc(self.bufferSize)

        self.channel = DispatchSource.makeWriteSource(fileDescriptor: fd, queue: queue.queue)
        self.channel.setEventHandler(handler: { [weak self] in
            guard let strongSelf = self else {
                return
            }

            while true {
                if let currentData = strongSelf.currentData {
                    if !currentData.didWriteHeader {
                        var length: Int32 = Int32(currentData.data.count)
                        let writtenBytes = Darwin.write(fd, &length, 4)
                        if writtenBytes > 0 {
                            assert(writtenBytes == 4)
                            currentData.didWriteHeader = true
                        } else {
                            strongSelf.channel.suspend()
                            strongSelf.isResumed = false
                            break
                        }
                    } else {
                        let offset = currentData.offset
                        let count = currentData.data.count - offset
                        let writtenBytes = currentData.data.withUnsafeBytes { bytes -> Int in
                            return Darwin.write(fd, bytes.baseAddress!.advanced(by: offset), min(count, strongSelf.bufferSize))
                        }
                        if writtenBytes > 0 {
                            currentData.offset += writtenBytes
                            if currentData.offset == currentData.data.count {
                                strongSelf.currentData = nil

                                if !strongSelf.nextDataList.isEmpty {
                                    let nextData = strongSelf.nextDataList.removeFirst()
                                    strongSelf.currentData = PendingData(data: nextData)
                                } else {
                                    strongSelf.channel.suspend()
                                    strongSelf.isResumed = false
                                    break
                                }
                            }
                        } else {
                            strongSelf.channel.suspend()
                            strongSelf.isResumed = false
                            break
                        }
                    }
                } else {
                    strongSelf.channel.suspend()
                    strongSelf.isResumed = false
                    break
                }
            }
        })
    }

    deinit {
        assert(self.queue.isCurrent())

        if !self.isResumed {
            self.channel.resume()
        }
        self.channel.cancel()

        free(self.buffer)
    }

    func addData(data: Data) {
        if self.currentData == nil {
            self.currentData = PendingData(data: data)
        } else {
            var totalBytes = 0
            for data in self.nextDataList {
                totalBytes += data.count
            }
            if totalBytes < 1 * 1024 * 1024 {
                self.nextDataList.append(data)
            }
        }

        if !self.isResumed {
            self.isResumed = true
            self.channel.resume()
        }
    }
}

private final class NamedPipeReaderImpl {
    private let queue: Queue
    private var connection: FdReadConnection?
    
    init(queue: Queue, path: String, didRead: @escaping (Data) -> Void) {
        self.queue = queue

        unlink(path)
        mkfifo(path, 0o666)
        let fd = open(path, O_RDONLY | O_NONBLOCK, S_IRUSR | S_IWUSR)
        if fd != -1 {
            self.connection = FdReadConnection(queue: self.queue, fd: fd, didRead: { data in
                didRead(data)
            })
        }
    }
}

private final class NamedPipeReader {
    private let queue = Queue()
    let impl: QueueLocalObject<NamedPipeReaderImpl>

    init(path: String, didRead: @escaping (Data) -> Void) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return NamedPipeReaderImpl(queue: queue, path: path, didRead: didRead)
        })
    }
}

private final class NamedPipeWriterImpl {
    private let queue: Queue
    private var connection: FdWriteConnection?

    init(queue: Queue, path: String) {
        self.queue = queue

        let fd = open(path, O_WRONLY | O_NONBLOCK, S_IRUSR | S_IWUSR)
        if fd != -1 {
            self.connection = FdWriteConnection(queue: self.queue, fd: fd)
        }
    }

    func addData(data: Data) {
        guard let connection = self.connection else {
            return
        }
        connection.addData(data: data)
    }
}

private final class NamedPipeWriter {
    private let queue = Queue()
    private let impl: QueueLocalObject<NamedPipeWriterImpl>

    init(path: String) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return NamedPipeWriterImpl(queue: queue, path: path)
        })
    }

    func addData(data: Data) {
        self.impl.with { impl in
            impl.addData(data: data)
        }
    }
}

private final class MappedFile {
    let path: String
    private var handle: Int32
    private var currentSize: Int
    private(set) var memory: UnsafeMutableRawPointer

    init?(path: String, createIfNotExists: Bool) {
        self.path = path

        var flags: Int32 = O_RDWR | O_APPEND
        if createIfNotExists {
            flags |= O_CREAT
        }
        self.handle = open(path, flags, S_IRUSR | S_IWUSR)

        if self.handle < 0 {
            return nil
        }

        var value = stat()
        stat(path, &value)
        self.currentSize = Int(value.st_size)

        self.memory = mmap(nil, self.currentSize, PROT_READ | PROT_WRITE, MAP_SHARED, self.handle, 0)
    }

    deinit {
        munmap(self.memory, self.currentSize)
        close(self.handle)
    }

    var size: Int {
        get {
            return self.currentSize
        } set(value) {
            if value != self.currentSize {
                munmap(self.memory, self.currentSize)
                ftruncate(self.handle, off_t(value))
                self.currentSize = value
                self.memory = mmap(nil, self.currentSize, PROT_READ | PROT_WRITE, MAP_SHARED, self.handle, 0)
            }
        }
    }

    func synchronize() {
        msync(self.memory, self.currentSize, MS_ASYNC)
    }

    func write(at range: Range<Int>, from data: UnsafeRawPointer) {
        memcpy(self.memory.advanced(by: range.lowerBound), data, range.count)
    }

    func read(at range: Range<Int>, to data: UnsafeMutableRawPointer) {
        memcpy(data, self.memory.advanced(by: range.lowerBound), range.count)
    }

    func clear() {
        memset(self.memory, 0, self.currentSize)
    }
}

public final class IpcGroupCallBufferAppContext {
    private let basePath: String
    private var audioServer: NamedPipeReader?

    private let id: UInt32

    private let isActivePromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    public var isActive: Signal<Bool, NoError> {
        return self.isActivePromise.get()
    }
    private var isActiveCheckTimer: SwiftSignalKit.Timer?

    private let framesPipe = ValuePipe<(CVPixelBuffer, CGImagePropertyOrientation)>()
    public var frames: Signal<(CVPixelBuffer, CGImagePropertyOrientation), NoError> {
        return self.framesPipe.signal()
    }

    private let audioDataPipe = ValuePipe<Data>()
    public var audioData: Signal<Data, NoError> {
        return self.audioDataPipe.signal()
    }

    private var framePollTimer: SwiftSignalKit.Timer?
    private var mappedFile: MappedFile?

    private var callActiveInfoTimer: SwiftSignalKit.Timer?

    public init(basePath: String) {
        self.basePath = basePath
        let _ = try? FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: true, attributes: nil)

        self.id = UInt32.random(in: 0 ..< UInt32.max)

        let dataPath = broadcastAppSocketPath(basePath: basePath) + "-data-\(self.id)"
        let audioDataPath = broadcastAppSocketPath(basePath: basePath) + "-audio-\(self.id)"

        if let mappedFile = MappedFile(path: dataPath, createIfNotExists: true) {
            self.mappedFile = mappedFile
            if mappedFile.size < 10 * 1024 * 1024 {
                mappedFile.size = 10 * 1024 * 1024
            }
        }

        let audioDataPipe = self.audioDataPipe
        self.audioServer = NamedPipeReader(path: audioDataPath, didRead: { data in
            audioDataPipe.putNext(data)
        })

        let framePollTimer = SwiftSignalKit.Timer(timeout: 1.0 / 30.0, repeat: true, completion: { [weak self] in
            guard let strongSelf = self, let mappedFile = strongSelf.mappedFile else {
                return
            }

            var orientationValue: Int32 = 0
            mappedFile.read(at: 0 ..< 4, to: &orientationValue)
            let orientation = CGImagePropertyOrientation(rawValue: UInt32(bitPattern: orientationValue)) ?? .up
            let data = Data(bytesNoCopy: mappedFile.memory.advanced(by: 4), count: mappedFile.size - 4, deallocator: .none)
            if let frame = deserializePixelBuffer(data: data) {
                strongSelf.framesPipe.putNext((frame, orientation))
            }
        }, queue: .mainQueue())
        self.framePollTimer = framePollTimer
        framePollTimer.start()

        self.updateCallIsActive()

        let callActiveInfoTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
            self?.updateCallIsActive()
        }, queue: .mainQueue())
        self.callActiveInfoTimer = callActiveInfoTimer
        callActiveInfoTimer.start()

        let isActiveCheckTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
            self?.updateKeepaliveInfo()
        }, queue: .mainQueue())
        self.isActiveCheckTimer = isActiveCheckTimer
        isActiveCheckTimer.start()
    }

    deinit {
        self.framePollTimer?.invalidate()
        self.callActiveInfoTimer?.invalidate()
        self.isActiveCheckTimer?.invalidate()
        if let mappedFile = self.mappedFile {
            self.mappedFile = nil
            let _ = try? FileManager.default.removeItem(atPath: mappedFile.path)
        }
    }

    private func updateCallIsActive() {
        let timestamp = Int32(Date().timeIntervalSince1970)
        let payloadDescription = PayloadDescription(
            id: self.id,
            timestamp: timestamp
        )
        guard let payloadDescriptionData = try? JSONEncoder().encode(payloadDescription) else {
            return
        }
        guard let _ = try? payloadDescriptionData.write(to: URL(fileURLWithPath: payloadDescriptionPath(basePath: self.basePath)), options: .atomic) else {
            return
        }
    }

    private func updateKeepaliveInfo() {
        let filePath = keepaliveInfoPath(basePath: self.basePath)
        guard let keepaliveInfoData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            return
        }
        guard let keepaliveInfo = try? JSONDecoder().decode(KeepaliveInfo.self, from: keepaliveInfoData) else {
            return
        }
        if keepaliveInfo.id != self.id {
            self.isActivePromise.set(false)
            return
        }
        let timestamp = Int32(Date().timeIntervalSince1970)
        if keepaliveInfo.timestamp < timestamp - Int32(keepaliveTimeout) {
            self.isActivePromise.set(false)
            return
        }

        self.isActivePromise.set(true)
    }
    
    public func stopScreencast() {
        let timestamp = Int32(Date().timeIntervalSince1970)
        let cutoffPayload = CutoffPayload(
            id: self.id,
            timestamp: timestamp
        )
        guard let cutoffPayloadData = try? JSONEncoder().encode(cutoffPayload) else {
            return
        }
        guard let _ = try? cutoffPayloadData.write(to: URL(fileURLWithPath: cutoffPayloadPath(basePath: self.basePath)), options: .atomic) else {
            return
        }
    }
}

public final class IpcGroupCallBufferBroadcastContext {
    public enum Status {
        public enum FinishReason {
            case screencastEnded
            case callEnded
            case error
        }
        case active
        case finished(FinishReason)
    }

    private let basePath: String
    private let client: NamedPipeWriter
    private var timer: SwiftSignalKit.Timer?

    private let statusPromise = Promise<Status>()
    public var status: Signal<Status, NoError> {
        return self.statusPromise.get()
    }

    private var mappedFile: MappedFile?
    private var currentId: UInt32?
    private var audioClient: NamedPipeWriter?

    private var callActiveInfoTimer: SwiftSignalKit.Timer?
    private var keepaliveInfoTimer: SwiftSignalKit.Timer?
    private var screencastCutoffTimer: SwiftSignalKit.Timer?
    
    public init(basePath: String) {
        self.basePath = basePath
        let _ = try? FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: true, attributes: nil)

        self.client = NamedPipeWriter(path: broadcastAppSocketPath(basePath: basePath))

        let callActiveInfoTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
            self?.updateCallIsActive()
        }, queue: .mainQueue())
        self.callActiveInfoTimer = callActiveInfoTimer
        callActiveInfoTimer.start()
        
        let screencastCutoffTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
            self?.updateScreencastCutoff()
        }, queue: .mainQueue())
        self.screencastCutoffTimer = screencastCutoffTimer
        screencastCutoffTimer.start()
    }

    deinit {
        self.endActiveIndication()

        self.callActiveInfoTimer?.invalidate()
        self.keepaliveInfoTimer?.invalidate()
        self.screencastCutoffTimer?.invalidate()
    }

    private func updateScreencastCutoff() {
        let filePath = cutoffPayloadPath(basePath: self.basePath)
        guard let cutoffPayloadData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            return
        }
        
        guard let cutoffPayload = try? JSONDecoder().decode(CutoffPayload.self, from: cutoffPayloadData) else {
            return
        }
        
        let timestamp = Int32(Date().timeIntervalSince1970)
        if let currentId = self.currentId, currentId == cutoffPayload.id && cutoffPayload.timestamp > timestamp - 10 {
            self.statusPromise.set(.single(.finished(.screencastEnded)))
            return
        }
    }
    
    private func updateCallIsActive() {
        let filePath = payloadDescriptionPath(basePath: self.basePath)
        guard let payloadDescriptionData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            self.statusPromise.set(.single(.finished(.error)))
            return
        }

        guard let payloadDescription = try? JSONDecoder().decode(PayloadDescription.self, from: payloadDescriptionData) else {
            self.statusPromise.set(.single(.finished(.error)))
            return
        }
        let timestamp = Int32(Date().timeIntervalSince1970)
        if payloadDescription.timestamp < timestamp - 4 {
            self.statusPromise.set(.single(.finished(.callEnded)))
            return
        }

        if let currentId = self.currentId {
            if currentId != payloadDescription.id {
                self.statusPromise.set(.single(.finished(.callEnded)))
            }
        } else {
            self.currentId = payloadDescription.id

            let dataPath = broadcastAppSocketPath(basePath: basePath) + "-data-\(payloadDescription.id)"
            let audioDataPath = broadcastAppSocketPath(basePath: basePath) + "-audio-\(payloadDescription.id)"

            if let mappedFile = MappedFile(path: dataPath, createIfNotExists: false) {
                self.mappedFile = mappedFile
                if mappedFile.size < 10 * 1024 * 1024 {
                    mappedFile.size = 10 * 1024 * 1024
                }
            }

            self.audioClient = NamedPipeWriter(path: audioDataPath)

            self.writeKeepaliveInfo()

            let keepaliveInfoTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
                self?.writeKeepaliveInfo()
            }, queue: .mainQueue())
            self.keepaliveInfoTimer = keepaliveInfoTimer
            keepaliveInfoTimer.start()

            self.statusPromise.set(.single(.active))
        }
    }

    public func setCurrentFrame(data: Data, orientation: CGImagePropertyOrientation) {
        if let mappedFile = self.mappedFile, mappedFile.size >= data.count {
            let _ = data.withUnsafeBytes { bytes in
                var orientationValue = Int32(bitPattern: orientation.rawValue)
                memmove(mappedFile.memory, &orientationValue, 4)
                memcpy(mappedFile.memory.advanced(by: 4), bytes.baseAddress!, data.count)
            }
        }
    }

    public func writeAudioData(data: Data) {
        self.audioClient?.addData(data: data)
    }

    private func writeKeepaliveInfo() {
        guard let currentId = self.currentId else {
            preconditionFailure()
        }
        let keepaliveInfo = KeepaliveInfo(
            id: currentId,
            timestamp: Int32(Date().timeIntervalSince1970)
        )
        guard let keepaliveInfoData = try? JSONEncoder().encode(keepaliveInfo) else {
            preconditionFailure()
        }
        guard let _ = try? keepaliveInfoData.write(to: URL(fileURLWithPath: keepaliveInfoPath(basePath: self.basePath)), options: .atomic) else {
            preconditionFailure()
        }
    }

    private func endActiveIndication() {
        let _ = try? FileManager.default.removeItem(atPath: keepaliveInfoPath(basePath: self.basePath))
    }
}

public func serializePixelBuffer(buffer: CVPixelBuffer) -> Data? {
    let pixelFormat = CVPixelBufferGetPixelFormatType(buffer)
    switch pixelFormat {
    case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
        let status = CVPixelBufferLockBaseAddress(buffer, .readOnly)
        if status != kCVReturnSuccess {
            return nil
        }
        defer {
            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
        }

        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)

        guard let yPlane = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else {
            return nil
        }
        let yStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        let yPlaneSize = yStride * height

        guard let uvPlane = CVPixelBufferGetBaseAddressOfPlane(buffer, 1) else {
            return nil
        }
        let uvStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
        let uvPlaneSize = uvStride * (height / 2)

        let headerSize: Int = 4 + 4 + 4 + 4 + 4

        let dataSize = headerSize + yPlaneSize + uvPlaneSize
        let resultBytes = malloc(dataSize)!

        var pixelFormatValue = pixelFormat
        memcpy(resultBytes.advanced(by: 0), &pixelFormatValue, 4)
        var widthValue = Int32(width)
        memcpy(resultBytes.advanced(by: 4), &widthValue, 4)
        var heightValue = Int32(height)
        memcpy(resultBytes.advanced(by: 4 + 4), &heightValue, 4)
        var yStrideValue = Int32(yStride)
        memcpy(resultBytes.advanced(by: 4 + 4 + 4), &yStrideValue, 4)
        var uvStrideValue = Int32(uvStride)
        memcpy(resultBytes.advanced(by: 4 + 4 + 4 + 4), &uvStrideValue, 4)

        memcpy(resultBytes.advanced(by: headerSize), yPlane, yPlaneSize)
        memcpy(resultBytes.advanced(by: headerSize + yPlaneSize), uvPlane, uvPlaneSize)

        return Data(bytesNoCopy: resultBytes, count: dataSize, deallocator: .free)
    default:
        return nil
    }
}

public func deserializePixelBuffer(data: Data) -> CVPixelBuffer? {
    if data.count < 4 + 4 + 4 + 4 {
        return nil
    }
    let count = data.count
    return data.withUnsafeBytes { bytes -> CVPixelBuffer? in
        let dataBytes = bytes.baseAddress!

        var pixelFormat: UInt32 = 0
        memcpy(&pixelFormat, dataBytes.advanced(by: 0), 4)

        switch pixelFormat {
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            break
        default:
            return nil
        }

        var width: Int32 = 0
        memcpy(&width, dataBytes.advanced(by: 4), 4)
        var height: Int32 = 0
        memcpy(&height, dataBytes.advanced(by: 4 + 4), 4)
        var yStride: Int32 = 0
        memcpy(&yStride, dataBytes.advanced(by: 4 + 4 + 4), 4)
        var uvStride: Int32 = 0
        memcpy(&uvStride, dataBytes.advanced(by: 4 + 4 + 4 + 4), 4)

        if width < 0 || width > 8192 {
            return nil
        }
        if height < 0 || height > 8192 {
            return nil
        }

        let headerSize: Int = 4 + 4 + 4 + 4 + 4

        let yPlaneSize = Int(yStride * height)
        let uvPlaneSize = Int(uvStride * height / 2)
        let dataSize = headerSize + yPlaneSize + uvPlaneSize

        if dataSize > count {
            return nil
        }

        var buffer: CVPixelBuffer? = nil
        CVPixelBufferCreate(nil, Int(width), Int(height), pixelFormat, nil, &buffer)
        if let buffer = buffer {
            let status = CVPixelBufferLockBaseAddress(buffer, [])
            if status != kCVReturnSuccess {
                return nil
            }
            defer {
                CVPixelBufferUnlockBaseAddress(buffer, [])
            }

            guard let destYPlane = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else {
                return nil
            }
            let destYStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
            if destYStride != Int(yStride) {
                return nil
            }

            guard let destUvPlane = CVPixelBufferGetBaseAddressOfPlane(buffer, 1) else {
                return nil
            }
            let destUvStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
            if destUvStride != Int(uvStride) {
                return nil
            }

            memcpy(destYPlane, dataBytes.advanced(by: headerSize), yPlaneSize)
            memcpy(destUvPlane, dataBytes.advanced(by: headerSize + yPlaneSize), uvPlaneSize)

            return buffer
        } else {
            return nil
        }
    }
}
