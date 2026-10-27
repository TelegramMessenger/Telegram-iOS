import Foundation
import AVFoundation
import CoreMedia
import CoreVideo
import VideoToolbox
import QuartzCore

@available(iOS 17.0, *)
final class MediaEditorDecodeProbe {
    struct Measurement {
        var seconds: Double = 0.0
        var frames: Int = 0
        var uniqueFrames: Int = 0
        var errors: Int = 0
        var maxPending: Int = 0
        var segmentSeconds: [Double] = []
    }

    enum Kind {
        case reader(pixelFormat: OSType?, colorProperties: Bool, copies: Bool)
        case toolbox(inFlight: Int, realTime: Bool?, temporal: Bool, pixelFormat: OSType?, transferTo709: Bool)
        case parallelReaders(segments: Int)
        case parallelToolbox(segments: Int, inFlight: Int)
    }

    struct Variant {
        let name: String
        let kind: Kind
    }

    static let variants: [Variant] = [
        Variant(name: "reader-export", kind: .reader(pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, colorProperties: true, copies: true)),
        Variant(name: "reader-export-nocopy", kind: .reader(pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, colorProperties: true, copies: false)),
        Variant(name: "reader-native", kind: .reader(pixelFormat: nil, colorProperties: false, copies: false)),
        Variant(name: "reader-420v-color", kind: .reader(pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, colorProperties: true, copies: true)),
        Variant(name: "reader-420f-nocolor", kind: .reader(pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, colorProperties: false, copies: true)),
        Variant(name: "vt-1", kind: .toolbox(inFlight: 1, realTime: nil, temporal: false, pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, transferTo709: false)),
        Variant(name: "vt-4", kind: .toolbox(inFlight: 4, realTime: nil, temporal: false, pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, transferTo709: false)),
        Variant(name: "vt-8", kind: .toolbox(inFlight: 8, realTime: nil, temporal: false, pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, transferTo709: false)),
        Variant(name: "vt-16", kind: .toolbox(inFlight: 16, realTime: nil, temporal: false, pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, transferTo709: false)),
        Variant(name: "vt-8-realtime", kind: .toolbox(inFlight: 8, realTime: true, temporal: false, pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, transferTo709: false)),
        Variant(name: "vt-8-notrealtime", kind: .toolbox(inFlight: 8, realTime: false, temporal: false, pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, transferTo709: false)),
        Variant(name: "vt-8-temporal", kind: .toolbox(inFlight: 8, realTime: nil, temporal: true, pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, transferTo709: false)),
        Variant(name: "vt-8-native", kind: .toolbox(inFlight: 8, realTime: nil, temporal: false, pixelFormat: nil, transferTo709: false)),
        Variant(name: "vt-8-transfer709", kind: .toolbox(inFlight: 8, realTime: nil, temporal: false, pixelFormat: nil, transferTo709: true)),
        Variant(name: "parallel-2", kind: .parallelReaders(segments: 2)),
        Variant(name: "parallel-3", kind: .parallelReaders(segments: 3)),
        Variant(name: "parallel-4", kind: .parallelReaders(segments: 4)),
        Variant(name: "parallel-vt-2", kind: .parallelToolbox(segments: 2, inFlight: 8)),
        Variant(name: "parallel-vt-4", kind: .parallelToolbox(segments: 4, inFlight: 8))
    ]

    static let parityVariants = ["reader-export", "reader-export-nocopy", "reader-420f-nocolor", "vt-8", "vt-8-transfer709", "parallel-4", "parallel-vt-4"]

    let asset: AVURLAsset
    let track: AVAssetTrack
    let frameRate: Int32
    let duration: CMTime
    var sink: ((Int, CVPixelBuffer) -> Void)?
    let nativeFormat: OSType
    private(set) var presentationIndices: [Int] = []

    init?(url: URL) {
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else {
            return nil
        }
        self.asset = asset
        self.track = track
        self.frameRate = Int32(track.nominalFrameRate.rounded())
        self.duration = asset.duration
        var nativeFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        if let first = track.formatDescriptions.first {
            let description = first as! CMFormatDescription
            if let transfer = CMFormatDescriptionGetExtension(description, extensionKey: kCMFormatDescriptionExtension_TransferFunction) as? String, transfer == (kCVImageBufferTransferFunction_ITU_R_2100_HLG as String) {
                nativeFormat = kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
            }
        }
        self.nativeFormat = nativeFormat
    }

    func frameIndex(_ time: CMTime) -> Int {
        return Int((time.seconds * Double(self.frameRate)).rounded())
    }

    func run(_ variant: Variant) -> Measurement {
        switch variant.kind {
        case let .reader(pixelFormat, colorProperties, copies):
            let start = CACurrentMediaTime()
            var measurement = self.readerSegment(range: nil, pixelFormat: pixelFormat, colorProperties: colorProperties, copies: copies, seen: nil)
            measurement.seconds = CACurrentMediaTime() - start
            measurement.uniqueFrames = measurement.frames
            return measurement
        case let .toolbox(inFlight, realTime, temporal, pixelFormat, transferTo709):
            if self.presentationIndices.isEmpty {
                self.presentationIndices = self.compressedSamples().map { self.frameIndex(CMSampleBufferGetPresentationTimeStamp($0)) }
            }
            let start = CACurrentMediaTime()
            var measurement = self.toolboxDecode(samples: nil, inFlight: inFlight, realTime: realTime, temporal: temporal, pixelFormat: pixelFormat, transferTo709: transferTo709)
            measurement.seconds = CACurrentMediaTime() - start
            measurement.uniqueFrames = measurement.frames
            return measurement
        case let .parallelReaders(segments):
            let ranges = self.segmentRanges(count: segments)
            let seen = SeenFrames(count: self.frameIndex(self.duration) + 1)
            var results = [Measurement](repeating: Measurement(), count: ranges.count)
            let lock = NSLock()
            let group = DispatchGroup()
            let start = CACurrentMediaTime()
            for (index, range) in ranges.enumerated() {
                group.enter()
                DispatchQueue(label: "MediaEditorDecodeProbe.segment\(index)", qos: .userInitiated).async {
                    let segmentStart = CACurrentMediaTime()
                    var result = self.readerSegment(range: range, pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, colorProperties: true, copies: true, seen: seen)
                    result.seconds = CACurrentMediaTime() - segmentStart
                    lock.lock()
                    results[index] = result
                    lock.unlock()
                    group.leave()
                }
            }
            group.wait()
            var measurement = Measurement()
            measurement.seconds = CACurrentMediaTime() - start
            measurement.frames = results.reduce(0) { $0 + $1.frames }
            measurement.errors = results.reduce(0) { $0 + $1.errors }
            measurement.segmentSeconds = results.map { $0.seconds }
            measurement.uniqueFrames = seen.unique
            return measurement
        case let .parallelToolbox(segments, inFlight):
            let samples = self.compressedSamples()
            let slices = self.decodeSlices(samples: samples, count: segments)
            var results = [Measurement](repeating: Measurement(), count: slices.count)
            let seen = SeenFrames(count: self.frameIndex(self.duration) + 1)
            let lock = NSLock()
            let group = DispatchGroup()
            let start = CACurrentMediaTime()
            for (index, slice) in slices.enumerated() {
                group.enter()
                DispatchQueue(label: "MediaEditorDecodeProbe.vtsegment\(index)", qos: .userInitiated).async {
                    let segmentStart = CACurrentMediaTime()
                    var result = self.toolboxDecode(samples: slice, inFlight: inFlight, realTime: nil, temporal: false, pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, transferTo709: false, seen: seen)
                    result.seconds = CACurrentMediaTime() - segmentStart
                    lock.lock()
                    results[index] = result
                    lock.unlock()
                    group.leave()
                }
            }
            group.wait()
            var measurement = Measurement()
            measurement.seconds = CACurrentMediaTime() - start
            measurement.frames = results.reduce(0) { $0 + $1.frames }
            measurement.errors = results.reduce(0) { $0 + $1.errors }
            measurement.maxPending = results.map { $0.maxPending }.max() ?? 0
            measurement.segmentSeconds = results.map { $0.seconds }
            measurement.uniqueFrames = seen.unique
            return measurement
        }
    }

    final class SeenFrames {
        private let lock = NSLock()
        private var flags: [Bool]
        private(set) var unique = 0

        init(count: Int) {
            self.flags = [Bool](repeating: false, count: count + 1)
        }

        func mark(_ index: Int) -> Bool {
            self.lock.lock()
            defer {
                self.lock.unlock()
            }
            guard index >= 0 && index < self.flags.count, !self.flags[index] else {
                return false
            }
            self.flags[index] = true
            self.unique += 1
            return true
        }
    }

    func segmentRanges(count: Int) -> [CMTimeRange] {
        let totalSeconds = Int(self.duration.seconds.rounded(.down))
        var bounds: [CMTime] = [.zero]
        for i in 1 ..< count {
            bounds.append(CMTime(value: Int64((totalSeconds * i + count / 2) / count), timescale: 1))
        }
        bounds.append(self.duration)
        return (0 ..< count).map { CMTimeRange(start: bounds[$0], end: bounds[$0 + 1]) }
    }

    func readerSegment(range: CMTimeRange?, pixelFormat: OSType?, colorProperties: Bool, copies: Bool, seen: SeenFrames?) -> Measurement {
        var measurement = Measurement()
        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            measurement.errors = 1
            return measurement
        }
        compositionTrack.preferredTransform = self.track.preferredTransform
        try? compositionTrack.insertTimeRange(CMTimeRange(start: .zero, duration: self.duration), of: self.track, at: .zero)
        guard let reader = try? AVAssetReader(asset: composition) else {
            measurement.errors = 1
            return measurement
        }
        reader.timeRange = range ?? CMTimeRange(start: .zero, duration: self.duration)
        var outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormat ?? self.nativeFormat,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        if colorProperties {
            outputSettings[AVVideoColorPropertiesKey] = [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
            ]
        }
        let output = AVAssetReaderTrackOutput(track: compositionTrack, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = copies
        guard reader.canAdd(output) else {
            measurement.errors = 1
            return measurement
        }
        reader.add(output)
        guard reader.startReading() else {
            measurement.errors = 1
            return measurement
        }
        while let sampleBuffer = output.copyNextSampleBuffer() {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                continue
            }
            let index = self.frameIndex(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            if let seen, !seen.mark(index) {
                continue
            }
            measurement.frames += 1
            self.sink?(index, pixelBuffer)
        }
        if reader.status != .completed {
            measurement.errors += 1
        }
        return measurement
    }

    func compressedSamples() -> [CMSampleBuffer] {
        guard let reader = try? AVAssetReader(asset: self.asset) else {
            return []
        }
        let output = AVAssetReaderTrackOutput(track: self.track, outputSettings: nil)
        output.alwaysCopiesSampleData = false
        reader.add(output)
        reader.startReading()
        var samples: [CMSampleBuffer] = []
        while let sampleBuffer = output.copyNextSampleBuffer() {
            if CMSampleBufferGetNumSamples(sampleBuffer) > 0 {
                samples.append(sampleBuffer)
            }
        }
        return samples
    }

    static func isSync(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[CFString: Any]], let first = attachments.first else {
            return true
        }
        return !((first[kCMSampleAttachmentKey_NotSync] as? Bool) ?? false)
    }

    func decodeSlices(samples: [CMSampleBuffer], count: Int) -> [ArraySlice<CMSampleBuffer>] {
        let syncIndices = samples.indices.filter { MediaEditorDecodeProbe.isSync(samples[$0]) }
        var bounds: [Int] = [0]
        for i in 1 ..< count {
            let target = samples.count * i / count
            if let nearest = syncIndices.min(by: { abs($0 - target) < abs($1 - target) }), nearest > bounds.last! {
                bounds.append(nearest)
            }
        }
        bounds.append(samples.count)
        return (0 ..< bounds.count - 1).map { samples[bounds[$0] ..< bounds[$0 + 1]] }
    }

    func syncDescription() -> String {
        let samples = self.compressedSamples()
        let syncIndices = samples.indices.filter { MediaEditorDecodeProbe.isSync(samples[$0]) }
        var nalTypes = Set<Int>()
        var leadingAfterSync = 0
        for index in syncIndices {
            if let attachments = CMSampleBufferGetSampleAttachmentsArray(samples[index], createIfNecessary: false) as? [[CFString: Any]], let first = attachments.first, let type = first[kCMSampleAttachmentKey_HEVCSyncSampleNALUnitType] as? Int {
                nalTypes.insert(type)
            }
            let syncPts = CMSampleBufferGetPresentationTimeStamp(samples[index])
            var next = index + 1
            while next < samples.count, CMSampleBufferGetPresentationTimeStamp(samples[next]) < syncPts {
                leadingAfterSync += 1
                next += 1
            }
        }
        var maxDepth = 0
        for (index, sample) in samples.enumerated() {
            let pts = self.frameIndex(CMSampleBufferGetPresentationTimeStamp(sample))
            maxDepth = max(maxDepth, abs(pts - index))
        }
        return "samples=\(samples.count) sync=\(syncIndices.count) firstSyncs=\(syncIndices.prefix(4).map { self.frameIndex(CMSampleBufferGetPresentationTimeStamp(samples[$0])) }) syncNalTypes=\(nalTypes.sorted()) leadingPicturesAfterSync=\(leadingAfterSync) maxReorder=\(maxDepth)"
    }

    final class ToolboxState {
        let lock = NSLock()
        var pending: [Int: CVPixelBuffer] = [:]
        var next: Int
        var frames = 0
        var errors = 0
        var maxPending = 0
        var expected: [Int]
        var expectedPosition = 0

        init(expected: [Int]) {
            self.expected = expected.sorted()
            self.next = self.expected.first ?? 0
        }
    }

    func toolboxDecode(samples: ArraySlice<CMSampleBuffer>?, inFlight: Int, realTime: Bool?, temporal: Bool, pixelFormat: OSType?, transferTo709: Bool, seen: SeenFrames? = nil) -> Measurement {
        var measurement = Measurement()
        var reader: AVAssetReader?
        var output: AVAssetReaderTrackOutput?
        var expected: [Int] = []
        if let samples {
            expected = samples.map { self.frameIndex(CMSampleBufferGetPresentationTimeStamp($0)) }
        } else {
            reader = try? AVAssetReader(asset: self.asset)
            let trackOutput = AVAssetReaderTrackOutput(track: self.track, outputSettings: nil)
            trackOutput.alwaysCopiesSampleData = false
            reader?.add(trackOutput)
            reader?.startReading()
            output = trackOutput
            expected = self.presentationIndices
        }
        guard let firstDescription = self.track.formatDescriptions.first else {
            measurement.errors = 1
            return measurement
        }
        let formatDescription = firstDescription as! CMFormatDescription
        var destination: [String: Any] = [
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()
        ]
        if let pixelFormat {
            destination[kCVPixelBufferPixelFormatTypeKey as String] = pixelFormat
        }
        let specification: [String: Any] = [
            kVTVideoDecoderSpecification_RequireHardwareAcceleratedVideoDecoder as String: true
        ]
        var sessionValue: VTDecompressionSession?
        let status = VTDecompressionSessionCreate(allocator: nil, formatDescription: formatDescription, decoderSpecification: specification as CFDictionary, imageBufferAttributes: destination as CFDictionary, outputCallback: nil, decompressionSessionOut: &sessionValue)
        guard status == noErr, let session = sessionValue else {
            measurement.errors = 1
            return measurement
        }
        if let realTime {
            VTSessionSetProperty(session, key: kVTDecompressionPropertyKey_RealTime, value: realTime ? kCFBooleanTrue : kCFBooleanFalse)
        }
        var transferSession: VTPixelTransferSession?
        var transferPool: CVPixelBufferPool?
        if transferTo709 {
            VTPixelTransferSessionCreate(allocator: nil, pixelTransferSessionOut: &transferSession)
            if let transferSession {
                VTSessionSetProperty(transferSession, key: kVTPixelTransferPropertyKey_DestinationColorPrimaries, value: kCVImageBufferColorPrimaries_ITU_R_709_2)
                VTSessionSetProperty(transferSession, key: kVTPixelTransferPropertyKey_DestinationTransferFunction, value: kCVImageBufferTransferFunction_ITU_R_709_2)
                VTSessionSetProperty(transferSession, key: kVTPixelTransferPropertyKey_DestinationYCbCrMatrix, value: kCVImageBufferYCbCrMatrix_ITU_R_709_2)
            }
            let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
            let poolAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                kCVPixelBufferWidthKey as String: Int(dimensions.width),
                kCVPixelBufferHeightKey as String: Int(dimensions.height),
                kCVPixelBufferMetalCompatibilityKey as String: true,
                kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()
            ]
            CVPixelBufferPoolCreate(nil, nil, poolAttributes as CFDictionary, &transferPool)
        }

        let state = ToolboxState(expected: expected)
        let semaphore = DispatchSemaphore(value: inFlight)
        let sink = self.sink
        let deliver: (Int, CVPixelBuffer) -> Void = { index, pixelBuffer in
            var buffer = pixelBuffer
            if let transferSession, let transferPool {
                var destinationBuffer: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(nil, transferPool, &destinationBuffer)
                if let destinationBuffer, VTPixelTransferSessionTransferImage(transferSession, from: pixelBuffer, to: destinationBuffer) == noErr {
                    buffer = destinationBuffer
                }
            }
            if let seen, !seen.mark(index) {
                return
            }
            state.frames += 1
            sink?(index, buffer)
        }
        var flags: VTDecodeFrameFlags = [._EnableAsynchronousDecompression]
        if temporal {
            flags.insert(._EnableTemporalProcessing)
        }
        let handler: VTDecompressionOutputHandler = { status, _, imageBuffer, presentationTime, _ in
            state.lock.lock()
            if status != noErr || imageBuffer == nil {
                state.errors += 1
                if let position = state.expected.firstIndex(of: self.frameIndex(presentationTime)) {
                    state.expected.remove(at: position)
                }
            } else if let imageBuffer {
                state.pending[self.frameIndex(presentationTime)] = imageBuffer
            }
            state.maxPending = max(state.maxPending, state.pending.count)
            while state.expectedPosition < state.expected.count, let buffer = state.pending.removeValue(forKey: state.expected[state.expectedPosition]) {
                let index = state.expected[state.expectedPosition]
                state.expectedPosition += 1
                deliver(index, buffer)
            }
            state.lock.unlock()
            semaphore.signal()
        }
        var iterator = samples?.makeIterator()
        while true {
            let sample: CMSampleBuffer?
            if iterator != nil {
                sample = iterator!.next()
            } else {
                sample = output?.copyNextSampleBuffer()
            }
            guard let sampleBuffer = sample else {
                break
            }
            if CMSampleBufferGetNumSamples(sampleBuffer) == 0 {
                continue
            }
            semaphore.wait()
            let decodeStatus = VTDecompressionSessionDecodeFrame(session, sampleBuffer: sampleBuffer, flags: flags, infoFlagsOut: nil, outputHandler: handler)
            if decodeStatus != noErr {
                state.lock.lock()
                state.errors += 1
                state.lock.unlock()
                semaphore.signal()
            }
        }
        VTDecompressionSessionFinishDelayedFrames(session)
        VTDecompressionSessionWaitForAsynchronousFrames(session)
        VTDecompressionSessionInvalidate(session)
        if let transferSession {
            VTPixelTransferSessionInvalidate(transferSession)
        }
        state.lock.lock()
        measurement.frames = state.frames
        measurement.errors = state.errors + (state.expected.count - state.expectedPosition)
        measurement.maxPending = state.maxPending
        state.lock.unlock()
        _ = reader
        return measurement
    }
}

struct MediaEditorDecodeProbeFrameDigest {
    var hashes: [UInt64]
    var reference: [UInt8]?
}

func mediaEditorPixelBufferDigest(_ pixelBuffer: CVPixelBuffer, keepBytes: Bool) -> (UInt64, [UInt8]?) {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    }
    let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
    let bytesPerElement: [Int]
    switch format {
    case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr10BiPlanarFullRange:
        bytesPerElement = [2, 4]
    default:
        bytesPerElement = [1, 2]
    }
    var hash: UInt64 = 0xcbf29ce484222325
    var kept: [UInt8]? = keepBytes ? [] : nil
    for plane in 0 ..< CVPixelBufferGetPlaneCount(pixelBuffer) {
        guard let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, plane) else {
            continue
        }
        let rowBytes = CVPixelBufferGetWidthOfPlane(pixelBuffer, plane) * bytesPerElement[min(plane, 1)]
        let stride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, plane)
        for row in 0 ..< CVPixelBufferGetHeightOfPlane(pixelBuffer, plane) {
            let rowPointer = base.advanced(by: row * stride)
            let words = rowBytes / 8
            let wordPointer = rowPointer.assumingMemoryBound(to: UInt64.self)
            for i in 0 ..< words {
                hash = (hash ^ wordPointer[i]) &* 0x100000001b3
            }
            let bytePointer = rowPointer.assumingMemoryBound(to: UInt8.self)
            for i in (words * 8) ..< rowBytes {
                hash = (hash ^ UInt64(bytePointer[i])) &* 0x100000001b3
            }
            if keepBytes {
                kept!.append(contentsOf: UnsafeBufferPointer(start: bytePointer, count: rowBytes))
            }
        }
    }
    return (hash, kept)
}

@available(iOS 17.0, *)
enum MediaEditorDecodeProbeRunner {
    static func cpuSeconds() -> Double {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        return Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1e6 + Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1e6
    }

    static func footprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : 0
    }

    static func waitForRest(minimum: Double, maximum: Double, log: (String) -> Void) {
        let start = CACurrentMediaTime()
        Thread.sleep(forTimeInterval: minimum)
        while ProcessInfo.processInfo.thermalState != .nominal && CACurrentMediaTime() - start < maximum {
            Thread.sleep(forTimeInterval: 5.0)
        }
    }

    static func run(arguments: [String], outputDirectory: URL, log: @escaping (String) -> Void) -> [String] {
        func value(_ name: String) -> String? {
            return arguments.firstIndex(of: name).flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }
        }
        let rounds = value("--rounds").flatMap(Int.init) ?? 1
        let rest = value("--rest").flatMap(Double.init) ?? 15.0
        let reverse = arguments.contains("--reverse")
        let parity = arguments.contains("--parity")
        let names = value("--variants").map { Set($0.split(separator: ",").map(String.init)) }
        let sourceNames = value("--sources")?.split(separator: ",").map(String.init) ?? ["sdr", "hlg"]
        var failures: [String] = []
        var sources: [(String, URL)] = []
        for name in sourceNames {
            let variant: MediaEditorRealisticSource.Variant = name == "hlg" ? .hlg : .sdr
            guard let url = MediaEditorRealisticSource.url(variant, log: log) else {
                failures.append("decode-probe: no \(name) source")
                continue
            }
            sources.append((name, url))
        }
        if parity {
            failures.append(contentsOf: self.runParity(sources: sources, outputDirectory: outputDirectory, log: log))
            return failures
        }
        var variants = MediaEditorDecodeProbe.variants.filter { names?.contains($0.name) ?? true }
        if reverse {
            variants.reverse()
        }
        let csvURL = outputDirectory.appendingPathComponent("decode-probe.csv")
        var csv = "round,source,variant,seconds,frames,unique,errors,fps,cpu,thermalBefore,thermalAfter,peakMB,maxPending,segments\n"
        for (name, url) in sources {
            if let probe = MediaEditorDecodeProbe(url: url) {
                log("decode-probe \(name) \(probe.syncDescription())")
            }
        }
        for round in 0 ..< rounds {
            for variant in variants {
                for (name, url) in sources {
                    guard let probe = MediaEditorDecodeProbe(url: url) else {
                        failures.append("decode-probe: cannot open \(name)")
                        continue
                    }
                    self.waitForRest(minimum: rest, maximum: 120.0, log: log)
                    let thermalBefore = ProcessInfo.processInfo.thermalState.rawValue
                    let peak = PeakFootprint()
                    peak.start()
                    let cpuStart = self.cpuSeconds()
                    let measurement = probe.run(variant)
                    let cpu = self.cpuSeconds() - cpuStart
                    let peakMB = Double(peak.stop()) / 1_000_000.0
                    let thermalAfter = ProcessInfo.processInfo.thermalState.rawValue
                    let fps = Double(measurement.frames) / measurement.seconds
                    let segments = measurement.segmentSeconds.map { String(format: "%.2f", $0) }.joined(separator: "/")
                    let line = "\(round),\(name),\(variant.name),\(String(format: "%.3f", measurement.seconds)),\(measurement.frames),\(measurement.uniqueFrames),\(measurement.errors),\(String(format: "%.1f", fps)),\(String(format: "%.2f", cpu)),\(thermalBefore),\(thermalAfter),\(String(format: "%.0f", peakMB)),\(measurement.maxPending),\(segments)"
                    log("decode-probe " + line)
                    csv += line + "\n"
                    try? csv.write(to: csvURL, atomically: true, encoding: .utf8)
                    if measurement.uniqueFrames != MediaEditorRealisticSource.frameCount || measurement.errors != 0 {
                        failures.append("decode-probe \(name) \(variant.name): \(measurement.uniqueFrames) frames, \(measurement.errors) errors")
                    }
                }
            }
        }
        return failures
    }

    static func runParity(sources: [(String, URL)], outputDirectory: URL, log: @escaping (String) -> Void) -> [String] {
        var failures: [String] = []
        let keptIndex = 1350
        var lines: [String] = []
        for (name, url) in sources {
            var referenceHashes: [UInt64]?
            var referenceBytes: [UInt8]?
            for variantName in MediaEditorDecodeProbe.parityVariants {
                guard let variant = MediaEditorDecodeProbe.variants.first(where: { $0.name == variantName }), let probe = MediaEditorDecodeProbe(url: url) else {
                    continue
                }
                let lock = NSLock()
                var hashes = [UInt64](repeating: 0, count: MediaEditorRealisticSource.frameCount)
                var kept: [UInt8]?
                var format: OSType = 0
                probe.sink = { index, pixelBuffer in
                    let digest = mediaEditorPixelBufferDigest(pixelBuffer, keepBytes: index == keptIndex)
                    lock.lock()
                    if index < hashes.count {
                        hashes[index] = digest.0
                    }
                    if let bytes = digest.1 {
                        kept = bytes
                        format = CVPixelBufferGetPixelFormatType(pixelBuffer)
                    }
                    lock.unlock()
                }
                let measurement = probe.run(variant)
                var line = "parity \(name) \(variantName) frames=\(measurement.uniqueFrames) format=\(String(format: "%08x", format))"
                if let referenceHashes, let referenceBytes, let kept {
                    let mismatched = zip(referenceHashes, hashes).filter { $0 != $1 }.count
                    var maxDiff = 0
                    var differing = 0
                    if kept.count == referenceBytes.count {
                        for i in 0 ..< kept.count {
                            let d = abs(Int(kept[i]) - Int(referenceBytes[i]))
                            if d != 0 {
                                differing += 1
                                maxDiff = max(maxDiff, d)
                            }
                        }
                    } else {
                        differing = -1
                    }
                    line += " mismatchedFrames=\(mismatched) frame\(keptIndex): differingBytes=\(differing) of \(kept.count) maxDiff=\(maxDiff)"
                } else {
                    referenceHashes = hashes
                    referenceBytes = kept
                    line += " reference"
                }
                if measurement.uniqueFrames != MediaEditorRealisticSource.frameCount {
                    failures.append("parity \(name) \(variantName): \(measurement.uniqueFrames) frames")
                }
                log(line)
                lines.append(line)
            }
        }
        try? (lines.joined(separator: "\n") + "\n").write(to: outputDirectory.appendingPathComponent("decode-parity.txt"), atomically: true, encoding: .utf8)
        return failures
    }

    final class PeakFootprint {
        private let lock = NSLock()
        private var running = false
        private var peak: UInt64 = 0
        private let finished = DispatchSemaphore(value: 0)

        func start() {
            self.running = true
            self.peak = MediaEditorDecodeProbeRunner.footprint()
            let thread = Thread {
                while true {
                    self.lock.lock()
                    let running = self.running
                    self.peak = max(self.peak, MediaEditorDecodeProbeRunner.footprint())
                    self.lock.unlock()
                    if !running {
                        break
                    }
                    Thread.sleep(forTimeInterval: 0.05)
                }
                self.finished.signal()
            }
            thread.start()
        }

        func stop() -> UInt64 {
            self.lock.lock()
            self.running = false
            self.lock.unlock()
            self.finished.wait()
            return self.peak
        }
    }
}
