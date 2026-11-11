import XCTest
import AVFoundation

final class CameraCaptureModeTests: XCTestCase {
    private typealias Dimensions = CameraFormatDescriptor.Dimensions

    private func formats(_ items: [(Int32, Int32, Bool, [Double], Bool, Bool, [(Int32, Int32)])]) -> [CameraFormatDescriptor] {
        return items.enumerated().map { index, item in
            return CameraFormatDescriptor(
                index: index,
                dimensions: Dimensions(width: item.0, height: item.1),
                isVideoRange420: item.2,
                maxFrameRates: item.3,
                hasSecondaryZoomLevels: item.4,
                isHighPhotoQualitySupported: item.5,
                maxPhotoDimensions: item.6.map { Dimensions(width: $0.0, height: $0.1) }
            )
        }
    }

    private var iPhoneLikeFormats: [CameraFormatDescriptor] {
        return self.formats([
            (640, 480, true, [30.0], false, false, [(640, 480)]),
            (640, 480, false, [30.0], false, false, [(640, 480)]),
            (1280, 720, true, [60.0], false, true, [(1280, 720)]),
            (1440, 1080, true, [30.0], false, true, [(4032, 3024)]),
            (1920, 1080, true, [30.0], false, true, [(1920, 1080), (4032, 2268)]),
            (1920, 1080, true, [60.0], false, false, [(1920, 1080)]),
            (1920, 1080, true, [240.0], false, false, [(1920, 1080)]),
            (1920, 1440, true, [30.0], false, true, [(4032, 3024), (8064, 6048)]),
            (1920, 1440, false, [30.0], false, true, [(4032, 3024), (8064, 6048)]),
            (3840, 2160, true, [30.0], false, true, [(3840, 2160)]),
            (4032, 3024, true, [30.0], false, false, [(4032, 3024)]),
            (4032, 3024, true, [30.0], false, true, [(4032, 3024), (8064, 6048)])
        ])
    }

    func testPhotoFormatChoice4x3() {
        let formats = self.iPhoneLikeFormats
        guard let chosen = cameraPreferredFormat(formats: formats, mode: .photo) else {
            XCTFail("no photo format")
            return
        }
        XCTAssertEqual(chosen.dimensions.width * 3, chosen.dimensions.height * 4)
        XCTAssertEqual(chosen.index, 7)
        XCTAssertTrue(chosen.isHighPhotoQualitySupported)
        XCTAssertEqual(cameraPreferredPhotoDimensions(for: chosen), Dimensions(width: 4032, height: 3024))

        let onlyLarge = self.formats([
            (1920, 1080, true, [30.0], false, true, [(4032, 2268)]),
            (4032, 3024, true, [30.0], false, false, [(4032, 3024)]),
            (4032, 3024, true, [30.0], false, true, [(4032, 3024)])
        ])
        XCTAssertEqual(cameraPreferredFormat(formats: onlyLarge, mode: .photo)?.index, 2)

        let lowPhotoQualityHasMorePixels = self.formats([
            (1440, 1080, true, [30.0], false, true, [(2016, 1512)]),
            (1920, 1440, true, [30.0], false, false, [(4032, 3024)])
        ])
        XCTAssertEqual(cameraPreferredFormat(formats: lowPhotoQualityHasMorePixels, mode: .photo)?.index, 1)

        let samePhotoDims = self.formats([
            (1920, 1440, true, [30.0], false, false, [(4032, 3024)]),
            (1440, 1080, true, [30.0], false, true, [(4032, 3024)])
        ])
        XCTAssertEqual(cameraPreferredFormat(formats: samePhotoDims, mode: .photo)?.index, 1)

        let tooLarge = self.formats([
            (1920, 1440, true, [30.0], false, true, [(8064, 6048)]),
            (1440, 1080, true, [30.0], false, true, [(3264, 2448)])
        ])
        XCTAssertEqual(cameraPreferredFormat(formats: tooLarge, mode: .photo)?.index, 1)
        XCTAssertNil(cameraPreferredPhotoDimensions(for: tooLarge[0]))

        let no4x3 = self.formats([
            (1280, 720, true, [30.0], false, true, [(1280, 720)]),
            (1920, 1080, true, [30.0], false, true, [(1920, 1080)]),
            (3840, 2160, true, [30.0], false, true, [(3840, 2160)])
        ])
        XCTAssertEqual(cameraPreferredFormat(formats: no4x3, mode: .photo)?.index, 1)
        XCTAssertEqual(
            cameraPreferredFormat(formats: no4x3, mode: .photo),
            cameraPreferredFormat(formats: no4x3, maxDimensions: Dimensions(width: 1920, height: 1440), maxFramerate: 30.0)
        )
        XCTAssertNil(cameraPreferredFormat(formats: [], mode: .photo))
    }

    func testPhotoExifOrientation() {
        XCTAssertEqual(cameraPhotoExifOrientation(orientation: .portrait, mirror: false), 6)
        XCTAssertEqual(cameraPhotoExifOrientation(orientation: .portrait, mirror: true), 5)
        XCTAssertEqual(cameraPhotoExifOrientation(orientation: .portraitUpsideDown, mirror: false), 8)
        XCTAssertEqual(cameraPhotoExifOrientation(orientation: .portraitUpsideDown, mirror: true), 7)
        XCTAssertEqual(cameraPhotoExifOrientation(orientation: .landscapeLeft, mirror: false), 3)
        XCTAssertEqual(cameraPhotoExifOrientation(orientation: .landscapeLeft, mirror: true), 2)
        XCTAssertEqual(cameraPhotoExifOrientation(orientation: .landscapeRight, mirror: false), 1)
        XCTAssertEqual(cameraPhotoExifOrientation(orientation: .landscapeRight, mirror: true), 4)
    }

    func testVideoFormatCapped1080p() {
        let formats = self.iPhoneLikeFormats
        guard let chosen = cameraPreferredFormat(formats: formats, mode: .video) else {
            XCTFail("no video format")
            return
        }
        XCTAssertEqual(chosen.dimensions, Dimensions(width: 1920, height: 1080))
        XCTAssertEqual(chosen.index, 4)
        XCTAssertEqual(
            chosen,
            cameraPreferredFormat(formats: formats, maxDimensions: Dimensions(width: 1920, height: 1080), maxFramerate: 30.0)
        )

        let noHighQuality = self.formats([
            (1280, 720, true, [30.0], false, false, [(1280, 720)]),
            (1920, 1080, true, [60.0], false, false, [(1920, 1080)]),
            (1920, 1080, true, [30.0], false, false, [(1920, 1080)]),
            (3840, 2160, true, [30.0], false, false, [(3840, 2160)])
        ])
        XCTAssertEqual(cameraPreferredFormat(formats: noHighQuality, mode: .video)?.index, 2)
    }

    func testDefaultUnchangedWithoutCaptureMode() {
        XCTAssertEqual(
            cameraFormatRule(captureMode: nil, legacyMaxDimensions: Dimensions(width: 1920, height: 1080)),
            .legacy(maxDimensions: Dimensions(width: 1920, height: 1080))
        )
        XCTAssertEqual(
            cameraFormatRule(captureMode: nil, legacyMaxDimensions: Dimensions(width: 1920, height: 1440)),
            .legacy(maxDimensions: Dimensions(width: 1920, height: 1440))
        )
        XCTAssertEqual(cameraFormatRule(captureMode: .photo, legacyMaxDimensions: Dimensions(width: 1920, height: 1080)), .photo)
        XCTAssertEqual(cameraFormatRule(captureMode: .video, legacyMaxDimensions: Dimensions(width: 1920, height: 1440)), .video)

        XCTAssertTrue(cameraAttachesAudio(captureMode: nil, configuredAudio: true))
        XCTAssertFalse(cameraAttachesAudio(captureMode: nil, configuredAudio: false))
        XCTAssertFalse(cameraAttachesAudio(captureMode: .photo, configuredAudio: true))
        XCTAssertTrue(cameraAttachesAudio(captureMode: .video, configuredAudio: false))

        let formats = self.iPhoneLikeFormats
        XCTAssertEqual(cameraPreferredFormat(formats: formats, maxDimensions: Dimensions(width: 1920, height: 1080), maxFramerate: 30.0)?.index, 4)
        XCTAssertEqual(cameraPreferredFormat(formats: formats, maxDimensions: Dimensions(width: 1920, height: 1440), maxFramerate: 30.0)?.index, 7)
        XCTAssertEqual(cameraPreferredFormat(formats: formats, maxDimensions: Dimensions(width: 640, height: 480), maxFramerate: 30.0)?.index, 0)

        let staleHighQualityCandidate = self.formats([
            (1280, 720, true, [30.0], false, true, [(1280, 720)]),
            (1920, 1080, true, [30.0], false, false, [(1920, 1080)])
        ])
        XCTAssertEqual(cameraPreferredFormat(formats: staleHighQualityCandidate, maxDimensions: Dimensions(width: 1920, height: 1080), maxFramerate: 30.0)?.index, 0)

        let secondaryZoom = self.formats([
            (1920, 1080, true, [30.0], true, false, [(1920, 1080)]),
            (1920, 1080, true, [30.0], false, true, [(1920, 1080)])
        ])
        XCTAssertEqual(cameraPreferredFormat(formats: secondaryZoom, maxDimensions: Dimensions(width: 1920, height: 1080), maxFramerate: 30.0)?.index, 0)

        let onlyFast = self.formats([
            (1920, 1080, true, [60.0], false, false, [(1920, 1080)])
        ])
        XCTAssertEqual(cameraPreferredFormat(formats: onlyFast, maxDimensions: Dimensions(width: 1920, height: 1080), maxFramerate: 30.0)?.index, 0)

        XCTAssertNil(cameraPreferredFormat(formats: [], maxDimensions: Dimensions(width: 1920, height: 1080), maxFramerate: 30.0))

        let wide: [String: Any] = [AVVideoWidthKey: 1920, AVVideoHeightKey: 1440]
        XCTAssertEqual(cameraRecordedDimensions(captureMode: nil, videoSettings: wide, isLandscape: false), CGSize(width: 1080, height: 1920))
        XCTAssertEqual(cameraRecordedDimensions(captureMode: nil, videoSettings: wide, isLandscape: true), CGSize(width: 1920, height: 1080))
    }

    func testRecordedDimsFromSettings() {
        let wide: [String: Any] = [AVVideoWidthKey: 1920, AVVideoHeightKey: 1440]
        XCTAssertEqual(cameraRecordedDimensions(captureMode: .video, videoSettings: wide, isLandscape: false), CGSize(width: 1440, height: 1920))
        XCTAssertEqual(cameraRecordedDimensions(captureMode: .video, videoSettings: wide, isLandscape: true), CGSize(width: 1920, height: 1440))

        let hd: [String: Any] = [AVVideoWidthKey: NSNumber(value: 1280), AVVideoHeightKey: NSNumber(value: 720)]
        XCTAssertEqual(cameraRecordedDimensions(captureMode: .photo, videoSettings: hd, isLandscape: false), CGSize(width: 720, height: 1280))

        let portraitBuffers: [String: Any] = [AVVideoWidthKey: 1080, AVVideoHeightKey: 1920]
        XCTAssertEqual(cameraRecordedDimensions(captureMode: .video, videoSettings: portraitBuffers, isLandscape: false), CGSize(width: 1080, height: 1920))
        XCTAssertEqual(cameraRecordedDimensions(captureMode: .video, videoSettings: portraitBuffers, isLandscape: true), CGSize(width: 1920, height: 1080))

        XCTAssertEqual(cameraRecordedDimensions(captureMode: .video, videoSettings: [:], isLandscape: false), CGSize(width: 1080, height: 1920))
    }
}
