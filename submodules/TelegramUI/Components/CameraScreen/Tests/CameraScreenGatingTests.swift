import XCTest

final class CameraScreenGatingTests: XCTestCase {
    func testChatModeHidesStoryControls() {
        let chat = cameraScreenStoryControls(mode: .chat)
        XCTAssertFalse(chat.dualCamera)
        XCTAssertFalse(chat.collage)
        XCTAssertFalse(chat.liveStream)
        XCTAssertFalse(chat.storyGallery)
        XCTAssertFalse(chat.tooltips)
        XCTAssertFalse(chat.storyPrivacy)
        XCTAssertFalse(chat.recentGalleryAsset)

        let story = cameraScreenStoryControls(mode: .story)
        XCTAssertEqual(story, CameraScreenStoryControls(dualCamera: true, collage: true, liveStream: true, storyGallery: true, tooltips: true, storyPrivacy: true, recentGalleryAsset: true))

        for mode in [CameraScreenModeKind.sticker, .avatar] {
            XCTAssertEqual(cameraScreenStoryControls(mode: mode), CameraScreenStoryControls(dualCamera: false, collage: false, liveStream: false, storyGallery: false, tooltips: true, storyPrivacy: true, recentGalleryAsset: true))
        }

        XCTAssertTrue(cameraScreenUsesModalPresentation(mode: .chat))
        XCTAssertTrue(cameraScreenUsesModalPresentation(mode: .sticker))
        XCTAssertTrue(cameraScreenUsesModalPresentation(mode: .avatar))
        XCTAssertFalse(cameraScreenUsesModalPresentation(mode: .story))

        XCTAssertTrue(cameraScreenInvalidatesCameraOnDismiss(mode: .chat, hasHolder: false))
        XCTAssertFalse(cameraScreenInvalidatesCameraOnDismiss(mode: .chat, hasHolder: true))
        XCTAssertTrue(cameraScreenInvalidatesCameraOnDismiss(mode: .story, hasHolder: false))
        XCTAssertTrue(cameraScreenInvalidatesCameraOnDismiss(mode: .story, hasHolder: true))
        XCTAssertFalse(cameraScreenInvalidatesCameraOnDismiss(mode: .sticker, hasHolder: false))
        XCTAssertFalse(cameraScreenInvalidatesCameraOnDismiss(mode: .avatar, hasHolder: true))

        XCTAssertEqual(cameraScreenPreviewAspectRatio(mode: .chat, captureKind: .photo, isTablet: false), 4.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(cameraScreenPreviewAspectRatio(mode: .chat, captureKind: .video, isTablet: false), 1.77778, accuracy: 0.0001)
        XCTAssertEqual(cameraScreenPreviewAspectRatio(mode: .chat, captureKind: .photo, isTablet: true), 1.77778, accuracy: 0.0001)
        for mode in [CameraScreenModeKind.story, .sticker, .avatar] {
            XCTAssertEqual(cameraScreenPreviewAspectRatio(mode: mode, captureKind: .photo, isTablet: false), 1.77778, accuracy: 0.0001)
        }

        XCTAssertEqual(cameraScreenHoldMinimumPressDuration(mode: .chat), 0.25)
        XCTAssertEqual(cameraScreenHoldMinimumPressDuration(mode: .story), 0.3)
        XCTAssertEqual(cameraScreenHoldMinimumPressDuration(mode: .avatar), 0.3)
    }

    func testMicNotRequiredForPhoto() {
        XCTAssertFalse(cameraScreenRequiresMicrophone(mode: .chat))
        for mode in [CameraScreenModeKind.story, .sticker, .avatar] {
            XCTAssertTrue(cameraScreenRequiresMicrophone(mode: mode))
        }

        XCTAssertTrue(cameraScreenHasAllRequiredAccess(mode: .chat, camera: .allowed, microphone: .denied))
        XCTAssertTrue(cameraScreenHasAllRequiredAccess(mode: .chat, camera: .notDetermined, microphone: .denied))
        XCTAssertFalse(cameraScreenHasAllRequiredAccess(mode: .chat, camera: .denied, microphone: .allowed))
        XCTAssertFalse(cameraScreenHasAllRequiredAccess(mode: .story, camera: .allowed, microphone: .denied))
        XCTAssertTrue(cameraScreenHasAllRequiredAccess(mode: .story, camera: .allowed, microphone: .notDetermined))
        XCTAssertTrue(cameraScreenHasAllRequiredAccess(mode: .story, camera: .notDetermined, microphone: .denied))
        XCTAssertFalse(cameraScreenHasAllRequiredAccess(mode: .sticker, camera: .denied, microphone: .allowed))

        XCTAssertTrue(cameraScreenCanSetupCamera(mode: .chat, camera: .allowed, microphone: .denied))
        XCTAssertTrue(cameraScreenCanSetupCamera(mode: .chat, camera: .allowed, microphone: .notDetermined))
        XCTAssertFalse(cameraScreenCanSetupCamera(mode: .chat, camera: .notDetermined, microphone: .allowed))
        XCTAssertFalse(cameraScreenCanSetupCamera(mode: .story, camera: .allowed, microphone: .denied))
        XCTAssertFalse(cameraScreenCanSetupCamera(mode: .story, camera: .allowed, microphone: .notDetermined))
        XCTAssertTrue(cameraScreenCanSetupCamera(mode: .story, camera: .allowed, microphone: .allowed))

        XCTAssertFalse(cameraScreenRequestsMicrophone(mode: .chat, allowVideo: false, hasAudio: true))
        XCTAssertFalse(cameraScreenRequestsMicrophone(mode: .chat, allowVideo: true, hasAudio: false))
        XCTAssertTrue(cameraScreenRequestsMicrophone(mode: .chat, allowVideo: true, hasAudio: true))
        XCTAssertTrue(cameraScreenRequestsMicrophone(mode: .story, allowVideo: true, hasAudio: true))

        XCTAssertFalse(cameraScreenPushesAudioSessionOnActivation(mode: .chat))
        for mode in [CameraScreenModeKind.story, .sticker, .avatar] {
            XCTAssertTrue(cameraScreenPushesAudioSessionOnActivation(mode: mode))
        }
    }

    func testNoDurationLimitInChat() {
        XCTAssertNil(cameraScreenMaxRecordingDuration(mode: .chat))
        XCTAssertFalse(cameraScreenShouldStopRecording(mode: .chat, duration: 59.5))
        XCTAssertFalse(cameraScreenShouldStopRecording(mode: .chat, duration: 7200.0))
        XCTAssertEqual(cameraScreenHoldRecordingProgress(mode: .chat, duration: 30.0), 0.0)
        XCTAssertEqual(cameraScreenHoldRecordingProgress(mode: .chat, duration: 90.0), 0.0)

        for mode in [CameraScreenModeKind.story, .sticker, .avatar] {
            XCTAssertEqual(cameraScreenMaxRecordingDuration(mode: mode), 59.0)
            XCTAssertFalse(cameraScreenShouldStopRecording(mode: mode, duration: 59.0))
            XCTAssertTrue(cameraScreenShouldStopRecording(mode: mode, duration: 59.01))
            XCTAssertEqual(cameraScreenHoldRecordingProgress(mode: mode, duration: 30.0), 0.5)
            XCTAssertEqual(cameraScreenHoldRecordingProgress(mode: mode, duration: 90.0), 1.0)
        }
    }

    func testModesFromBans() {
        XCTAssertEqual(cameraScreenAvailableModes(mode: .chat, allowPhoto: true, allowVideo: true, canLivestream: false, isTablet: false), [.photo, .video])
        XCTAssertEqual(cameraScreenAvailableModes(mode: .chat, allowPhoto: false, allowVideo: true, canLivestream: true, isTablet: false), [.video])
        XCTAssertEqual(cameraScreenAvailableModes(mode: .chat, allowPhoto: true, allowVideo: false, canLivestream: false, isTablet: false), [.photo])
        XCTAssertEqual(cameraScreenAvailableModes(mode: .story, allowPhoto: true, allowVideo: true, canLivestream: true, isTablet: false), [.photo, .video, .live])
        XCTAssertEqual(cameraScreenAvailableModes(mode: .story, allowPhoto: true, allowVideo: true, canLivestream: true, isTablet: true), [.photo, .video])
        XCTAssertEqual(cameraScreenAvailableModes(mode: .avatar, allowPhoto: true, allowVideo: true, canLivestream: false, isTablet: false), [.photo, .video])

        XCTAssertTrue(cameraScreenShowsModeControl(mode: .chat, availableModes: [.photo, .video]))
        XCTAssertFalse(cameraScreenShowsModeControl(mode: .chat, availableModes: [.photo]))
        XCTAssertFalse(cameraScreenShowsModeControl(mode: .chat, availableModes: [.video]))
        XCTAssertFalse(cameraScreenShowsModeControl(mode: .sticker, availableModes: [.photo, .video]))
        XCTAssertTrue(cameraScreenShowsModeControl(mode: .story, availableModes: [.photo, .video]))
        XCTAssertTrue(cameraScreenShowsModeControl(mode: .avatar, availableModes: [.photo, .video]))

        XCTAssertEqual(chatCameraInitialMode(allowPhoto: true, allowVideo: true), .photo)
        XCTAssertEqual(chatCameraInitialMode(allowPhoto: true, allowVideo: false), .photo)
        XCTAssertEqual(chatCameraInitialMode(allowPhoto: false, allowVideo: true), .video)

        XCTAssertTrue(cameraScreenAllowsHoldToRecord(mode: .chat, allowVideo: true))
        XCTAssertFalse(cameraScreenAllowsHoldToRecord(mode: .chat, allowVideo: false))
        XCTAssertFalse(cameraScreenAllowsHoldToRecord(mode: .sticker, allowVideo: true))
        XCTAssertTrue(cameraScreenAllowsHoldToRecord(mode: .story, allowVideo: true))
        XCTAssertTrue(cameraScreenAllowsHoldToRecord(mode: .avatar, allowVideo: true))

        XCTAssertEqual(chatCameraRecordingCaptureModes(captureKind: .photo), ChatCameraRecordingCaptureModes(beforeRecording: .video, afterRecording: .photo))
        XCTAssertEqual(chatCameraRecordingCaptureModes(captureKind: .video), ChatCameraRecordingCaptureModes(beforeRecording: nil, afterRecording: nil))
    }

    func testTimecodeFormatPastHour() {
        XCTAssertEqual(cameraScreenTimecode(mode: .chat, duration: 0.0), "00:00")
        XCTAssertEqual(cameraScreenTimecode(mode: .chat, duration: 65.4), "01:05")
        XCTAssertEqual(cameraScreenTimecode(mode: .chat, duration: 3599.9), "59:59")
        XCTAssertEqual(cameraScreenTimecode(mode: .chat, duration: 3600.0), "1:00:00")
        XCTAssertEqual(cameraScreenTimecode(mode: .chat, duration: 3725.0), "1:02:05")
        XCTAssertEqual(cameraScreenTimecode(mode: .chat, duration: 36125.0), "10:02:05")

        XCTAssertEqual(cameraScreenTimecode(mode: .story, duration: 65.0), "01:05")
        XCTAssertEqual(cameraScreenTimecode(mode: .story, duration: 3725.0), "02:05")
        XCTAssertEqual(cameraScreenTimecode(mode: .sticker, duration: 59.0), "00:59")
    }

    func testFlashModesInChat() {
        XCTAssertEqual(cameraScreenNextFlashMode(mode: .chat, current: .off, captureKind: .photo), .auto)
        XCTAssertEqual(cameraScreenNextFlashMode(mode: .chat, current: .auto, captureKind: .photo), .off)
        XCTAssertEqual(cameraScreenNextFlashMode(mode: .chat, current: .on, captureKind: .photo), .off)
        XCTAssertEqual(cameraScreenNextFlashMode(mode: .chat, current: .off, captureKind: .video), .auto)
        XCTAssertEqual(cameraScreenNextFlashMode(mode: .chat, current: .on, captureKind: .video), .off)
        XCTAssertEqual(cameraScreenNextFlashMode(mode: .chat, current: .auto, captureKind: .video), .off)

        for mode in [CameraScreenModeKind.story, .sticker, .avatar] {
            XCTAssertEqual(cameraScreenNextFlashMode(mode: mode, current: .off, captureKind: .photo), .on)
            XCTAssertEqual(cameraScreenNextFlashMode(mode: mode, current: .on, captureKind: .photo), .auto)
            XCTAssertEqual(cameraScreenNextFlashMode(mode: mode, current: .auto, captureKind: .photo), .off)
            XCTAssertEqual(cameraScreenNextFlashMode(mode: mode, current: .on, captureKind: .video), .off)
        }

        XCTAssertNil(cameraScreenFlashModeAfterModeSwitch(mode: .chat, current: .auto, to: .video))
        XCTAssertNil(cameraScreenFlashModeAfterModeSwitch(mode: .chat, current: .auto, to: .photo))
        XCTAssertEqual(cameraScreenFlashModeAfterModeSwitch(mode: .chat, current: .on, to: .photo), .auto)
        XCTAssertEqual(cameraScreenFlashModeAfterModeSwitch(mode: .chat, current: .on, to: .video), .auto)
        XCTAssertNil(cameraScreenFlashModeAfterModeSwitch(mode: .chat, current: .off, to: .photo))
        XCTAssertNil(cameraScreenFlashModeAfterModeSwitch(mode: .chat, current: .off, to: .video))
        XCTAssertEqual(cameraScreenFlashModeAfterModeSwitch(mode: .story, current: .auto, to: .video), .on)
        XCTAssertNil(cameraScreenFlashModeAfterModeSwitch(mode: .story, current: .on, to: .photo))
    }

    func testChatZoomScale() {
        let levels: [Float] = [0.5, 1.0, 2.0, 8.0]
        XCTAssertEqual(chatCameraClampedZoomScale(levels: levels, scale: 0.2), 0.5)
        XCTAssertEqual(chatCameraClampedZoomScale(levels: levels, scale: 12.0), 8.0)
        XCTAssertEqual(chatCameraClampedZoomScale(levels: [1.0, 2.0], scale: 0.5), 1.0)
        XCTAssertEqual(chatCameraClampedZoomScale(levels: [1.0, 2.0], scale: 9.0), 8.0)
        XCTAssertEqual(chatCameraClampedZoomScale(levels: [1.0, 2.0], scale: 3.0), 3.0)

        XCTAssertEqual(chatCameraSelectedZoomLevel(levels: levels, scale: 1.0), 1.0)
        XCTAssertEqual(chatCameraSelectedZoomLevel(levels: levels, scale: 1.7), 1.0)
        XCTAssertEqual(chatCameraSelectedZoomLevel(levels: levels, scale: 0.7), 0.5)
        XCTAssertEqual(chatCameraSelectedZoomLevel(levels: levels, scale: 2.0), 2.0)
        XCTAssertEqual(chatCameraSelectedZoomLevel(levels: levels, scale: 7.99), 2.0)
        XCTAssertEqual(chatCameraSelectedZoomLevel(levels: levels, scale: 8.0), 8.0)

        XCTAssertEqual(chatCameraZoomLabel(level: 1.0, selected: true, scale: 1.0), "1×")
        XCTAssertEqual(chatCameraZoomLabel(level: 1.0, selected: true, scale: 1.46), "1.5×")
        XCTAssertEqual(chatCameraZoomLabel(level: 2.0, selected: false, scale: 1.0), "2")
        XCTAssertEqual(chatCameraZoomLabel(level: 0.5, selected: false, scale: 1.0), "0.5")
        XCTAssertEqual(chatCameraZoomLabel(level: 0.5, selected: true, scale: 0.5), "0.5×")
    }

    func testChatQRCodeDeduplication() {
        XCTAssertEqual(chatCameraUnseenQRCodes(["a", "b", "a"], seen: []), ["a", "b"])
        XCTAssertEqual(chatCameraUnseenQRCodes(["a", "c"], seen: ["a"]), ["c"])
        XCTAssertEqual(chatCameraUnseenQRCodes(["a", "b", "c"], seen: ["a", "b", "c"]), [])
    }

    func testChatAudioSessionOnlyForVideo() {
        XCTAssertFalse(chatCameraNeedsAudioSession(captureKind: .photo, isRecording: false, allowVideo: true, hasAudio: true))
        XCTAssertTrue(chatCameraNeedsAudioSession(captureKind: .photo, isRecording: true, allowVideo: true, hasAudio: true))
        XCTAssertTrue(chatCameraNeedsAudioSession(captureKind: .video, isRecording: false, allowVideo: true, hasAudio: true))
        XCTAssertFalse(chatCameraNeedsAudioSession(captureKind: .video, isRecording: true, allowVideo: true, hasAudio: false))
        XCTAssertFalse(chatCameraNeedsAudioSession(captureKind: .video, isRecording: false, allowVideo: false, hasAudio: true))
    }

    func testHoldRecordingIsVideoInterface() {
        XCTAssertEqual(chatCameraEffectiveCaptureKind(captureKind: .photo, isRecording: false), .photo)
        XCTAssertEqual(chatCameraEffectiveCaptureKind(captureKind: .photo, isRecording: true), .video)
        XCTAssertEqual(chatCameraEffectiveCaptureKind(captureKind: .video, isRecording: false), .video)
        XCTAssertEqual(chatCameraEffectiveCaptureKind(captureKind: .video, isRecording: true), .video)
    }

    func testHoldSlideZoom() {
        let levels: [Float] = [0.5, 1.0, 2.0, 8.0]
        XCTAssertEqual(chatCameraHoldZoomScale(startScale: 2.0, travel: 0.0, levels: levels), 2.0)
        XCTAssertEqual(chatCameraHoldZoomScale(startScale: 2.0, travel: 1.5, levels: levels), 3.5)
        XCTAssertEqual(chatCameraHoldZoomScale(startScale: 2.0, travel: 20.0, levels: levels), 8.0)
        XCTAssertEqual(chatCameraHoldZoomScale(startScale: 0.5, travel: 0.0, levels: levels), 0.5)
        XCTAssertEqual(chatCameraHoldZoomScale(startScale: 1.0, travel: -3.0, levels: levels), 1.0)

        XCTAssertEqual(chatCameraZoomLevels(backLevels: levels, isFront: false), levels)
        XCTAssertEqual(chatCameraZoomLevels(backLevels: levels, isFront: true), [1.0])
        XCTAssertEqual(chatCameraClampedZoomScale(levels: chatCameraZoomLevels(backLevels: levels, isFront: true), scale: 0.6), 1.0)
    }

    func testExposureDrag() {
        XCTAssertEqual(chatCameraExposureValue(current: 0.0, translation: 75.0), 0.1, accuracy: 0.0001)
        XCTAssertEqual(chatCameraExposureValue(current: 0.5, translation: -750.0), -0.5, accuracy: 0.0001)
        XCTAssertEqual(chatCameraExposureValue(current: 0.9, translation: 300.0), 1.0, accuracy: 0.0001)
        XCTAssertEqual(chatCameraExposureValue(current: -0.9, translation: -300.0), -1.0, accuracy: 0.0001)
        XCTAssertEqual(chatCameraExposureBias(value: 0.4), -0.4, accuracy: 0.0001)
        XCTAssertEqual(chatCameraExposureSliderOffset(value: 1.0), 59.5, accuracy: 0.0001)
        XCTAssertEqual(chatCameraExposureSliderOffset(value: -1.0), -59.5, accuracy: 0.0001)
        XCTAssertEqual(chatCameraExposureSliderOffset(value: 0.0), 0.0, accuracy: 0.0001)
    }

    func testHoldLockHintWithoutGallery() {
        XCTAssertEqual(captureControlsLockReferenceFrameWithoutGallery(isChat: true, isTablet: false, isSticker: false, controlsHeight: 120.0, sideInset: 28.0), CGRect(x: 28.0, y: 36.0, width: 48.0, height: 48.0))
        XCTAssertEqual(captureControlsLockReferenceFrameWithoutGallery(isChat: true, isTablet: false, isSticker: true, controlsHeight: 120.0, sideInset: 28.0), .zero)
        XCTAssertEqual(captureControlsLockReferenceFrameWithoutGallery(isChat: true, isTablet: true, isSticker: false, controlsHeight: 120.0, sideInset: 28.0), .zero)
        XCTAssertEqual(captureControlsLockReferenceFrameWithoutGallery(isChat: false, isTablet: false, isSticker: false, controlsHeight: 120.0, sideInset: 28.0), .zero)
    }

    func testVideoStopTransitionSkippedInChat() {
        XCTAssertTrue(cameraScreenTransitionsAfterVideoRecording(mode: .story, isCollageEnabled: false))
        XCTAssertFalse(cameraScreenTransitionsAfterVideoRecording(mode: .story, isCollageEnabled: true))
        XCTAssertTrue(cameraScreenTransitionsAfterVideoRecording(mode: .avatar, isCollageEnabled: false))
        XCTAssertTrue(cameraScreenTransitionsAfterVideoRecording(mode: .sticker, isCollageEnabled: false))
        XCTAssertFalse(cameraScreenTransitionsAfterVideoRecording(mode: .chat, isCollageEnabled: false))
    }

    func testDocumentFrameBand() {
        let rects = cameraScreenDocumentFrameDimRects(containerSize: CGSize(width: 390.0, height: 520.0))
        let bandHeight: CGFloat = 390.0 * 704.0 / 1000.0
        XCTAssertEqual(rects.top, CGRect(x: 0.0, y: 0.0, width: 390.0, height: (520.0 - bandHeight) / 2.0))
        XCTAssertEqual(rects.bottom.minX, 0.0)
        XCTAssertEqual(rects.bottom.width, 390.0)
        XCTAssertEqual(rects.bottom.minY, (520.0 + bandHeight) / 2.0, accuracy: 0.0001)
        XCTAssertEqual(rects.bottom.maxY, 520.0, accuracy: 0.0001)
        XCTAssertEqual(rects.bottom.minY - rects.top.maxY, bandHeight, accuracy: 0.0001)
        XCTAssertEqual(cameraScreenDocumentFrameDimAlpha, 0.7)
    }

    func testChatCameraFrontPreferenceAndMirroring() {
        XCTAssertFalse(chatCameraInitialFrontPosition(storedFront: false, prefersFront: false, fixesPosition: false))
        XCTAssertTrue(chatCameraInitialFrontPosition(storedFront: true, prefersFront: false, fixesPosition: false))
        XCTAssertTrue(chatCameraInitialFrontPosition(storedFront: false, prefersFront: true, fixesPosition: false))
        XCTAssertFalse(chatCameraInitialFrontPosition(storedFront: true, prefersFront: false, fixesPosition: true))
        XCTAssertTrue(chatCameraInitialFrontPosition(storedFront: false, prefersFront: true, fixesPosition: true))
        XCTAssertTrue(chatCameraPersistsPosition(fixesPosition: false))
        XCTAssertFalse(chatCameraPersistsPosition(fixesPosition: true))
        XCTAssertFalse(chatCameraUnmirrorsResult(isFront: true, mirrorsFrontResult: true))
        XCTAssertTrue(chatCameraUnmirrorsResult(isFront: true, mirrorsFrontResult: false))
        XCTAssertFalse(chatCameraUnmirrorsResult(isFront: false, mirrorsFrontResult: false))
    }

    func testEditorHandoffOnlyFromAVisibleBottomRow() {
        XCTAssertTrue(cameraScreenEditorHandoffAvailable(mode: .story, isTablet: false, isRecording: false, isCollageComplete: false, isTransitioning: false))
        XCTAssertTrue(cameraScreenEditorHandoffAvailable(mode: .chat, isTablet: false, isRecording: false, isCollageComplete: false, isTransitioning: false))
        XCTAssertFalse(cameraScreenEditorHandoffAvailable(mode: .story, isTablet: false, isRecording: true, isCollageComplete: false, isTransitioning: false))
        XCTAssertFalse(cameraScreenEditorHandoffAvailable(mode: .story, isTablet: false, isRecording: false, isCollageComplete: false, isTransitioning: true))
        XCTAssertFalse(cameraScreenEditorHandoffAvailable(mode: .story, isTablet: false, isRecording: false, isCollageComplete: true, isTransitioning: false))
        XCTAssertFalse(cameraScreenEditorHandoffAvailable(mode: .story, isTablet: true, isRecording: false, isCollageComplete: false, isTransitioning: false))
        XCTAssertFalse(cameraScreenEditorHandoffAvailable(mode: .sticker, isTablet: false, isRecording: false, isCollageComplete: false, isTransitioning: false))
        XCTAssertFalse(cameraScreenEditorHandoffAvailable(mode: .avatar, isTablet: false, isRecording: false, isCollageComplete: false, isTransitioning: false))
    }

    func testGalleryThumbnailFillsItsGlass() {
        XCTAssertEqual(cameraScreenGalleryThumbnailInset, 0.0)
    }

    func testCounterTransformKeepsTheBottomRowStillUnderAShrinkingCamera() {
        let container = CameraScreenContainerScale(scale: 0.92, offset: CGPoint(x: 0.0, y: -20.0), center: CGPoint(x: 201.0, y: 437.0))
        let center = CGPoint(x: 40.0, y: 814.0)
        let counter = container.counterTransform(at: center)
        for d in [CGPoint(x: 0.0, y: 0.0), CGPoint(x: -24.0, y: 24.0), CGPoint(x: 18.0, y: -10.0)] {
            let local = CGPoint(x: center.x + d.x * counter.scale + counter.translation.x, y: center.y + d.y * counter.scale + counter.translation.y)
            let rendered = CGPoint(x: container.center.x + container.scale * (local.x - container.center.x + container.offset.x), y: container.center.y + container.scale * (local.y - container.center.y + container.offset.y))
            XCTAssertEqual(rendered.x, center.x + d.x, accuracy: 0.0001)
            XCTAssertEqual(rendered.y, center.y + d.y, accuracy: 0.0001)
        }
        XCTAssertEqual(CameraScreenContainerScale(scale: 1.0, offset: .zero, center: CGPoint(x: 201.0, y: 437.0)).counterTransform(at: center), .identity)
    }
}
