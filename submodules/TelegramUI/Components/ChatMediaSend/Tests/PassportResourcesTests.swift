import Foundation
import UIKit
import AVFoundation
import XCTest
import SwiftSignalKit
import TelegramCore
import AccountContext
import ChatMediaSend

private let passportResourcesTempBoxInitialized: Void = {
    EngineTempBox.initializeShared(basePath: NSTemporaryDirectory() + "passport-resources-tests", processType: "tests", launchSpecificId: 1)
}()

private final class PassportResourcesTestRenderer: ChatMediaSendRendering {
    var renderCount = 0

    func renderPhoto(item: ChatMediaSendItem, forceHd: Bool) -> Signal<ChatMediaSendRenderEvent, NoError> {
        self.renderCount += 1
        return .single(.result(nil))
    }
}

final class PassportResourcesTests: XCTestCase {
    private func makeImage(size: CGSize, color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func writeImageFile(size: CGSize) -> String {
        let path = NSTemporaryDirectory() + "passport-resources-\(Int64.random(in: 1 ... Int64.max)).jpg"
        try! self.makeImage(size: size, color: .green).jpegData(compressionQuality: 0.9)!.write(to: URL(fileURLWithPath: path))
        return path
    }

    private func pixelSize(_ resource: TelegramMediaResource) -> CGSize? {
        guard let resource = resource as? LocalFileReferenceMediaResource, let image = UIImage(contentsOfFile: resource.localFilePath) else {
            return nil
        }
        return CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
    }

    func testAttachmentResourceIsScaledJpegFile() {
        let _ = passportResourcesTempBoxInitialized
        let large = passportAttachmentResource(image: self.makeImage(size: CGSize(width: 4032.0, height: 3024.0), color: .red))
        XCTAssertNotNil(large)
        XCTAssertEqual(large.flatMap(self.pixelSize), CGSize(width: 2048.0, height: 1536.0))

        let small = passportAttachmentResource(image: self.makeImage(size: CGSize(width: 1000.0, height: 800.0), color: .blue))
        XCTAssertEqual(small.flatMap(self.pixelSize), CGSize(width: 1000.0, height: 800.0))
    }

    func testRenderedResourcesConvertEachItemAndSkipUnavailable() {
        let _ = passportResourcesTempBoxInitialized
        let first = self.writeImageFile(size: CGSize(width: 4032.0, height: 3024.0))
        let second = self.writeImageFile(size: CGSize(width: 3024.0, height: 4032.0))
        let missing = NSTemporaryDirectory() + "passport-resources-missing.jpg"
        let items: [PassportImageItem] = [
            PassportImageItem(uniqueId: "a", source: .imageFile(path: first, dimensions: PixelDimensions(width: 4032, height: 3024)), values: nil),
            PassportImageItem(uniqueId: "b", source: .imageFile(path: missing, dimensions: PixelDimensions(width: 10, height: 10)), values: nil),
            PassportImageItem(uniqueId: "c", source: .imageFile(path: second, dimensions: PixelDimensions(width: 3024, height: 4032)), values: nil)
        ]
        let renderer = PassportResourcesTestRenderer()
        let expectation = self.expectation(description: "resources")
        var result: [TelegramMediaResource]?
        let disposable = passportRenderedResources(renderer: renderer, items: items).start(next: { resources in
            result = resources
            expectation.fulfill()
        })
        self.wait(for: [expectation], timeout: 10.0)
        disposable.dispose()

        XCTAssertEqual(renderer.renderCount, 0)
        XCTAssertEqual(result?.count, 2)
        XCTAssertEqual(result?.compactMap(self.pixelSize), [CGSize(width: 2048.0, height: 1536.0), CGSize(width: 1536.0, height: 2048.0)])
    }

    func testRenderedResourcesEmptyItems() {
        var result: [TelegramMediaResource]?
        let _ = passportRenderedResources(renderer: PassportResourcesTestRenderer(), items: []).start(next: { resources in
            result = resources
        })
        XCTAssertEqual(result?.count, 0)
    }

    func testCarouselCameraStateFollowsAuthorization() {
        XCTAssertEqual(passportCarouselCameraState(authorization: .authorized), .live)
        XCTAssertEqual(passportCarouselCameraState(authorization: .notDetermined), .requestAccess)
        XCTAssertEqual(passportCarouselCameraState(authorization: .denied), .placeholder)
        XCTAssertEqual(passportCarouselCameraState(authorization: .restricted), .placeholder)
    }
}
