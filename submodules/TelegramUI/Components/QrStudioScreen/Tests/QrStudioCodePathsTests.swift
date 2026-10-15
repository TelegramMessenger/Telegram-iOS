import XCTest
import QrCode
@testable import QrStudioScreen

final class QrStudioCodePathsTests: XCTestCase {
    private func generatedMatrix(_ string: String) throws -> QrCodeMatrix {
        guard let matrix = qrCodeMatrix(string: string, ecl: "Q") else {
            throw XCTSkip("CoreImage renders nothing in this test process")
        }
        return matrix
    }

    private func syntheticMatrix() throws -> QrCodeMatrix {
        let size = 29
        var bits = [Bool](repeating: false, count: size * size)
        var seed: UInt64 = 0x2545F4914F6CDD1D
        for i in 0 ..< bits.count {
            seed ^= seed << 13
            seed ^= seed >> 7
            seed ^= seed << 17
            bits[i] = seed & 1 == 1
        }
        for (ex, ey) in [(0, 0), (size - 7, 0), (0, size - 7)] {
            for y in 0 ..< 7 {
                for x in 0 ..< 7 {
                    let ring = x == 0 || y == 0 || x == 6 || y == 6
                    let ball = (2 ... 4).contains(x) && (2 ... 4).contains(y)
                    bits[(ey + y) * size + ex + x] = ring || ball
                }
            }
        }
        return try XCTUnwrap(QrCodeMatrix(size: size, bits: bits))
    }
    func testMatrixHasFinderPatterns() throws {
        let matrix = try self.generatedMatrix("https://t.me/telegram")
        XCTAssertEqual((matrix.size - 21) % 4, 0)
        for eye in matrix.eyes {
            for i in 0 ..< 7 {
                XCTAssertTrue(matrix[eye.x + i, eye.y])
                XCTAssertTrue(matrix[eye.x + i, eye.y + 6])
                XCTAssertTrue(matrix[eye.x, eye.y + i])
                XCTAssertTrue(matrix[eye.x + 6, eye.y + i])
            }
            XCTAssertFalse(matrix[eye.x + 1, eye.y + 1])
            XCTAssertTrue(matrix[eye.x + 3, eye.y + 3])
        }
        XCTAssertFalse(matrix[-1, 0])
        XCTAssertFalse(matrix[matrix.size, 0])
    }

    func testMatrixIsStableAndDistinguishesStrings() throws {
        let _ = try self.generatedMatrix("https://t.me/a")
        let a = qrCodeMatrix(string: "https://t.me/a", ecl: "Q")
        XCTAssertEqual(a, qrCodeMatrix(string: "https://t.me/a", ecl: "Q"))
        XCTAssertNotEqual(a, qrCodeMatrix(string: "https://t.me/b", ecl: "Q"))
    }

    func testUnencodableStringReturnsNil() {
        XCTAssertNil(qrCodeMatrix(string: "привет", ecl: "Q"))
    }

    func testPathsCoverEyesAndLeaveLogoEmpty() throws {
        let matrix = try self.syntheticMatrix()
        let paths = QrStudioCodePaths(matrix: matrix, side: 200)
        let unit = 200 / CGFloat(matrix.size)
        XCTAssertFalse(paths.body.contains(CGPoint(x: 100, y: 100)))
        XCTAssertFalse(paths.body.contains(CGPoint(x: unit * 3.5, y: unit * 3.5)))
        XCTAssertTrue(paths.balls.contains(CGPoint(x: unit * 3.5, y: unit * 3.5)))
        XCTAssertTrue(paths.frames.contains(CGPoint(x: unit * 0.5, y: unit * 3.5), using: .evenOdd))
        XCTAssertFalse(paths.frames.contains(CGPoint(x: unit * 1.5, y: unit * 3.5), using: .evenOdd))
        XCTAssertTrue(paths.body.boundingBoxOfPath.maxX <= 200.001)
        XCTAssertGreaterThan(paths.logoDiameter, 30)
        XCTAssertLessThan(paths.logoDiameter, 60)
    }

    func testEveryDarkModuleOutsideEyesAndLogoIsFilled() throws {
        let matrix = try self.syntheticMatrix()
        let paths = QrStudioCodePaths(matrix: matrix, side: 200)
        let unit = 200 / CGFloat(matrix.size)
        for y in 0 ..< matrix.size {
            for x in 0 ..< matrix.size where !matrix.isEye(x: x, y: y) && !QrStudioCodePaths.isInLogo(x: x, y: y, size: matrix.size) {
                let center = CGPoint(x: (CGFloat(x) + 0.5) * unit, y: (CGFloat(y) + 0.5) * unit)
                XCTAssertEqual(paths.body.contains(center), matrix[x, y], "\(x),\(y)")
            }
        }
    }

    func testMatrixRejectsMismatchedBits() {
        XCTAssertNil(QrCodeMatrix(size: 3, bits: [true, false]))
        XCTAssertNil(QrCodeMatrix(size: 0, bits: []))
    }

    func testCardHeightWithoutUsername() {
        XCTAssertEqual(QrStudioCardMetrics.height(showsUsername: true), 319)
        XCTAssertEqual(QrStudioCardMetrics.height(showsUsername: false), 300)
        let withName = QrStudioCardMetrics.cardCenterY(screenHeight: 874, showsUsername: true)
        let expected: CGFloat = 437.0 - 9.5 - 179.5 + 159.5
        XCTAssertEqual(withName, expected, accuracy: 0.001)
    }
}
