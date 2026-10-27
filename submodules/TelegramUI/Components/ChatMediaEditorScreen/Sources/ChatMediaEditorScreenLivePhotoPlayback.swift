import Foundation
import UIKit
import Photos
import SwiftSignalKit
import AccountContext
import MediaEditor
import ChatMediaSend

private final class ChatMediaEditorLivePhotoDisplayLinkTarget: NSObject {
    private let tick: (CADisplayLink) -> Void

    init(tick: @escaping (CADisplayLink) -> Void) {
        self.tick = tick
    }

    @objc func displayLinkTick(_ displayLink: CADisplayLink) {
        self.tick(displayLink)
    }
}

final class ChatMediaEditorLivePhotoGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    var gatesTap: (UIGestureRecognizer) -> Bool = { _ in false }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return self.gatesTap(otherGestureRecognizer)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

private let chatMediaEditorLivePhotoEndTolerance: Double = 0.05
private let chatMediaEditorLivePhotoStartTolerance: Double = 0.02

final class ChatMediaEditorLivePhotoPlayer {
    let uniqueId: String
    let previewView: MediaEditorPreviewView
    private let context: AccountContext
    private let videoDisposable = MetaDisposable()
    private var mediaEditor: MediaEditor?
    private var duration: Double = 0.0
    private var isReady = false
    private var isShowingVideo = false
    private var pendingAction: ChatMediaEditorLivePhotoPlaybackAction?
    private var displayLink: CADisplayLink?
    private var isReversing = false
    private var reversePosition: Double = 0.0
    private var lastForwardPosition: Double = 0.0
    private var isAwaitingRestart = false
    private var isInvalidated = false
    var fadesOut = true

    var reachedEnd: (() -> Void)?
    var reachedStart: (() -> Void)?

    init(context: AccountContext, uniqueId: String, identifier: String, photoValues: MediaEditorValues) {
        self.context = context
        self.uniqueId = uniqueId
        self.previewView = MediaEditorPreviewView(frame: .zero)
        self.previewView.alpha = 0.0
        self.previewView.isUserInteractionEnabled = false

        self.videoDisposable.set((chatMediaSendLivePhotoPairedVideo(identifier: identifier)
        |> deliverOnMainQueue).startStrict(next: { [weak self] video in
            self?.videoLoaded(video, photoValues: photoValues)
        }))
    }

    deinit {
        self.videoDisposable.dispose()
        self.displayLink?.invalidate()
        if let mediaEditor = self.mediaEditor, !self.isInvalidated {
            Queue.mainQueue().async {
                mediaEditor.stop()
                mediaEditor.invalidate()
            }
        }
    }

    private func videoLoaded(_ video: ChatMediaSendLivePhotoVideo?, photoValues: MediaEditorValues) {
        guard let video, !self.isInvalidated else {
            return
        }
        let values = chatMediaSendLivePhotoVideoValues(photoValues: photoValues, video: video, mode: .loop)
        let mediaEditor = MediaEditor(context: self.context, mode: .default, subject: .video(video.path, nil, false, nil, video.dimensions, video.duration), values: values)
        mediaEditor.maxDuration = .greatestFiniteMagnitude
        self.duration = video.duration
        mediaEditor.onFirstDisplay = { [weak self] in
            Queue.mainQueue().async {
                self?.firstDisplayed()
            }
        }
        self.mediaEditor = mediaEditor
        mediaEditor.attachPreviewView(self.previewView, andPlay: false)
    }

    private func firstDisplayed() {
        guard !self.isInvalidated, !self.isReady else {
            return
        }
        self.isReady = true
        if let pendingAction = self.pendingAction {
            self.pendingAction = nil
            self.apply(pendingAction)
        }
    }

    func apply(_ action: ChatMediaEditorLivePhotoPlaybackAction) {
        guard !self.isInvalidated else {
            return
        }
        switch action {
        case .none, .hide:
            break
        case let .playForward(fromStart):
            guard self.isReady, let mediaEditor = self.mediaEditor else {
                self.pendingAction = action
                return
            }
            self.isReversing = false
            if fromStart {
                self.isAwaitingRestart = true
                self.lastForwardPosition = 0.0
                mediaEditor.seek(0.0, andPlay: true)
            } else {
                self.isAwaitingRestart = false
                self.lastForwardPosition = max(0.0, mediaEditor.currentPosition.seconds)
                mediaEditor.play()
            }
            self.isShowingVideo = true
            self.previewView.layer.removeAllAnimations()
            self.previewView.alpha = 1.0
            self.startDisplayLink()
        case .playBackward:
            guard self.isReady, let mediaEditor = self.mediaEditor else {
                return
            }
            mediaEditor.stop()
            self.isReversing = true
            let position = mediaEditor.currentPosition.seconds
            self.reversePosition = position.isFinite ? max(0.0, min(self.duration, position)) : self.duration
            self.startDisplayLink()
        case .fadeOut:
            self.pendingAction = nil
            self.stopDisplayLink()
            self.isReversing = false
            self.isShowingVideo = false
            guard let mediaEditor = self.mediaEditor else {
                return
            }
            mediaEditor.stop()
            if !self.fadesOut {
                self.previewView.layer.removeAllAnimations()
                self.previewView.alpha = 0.0
                mediaEditor.seek(0.0, andPlay: false)
                return
            }
            UIView.animate(withDuration: chatMediaEditorLivePhotoFadeDuration, animations: {
                self.previewView.alpha = 0.0
            }, completion: { [weak self] _ in
                guard let self, !self.isShowingVideo, !self.isInvalidated else {
                    return
                }
                self.mediaEditor?.seek(0.0, andPlay: false)
            })
        }
    }

    private func startDisplayLink() {
        guard self.displayLink == nil else {
            return
        }
        let target = ChatMediaEditorLivePhotoDisplayLinkTarget(tick: { [weak self] displayLink in
            self?.tick(displayLink)
        })
        let displayLink = CADisplayLink(target: target, selector: #selector(ChatMediaEditorLivePhotoDisplayLinkTarget.displayLinkTick(_:)))
        displayLink.preferredFramesPerSecond = 30
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }

    private func stopDisplayLink() {
        self.displayLink?.invalidate()
        self.displayLink = nil
    }

    private func tick(_ displayLink: CADisplayLink) {
        guard let mediaEditor = self.mediaEditor, !self.isInvalidated else {
            self.stopDisplayLink()
            return
        }
        if self.isReversing {
            let step = max(1.0 / 45.0, displayLink.duration)
            self.reversePosition = max(0.0, self.reversePosition - step)
            mediaEditor.seek(self.reversePosition, andPlay: false)
            if self.reversePosition <= chatMediaEditorLivePhotoStartTolerance {
                self.stopDisplayLink()
                self.isReversing = false
                self.reachedStart?()
            }
            return
        }
        let position = mediaEditor.currentPosition.seconds
        guard position.isFinite, self.duration > 0.0 else {
            return
        }
        if self.isAwaitingRestart {
            if position < min(0.25, self.duration / 2.0) {
                self.isAwaitingRestart = false
                self.lastForwardPosition = position
            }
            return
        }
        if position >= self.duration - chatMediaEditorLivePhotoEndTolerance || position + 0.5 < self.lastForwardPosition {
            self.stopDisplayLink()
            mediaEditor.stop()
            self.reachedEnd?()
            return
        }
        self.lastForwardPosition = position
    }

    func invalidate() {
        guard !self.isInvalidated else {
            return
        }
        self.isInvalidated = true
        self.pendingAction = nil
        self.stopDisplayLink()
        self.videoDisposable.set(nil)
        if let mediaEditor = self.mediaEditor {
            mediaEditor.onFirstDisplay = {}
            mediaEditor.stop()
            mediaEditor.invalidate()
        }
        self.previewView.removeFromSuperview()
    }
}

extension ChatMediaEditorScreen.Node {
    func setupLivePhotoPlayback() {
        guard self.livePhotoModel != nil else {
            return
        }
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.livePhotoPressed(_:)))
        recognizer.minimumPressDuration = chatMediaEditorLivePhotoHoldDuration
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self.livePhotoGestureDelegate
        recognizer.isEnabled = false
        self.livePhotoGestureDelegate.gatesTap = { [weak self] other in
            guard let self, self.livePhotoPlaybackModel.holdGatesTap, let page = self.pagerView.page(at: self.pageModel.currentIndex) else {
                return false
            }
            return other === page.singleTapRecognizer
        }
        self.previewContainerView.addGestureRecognizer(recognizer)
        self.livePhotoPressRecognizer = recognizer
    }

    @objc private func livePhotoPressed(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            self.applyLivePhotoPlaybackAction(self.livePhotoPlaybackModel.holdBegan())
        case .ended, .cancelled, .failed:
            self.applyLivePhotoPlaybackAction(self.livePhotoPlaybackModel.holdEnded())
        default:
            break
        }
    }

    func updateLivePhotoPlayback() {
        let item = self.pageModel.currentItem
        let isLive = self.isLivePhotoButtonVisible
        var mode: ChatMediaSendLivePhotoMode = .off
        if isLive, let livePhotoModel = self.livePhotoModel {
            mode = livePhotoModel.mode(for: item.uniqueId, isLiveAsset: true)
        }
        let isActive = isLive && self.activeTool == nil && !self.isSending && !self.isInvalidated && !(self.controller?.isDismissing ?? true)
        if let player = self.livePhotoPlayer, player.uniqueId != item.uniqueId {
            self.destroyLivePhotoPlayer()
        }
        let action = self.livePhotoPlaybackModel.update(itemId: isLive ? item.uniqueId : nil, mode: mode, isActive: isActive)
        self.livePhotoPressRecognizer?.isEnabled = isActive && mode == .live
        self.applyLivePhotoPlaybackAction(action)
        self.updateLivePhotoPreviewGeometry()
    }

    private func applyLivePhotoPlaybackAction(_ action: ChatMediaEditorLivePhotoPlaybackAction) {
        switch action {
        case .none:
            return
        case .hide:
            self.destroyLivePhotoPlayer()
        case .playForward, .playBackward, .fadeOut:
            guard let player = self.ensureLivePhotoPlayer() else {
                return
            }
            player.fadesOut = chatMediaEditorLivePhotoFadesOut(hasPaintingOverlay: self.hasPaintChanges)
            player.apply(action)
        }
    }

    private func ensureLivePhotoPlayer() -> ChatMediaEditorLivePhotoPlayer? {
        let item = self.pageModel.currentItem
        if let player = self.livePhotoPlayer, player.uniqueId == item.uniqueId {
            return player
        }
        guard case let .asset(asset) = item.source, !self.isInvalidated else {
            return nil
        }
        self.destroyLivePhotoPlayer()
        let player = ChatMediaEditorLivePhotoPlayer(context: self.context, uniqueId: item.uniqueId, identifier: asset.localIdentifier, photoValues: self.mediaEditor.values)
        player.reachedEnd = { [weak self] in
            guard let self else {
                return
            }
            self.applyLivePhotoPlaybackAction(self.livePhotoPlaybackModel.reachedEnd())
        }
        player.reachedStart = { [weak self] in
            guard let self else {
                return
            }
            self.applyLivePhotoPlaybackAction(self.livePhotoPlaybackModel.reachedStart())
        }
        self.livePhotoPlayer = player
        self.updateLivePhotoPreviewGeometry()
        return player
    }

    func updateLivePhotoPreviewGeometry() {
        guard let player = self.livePhotoPlayer else {
            return
        }
        let previewView = self.previewView
        if player.previewView.superview !== self.previewContainerView || previewView.superview !== self.previewContainerView {
            if previewView.superview === self.previewContainerView {
                self.previewContainerView.insertSubview(player.previewView, aboveSubview: previewView)
            } else {
                player.previewView.removeFromSuperview()
                return
            }
        }
        if abs(player.previewView.contentScaleFactor - previewView.contentScaleFactor) > 0.001 {
            player.previewView.contentScaleFactor = previewView.contentScaleFactor
        }
        player.previewView.layer.bounds = previewView.layer.bounds
        player.previewView.layer.position = previewView.layer.position
        player.previewView.layer.transform = previewView.layer.transform
        player.previewView.setNeedsLayout()
    }

    func destroyLivePhotoPlayer() {
        guard let player = self.livePhotoPlayer else {
            return
        }
        self.livePhotoPlayer = nil
        player.invalidate()
    }
}
