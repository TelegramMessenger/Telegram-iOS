import XCTest
import AVFoundation
@testable import OpusKit

final class OpusDecoderTests: XCTestCase {

    private func fixtureURL(_ name: String, ext: String) throws -> URL {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext) else {
            throw XCTSkip("fixture not bundled: \(name).\(ext)")
        }
        return url
    }

    func testDecodesBundledVoiceNote() throws {
        let url = try fixtureURL("voice_note", ext: "ogg")
        let decoded = try OpusDecoder.decodePCM(url: url)
        XCTAssertEqual(decoded.pcm.format.sampleRate, 48000)
        XCTAssertGreaterThan(decoded.pcm.format.channelCount, 0)
        XCTAssertGreaterThan(decoded.pcm.frameLength, 0)
        // 18 s fixture at 48 kHz → ~864000 frames; allow ±5%.
        let expected: AVAudioFrameCount = 864_000
        let lower = AVAudioFrameCount(Double(expected) * 0.95)
        let upper = AVAudioFrameCount(Double(expected) * 1.05)
        XCTAssertGreaterThanOrEqual(decoded.pcm.frameLength, lower,
            "got frameLength=\(decoded.pcm.frameLength), expected ~\(expected)")
        XCTAssertLessThanOrEqual(decoded.pcm.frameLength, upper,
            "got frameLength=\(decoded.pcm.frameLength), expected ~\(expected)")
    }

    func testRejectsMissingFile() {
        let bogus = URL(fileURLWithPath: "/nonexistent/path/voice.ogg")
        XCTAssertThrowsError(try OpusDecoder.decodePCM(url: bogus)) { err in
            guard case OpusDecoderError.fileNotFound = err else {
                XCTFail("expected fileNotFound, got \(err)"); return
            }
        }
    }

    func testRejectsNonOggFile() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("not-ogg.bin")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        XCTAssertThrowsError(try OpusDecoder.decodePCM(url: tmp)) { err in
            guard case OpusDecoderError.notOggOpus = err else {
                XCTFail("expected notOggOpus, got \(err)"); return
            }
        }
    }

    func testRejectsEmptyFile() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("empty.ogg")
        try Data().write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        XCTAssertThrowsError(try OpusDecoder.decodePCM(url: tmp)) { err in
            guard case OpusDecoderError.notOggOpus = err else {
                XCTFail("expected notOggOpus, got \(err)"); return
            }
        }
    }
}
