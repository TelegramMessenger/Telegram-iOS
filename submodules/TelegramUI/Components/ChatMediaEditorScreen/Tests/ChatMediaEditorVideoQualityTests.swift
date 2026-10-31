import Foundation
import UIKit
import XCTest
import TelegramCore
import MediaEditor
import LegacyComponents
import ChatMediaSend
import ChatMediaEditorScreen

final class ChatMediaEditorVideoQualityTests: XCTestCase {
    private let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))

    private func values(width: Int32 = 1920, height: Int32 = 1080, qualityPreset: MediaQualityPreset? = .compressedMedium, videoIsMuted: Bool = false) -> MediaEditorValues {
        return MediaEditorValues(
            peerId: self.peerId,
            originalDimensions: PixelDimensions(width: width, height: height),
            cropOffset: .zero,
            cropRect: nil,
            cropScale: 1.0,
            cropRotation: 0.0,
            cropMirroring: false,
            cropOrientation: nil,
            cropPerspective: .zero,
            gradientColors: nil,
            videoTrimRange: nil,
            videoBounce: false,
            videoIsMuted: videoIsMuted,
            videoIsFullHd: false,
            videoIsMirrored: false,
            videoVolume: 1.0,
            additionalVideoPath: nil,
            additionalVideoIsDual: false,
            additionalVideoMirroringChanges: [],
            additionalVideoPosition: nil,
            additionalVideoScale: nil,
            additionalVideoRotation: nil,
            additionalVideoPositionChanges: [],
            additionalVideoTrimRange: nil,
            additionalVideoOffset: nil,
            additionalVideoVolume: nil,
            collage: [],
            nightTheme: false,
            drawing: nil,
            maskDrawing: nil,
            entities: [],
            toolValues: [:],
            audioTrack: nil,
            audioTrackTrimRange: nil,
            audioTrackOffset: nil,
            audioTrackVolume: nil,
            audioTrackSamples: nil,
            collageTrackSamples: nil,
            coverImageTimestamp: nil,
            coverDimensions: nil,
            qualityPreset: qualityPreset
        )
    }

    func testBestAvailablePresetForDimensions() {
        let cases: [(CGSize, MediaQualityPreset)] = [
            (CGSize(width: 3840.0, height: 2160.0), .compressedVeryHigh),
            (CGSize(width: 1920.0, height: 1080.0), .compressedVeryHigh),
            (CGSize(width: 1080.0, height: 1920.0), .compressedVeryHigh),
            (CGSize(width: 1919.0, height: 1080.0), .compressedHigh),
            (CGSize(width: 1280.0, height: 720.0), .compressedHigh),
            (CGSize(width: 1279.0, height: 720.0), .compressedMedium),
            (CGSize(width: 848.0, height: 480.0), .compressedMedium),
            (CGSize(width: 847.0, height: 480.0), .compressedLow),
            (CGSize(width: 640.0, height: 360.0), .compressedLow),
            (CGSize(width: 480.0, height: 270.0), .compressedLow),
            (CGSize(width: 100.0, height: 100.0), .compressedLow)
        ]
        for (size, expected) in cases {
            XCTAssertEqual(chatMediaEditorBestAvailableVideoPreset(dimensions: size), expected, "\(size)")
            XCTAssertEqual(chatMediaEditorBestAvailableVideoPreset(dimensions: size).rawValue, Int32(TGMediaVideoConverter.bestAvailablePreset(forDimensions: size).rawValue), "\(size)")
        }
    }

    func testPickerMaxClamped() {
        XCTAssertEqual(chatMediaEditorVideoQualityPickerPresets(dimensions: CGSize(width: 1920.0, height: 1080.0)), [.compressedVeryLow, .compressedLow, .compressedMedium, .compressedHigh, .compressedVeryHigh])
        XCTAssertEqual(chatMediaEditorVideoQualityPickerPresets(dimensions: CGSize(width: 1280.0, height: 720.0)), [.compressedVeryLow, .compressedLow, .compressedMedium, .compressedHigh])
        XCTAssertEqual(chatMediaEditorVideoQualityPickerPresets(dimensions: CGSize(width: 400.0, height: 300.0)), [.compressedVeryLow, .compressedLow])

        XCTAssertEqual(chatMediaEditorVideoQualityPickerInitialPreset(values: self.values(width: 1280, height: 720, qualityPreset: .compressedVeryHigh), fallback: .compressedMedium), .compressedHigh)
        XCTAssertEqual(chatMediaEditorVideoQualityPickerInitialPreset(values: self.values(width: 1920, height: 1080, qualityPreset: .compressedLow), fallback: .compressedMedium), .compressedLow)
        XCTAssertEqual(chatMediaEditorVideoQualityPickerInitialPreset(values: self.values(width: 1920, height: 1080, qualityPreset: nil), fallback: .compressedHigh), .compressedHigh)
        XCTAssertEqual(chatMediaEditorVideoQualityPickerInitialPreset(values: self.values(width: 1920, height: 1080, qualityPreset: .compressedDefault), fallback: .compressedHigh), .compressedHigh)
        XCTAssertEqual(chatMediaEditorVideoQualityPickerInitialPreset(values: self.values(width: 640, height: 360, qualityPreset: nil), fallback: .compressedVeryHigh), .compressedLow)

        XCTAssertEqual([MediaQualityPreset.compressedVeryLow, .compressedLow, .compressedMedium, .compressedHigh, .compressedVeryHigh].map(chatMediaEditorVideoQualityTitle), ["240p", "360p", "480p", "720p", "1080p"])
    }

    func testPresetPersisted() {
        let suiteName = "ChatMediaEditorVideoQualityTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail()
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        XCTAssertEqual(chatMediaEditorVideoQualityPreset(storedLegacyPreset: (defaults.object(forKey: "TG_preferredVideoPreset_v0") as? NSNumber)?.intValue), .compressedMedium)

        guard let updated = chatMediaEditorCommitVideoQuality(values: self.values(), preset: .compressedHigh, fallback: .compressedMedium, defaults: defaults) else {
            XCTFail()
            return
        }
        XCTAssertEqual(updated.qualityPreset, .compressedHigh)
        XCTAssertEqual((defaults.object(forKey: "TG_preferredVideoPreset_v0") as? NSNumber)?.intValue, 4)
        XCTAssertEqual(chatMediaEditorVideoQualityPreset(storedLegacyPreset: (defaults.object(forKey: "TG_preferredVideoPreset_v0") as? NSNumber)?.intValue), .compressedHigh)

        guard let lowered = chatMediaEditorCommitVideoQuality(values: updated, preset: .compressedVeryLow, fallback: .compressedMedium, defaults: defaults) else {
            XCTFail()
            return
        }
        XCTAssertEqual(lowered.qualityPreset, .compressedVeryLow)
        XCTAssertEqual(defaults.integer(forKey: "TG_preferredVideoPreset_v0"), 1)
    }

    func testMuteHiddenForAnimationItems() {
        XCTAssertTrue(chatMediaEditorMuteButtonIsVisible(isGallery: true, isVideo: true, isAnimation: false))
        XCTAssertFalse(chatMediaEditorMuteButtonIsVisible(isGallery: true, isVideo: true, isAnimation: true))
        XCTAssertFalse(chatMediaEditorMuteButtonIsVisible(isGallery: true, isVideo: false, isAnimation: false))
        XCTAssertFalse(chatMediaEditorMuteButtonIsVisible(isGallery: false, isVideo: true, isAnimation: false))
    }

    func testMuteButtonFrame() {
        let size = CGSize(width: 393.0, height: 852.0)
        let header = chatMediaEditorVideoHeaderFrame(size: size, toolbarMinY: 803.0, captionBaseHeight: 40.0)
        let frame = chatMediaEditorMuteButtonFrame(headerFrame: header, safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 34.0, right: 0.0))
        XCTAssertEqual(frame, CGRect(x: 16.0, y: 655.0, width: 40.0, height: 40.0))
    }

    func testQualityDisabledWhenMuted() {
        XCTAssertTrue(chatMediaEditorVideoQualityIsEnabled(values: self.values()))
        XCTAssertFalse(chatMediaEditorVideoQualityIsEnabled(values: self.values(videoIsMuted: true)))
        XCTAssertTrue(chatMediaEditorDisabledToolbarTabs(isVideo: true, values: self.values(videoIsMuted: true)).contains(.qualityTab))
        XCTAssertFalse(chatMediaEditorDisabledToolbarTabs(isVideo: true, values: self.values()).contains(.qualityTab))
        XCTAssertFalse(chatMediaEditorDisabledToolbarTabs(isVideo: false, values: self.values(videoIsMuted: true)).contains(.qualityTab))
    }

    func testToolbarLabelMapping() {
        XCTAssertEqual(chatMediaEditorLegacyVideoPreset(.compressedVeryLow), 1)
        XCTAssertEqual(chatMediaEditorLegacyVideoPreset(.compressedLow), 2)
        XCTAssertEqual(chatMediaEditorLegacyVideoPreset(.compressedMedium), 3)
        XCTAssertEqual(chatMediaEditorLegacyVideoPreset(.compressedHigh), 4)
        XCTAssertEqual(chatMediaEditorLegacyVideoPreset(.compressedVeryHigh), 5)
        XCTAssertEqual([1, 2, 3, 4, 5].map { chatMediaEditorVideoQualityPreset(storedLegacyPreset: $0) }, [.compressedVeryLow, .compressedLow, .compressedMedium, .compressedHigh, .compressedVeryHigh])

        XCTAssertEqual(chatMediaEditorToolbarVideoPreset(values: self.values(qualityPreset: .compressedVeryLow), fallback: .compressedMedium), 1)
        XCTAssertEqual(chatMediaEditorToolbarVideoPreset(values: self.values(qualityPreset: .compressedLow), fallback: .compressedMedium), 2)
        XCTAssertEqual(chatMediaEditorToolbarVideoPreset(values: self.values(qualityPreset: .compressedMedium), fallback: .compressedMedium), 3)
        XCTAssertEqual(chatMediaEditorToolbarVideoPreset(values: self.values(qualityPreset: .compressedHigh), fallback: .compressedMedium), 4)
        XCTAssertEqual(chatMediaEditorToolbarVideoPreset(values: self.values(qualityPreset: .compressedVeryHigh), fallback: .compressedMedium), 5)
        XCTAssertEqual(chatMediaEditorToolbarVideoPreset(values: self.values(qualityPreset: nil), fallback: .compressedMedium), 3)
        XCTAssertEqual(chatMediaEditorToolbarVideoPreset(values: self.values(width: 1280, height: 720, qualityPreset: .compressedVeryHigh), fallback: .compressedMedium), 4)
        XCTAssertEqual(chatMediaEditorToolbarVideoPreset(values: self.values(width: 640, height: 360, qualityPreset: nil), fallback: .compressedHigh), 2)
    }

    func testUserChangedPresetIsSavedAndSelects() {
        let items = ["a", "b"].map { ChatMediaEditorItem(uniqueId: $0, source: .video(path: "/\($0).mp4", dimensions: PixelDimensions(width: 1920, height: 1080), duration: 3.0)) }
        let store = ChatMediaEditorItemStore()
        let model = ChatMediaEditorPageModel(itemsSource: ChatMediaEditorListSource(items: items), store: store, initialIndex: 0)
        let defaults = self.values(qualityPreset: .compressedMedium)
        let changed = defaults.withUpdatedQualityPreset(.compressedHigh)

        store.noteQualityPresetBaseline(.compressedMedium, for: "a")
        XCTAssertFalse(chatMediaEditorShouldSaveItem(hasEntry: false, values: defaults, baselineQualityPreset: .compressedMedium))
        XCTAssertTrue(chatMediaEditorShouldSaveItem(hasEntry: false, values: changed, baselineQualityPreset: .compressedMedium))
        XCTAssertFalse(model.save(values: defaults, lockedAspectRatio: nil))
        XCTAssertNil(store.entry(for: "a"))
        XCTAssertTrue(model.save(values: changed, lockedAspectRatio: nil))
        XCTAssertEqual(store.editedIdentifiers, ["a"])
        XCTAssertFalse(model.storeThumbnail(UIImage(), uniqueId: "a", values: changed))

        XCTAssertTrue(chatMediaEditorCommitShouldAutoSelect(before: defaults, after: changed, baselineQualityPreset: .compressedMedium))
        XCTAssertFalse(chatMediaEditorCommitShouldAutoSelect(before: changed, after: defaults, baselineQualityPreset: .compressedMedium))
        XCTAssertFalse(chatMediaEditorCommitShouldAutoSelect(before: defaults, after: changed, baselineQualityPreset: nil))
    }

    func testFreshVideoPresetClampedToSource() {
        XCTAssertEqual(chatMediaEditorInitialVideoQualityPreset(preferred: .compressedVeryHigh, dimensions: CGSize(width: 1280.0, height: 720.0)), .compressedHigh)
        XCTAssertEqual(chatMediaEditorInitialVideoQualityPreset(preferred: .compressedHigh, dimensions: CGSize(width: 640.0, height: 360.0)), .compressedLow)
        XCTAssertEqual(chatMediaEditorInitialVideoQualityPreset(preferred: .compressedLow, dimensions: CGSize(width: 1920.0, height: 1080.0)), .compressedLow)
        XCTAssertEqual(chatMediaEditorInitialVideoQualityPreset(preferred: .compressedMedium, dimensions: CGSize(width: 3840.0, height: 2160.0)), .compressedMedium)
        XCTAssertEqual(chatMediaEditorInitialVideoQualityPreset(preferred: .compressedVeryHigh, dimensions: CGSize(width: 100.0, height: 100.0)), .compressedLow)

        let setup = chatMediaEditorEditorSetup(subject: .video(path: "/a.mp4", dimensions: PixelDimensions(width: 400, height: 300), duration: 3.0), peerId: self.peerId)
        XCTAssertEqual(setup.values.qualityPreset, .compressedLow)
    }

    func testUnchangedDoneOnClampedVideoIsNoOp() {
        let suiteName = "ChatMediaEditorVideoQualityTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail()
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults.set(NSNumber(value: 5), forKey: "TG_preferredVideoPreset_v0")
        let preferred = chatMediaEditorVideoQualityPreset(storedLegacyPreset: 5)
        let dimensions = CGSize(width: 1280.0, height: 720.0)
        let baseline = chatMediaEditorInitialVideoQualityPreset(preferred: preferred, dimensions: dimensions)
        let fresh = self.values(width: 1280, height: 720, qualityPreset: baseline)

        let opened = chatMediaEditorVideoQualityPickerInitialPreset(values: fresh, fallback: preferred)
        XCTAssertEqual(opened, baseline)
        XCTAssertNil(chatMediaEditorCommitVideoQuality(values: fresh, preset: opened, fallback: preferred, defaults: defaults))
        XCTAssertEqual(defaults.integer(forKey: "TG_preferredVideoPreset_v0"), 5)
        XCTAssertFalse(chatMediaEditorValuesAreEdited(fresh, baselineQualityPreset: baseline))
        XCTAssertFalse(chatMediaEditorCommitShouldAutoSelect(before: fresh, after: fresh, baselineQualityPreset: baseline))

        guard let lowered = chatMediaEditorCommitVideoQuality(values: fresh, preset: .compressedMedium, fallback: preferred, defaults: defaults) else {
            XCTFail()
            return
        }
        XCTAssertEqual(lowered.qualityPreset, .compressedMedium)
        XCTAssertEqual(defaults.integer(forKey: "TG_preferredVideoPreset_v0"), 3)
        XCTAssertTrue(chatMediaEditorValuesAreEdited(lowered, baselineQualityPreset: baseline))
    }

    func testQualityPanelFramePortraitMatchesToday() {
        let size = CGSize(width: 402.0, height: 874.0)
        let insets = UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0)
        let toolbarMinY = chatMediaEditorBottomPanelFrame(size: size, safeInsets: insets, toolbarHeight: 49.0).minY
        let expected = CGRect(x: 0.0, y: toolbarMinY - 75.0 + 7.0, width: size.width, height: 68.0)
        XCTAssertEqual(chatMediaEditorQualityPanelFrame(size: size, safeInsets: insets, toolbarSide: nil), expected)
        XCTAssertEqual(expected, CGRect(x: 0.0, y: 723.0, width: 402.0, height: 68.0))
    }

    func testQualityPanelFrameLandscapeLeft() {
        let size = CGSize(width: 874.0, height: 402.0)
        let insets = UIEdgeInsets(top: 0.0, left: 62.0, bottom: 20.0, right: 62.0)
        XCTAssertEqual(chatMediaEditorQualityPanelFrame(size: size, safeInsets: insets, toolbarSide: .left), CGRect(x: 111.0, y: 0.0, width: 75.0, height: 382.0))
    }

    func testQualityPanelFrameLandscapeRight() {
        let size = CGSize(width: 874.0, height: 402.0)
        let insets = UIEdgeInsets(top: 0.0, left: 62.0, bottom: 20.0, right: 62.0)
        XCTAssertEqual(chatMediaEditorQualityPanelFrame(size: size, safeInsets: insets, toolbarSide: .right), CGRect(x: 688.0, y: 0.0, width: 75.0, height: 382.0))
    }
}
