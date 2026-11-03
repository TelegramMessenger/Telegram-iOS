import COpus
import COpusHelpers
import Foundation

public enum OpusEncoderError: Swift.Error, Equatable {
    case createFailed(Int32)
    case wrongFrameSize(Int)
    case encodeFailed(Int32)
}

/// Encodes 48 kHz mono Float32 PCM to Opus packets — one packet per 20 ms frame
/// (960 samples). Configured for Telegram's voice-note profile: VOIP application,
/// 16 kbps VBR, complexity 8, voice signal bias.
///
/// Not thread-safe: holds a stateful encoder handle + a reused packet buffer, so
/// `encode(_:)` must be called serially (the recording sink confines it to one queue).
public final class OpusEncoder {
    public static let sampleRate: Int32 = 48_000
    public static let frameSize = 960            // 20 ms @ 48 kHz
    private static let maxPacketBytes = 4_000

    private let enc: OpaquePointer
    private var packetBuf = [UInt8](repeating: 0, count: maxPacketBytes)

    public init(bitrate: Int32 = 16_000, complexity: Int32 = 8) throws {
        var err: Int32 = 0
        guard let e = opus_encoder_create(Self.sampleRate, 1, OPUS_APPLICATION_VOIP, &err),
              err == OPUS_OK else {
            throw OpusEncoderError.createFailed(err)
        }
        enc = e
        _ = copus_set_bitrate(enc, bitrate)
        _ = copus_set_vbr(enc, 1)
        _ = copus_set_complexity(enc, complexity)
        _ = copus_set_signal(enc, OPUS_SIGNAL_VOICE)
    }

    deinit { opus_encoder_destroy(enc) }

    /// Encodes exactly `frameSize` (960) Float32 samples. Returns the encoded packet.
    public func encode(_ frame: [Float]) throws -> Data {
        guard frame.count == Self.frameSize else {
            throw OpusEncoderError.wrongFrameSize(frame.count)
        }
        let n = frame.withUnsafeBufferPointer { src in
            packetBuf.withUnsafeMutableBufferPointer { dst in
                opus_encode_float(enc, src.baseAddress!, Int32(Self.frameSize),
                                  dst.baseAddress!, Int32(Self.maxPacketBytes))
            }
        }
        if n < 0 { throw OpusEncoderError.encodeFailed(n) }
        return Data(packetBuf[0..<Int(n)])
    }
}
