import XCTest
import TLottieBinding

final class TLottieAnimationTests: XCTestCase {
    func testParsesFixtureMetadata() {
        guard let instance = TLottieAnimation(
            data: TLottieTestFixtures.solidRed(),
            fitzModifier: .none,
            colorReplacements: nil
        ) else {
            XCTFail("fixture did not parse")
            return
        }
        XCTAssertEqual(instance.dimensions, CGSize(width: 32.0, height: 32.0))
        XCTAssertEqual(instance.frameCount, 60)
        XCTAssertEqual(instance.frameRate, 60)
        XCTAssertEqual(instance.duration, 1.0, accuracy: 0.01)
    }

    /// tlottie's Composition::frame_count() returns 1 for any composition it can
    /// prove static, where rlottie reports the authored range. The detection is
    /// documented conservative — true guarantees every playable frame is
    /// identical — so collapsing is visually lossless, but the reported count
    /// differs and anything deriving a duration from it will too.
    func testStaticCompositionCollapsesToOneFrame() {
        guard let instance = TLottieAnimation(
            data: TLottieTestFixtures.staticSolidRed(),
            fitzModifier: .none,
            colorReplacements: nil
        ) else {
            XCTFail("fixture did not parse")
            return
        }
        XCTAssertEqual(instance.frameCount, 1)
    }

    private func makeSolidRedInstance() -> TLottieAnimation? {
        return TLottieAnimation(
            data: TLottieTestFixtures.solidRed(),
            fitzModifier: .none,
            colorReplacements: nil
        )
    }

    func testWritesBGRAByteOrder() {
        guard let instance = self.makeSolidRedInstance() else {
            XCTFail("fixture did not parse")
            return
        }
        let width = 32, height = 32
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        buffer.withUnsafeMutableBufferPointer { pointer in
            instance.renderFrame(with: 0, into: pointer.baseAddress!,
                                 width: Int32(width), height: Int32(height),
                                 bytesPerRow: Int32(width * 4))
        }
        // Sample the middle of the canvas, away from any edge coverage.
        let offset = ((height / 2) * width + (width / 2)) * 4
        XCTAssertEqual(buffer[offset + 0], 0, "blue")
        XCTAssertEqual(buffer[offset + 1], 0, "green")
        XCTAssertEqual(buffer[offset + 2], 255, "red")
        XCTAssertEqual(buffer[offset + 3], 255, "alpha")
    }

    func testStridedRenderLeavesRowPaddingUntouched() {
        guard let instance = self.makeSolidRedInstance() else {
            XCTFail("fixture did not parse")
            return
        }
        let width = 25, height = 25              // 25 * 4 == 100, not 64-aligned
        let bytesPerRow = 128                    // strictly greater than width * 4
        XCTAssertGreaterThan(bytesPerRow, width * 4)

        let poison: UInt8 = 0xAB
        var buffer = [UInt8](repeating: poison, count: bytesPerRow * height)
        buffer.withUnsafeMutableBufferPointer { pointer in
            instance.renderFrame(with: 0, into: pointer.baseAddress!,
                                 width: Int32(width), height: Int32(height),
                                 bytesPerRow: Int32(bytesPerRow))
        }

        for y in 0 ..< height {
            let rowStart = y * bytesPerRow
            // The pixel region of every row must have been written.
            let centre = rowStart + (width / 2) * 4
            XCTAssertEqual(buffer[centre + 3], 255, "row \(y) alpha")
            // The padding after it must not have been.
            for x in (width * 4) ..< bytesPerRow {
                XCTAssertEqual(buffer[rowStart + x], poison,
                               "row \(y) byte \(x) was overwritten")
            }
        }
    }

    func testPackedAndStridedRendersAgree() {
        guard let packedInstance = self.makeSolidRedInstance(),
              let stridedInstance = self.makeSolidRedInstance() else {
            XCTFail("fixture did not parse")
            return
        }
        let width = 25, height = 25
        let bytesPerRow = 128

        var packed = [UInt8](repeating: 0, count: width * 4 * height)
        packed.withUnsafeMutableBufferPointer { pointer in
            packedInstance.renderFrame(with: 0, into: pointer.baseAddress!,
                                       width: Int32(width), height: Int32(height),
                                       bytesPerRow: Int32(width * 4))
        }

        var strided = [UInt8](repeating: 0, count: bytesPerRow * height)
        strided.withUnsafeMutableBufferPointer { pointer in
            stridedInstance.renderFrame(with: 0, into: pointer.baseAddress!,
                                        width: Int32(width), height: Int32(height),
                                        bytesPerRow: Int32(bytesPerRow))
        }

        for y in 0 ..< height {
            for x in 0 ..< (width * 4) {
                XCTAssertEqual(strided[y * bytesPerRow + x], packed[y * width * 4 + x],
                               "mismatch at row \(y) byte \(x)")
            }
        }
    }
}

