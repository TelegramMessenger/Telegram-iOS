import Foundation
import AVFoundation
import VideoToolbox
import TelegramCore
import FFMpegBinding

final class MediaEditorVideoStreamingWriter: MediaEditorVideoExportWriter {
    private struct Packet {
        let isVideo: Bool
        let data: Data
        let pts: Int64
        let dts: Int64
        let duration: Int64
        let isKeyframe: Bool
    }

    private struct WriterError: LocalizedError {
        let message: String

        var errorDescription: String? {
            return self.message
        }
    }

    private static let videoTimescale: Int32 = 90000
    private static let interleaveWindow: Double = 1.0
    private static let maxKeyFrameInterval = 30
    private static let maxPendingVideoFrameCount = 8
    private static let encoderStallTimeout: Double = 0.02
    private static let reorderDepthProbeCount = 16
    private static let heldAudioPacketCount = 3

    static func supports(configuration: MediaEditorVideoExport.Configuration) -> Bool {
        guard let codec = videoCodec(configuration: configuration), codec == .hevc || codec == .h264 else {
            return false
        }
        if configuration.audioSettings.isEmpty {
            return true
        }
        return (configuration.audioSettings[AVFormatIDKey] as? NSNumber)?.uint32Value == kAudioFormatMPEG4AAC
    }

    static func reservedMoovSize(duration: Double, frameRate: Double, audioSampleRate: Int) -> Int64 {
        let videoSamples = ceil(duration * frameRate * 1.02) + 2
        let audioSamples = ceil(duration * Double(audioSampleRate) / 1024.0 * 1.02) + 2
        let chunks = ceil(duration / 0.5) + 4
        let videoBytes = videoSamples * (5.0 + 8.0 + 8.0 + 0.5) + chunks * 2.0 * 20.0
        let audioBytes = audioSamples * 5.0 + chunks * 20.0
        return Int64(videoBytes + audioBytes) + 24 * 1024
    }

    private static func videoCodec(configuration: MediaEditorVideoExport.Configuration) -> AVVideoCodecType? {
        if let codec = configuration.videoSettings[AVVideoCodecKey] as? AVVideoCodecType {
            return codec
        } else if let codec = configuration.videoSettings[AVVideoCodecKey] as? String {
            return AVVideoCodecType(rawValue: codec)
        } else {
            return nil
        }
    }

    private let expectedDuration: Double

    var onFileGrowth: ((Int64, Int64) -> Void)?
    private var headerEnd: Int64 = 0

    private let lock = NSLock()
    private let muxQueue = DispatchQueue(label: "MediaEditorVideoStreamingWriter.mux")
    private let audioQueue = DispatchQueue(label: "MediaEditorVideoStreamingWriter.audio")

    private var outputPath = ""
    private var isHEVC = true
    private var dimensions = CGSize()
    private var audioSampleRate = 44100
    private var audioChannels = 2
    private var audioBitrate = 64000

    private var writer: FFMpegMP4StreamWriter?
    private var session: VTCompressionSession?
    private var frameDuration = CMTime(value: 1, timescale: 30)
    private var sessionStart = CMTime.zero

    private var headerWritten = false
    private var pendingPackets: [Packet] = []
    private var pendingVideoPacketCount = 0
    private var videoReorderDepth: Int?
    private var videoFirstPts: Int64 = 0
    private var videoPacketIndex = 0
    private var videoPendingPts: [Int64] = []
    private var lastVideoDts: Int64?
    private var videoExtradata: Data?
    private var audioExtradata: Data?
    private var muxAudioPriming: Int64 = 0
    private var muxHasAudio = false
    private var videoStreamIndex: Int32 = -1
    private var audioStreamIndex: Int32 = -1

    private var statusValue: ExportWriterStatus = .unknown
    private var errorValue: Error?
    private var hasAudio = false
    private var lastVideoTime: Double = 0.0
    private var lastAudioTime: Double = 0.0
    private var videoFinished = false
    private var audioFinished = false
    private var videoBlock: (() -> Void)?
    private var audioBlock: (() -> Void)?
    private var blockQueue: DispatchQueue?
    private var pumpScheduled = false
    private var pendingVideoFrames = 0
    private var pendingVideoFrameLimit = MediaEditorVideoStreamingWriter.maxPendingVideoFrameCount
    private var encodedVideoFrameCount = 0
    private var stallCheckScheduled = false

    private var audioConverter: AVAudioConverter?
    private var aacFormat: AVAudioFormat?
    private var audioInputQueue: [AVAudioPCMBuffer] = []
    private var audioPacketIndex: Int64 = 0
    private var audioPriming: Int64 = 0
    private var audioInputFrames: Int64 = 0
    private var audioInputSampleRate: Double = 0
    private var heldAudioPackets: [Packet] = []

    init(expectedDuration: Double) {
        self.expectedDuration = expectedDuration
    }

    deinit {
        if let session = self.session {
            VTCompressionSessionInvalidate(session)
        }
    }

    func setup(configuration: MediaEditorVideoExport.Configuration, outputPath: String) {
        Logger.shared.log("VideoExport", "Will setup streaming writer")
        self.outputPath = outputPath
        self.isHEVC = MediaEditorVideoStreamingWriter.videoCodec(configuration: configuration) == .hevc
        self.dimensions = configuration.dimensions
        if let sampleRate = (configuration.audioSettings[AVSampleRateKey] as? NSNumber)?.intValue {
            self.audioSampleRate = sampleRate
        }
        if let channels = (configuration.audioSettings[AVNumberOfChannelsKey] as? NSNumber)?.intValue {
            self.audioChannels = channels
        }
        if let bitrate = (configuration.audioSettings[AVEncoderBitRateKey] as? NSNumber)?.intValue {
            self.audioBitrate = bitrate
        }
    }

    func setupVideoInput(configuration: MediaEditorVideoExport.Configuration, preferredTransform: CGAffineTransform?, sourceFrameRate: Float) {
        if sourceFrameRate > 0 {
            self.frameDuration = CMTime(seconds: 1.0 / Double(sourceFrameRate), preferredTimescale: 600000)
        }
        let reservedMoovSize = MediaEditorVideoStreamingWriter.reservedMoovSize(duration: self.expectedDuration, frameRate: max(Double(sourceFrameRate), Double(configuration.frameRate), 30.0), audioSampleRate: self.audioSampleRate)
        guard let writer = FFMpegMP4StreamWriter(path: self.outputPath, reservedMoovSize: reservedMoovSize) else {
            self.fail("Failed to create muxer")
            return
        }
        writer.writeObserver = { [weak self] fileSize, finalizing in
            guard let self, !finalizing, self.headerEnd > 0 else {
                return
            }
            self.onFileGrowth?(fileSize, self.headerEnd)
        }
        self.writer = writer

        let width = Int32(self.dimensions.width)
        let height = Int32(self.dimensions.height)
        let sourceAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        var session: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: nil,
            width: width,
            height: height,
            codecType: self.isHEVC ? kCMVideoCodecType_HEVC : kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: sourceAttributes as CFDictionary,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &session
        )
        guard status == noErr, let session else {
            self.fail("VTCompressionSessionCreate failed: \(status)")
            return
        }

        let compressionSettings = configuration.videoSettings[AVVideoCompressionPropertiesKey] as? [String: Any] ?? [:]
        var properties: [CFString: Any] = [
            kVTCompressionPropertyKey_RealTime: kCFBooleanFalse as Any,
            kVTCompressionPropertyKey_ExpectedFrameRate: sourceFrameRate,
            kVTCompressionPropertyKey_MaxKeyFrameInterval: MediaEditorVideoStreamingWriter.maxKeyFrameInterval
        ]
        if let bitrate = compressionSettings[AVVideoAverageBitRateKey] {
            properties[kVTCompressionPropertyKey_AverageBitRate] = bitrate
        }
        if let profileLevel = compressionSettings[AVVideoProfileLevelKey] {
            properties[kVTCompressionPropertyKey_ProfileLevel] = profileLevel
        }
        if let entropyMode = compressionSettings[AVVideoH264EntropyModeKey] {
            properties[kVTCompressionPropertyKey_H264EntropyMode] = entropyMode
        }
        for (key, value) in properties {
            let propertyStatus = VTSessionSetProperty(session, key: key, value: value as CFTypeRef)
            if propertyStatus != noErr {
                Logger.shared.log("VideoExport", "Streaming writer failed to set \(key): \(propertyStatus)")
            }
        }
        VTCompressionSessionPrepareToEncodeFrames(session)
        self.session = session
    }

    func setupAudioInput(configuration: MediaEditorVideoExport.Configuration) {
        self.lock.lock()
        self.hasAudio = true
        self.lock.unlock()
    }

    func startWriting() -> Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        guard self.writer != nil, self.session != nil, self.statusValue == .unknown else {
            return false
        }
        self.statusValue = .writing
        return true
    }

    func startSession(atSourceTime time: CMTime) {
        self.lock.lock()
        self.sessionStart = time
        self.lastVideoTime = time.seconds
        self.lastAudioTime = time.seconds
        self.lock.unlock()
    }

    func requestVideoDataWhenReady(on queue: DispatchQueue, using block: @escaping () -> Void) {
        self.lock.lock()
        self.blockQueue = queue
        self.videoBlock = block
        self.lock.unlock()
        self.schedulePump()
    }

    func requestAudioDataWhenReady(on queue: DispatchQueue, using block: @escaping () -> Void) {
        self.lock.lock()
        self.blockQueue = queue
        self.audioBlock = block
        self.lock.unlock()
        self.schedulePump()
    }

    private var isReadyForMoreVideoDataLocked: Bool {
        if self.videoFinished {
            return false
        }
        if self.statusValue == .failed || self.statusValue == .cancelled {
            return true
        }
        guard self.statusValue == .writing else {
            return false
        }
        if self.pendingVideoFrames >= self.pendingVideoFrameLimit {
            return false
        }
        if !self.hasAudio || self.audioFinished {
            return true
        }
        return self.lastVideoTime <= self.lastAudioTime + MediaEditorVideoStreamingWriter.interleaveWindow
    }

    private var isReadyForMoreAudioDataLocked: Bool {
        if self.audioFinished {
            return false
        }
        if self.statusValue == .failed || self.statusValue == .cancelled {
            return true
        }
        guard self.statusValue == .writing else {
            return false
        }
        if self.videoFinished {
            return true
        }
        return self.lastAudioTime <= self.lastVideoTime + MediaEditorVideoStreamingWriter.interleaveWindow
    }

    var isReadyForMoreVideoData: Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.isReadyForMoreVideoDataLocked
    }

    var isReadyForMoreAudioData: Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.isReadyForMoreAudioDataLocked
    }

    private func schedulePump() {
        self.lock.lock()
        guard let queue = self.blockQueue, !self.pumpScheduled else {
            self.lock.unlock()
            return
        }
        self.pumpScheduled = true
        self.lock.unlock()

        queue.async {
            self.lock.lock()
            self.pumpScheduled = false
            let videoBlock = self.isReadyForMoreVideoDataLocked ? self.videoBlock : nil
            self.lock.unlock()
            if let videoBlock {
                autoreleasepool {
                    videoBlock()
                }
            }
            self.scheduleStallCheckIfNeeded()

            self.lock.lock()
            let audioBlock = self.isReadyForMoreAudioDataLocked ? self.audioBlock : nil
            self.lock.unlock()
            if let audioBlock {
                autoreleasepool {
                    audioBlock()
                }
            }
        }
    }

    private func scheduleStallCheckIfNeeded() {
        self.lock.lock()
        guard let queue = self.blockQueue, !self.stallCheckScheduled, self.videoBlock != nil, self.statusValue == .writing, self.pendingVideoFrames >= self.pendingVideoFrameLimit else {
            self.lock.unlock()
            return
        }
        self.stallCheckScheduled = true
        let encodedCount = self.encodedVideoFrameCount
        self.lock.unlock()

        queue.asyncAfter(deadline: .now() + MediaEditorVideoStreamingWriter.encoderStallTimeout) {
            self.lock.lock()
            self.stallCheckScheduled = false
            if self.encodedVideoFrameCount == encodedCount && self.pendingVideoFrames >= self.pendingVideoFrameLimit {
                self.pendingVideoFrameLimit += 1
            }
            self.lock.unlock()
            self.schedulePump()
        }
    }

    var pixelBufferPool: CVPixelBufferPool? {
        guard let session = self.session else {
            return nil
        }
        return VTCompressionSessionGetPixelBufferPool(session)
    }

    func appendVideoBuffer(_ buffer: CMSampleBuffer) -> Bool {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(buffer) else {
            return false
        }
        return self.appendPixelBuffer(pixelBuffer, at: CMSampleBufferGetPresentationTimeStamp(buffer))
    }

    func appendPixelBuffer(_ buffer: CVPixelBuffer, at time: CMTime) -> Bool {
        guard let session = self.session else {
            return false
        }
        self.lock.lock()
        guard self.statusValue == .writing else {
            self.lock.unlock()
            return false
        }
        self.lastVideoTime = time.seconds
        self.pendingVideoFrames += 1
        self.lock.unlock()

        let status = VTCompressionSessionEncodeFrame(session, imageBuffer: buffer, presentationTimeStamp: time, duration: .invalid, frameProperties: nil, infoFlagsOut: nil, outputHandler: { [weak self] status, _, sampleBuffer in
            self?.handleEncodedFrame(status: status, sampleBuffer: sampleBuffer)
        })
        if status != noErr {
            self.lock.lock()
            self.pendingVideoFrames -= 1
            self.lock.unlock()
            self.fail("VTCompressionSessionEncodeFrame failed: \(status)")
            return false
        }
        return true
    }

    private func handleEncodedFrame(status: OSStatus, sampleBuffer: CMSampleBuffer?) {
        defer {
            self.lock.lock()
            self.pendingVideoFrames -= 1
            self.encodedVideoFrameCount += 1
            self.lock.unlock()
            self.schedulePump()
        }
        guard status == noErr else {
            self.fail("Encoder callback failed: \(status)")
            return
        }
        guard let sampleBuffer, let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return
        }

        var extradata: Data?
        if let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer), let atoms = CMFormatDescriptionGetExtension(formatDescription, extensionKey: kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms) as? [String: Any] {
            extradata = (atoms["hvcC"] as? Data) ?? (atoms["avcC"] as? Data)
        }

        let length = CMBlockBufferGetDataLength(dataBuffer)
        var data = Data(count: length)
        let copyStatus = data.withUnsafeMutableBytes { bytes -> OSStatus in
            guard let baseAddress = bytes.baseAddress else {
                return -1
            }
            return CMBlockBufferCopyDataBytes(dataBuffer, atOffset: 0, dataLength: length, destination: baseAddress)
        }
        guard copyStatus == noErr else {
            self.fail("CMBlockBufferCopyDataBytes failed: \(copyStatus)")
            return
        }

        var isKeyframe = true
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[CFString: Any]], let first = attachments.first {
            isKeyframe = !((first[kCMSampleAttachmentKey_NotSync] as? Bool) ?? false)
        }

        self.lock.lock()
        let start = self.sessionStart
        self.lock.unlock()
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer) - start
        let rawDecodeTime = CMSampleBufferGetDecodeTimeStamp(sampleBuffer)
        let decodeTime = rawDecodeTime.isValid ? rawDecodeTime - start : presentationTime
        let duration = CMSampleBufferGetDuration(sampleBuffer)

        let timescale = MediaEditorVideoStreamingWriter.videoTimescale
        let packet = Packet(
            isVideo: true,
            data: data,
            pts: CMTimeConvertScale(presentationTime, timescale: timescale, method: .roundHalfAwayFromZero).value,
            dts: CMTimeConvertScale(decodeTime, timescale: timescale, method: .roundHalfAwayFromZero).value,
            duration: CMTimeConvertScale(duration.isValid ? duration : self.frameDuration, timescale: timescale, method: .roundHalfAwayFromZero).value,
            isKeyframe: isKeyframe
        )
        self.muxQueue.async {
            if self.videoExtradata == nil {
                self.videoExtradata = extradata
            }
            self.enqueue(packet)
        }
    }

    func markVideoAsFinished() {
        self.lock.lock()
        self.videoFinished = true
        self.videoBlock = nil
        self.lock.unlock()
        self.schedulePump()
    }

    func appendAudioBuffer(_ buffer: CMSampleBuffer) -> Bool {
        guard let pcmBuffer = makePCMBuffer(buffer) else {
            self.fail("Failed to convert audio sample buffer")
            return false
        }
        let endTime = (CMSampleBufferGetPresentationTimeStamp(buffer) + CMSampleBufferGetDuration(buffer)).seconds
        self.lock.lock()
        guard self.statusValue == .writing else {
            self.lock.unlock()
            return false
        }
        self.lastAudioTime = endTime
        self.lock.unlock()

        self.audioQueue.async {
            autoreleasepool {
                self.audioInputFrames += Int64(pcmBuffer.frameLength)
                self.audioInputSampleRate = pcmBuffer.format.sampleRate
                self.audioInputQueue.append(pcmBuffer)
                self.encodeAudio(final: false)
            }
            self.schedulePump()
        }
        return true
    }

    func markAudioAsFinished() {
        self.lock.lock()
        self.audioFinished = true
        self.audioBlock = nil
        self.lock.unlock()
        self.audioQueue.async {
            autoreleasepool {
                self.encodeAudio(final: true)
            }
        }
        self.schedulePump()
    }

    private func makeAudioConverter(inputFormat: AVAudioFormat) -> Bool {
        var description = AudioStreamBasicDescription(
            mSampleRate: Double(self.audioSampleRate),
            mFormatID: kAudioFormatMPEG4AAC,
            mFormatFlags: 0,
            mBytesPerPacket: 0,
            mFramesPerPacket: 1024,
            mBytesPerFrame: 0,
            mChannelsPerFrame: UInt32(self.audioChannels),
            mBitsPerChannel: 0,
            mReserved: 0
        )
        guard let aacFormat = AVAudioFormat(streamDescription: &description), let converter = AVAudioConverter(from: inputFormat, to: aacFormat) else {
            return false
        }
        converter.bitRate = self.audioBitrate
        let leadingFrames = Int64(converter.primeInfo.leadingFrames)
        self.audioPriming = leadingFrames > 0 ? leadingFrames : 2112
        self.audioConverter = converter
        self.aacFormat = aacFormat

        let audioSpecificConfig = makeAudioSpecificConfig(sampleRate: self.audioSampleRate, channels: self.audioChannels)
        let priming = self.audioPriming
        self.muxQueue.async {
            self.audioExtradata = audioSpecificConfig
            self.muxAudioPriming = priming
            self.muxHasAudio = true
            self.tryWriteHeader()
        }
        return true
    }

    private func encodeAudio(final: Bool) {
        if self.audioConverter == nil {
            guard let first = self.audioInputQueue.first else {
                return
            }
            if !self.makeAudioConverter(inputFormat: first.format) {
                self.fail("Failed to create audio converter")
                return
            }
        }
        guard let converter = self.audioConverter, let aacFormat = self.aacFormat else {
            return
        }
        let maximumPacketSize = max(converter.maximumOutputPacketSize, 2048)
        while true {
            let output = AVAudioCompressedBuffer(format: aacFormat, packetCapacity: 32, maximumPacketSize: maximumPacketSize)
            var error: NSError?
            let result = converter.convert(to: output, error: &error, withInputFrom: { _, inputStatus in
                if !self.audioInputQueue.isEmpty {
                    inputStatus.pointee = .haveData
                    return self.audioInputQueue.removeFirst()
                }
                inputStatus.pointee = final ? .endOfStream : .noDataNow
                return nil
            })
            self.emitAudioPackets(output, final: final && result == .endOfStream)
            switch result {
            case .haveData:
                if output.packetCount == 0 {
                    return
                }
            case .inputRanDry, .endOfStream:
                return
            case .error:
                self.fail("Audio conversion failed: \(error?.localizedDescription ?? "unknown")")
                return
            @unknown default:
                return
            }
        }
    }

    private func emitAudioPackets(_ output: AVAudioCompressedBuffer, final: Bool) {
        if output.packetCount > 0, let descriptions = output.packetDescriptions {
            for index in 0 ..< Int(output.packetCount) {
                let description = descriptions[index]
                let data = Data(bytes: output.data.advanced(by: Int(description.mStartOffset)), count: Int(description.mDataByteSize))
                let pts = self.audioPacketIndex * 1024 - self.audioPriming
                self.audioPacketIndex += 1
                self.heldAudioPackets.append(Packet(isVideo: false, data: data, pts: pts, dts: pts, duration: 1024, isKeyframe: true))
            }
        }
        var packets: [Packet] = []
        if final {
            let expectedSamples = self.audioInputSampleRate > 0 ? Int64((Double(self.audioInputFrames) * Double(self.audioSampleRate) / self.audioInputSampleRate).rounded()) : Int64.max
            for packet in self.heldAudioPackets {
                let duration = max(1, min(1024, expectedSamples - packet.pts))
                packets.append(Packet(isVideo: false, data: packet.data, pts: packet.pts, dts: packet.dts, duration: duration, isKeyframe: true))
            }
            self.heldAudioPackets = []
        } else if self.heldAudioPackets.count > MediaEditorVideoStreamingWriter.heldAudioPacketCount {
            let count = self.heldAudioPackets.count - MediaEditorVideoStreamingWriter.heldAudioPacketCount
            packets = Array(self.heldAudioPackets.prefix(count))
            self.heldAudioPackets.removeFirst(count)
        }
        guard !packets.isEmpty else {
            return
        }
        self.muxQueue.async {
            for packet in packets {
                self.enqueue(packet)
            }
        }
    }

    private func enqueue(_ packet: Packet) {
        if !self.headerWritten || self.videoReorderDepth == nil {
            self.pendingPackets.append(packet)
            if packet.isVideo {
                self.pendingVideoPacketCount += 1
                if self.pendingVideoPacketCount >= MediaEditorVideoStreamingWriter.reorderDepthProbeCount {
                    self.resolveVideoReorderDepth()
                }
            }
            self.tryWriteHeader()
            return
        }
        self.write(packet)
    }

    private func resolveVideoReorderDepth() {
        guard self.videoReorderDepth == nil else {
            return
        }
        let videoPts = self.pendingPackets.filter(\.isVideo).map(\.pts)
        let sortedPts = videoPts.sorted()
        var depth = 0
        for (index, pts) in videoPts.enumerated() {
            if let rank = sortedPts.firstIndex(of: pts) {
                depth = max(depth, index - rank)
            }
        }
        self.videoReorderDepth = depth
        self.videoFirstPts = sortedPts.first ?? 0
    }

    private func nextVideoDts(pts: Int64) -> Int64 {
        let depth = self.videoReorderDepth ?? 0
        let insertionIndex = self.videoPendingPts.firstIndex(where: { $0 > pts }) ?? self.videoPendingPts.count
        self.videoPendingPts.insert(pts, at: insertionIndex)
        let index = self.videoPacketIndex
        self.videoPacketIndex += 1
        if index < depth {
            let frameTicks = max(1, CMTimeConvertScale(self.frameDuration, timescale: MediaEditorVideoStreamingWriter.videoTimescale, method: .roundHalfAwayFromZero).value)
            return self.videoFirstPts - Int64(depth - index) * frameTicks
        }
        return self.videoPendingPts.removeFirst()
    }

    private func tryWriteHeader(force: Bool = false) {
        if force {
            self.resolveVideoReorderDepth()
        }
        guard !self.headerWritten, self.videoReorderDepth != nil, let writer = self.writer, let videoExtradata = self.videoExtradata else {
            return
        }
        self.lock.lock()
        let expectsAudio = self.hasAudio
        self.lock.unlock()
        if expectsAudio && !self.muxHasAudio && !force {
            return
        }

        self.videoStreamIndex = writer.addVideoStream(with: self.isHEVC ? .HEVC : .H264, width: Int32(self.dimensions.width), height: Int32(self.dimensions.height), extradata: videoExtradata, timescale: MediaEditorVideoStreamingWriter.videoTimescale)
        if self.muxHasAudio, let audioExtradata = self.audioExtradata {
            self.audioStreamIndex = writer.addAudioStream(withSampleRate: Int32(self.audioSampleRate), channels: Int32(self.audioChannels), bitrate: Int32(self.audioBitrate), initialPadding: Int32(self.muxAudioPriming), extradata: audioExtradata)
        }
        guard self.videoStreamIndex >= 0, !self.muxHasAudio || self.audioStreamIndex >= 0 else {
            self.fail("Failed to add streams")
            return
        }
        guard writer.writeHeader() else {
            self.fail(writer.lastError ?? "Failed to write header")
            return
        }
        self.headerWritten = true
        self.headerEnd = writer.headerEnd

        let pending = self.pendingPackets
        self.pendingPackets = []
        for packet in pending {
            self.write(packet)
        }
    }

    private func write(_ packet: Packet) {
        guard let writer = self.writer else {
            return
        }
        let streamIndex = packet.isVideo ? self.videoStreamIndex : self.audioStreamIndex
        guard streamIndex >= 0 else {
            return
        }
        var dts = packet.dts
        if packet.isVideo {
            dts = self.nextVideoDts(pts: packet.pts)
            if dts > packet.pts {
                dts = packet.pts
            }
            if let lastVideoDts = self.lastVideoDts, dts <= lastVideoDts {
                dts = lastVideoDts + 1
            }
            self.lastVideoDts = dts
        }
        if !writer.writePacket(withStreamIndex: streamIndex, data: packet.data, pts: packet.pts, dts: dts, duration: packet.duration, isKeyframe: packet.isKeyframe) {
            self.fail(writer.lastError ?? "Failed to write packet")
        }
    }

    func finishWriting(completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let session = self.session {
                VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
            }
            self.audioQueue.sync {}
            self.muxQueue.async {
                if !self.headerWritten {
                    self.tryWriteHeader(force: true)
                }
                if let writer = self.writer, self.headerWritten, self.status == .writing {
                    if writer.finish() {
                        if writer.wroteMoovAtEnd {
                            Logger.shared.log("VideoExport", "Streaming writer: reserved moov space was too small, wrote moov at the end")
                        }
                        self.lock.lock()
                        self.statusValue = .completed
                        self.lock.unlock()
                    } else {
                        self.fail(writer.lastError ?? "Failed to finish")
                    }
                } else if self.status == .writing {
                    self.fail("Header was never written")
                }
                self.writer = nil
                completion()
            }
        }
    }

    func cancelWriting() {
        self.lock.lock()
        self.statusValue = .cancelled
        self.lock.unlock()
        if let session = self.session {
            VTCompressionSessionInvalidate(session)
            self.session = nil
        }
    }

    var status: ExportWriterStatus {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.statusValue
    }

    var error: Error? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.errorValue
    }

    private func fail(_ message: String) {
        Logger.shared.log("VideoExport", "Streaming writer: \(message)")
        self.lock.lock()
        if self.statusValue == .writing || self.statusValue == .unknown {
            self.statusValue = .failed
            self.errorValue = WriterError(message: message)
        }
        self.lock.unlock()
        self.schedulePump()
    }
}

private func makePCMBuffer(_ sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
    guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
        return nil
    }
    let format = AVAudioFormat(cmAudioFormatDescription: formatDescription)
    let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
    guard frameCount > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
        return nil
    }
    buffer.frameLength = AVAudioFrameCount(frameCount)
    let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(sampleBuffer, at: 0, frameCount: Int32(frameCount), into: buffer.mutableAudioBufferList)
    return status == noErr ? buffer : nil
}

private func makeAudioSpecificConfig(sampleRate: Int, channels: Int) -> Data {
    let sampleRates = [96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 16000, 12000, 11025, 8000, 7350]
    let frequencyIndex = sampleRates.firstIndex(of: sampleRate) ?? 4
    let objectType = 2
    let value = (objectType << 11) | (frequencyIndex << 7) | (channels << 3)
    return Data([UInt8((value >> 8) & 0xff), UInt8(value & 0xff)])
}
