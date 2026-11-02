import Foundation
import UIKit
import AVFoundation
import Display
import SwiftSignalKit
import TelegramCore
import ComponentFlow
import TelegramPresentationData
import MediaEditor
import MediaEditorScreen
import MediaScrubberComponent
import ChatMediaSend

let chatMediaEditorPreferredVideoPresetKey = "TG_preferredVideoPreset_v0"

public func chatMediaEditorVideoQualityPreset(storedLegacyPreset: Int?) -> MediaQualityPreset {
    guard let storedLegacyPreset else {
        return .compressedMedium
    }
    return MediaQualityPreset(legacyPresetRawValue: UInt32(clamping: storedLegacyPreset))
}

func chatMediaEditorPreferredVideoQualityPreset() -> MediaQualityPreset {
    let storedValue = (UserDefaults.standard.object(forKey: chatMediaEditorPreferredVideoPresetKey) as? NSNumber)?.intValue
    return chatMediaEditorVideoQualityPreset(storedLegacyPreset: storedValue)
}

public func chatMediaEditorCanResumePlayback(isSending: Bool, isInvalidated: Bool, isDismissing: Bool) -> Bool {
    return !isSending && !isInvalidated && !isDismissing
}

private let chatMediaEditorScrubberMinDuration: Double = 1.0
private let chatMediaEditorScrubberPositionTrackingSource = "scrubberPosition"
private let chatMediaEditorScrubberTrimTrackingSource = "scrubberTrim"

extension ChatMediaEditorScreen.Node {
    var canResumePlayback: Bool {
        return chatMediaEditorCanResumePlayback(isSending: self.isSending, isInvalidated: self.isInvalidated, isDismissing: self.controller?.isDismissing ?? true)
    }

    func setupVideo() {
        self.previewTapRecognizer.addTarget(self, action: #selector(self.previewTapped))
        self.previewContainerView.addGestureRecognizer(self.previewTapRecognizer)
    }

    private func startPlayerStateUpdates(framesCount: Int) {
        let disposable = MetaDisposable()
        self.playerStateDisposable = disposable
        disposable.set((self.mediaEditor.playerState(framesCount: framesCount)
        |> deliverOnMainQueue).startStrict(next: { [weak self] playerState in
            guard let self else {
                return
            }
            if self.playerState != playerState {
                self.playerState = playerState
                if playerState?.isPlaying == true {
                    self.hasStartedPlayback = true
                }
                if let layout = self.validLayout {
                    self.updateScrubber(layout: layout, safeInsets: self.editorSafeInsets(layout: layout), transition: .immediate)
                    self.updateCoverScrubber(layout: layout, safeInsets: self.editorSafeInsets(layout: layout), transition: .immediate)
                    self.updateMuteButton(layout: layout, safeInsets: self.editorSafeInsets(layout: layout), transition: .animated(duration: 0.2, curve: .easeInOut))
                }
                self.updatePlayButton(transition: .animated(duration: 0.2, curve: .easeInOut))
            }
        }))
    }

    @objc private func previewTapped() {
        guard self.subject.isVideo, self.activeTool == nil, !self.isSending, !self.isInvalidated else {
            return
        }
        self.mediaEditor.togglePlayback()
    }

    func updateScrubber(layout: ContainerViewLayout, safeInsets: UIEdgeInsets, transition: ComponentTransition) {
        guard self.subject.isVideo else {
            return
        }
        let toolbarMinY = chatMediaEditorBottomPanelFrame(size: layout.size, safeInsets: safeInsets, toolbarHeight: chatMediaEditorToolbarHeight).minY
        let toolbarSide = self.toolbarSide(layout: layout)
        let headerFrame = chatMediaEditorVideoHeaderFrame(size: layout.size, toolbarMinY: toolbarMinY, captionBaseHeight: self.captionPanelView?.baseHeight() ?? 0.0, safeInsets: safeInsets, toolbarSide: toolbarSide, reservedCorners: layout.reservedCorners)
        let availableWidth = chatMediaEditorScrubberFrame(size: layout.size, safeInsets: safeInsets, headerFrame: headerFrame, scrubberHeight: 0.0, toolbarSide: toolbarSide).width
        let framesCount = chatMediaEditorScrubberFramesCount(trackWidth: availableWidth, mediaSize: self.subject.dimensions.cgSize)
        if !self.isInvalidated && (self.playerStateDisposable == nil || self.playerStateFramesCount != framesCount) {
            self.playerStateDisposable?.dispose()
            self.playerStateFramesCount = framesCount
            self.startPlayerStateUpdates(framesCount: framesCount)
        }
        guard let playerState = self.playerState, let mainTrack = playerState.tracks.first(where: { $0.id == 0 }) else {
            return
        }
        let mediaEditor = self.mediaEditor
        let scrubberSize = self.scrubber.update(
            transition: transition,
            component: AnyComponent(MediaScrubberComponent(
                context: self.context,
                style: .editor,
                theme: defaultDarkColorPresentationTheme,
                generationTimestamp: playerState.generationTimestamp,
                position: playerState.position,
                minDuration: chatMediaEditorScrubberMinDuration,
                maxDuration: max(chatMediaEditorScrubberMinDuration, mainTrack.duration),
                isPlaying: playerState.isPlaying,
                tracks: [MediaScrubberComponent.Track(mainTrack)],
                isCollage: false,
                allowsTrimming: !self.isFilePreview,
                positionUpdated: { [weak self, weak mediaEditor] position, apply in
                    self?.setScrubberTracking(!apply, source: chatMediaEditorScrubberPositionTrackingSource)
                    mediaEditor?.seek(position, andPlay: apply)
                },
                trackTrimUpdated: { [weak self, weak mediaEditor] _, start, end, updatedEnd, apply in
                    self?.setScrubberTracking(!apply, source: chatMediaEditorScrubberTrimTrackingSource)
                    guard let mediaEditor else {
                        return
                    }
                    mediaEditor.setVideoTrimRange(start ..< end, apply: apply)
                    if apply {
                        mediaEditor.seek(start, completion: { [weak self, weak mediaEditor] in
                            guard let self else {
                                return
                            }
                            guard self.canResumePlayback else {
                                self.updatePlayButton(transition: .animated(duration: 0.2, curve: .easeInOut))
                                return
                            }
                            mediaEditor?.play()
                        })
                    } else {
                        mediaEditor.seek(updatedEnd ? end : start, andPlay: false)
                    }
                },
                trackOffsetUpdated: { _, _, _ in
                },
                trackLongPressed: { _, _ in
                }
            )),
            environment: {},
            containerSize: CGSize(width: availableWidth, height: layout.size.height)
        )
        guard let scrubberView = self.scrubber.view else {
            return
        }
        let scrubberFrame = chatMediaEditorScrubberFrame(size: layout.size, safeInsets: safeInsets, headerFrame: headerFrame, scrubberHeight: scrubberSize.height, toolbarSide: toolbarSide)
        let isToolActive = self.activeTool != nil || self.isInterfaceHiddenBySwipe || self.isEditingCaption || (layout.inputHeight ?? 0.0) > 0.0
        if scrubberView.superview == nil {
            self.view.insertSubview(scrubberView, aboveSubview: self.pagerView)
            scrubberView.frame = scrubberFrame
        } else {
            transition.setFrame(view: scrubberView, frame: scrubberFrame)
        }
        transition.setAlpha(view: scrubberView, alpha: isToolActive ? 0.0 : 1.0)
        scrubberView.isUserInteractionEnabled = !isToolActive
    }

    var isScrubberTracking: Bool {
        let sources = self.interactionTracking.sources
        return sources.contains(chatMediaEditorScrubberPositionTrackingSource) || sources.contains(chatMediaEditorScrubberTrimTrackingSource)
    }

    private func setScrubberTracking(_ tracking: Bool, source: String) {
        self.setInteractionTracking(tracking, source: source)
        if tracking {
            self.updatePlayButton(transition: .animated(duration: 0.2, curve: .easeInOut))
        }
    }

    func releaseScrubberTracking() {
        self.setInteractionTracking(false, source: chatMediaEditorScrubberPositionTrackingSource)
        self.setInteractionTracking(false, source: chatMediaEditorScrubberTrimTrackingSource)
        self.updatePlayButton(transition: .immediate)
    }

    func sendVideo(path: String, duration: Double, values: MediaEditorValues, caption: NSAttributedString, stickers: [TelegramMediaFile], completion: @escaping (ChatMediaEditorResult) -> Void) {
        self.mediaEditor.stop()

        let firstFrameTime = CMTime(seconds: values.videoTrimRange?.lowerBound ?? 0.0, preferredTimescale: CMTimeScale(60))
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: URL(fileURLWithPath: path)))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: firstFrameTime)], completionHandler: { [weak self] _, cgImage, _, _, _ in
            let _ = generator
            let firstFrame = cgImage.flatMap { UIImage(cgImage: $0) }
            Queue.mainQueue().async {
                guard let self, let controller = self.controller, !controller.isDismissing, !self.isInvalidated else {
                    return
                }
                if let firstFrame {
                    self.mediaEditor.replaceSource(firstFrame, additionalImage: nil, time: firstFrameTime, mirror: false)
                }
                let input: MediaEditorCompositionInput = self.mediaEditor.resultTexture().map { .editorResult($0) } ?? .image(firstFrame ?? UIImage())
                makeChatEditorImageComposition(accountContext: self.context, input: input, values: values, time: firstFrameTime, maxOutputSide: chatMediaEditorImageMaxSide(forceHd: chatMediaEditorSendsForceHd), completion: { [weak self] thumbnail in
                    guard let self, let controller = self.controller, !controller.isDismissing, !self.isInvalidated else {
                        return
                    }
                    let result = ChatMediaEditorResult(
                        media: .video(path: path, values: values, duration: duration),
                        thumbnail: thumbnail,
                        caption: caption,
                        stickers: stickers,
                        isAnimation: self.pageModel.currentItem.isAnimation
                    )
                    completion(result)
                })
            }
        })
    }
}
