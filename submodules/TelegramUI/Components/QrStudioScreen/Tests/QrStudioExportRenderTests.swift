import XCTest
import UIKit
import AVFoundation
@testable import QrStudioScreen

final class QrStudioExportRenderTests: XCTestCase {
    private func solid(_ color: UIColor, side: Int) -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        }.cgImage!
    }

    private func pixel(_ image: UIImage, x: Int, y: Int) -> (UInt8, UInt8, UInt8) {
        let cg = image.cgImage!
        var data = [UInt8](repeating: 0, count: 4)
        let context = CGContext(data: &data, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(cg, in: CGRect(x: -x, y: -(cg.height - 1 - y), width: cg.width, height: cg.height))
        return (data[0], data[1], data[2])
    }

    private let screen = CGSize(width: 402.0, height: 874.0)
    private let screenCard = CGRect(x: 69.0, y: 250.0, width: 264.0, height: 318.0)

    func testStoryImageSizeAndCard() {
        let cardImage = self.solid(.red, side: 100)
        let scene = QrStudioExportScene(background: .mesh(Array(repeating: QrStudioColor(0.0, 0.0, 1.0), count: 9)), card: cardImage, screenSize: self.screen, screenCard: self.screenCard, isLight: false)
        let image = qrStudioExportImage(scene, canvas: .story)!
        XCTAssertEqual(image.cgImage!.width, 1080)
        XCTAssertEqual(image.cgImage!.height, 1920)
        let centre = self.pixel(image, x: 540, y: 960)
        XCTAssertGreaterThan(centre.0, 200)
        let corner = self.pixel(image, x: 10, y: 10)
        XCTAssertGreaterThan(corner.2, 200)
        XCTAssertLessThan(corner.0, 40)
    }

    func testScreenExportDrawsEmojiWhereTheScreenShowsThem() {
        let sticker = QrStudioExportSticker(frames: [self.solid(.green, side: 48)], period: 0.0)
        let item = QrStudioExportPatternItem(content: .sticker(0), point: CGPoint(x: 200.0, y: 140.0), side: 40.0, degrees: 0.0, hash: 0.3)
        let scene = QrStudioExportScene(background: .emoji(colors: QrStudioPalette.fallback.colors, stickers: [sticker], items: [item]), card: self.solid(.white, side: 100), screenSize: self.screen, screenCard: self.screenCard, isLight: true)
        let image = qrStudioExportImage(scene, canvas: .screen(size: self.screen, scale: 3.0))!
        let hit = self.pixel(image, x: 600, y: 420)
        XCTAssertGreaterThan(hit.1, 150)
        XCTAssertLessThan(hit.0, 100)
        let miss = self.pixel(image, x: 600, y: 520)
        XCTAssertGreaterThan(miss.0, 200)
    }

    func testStickerImageLoops() {
        let frames = (0 ..< 90).map { _ in self.solid(.blue, side: 4) }
        let sticker = QrStudioExportSticker(frames: frames, period: 1.5)
        XCTAssertTrue(sticker.image(phase: 0.4, at: 0.0) === sticker.image(phase: 0.4, at: QrStudioExportMotion.loop))
    }

    func testRgbaFrameConversion() {
        let width = 4
        let height = 4
        let bytesPerRow = 16
        var bytes = [UInt8](repeating: 0, count: height * bytesPerRow)
        for i in stride(from: 0, to: bytes.count, by: 4) {
            bytes[i] = 255
            bytes[i + 3] = 255
        }
        let image = qrStudioExportCGImage(rgba: Data(bytes), width: width, height: height, bytesPerRow: bytesPerRow)
        XCTAssertEqual(image?.width, 4)
        XCTAssertEqual(image?.height, 4)
    }

    func testVideoExporterWritesFrames() {
        let cardImage = self.solid(.white, side: 64)
        let frames = (0 ..< 10).map { i in self.solid(UIColor(white: CGFloat(i) / 10.0, alpha: 1.0), side: 32) }
        let item = QrStudioExportPatternItem(content: .sticker(0), point: CGPoint(x: 200.0, y: 140.0), side: 40.0, degrees: 0.0, hash: 0.3)
        let scene = QrStudioExportScene(background: .emoji(colors: QrStudioPalette.fallback.colors, stickers: [QrStudioExportSticker(frames: frames, period: 1.0)], items: [item]), card: cardImage, screenSize: self.screen, screenCard: self.screenCard, isLight: true)
        let exporter = QrStudioVideoExporter(scene: scene, canvas: .story, frameCount: 12)
        let done = self.expectation(description: "done")
        var output: URL?
        exporter.start(progress: { _ in }, completion: { url in
            output = url
            done.fulfill()
        })
        self.wait(for: [done], timeout: 60.0)
        guard let output else {
            XCTFail("no file")
            return
        }
        let asset = AVURLAsset(url: output)
        let track = asset.tracks(withMediaType: .video).first
        XCTAssertEqual(track?.naturalSize, CGSize(width: 1080.0, height: 1920.0))
        XCTAssertEqual(CMTimeGetSeconds(asset.duration), 12.0 / 30.0, accuracy: 0.05)
        try? FileManager.default.removeItem(at: output)
    }

    func testVideoExporterCancelRemovesFile() {
        let scene = QrStudioExportScene(background: .mesh(Array(repeating: QrStudioColor(0.5, 0.5, 0.5), count: 9)), card: self.solid(.white, side: 64), screenSize: self.screen, screenCard: self.screenCard, isLight: false)
        let exporter = QrStudioVideoExporter(scene: scene, canvas: .story, frameCount: QrStudioExportMotion.frameCount)
        let done = self.expectation(description: "done")
        exporter.start(progress: { value in
            if value > 0.05 {
                exporter.cancel()
            }
        }, completion: { url in
            XCTAssertNil(url)
            done.fulfill()
        })
        self.wait(for: [done], timeout: 60.0)
        XCTAssertTrue(exporter.isCancelled)
    }

    func testVideoPlaneIsDrawnOverTheCard() {
        let cardImage = self.solid(.white, side: 100)
        let plane = QrStudioExportSticker(frames: [self.solid(.blue, side: 40)], period: 0.0)
        var scene = QrStudioExportScene(background: .mesh(Array(repeating: QrStudioColor(0.0, 0.0, 0.0), count: 9)), card: cardImage, screenSize: self.screen, screenCard: self.screenCard, isLight: false)
        scene.plane = QrStudioExportScene.Plane(sticker: plane, rect: CGRect(x: 112.0, y: 139.0, width: 40.0, height: 40.0))
        let image = qrStudioExportImage(scene, canvas: .screen(size: self.screen, scale: 3.0))!
        let center = self.pixel(image, x: Int((self.screenCard.minX + 132.0) * 3.0), y: Int((self.screenCard.minY + 159.0) * 3.0))
        XCTAssertGreaterThan(center.2, 200)
        XCTAssertLessThan(center.0, 60)
    }

    func testTintKeepsSize() {
        let tinted = qrStudioTinted(self.solid(.white, side: 8), color: .red)
        XCTAssertEqual(tinted?.width, 8)
    }
}
