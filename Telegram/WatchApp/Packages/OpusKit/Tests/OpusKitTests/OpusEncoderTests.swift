import XCTest
import AVFoundation
@testable import OpusKit

final class OpusEncoderTests: XCTestCase {

    /// Generates `seconds` of a mono 48 kHz sine at `freq` Hz, amplitude 0.5.
    private func sine(seconds: Double, freq: Double = 440, rate: Double = 48000) -> [Float] {
        let n = Int(seconds * rate)
        return (0..<n).map { Float(0.5 * sin(2 * .pi * freq * Double($0) / rate)) }
    }

    func testRejectsWrongFrameSize() throws {
        let enc = try OpusEncoder()
        XCTAssertThrowsError(try enc.encode([Float](repeating: 0, count: 480))) { err in
            XCTAssertEqual(err as? OpusEncoderError, .wrongFrameSize(480))
        }
    }

    func testEncodeProducesNonEmptyPacket() throws {
        let enc = try OpusEncoder()
        let frame = Array(sine(seconds: 0.02).prefix(OpusEncoder.frameSize)) // exactly 960
        let packet = try enc.encode(frame)
        XCTAssertGreaterThan(packet.count, 0)
    }

    func testRoundtripPreservesDuration() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).ogg")
        defer { try? FileManager.default.removeItem(at: url) }

        let enc = try OpusEncoder()
        let writer = try OggOpusWriter(url: url)
        let pcm = sine(seconds: 2.0)
        var i = 0
        while i + OpusEncoder.frameSize <= pcm.count {
            let frame = Array(pcm[i..<i + OpusEncoder.frameSize])
            writer.writePacket(try enc.encode(frame), samples: OpusEncoder.frameSize)
            i += OpusEncoder.frameSize
        }
        writer.finish()

        let decoded = try OpusDecoder.decodePCM(url: url)
        let seconds = Double(decoded.pcm.frameLength) / decoded.pcm.format.sampleRate
        XCTAssertEqual(seconds, 2.0, accuracy: 0.06)
    }

    // Signal-fidelity proxy: encode a sine, decode, assert the result is non-silent.
    // (A spectral-peak assertion would need an FFT dependency; RMS energy is a
    // sufficient guard against the encoder/muxer producing garbage or silence.)
    func testRoundtripPreservesEnergy() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).ogg")
        defer { try? FileManager.default.removeItem(at: url) }

        let enc = try OpusEncoder()
        let writer = try OggOpusWriter(url: url)
        let pcm = sine(seconds: 1.0)
        var i = 0
        while i + OpusEncoder.frameSize <= pcm.count {
            writer.writePacket(try enc.encode(Array(pcm[i..<i + OpusEncoder.frameSize])),
                               samples: OpusEncoder.frameSize)
            i += OpusEncoder.frameSize
        }
        writer.finish()

        let decoded = try OpusDecoder.decodePCM(url: url)
        let ch = decoded.pcm.floatChannelData![0]
        let n = Int(decoded.pcm.frameLength)
        var sum: Float = 0
        for k in 0..<n { sum += ch[k] * ch[k] }
        let rms = (sum / Float(max(1, n))).squareRoot()
        XCTAssertGreaterThan(rms, 0.05)   // sine at amp 0.5 → RMS ~0.35; well above floor
    }
}
