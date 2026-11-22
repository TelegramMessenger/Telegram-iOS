import Foundation
import AVFoundation
import CoreMedia
import CoreVideo
import Metal
import VideoToolbox

enum MediaEditorRealisticSource {
    enum Variant: String {
        case sdr = "camera-4k60-hevc-sdr"
        case hlg = "camera-4k60-hevc-hlg"
    }

    static let codedWidth = 3840
    static let codedHeight = 2160
    static let frameRate: Int32 = 60
    static let duration: Double = 45.0
    static let videoBitrate = 50_000_000
    static let audioSampleRate: Int32 = 48000
    static let audioBitrate = 160_000
    static let version = 1

    static var frameCount: Int {
        return Int(self.duration * Double(self.frameRate))
    }

    static var directory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let url = caches.appendingPathComponent("MediaEditorRealisticSources")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static let lock = NSLock()

    static func url(_ variant: Variant, log: (String) -> Void = { print($0) }) -> URL? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        let url = self.directory.appendingPathComponent("\(variant.rawValue)-v\(self.version).mov")
        if FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        let temporaryURL = self.directory.appendingPathComponent("\(variant.rawValue)-incomplete.mov")
        try? FileManager.default.removeItem(at: temporaryURL)
        log("generating realistic source \(url.lastPathComponent)")
        let startTime = CACurrentMediaTime()
        if let error = self.generate(variant, to: temporaryURL) {
            log("cannot generate \(url.lastPathComponent): \(error)")
            try? FileManager.default.removeItem(at: temporaryURL)
            return nil
        }
        do {
            try FileManager.default.moveItem(at: temporaryURL, to: url)
        } catch {
            log("cannot store \(url.lastPathComponent): \(error)")
            return nil
        }
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        log("generated \(url.lastPathComponent) in \(String(format: "%.1f", CACurrentMediaTime() - startTime)) s, \(size / 1_000_000) MB, \(String(format: "%.1f", Double(size) * 8.0 / self.duration / 1_000_000.0)) Mbps")
        return url
    }

    private struct ColorTags {
        let primaries: String
        let transfer: String
        let matrix: String
        let bufferPrimaries: CFString
        let bufferTransfer: CFString
        let bufferMatrix: CFString
    }

    private static func colorTags(_ variant: Variant) -> ColorTags {
        switch variant {
        case .sdr:
            return ColorTags(primaries: AVVideoColorPrimaries_ITU_R_709_2, transfer: AVVideoTransferFunction_ITU_R_709_2, matrix: AVVideoYCbCrMatrix_ITU_R_709_2, bufferPrimaries: kCVImageBufferColorPrimaries_ITU_R_709_2, bufferTransfer: kCVImageBufferTransferFunction_ITU_R_709_2, bufferMatrix: kCVImageBufferYCbCrMatrix_ITU_R_709_2)
        case .hlg:
            return ColorTags(primaries: AVVideoColorPrimaries_ITU_R_2020, transfer: AVVideoTransferFunction_ITU_R_2100_HLG, matrix: AVVideoYCbCrMatrix_ITU_R_2020, bufferPrimaries: kCVImageBufferColorPrimaries_ITU_R_2020, bufferTransfer: kCVImageBufferTransferFunction_ITU_R_2100_HLG, bufferMatrix: kCVImageBufferYCbCrMatrix_ITU_R_2020)
        }
    }

    private static func generate(_ variant: Variant, to url: URL) -> String? {
        guard let device = MTLCreateSystemDefaultDevice(), let commandQueue = device.makeCommandQueue() else {
            return "no Metal device"
        }
        let pipeline: MTLComputePipelineState
        do {
            let library = try device.makeLibrary(source: self.kernelSource, options: nil)
            guard let function = library.makeFunction(name: "realisticSourceFrame") else {
                return "no kernel function"
            }
            pipeline = try device.makeComputePipelineState(function: function)
        } catch {
            return "kernel: \(error)"
        }
        var textureCacheValue: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCacheValue)
        guard let textureCache = textureCacheValue else {
            return "no texture cache"
        }
        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        } catch {
            return "writer: \(error)"
        }

        let tags = self.colorTags(variant)
        let compression: [String: Any] = [
            AVVideoAverageBitRateKey: self.videoBitrate,
            AVVideoExpectedSourceFrameRateKey: Int(self.frameRate),
            AVVideoMaxKeyFrameIntervalKey: Int(self.frameRate),
            AVVideoAllowFrameReorderingKey: true,
            AVVideoProfileLevelKey: variant == .hlg ? (kVTProfileLevel_HEVC_Main10_AutoLevel as String) : (kVTProfileLevel_HEVC_Main_AutoLevel as String)
        ]
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: self.codedWidth,
            AVVideoHeightKey: self.codedHeight,
            AVVideoCompressionPropertiesKey: compression,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: tags.primaries,
                AVVideoTransferFunctionKey: tags.transfer,
                AVVideoYCbCrMatrixKey: tags.matrix
            ]
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false
        videoInput.transform = CGAffineTransform(a: 0.0, b: 1.0, c: -1.0, d: 0.0, tx: 0.0, ty: 0.0)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: self.codedWidth,
            kCVPixelBufferHeightKey as String: self.codedHeight,
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
            kCVPixelBufferMetalCompatibilityKey as String: true
        ])
        guard writer.canAdd(videoInput) else {
            return "cannot add the video input"
        }
        writer.add(videoInput)

        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: Double(self.audioSampleRate),
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: self.audioBitrate
        ])
        audioInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(audioInput) else {
            return "cannot add the audio input"
        }
        writer.add(audioInput)

        guard writer.startWriting() else {
            return "startWriting: \(String(describing: writer.error))"
        }
        writer.startSession(atSourceTime: .zero)

        let group = DispatchGroup()
        let failure = NSLock()
        var failureMessage: String?
        let setFailure: (String) -> Void = { message in
            failure.lock()
            if failureMessage == nil {
                failureMessage = message
            }
            failure.unlock()
        }

        group.enter()
        var frameIndex = 0
        var videoFinished = false
        let frameCount = self.frameCount
        let videoQueue = DispatchQueue(label: "MediaEditorRealisticSource.video")
        videoInput.requestMediaDataWhenReady(on: videoQueue) {
            guard !videoFinished else {
                return
            }
            while videoInput.isReadyForMoreMediaData {
                var appended = false
                if frameIndex < frameCount, let pool = adaptor.pixelBufferPool {
                    var pixelBufferValue: CVPixelBuffer?
                    CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBufferValue)
                    if let pixelBuffer = pixelBufferValue, self.render(frame: frameIndex, into: pixelBuffer, tags: tags, pipeline: pipeline, commandQueue: commandQueue, textureCache: textureCache) {
                        appended = adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: Int64(frameIndex), timescale: self.frameRate))
                        if !appended {
                            setFailure("video append: \(String(describing: writer.error))")
                        }
                    } else {
                        setFailure("cannot render frame \(frameIndex)")
                    }
                }
                if !appended {
                    videoFinished = true
                    videoInput.markAsFinished()
                    group.leave()
                    return
                }
                frameIndex += 1
            }
        }

        group.enter()
        var sampleIndex: Int64 = 0
        var audioFinished = false
        var noiseState: UInt32 = 0x12345678
        let totalSamples = Int64(self.duration * Double(self.audioSampleRate))
        let audioQueue = DispatchQueue(label: "MediaEditorRealisticSource.audio")
        audioInput.requestMediaDataWhenReady(on: audioQueue) {
            guard !audioFinished else {
                return
            }
            while audioInput.isReadyForMoreMediaData {
                var appended = false
                if sampleIndex < totalSamples {
                    let count = Int(min(1024, totalSamples - sampleIndex))
                    if let sampleBuffer = self.audioSampleBuffer(start: sampleIndex, count: count, noiseState: &noiseState) {
                        appended = audioInput.append(sampleBuffer)
                        if !appended {
                            setFailure("audio append: \(String(describing: writer.error))")
                        }
                    } else {
                        setFailure("cannot make an audio buffer")
                    }
                    sampleIndex += Int64(count)
                }
                if !appended {
                    audioFinished = true
                    audioInput.markAsFinished()
                    group.leave()
                    return
                }
            }
        }

        group.wait()
        let finished = DispatchSemaphore(value: 0)
        writer.finishWriting {
            finished.signal()
        }
        finished.wait()
        if let failureMessage {
            return failureMessage
        }
        if writer.status != .completed {
            return "finishWriting: \(String(describing: writer.error))"
        }
        return nil
    }

    private struct KernelParameters {
        var time: Float
        var frame: UInt32
        var width: UInt32
        var height: UInt32
    }

    private static func render(frame: Int, into pixelBuffer: CVPixelBuffer, tags: ColorTags, pipeline: MTLComputePipelineState, commandQueue: MTLCommandQueue, textureCache: CVMetalTextureCache) -> Bool {
        CVBufferSetAttachment(pixelBuffer, kCVImageBufferColorPrimariesKey, tags.bufferPrimaries, .shouldPropagate)
        CVBufferSetAttachment(pixelBuffer, kCVImageBufferTransferFunctionKey, tags.bufferTransfer, .shouldPropagate)
        CVBufferSetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, tags.bufferMatrix, .shouldPropagate)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        var textureValue: CVMetalTexture?
        let textureAttributes = [kCVMetalTextureUsage as String: MTLTextureUsage([.shaderRead, .shaderWrite]).rawValue] as CFDictionary
        CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, textureAttributes, .bgra8Unorm, width, height, 0, &textureValue)
        guard let cvTexture = textureValue, let texture = CVMetalTextureGetTexture(cvTexture), let commandBuffer = commandQueue.makeCommandBuffer(), let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return false
        }
        var parameters = KernelParameters(time: Float(Double(frame) / Double(self.frameRate)), frame: UInt32(frame), width: UInt32(width), height: UInt32(height))
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setBytes(&parameters, length: MemoryLayout<KernelParameters>.stride, index: 0)
        let threadgroup = MTLSize(width: 16, height: 16, depth: 1)
        encoder.dispatchThreadgroups(MTLSize(width: (width + 15) / 16, height: (height + 15) / 16, depth: 1), threadsPerThreadgroup: threadgroup)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        CVMetalTextureCacheFlush(textureCache, 0)
        return commandBuffer.status == .completed
    }

    private static func audioSampleBuffer(start: Int64, count: Int, noiseState: inout UInt32) -> CMSampleBuffer? {
        var description = AudioStreamBasicDescription(mSampleRate: Double(self.audioSampleRate), mFormatID: kAudioFormatLinearPCM, mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked, mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 2, mBitsPerChannel: 16, mReserved: 0)
        var formatDescription: CMAudioFormatDescription?
        guard CMAudioFormatDescriptionCreate(allocator: nil, asbd: &description, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &formatDescription) == noErr, let formatDescription else {
            return nil
        }
        var samples = [Int16](repeating: 0, count: count * 2)
        let rate = Double(self.audioSampleRate)
        for i in 0 ..< count {
            let t = Double(start + Int64(i)) / rate
            let envelope = 0.5 + 0.5 * sin(2.0 * .pi * 3.1 * t) * sin(2.0 * .pi * 0.37 * t)
            let tone = sin(2.0 * .pi * (180.0 + 40.0 * sin(2.0 * .pi * 0.5 * t)) * t) + 0.4 * sin(2.0 * .pi * 720.0 * t)
            noiseState = noiseState &* 1664525 &+ 1013904223
            let noise = Double(Int32(bitPattern: noiseState)) / Double(Int32.max)
            let left = 0.25 * envelope * tone + 0.06 * noise
            noiseState = noiseState &* 1664525 &+ 1013904223
            let right = 0.25 * envelope * tone * 0.8 + 0.06 * Double(Int32(bitPattern: noiseState)) / Double(Int32.max)
            samples[i * 2] = Int16(max(-1.0, min(1.0, left)) * 32767.0)
            samples[i * 2 + 1] = Int16(max(-1.0, min(1.0, right)) * 32767.0)
        }
        let byteCount = samples.count * MemoryLayout<Int16>.size
        var blockBuffer: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: byteCount, blockAllocator: nil, customBlockSource: nil, offsetToData: 0, dataLength: byteCount, flags: 0, blockBufferOut: &blockBuffer) == noErr, let blockBuffer else {
            return nil
        }
        let copied = samples.withUnsafeBytes { bytes in
            CMBlockBufferReplaceDataBytes(with: bytes.baseAddress!, blockBuffer: blockBuffer, offsetIntoDestination: 0, dataLength: byteCount)
        }
        guard copied == noErr else {
            return nil
        }
        var sampleBuffer: CMSampleBuffer?
        guard CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: blockBuffer, formatDescription: formatDescription, sampleCount: count, presentationTimeStamp: CMTime(value: start, timescale: self.audioSampleRate), packetDescriptions: nil, sampleBufferOut: &sampleBuffer) == noErr else {
            return nil
        }
        return sampleBuffer
    }

    private static let kernelSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct RealisticSourceParameters {
        float time;
        uint frame;
        uint width;
        uint height;
    };

    static float hash21(float2 p) {
        p = fract(p * float2(123.34, 456.21));
        p += dot(p, p + 45.32);
        return fract(p.x * p.y);
    }

    static float valueNoise(float2 p) {
        float2 i = floor(p);
        float2 f = fract(p);
        float2 u = f * f * (3.0 - 2.0 * f);
        float a = hash21(i);
        float b = hash21(i + float2(1.0, 0.0));
        float c = hash21(i + float2(0.0, 1.0));
        float d = hash21(i + float2(1.0, 1.0));
        return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
    }

    static float fbm(float2 p) {
        float value = 0.0;
        float amplitude = 0.5;
        for (int i = 0; i < 6; i++) {
            value += amplitude * valueNoise(p);
            p = p * 2.03 + float2(17.1, 9.2);
            amplitude *= 0.5;
        }
        return value;
    }

    static uint hashUInt(uint x) {
        x ^= x >> 16;
        x *= 0x7feb352du;
        x ^= x >> 15;
        x *= 0x846ca68bu;
        x ^= x >> 16;
        return x;
    }

    kernel void realisticSourceFrame(texture2d<float, access::write> output [[texture(0)]], constant RealisticSourceParameters &parameters [[buffer(0)]], uint2 gid [[thread_position_in_grid]]) {
        if (gid.x >= parameters.width || gid.y >= parameters.height) {
            return;
        }
        float t = parameters.time;
        float2 uv = float2(gid) / float(parameters.height);
        float zoom = 1.0 + 0.15 * sin(t * 0.21);
        float angle = 0.04 * sin(t * 0.17) + 0.003 * sin(t * 11.0);
        float2 center = float2(0.89, 0.5);
        float2 shake = float2(0.002 * sin(t * 13.0) + 0.0015 * sin(t * 7.3), 0.002 * cos(t * 9.1));
        float2 q = uv - center;
        float2 p = float2(q.x * cos(angle) - q.y * sin(angle), q.x * sin(angle) + q.y * cos(angle)) / zoom + center + float2(t * 0.05, 0.02 * sin(t * 0.5)) + shake;
        float base = fbm(p * 6.0);
        float detail = fbm(p * 90.0 + 3.0);
        float fine = valueNoise(p * 700.0);
        float horizon = 0.42 + 0.1 * fbm(float2(p.x * 3.0, 1.7));
        float3 sky = mix(float3(0.85, 0.9, 0.95), float3(0.42, 0.6, 0.86), saturate(1.0 - p.y * 1.4)) * (0.92 + 0.08 * fbm(p * 4.0 + float2(t * 0.02, 0.0)));
        float3 ground = mix(float3(0.16, 0.3, 0.1), float3(0.56, 0.46, 0.31), base) * (0.55 + 0.7 * detail) * (0.85 + 0.3 * fine);
        float foliage = smoothstep(0.47, 0.53, fbm(p * 24.0 + float2(0.0, t * 0.4)));
        ground = mix(ground, float3(0.08, 0.22, 0.06) * (0.6 + detail + 0.4 * fine), foliage * 0.75);
        float3 color = mix(ground, sky, smoothstep(horizon + 0.004, horizon - 0.004, p.y));
        for (int k = 0; k < 4; k++) {
            float fk = float(k);
            float2 objectCenter = float2(fract(0.23 * fk + t * 0.04 * (fk + 1.0)) * 1.9, 0.62 + 0.09 * fk + 0.02 * sin(t * (1.0 + fk)));
            float radius = 0.05 + 0.02 * fk;
            float distanceToObject = length(uv - objectCenter);
            float3 objectColor = float3(0.75 - 0.15 * fk, 0.2 + 0.18 * fk, 0.12 + 0.1 * fk) * (0.6 + 0.5 * detail);
            color = mix(color, objectColor, smoothstep(radius, radius - 0.003, distanceToObject));
        }
        uint h = hashUInt(gid.x + gid.y * parameters.width + parameters.frame * 0x9E3779B9u);
        float3 grain = (float3(float(h & 0x3ffu), float((h >> 10) & 0x3ffu), float((h >> 20) & 0x3ffu)) / 1023.0 - 0.5) * 0.045;
        color = saturate(color + grain + (float(h & 0xffu) / 255.0 - 0.5) * 0.03);
        output.write(float4(color, 1.0), gid);
    }
    """
}
