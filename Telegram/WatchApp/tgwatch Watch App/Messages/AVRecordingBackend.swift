import AVFoundation
import Foundation
import OpusKit

/// Serial-queue bridge from AVAudioEngine tap buffers to an on-disk Ogg/Opus
/// file. Resamples each tap buffer to 48 kHz mono Float32 (on the audio thread),
/// then frames into 20 ms Opus frames, encodes, and muxes (on `queue`). Also
/// accumulates per-frame RMS for the outgoing waveform.
///
/// Thread model: `AVAudioConverter` is used ONLY on the audio render thread
/// (inside `append`, serialized by AVAudioEngine). The encoder, writer, `carry`,
/// `rms`, and `totalSamples` are touched ONLY on `queue`. The cross-thread handoff
/// is the `[Float]` mono array dispatched from the audio thread to `queue`.
final class OpusOggRecordingSink {
    private let queue = DispatchQueue(label: "org.telegram.TelegramWatch.opusEncode")
    private let encoder: OpusEncoder
    private let writer: OggOpusWriter
    private let converter: AVAudioConverter
    private let outFormat: AVAudioFormat
    private var carry: [Float] = []
    private var rms: [Float] = []
    private var totalSamples = 0

    init(outputURL: URL, inputFormat: AVAudioFormat) throws {
        encoder = try OpusEncoder()
        writer = try OggOpusWriter(url: outputURL)
        guard let out = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000,
                                      channels: 1, interleaved: false),
              let conv = AVAudioConverter(from: inputFormat, to: out) else {
            throw NSError(domain: "OpusOggRecordingSink", code: 1)
        }
        outFormat = out
        converter = conv
    }

    /// Audio-thread entry point. Returns the visual RMS level [0, 1] for this buffer.
    @discardableResult
    func append(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let mono = resample(buffer) else { return 0 }
        let level = visualLevel(mono)
        queue.async { [weak self] in self?.encodeFrames(mono) }
        return level
    }

    /// Flushes the trailing partial frame + closes the file. Returns (duration, packed waveform).
    /// `totalSamples`/`rms` are read inside the `queue.sync` block to keep all queue-confined
    /// state confined, rather than relying on the post-sync happens-after relationship.
    func finalize() -> (duration: Int, waveform: Data) {
        return queue.sync {
            if !carry.isEmpty {
                var frame = carry
                frame.append(contentsOf: Array(repeating: 0, count: OpusEncoder.frameSize - frame.count))
                if let packet = try? encoder.encode(frame) {
                    writer.writePacket(packet, samples: OpusEncoder.frameSize)
                    appendRMS(frame)
                    totalSamples += OpusEncoder.frameSize
                }
                carry.removeAll()
            }
            writer.finish()
            let duration = Int((Double(totalSamples) / 48_000.0).rounded())
            return (max(1, duration), WaveformPacker.pack(rms))
        }
    }

    func cancel() { queue.sync { writer.finish() } }

    // MARK: - audio thread

    private func resample(_ inBuf: AVAudioPCMBuffer) -> [Float]? {
        let ratio = outFormat.sampleRate / inBuf.format.sampleRate
        let cap = AVAudioFrameCount(Double(inBuf.frameLength) * ratio) + 256
        guard cap > 0, let outBuf = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: cap) else {
            return nil
        }
        var consumed = false
        var convErr: NSError?
        converter.convert(to: outBuf, error: &convErr) { _, status in
            if consumed { status.pointee = .noDataNow; return nil }
            consumed = true
            status.pointee = .haveData
            return inBuf
        }
        if convErr != nil { return nil }
        guard let ch = outBuf.floatChannelData, outBuf.frameLength > 0 else { return nil }
        return Array(UnsafeBufferPointer(start: ch[0], count: Int(outBuf.frameLength)))
    }

    private func visualLevel(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for s in samples { sum += s * s }
        let r = (sum / Float(samples.count)).squareRoot()
        return min(1, r * 4)   // visual gain so normal speech fills the meter
    }

    // MARK: - queue

    private func encodeFrames(_ mono: [Float]) {
        carry.append(contentsOf: mono)
        while carry.count >= OpusEncoder.frameSize {
            let frame = Array(carry[0..<OpusEncoder.frameSize])
            carry.removeFirst(OpusEncoder.frameSize)
            guard let packet = try? encoder.encode(frame) else { continue }
            writer.writePacket(packet, samples: OpusEncoder.frameSize)
            appendRMS(frame)
            totalSamples += OpusEncoder.frameSize
        }
    }

    private func appendRMS(_ frame: [Float]) {
        var sum: Float = 0
        for s in frame { sum += s * s }
        rms.append((sum / Float(frame.count)).squareRoot())
    }
}

/// Production `RecordingBackend`: AVAudioEngine mic capture → OpusOggRecordingSink.
@MainActor
final class AVRecordingBackend: RecordingBackend {
    private let engine = AVAudioEngine()
    private var sink: OpusOggRecordingSink?
    private var outputURL: URL?

    func ensurePermission() async -> RecordPermission {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:       return .granted
        case .denied:        return .denied
        case .undetermined:
            return await withCheckedContinuation { cont in
                AVAudioApplication.requestRecordPermission { granted in
                    cont.resume(returning: granted ? .granted : .denied)
                }
            }
        @unknown default:    return .denied
        }
    }

    func begin(onLevel: @escaping @MainActor (Float) -> Void) throws {
        let session = AVAudioSession.sharedInstance()
        // Use .voiceChat mode (available watchOS 2+) and .duckOthers.
        // .allowBluetooth is deprecated on watchOS 11+; use .allowBluetoothHFP instead
        // (available watchOS 11+, target is watchOS 26). Drop if not needed at runtime.
        try session.setCategory(.playAndRecord, mode: .voiceChat,
                                options: [.duckOthers, .allowBluetoothHFP])
        try session.setActive(true)

        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-\(UUID().uuidString).ogg")
        outputURL = url
        let sink = try OpusOggRecordingSink(outputURL: url, inputFormat: inFormat)
        self.sink = sink

        input.installTap(onBus: 0, bufferSize: 1024, format: inFormat) { buffer, _ in
            let level = sink.append(buffer)
            // AVAudioEngine fires this on the audio render thread — hop to main actor.
            Task { @MainActor in onLevel(level) }
        }
        engine.prepare()
        try engine.start()
    }

    func finish() async throws -> VoiceRecordingDraft {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
        guard let sink, let url = outputURL else {
            throw NSError(domain: "AVRecordingBackend", code: 1)
        }
        let (duration, waveform) = sink.finalize()
        self.sink = nil
        return VoiceRecordingDraft(fileURL: url, duration: duration, waveform: waveform)
    }

    func abort() {
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        try? AVAudioSession.sharedInstance().setActive(false)
        sink?.cancel()
        if let url = outputURL { try? FileManager.default.removeItem(at: url) }
        sink = nil
        outputURL = nil
    }
}
