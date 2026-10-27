import Foundation
import UIKit
import Display
import SwiftSignalKit
import LegacyComponents
import MediaEditorBottomControls

public struct ChatMediaEditorCameraHandoff {
    public var bottomControls: MediaEditorBottomControlsHandoff
    public var previewFrame: CGRect?
    public var moveViewfinder: ((CGRect, Bool) -> Void)?

    public init(bottomControls: MediaEditorBottomControlsHandoff, previewFrame: CGRect?, moveViewfinder: ((CGRect, Bool) -> Void)? = nil) {
        self.bottomControls = bottomControls
        self.previewFrame = previewFrame
        self.moveViewfinder = moveViewfinder
    }
}

public struct ChatMediaEditorGalleryCamera {
    public var hasCameraButton: Bool
    public var returnToCamera: () -> Void
    public var discard: () -> Void
    public var bottomHandoff: (() -> ChatMediaEditorCameraHandoff?)?
    public var bottomHandBack: (() -> MediaEditorBottomControlsHandBack?)?
    public var returnPreviewFrame: (() -> CGRect?)?
    public var moveViewfinder: ((CGRect, Bool) -> Void)?

    public init(hasCameraButton: Bool, returnToCamera: @escaping () -> Void, discard: @escaping () -> Void, bottomHandoff: (() -> ChatMediaEditorCameraHandoff?)? = nil, bottomHandBack: (() -> MediaEditorBottomControlsHandBack?)? = nil, returnPreviewFrame: (() -> CGRect?)? = nil, moveViewfinder: ((CGRect, Bool) -> Void)? = nil) {
        self.hasCameraButton = hasCameraButton
        self.returnToCamera = returnToCamera
        self.discard = discard
        self.bottomHandoff = bottomHandoff
        self.bottomHandBack = bottomHandBack
        self.returnPreviewFrame = returnPreviewFrame
        self.moveViewfinder = moveViewfinder
    }
}

public enum ChatMediaEditorGalleryOutStyle: Equatable {
    case zoomToSource
    case continueSwipe
    case crossfade
}

public func chatMediaEditorGalleryOutStyle(hasSourceView: Bool, swipeOffset: CGFloat, velocity: CGFloat) -> ChatMediaEditorGalleryOutStyle {
    if hasSourceView {
        return .zoomToSource
    }
    if swipeOffset != 0.0 || velocity != 0.0 {
        return .continueSwipe
    }
    return .crossfade
}

public struct ChatMediaEditorGalleryConfiguration {
    public var doneButton: TGPhotoEditorDoneButton
    public var hasSendMenu: Bool
    public var hasTimer: Bool
    public var timers: ChatMediaEditorTimerAdapter?
    public var presentTimerPicker: ((@escaping (Int32) -> Void) -> Void)?
    public var hasCoverButton: Bool
    public var covers: ChatMediaEditorCoverAdapter?
    public var editCover: ((CGSize, @escaping (UIImage) -> Void, @escaping () -> Void) -> Void)?
    public var hasLivePhotoButton: Bool
    public var livePhotos: ChatMediaEditorLivePhotoAdapter?
    public var sendWhenOnlineAvailable: Signal<Bool, NoError>
    public var sendInProgress: Signal<Bool, NoError>
    public var keepsDeselectedItems: Bool
    public var immediateThumbnail: UIImage?
    public var transitionHostView: () -> UIView?
    public var transitionView: (String) -> UIView?
    public var updateHiddenMedia: (String?) -> Void
    public var finishedTransitionIn: () -> Void
    public var willTransitionOut: () -> Void
    public var send: (_ uniqueId: String, _ silently: Bool, _ scheduleTime: Int32?, _ completion: @escaping () -> Void) -> Bool
    public var dismissAll: () -> Void
    public var camera: ChatMediaEditorGalleryCamera?
    public var tabPolicy: ChatMediaEditorTabPolicy

    public init(
        doneButton: TGPhotoEditorDoneButton,
        hasSendMenu: Bool,
        hasTimer: Bool = false,
        timers: ChatMediaEditorTimerAdapter? = nil,
        presentTimerPicker: ((@escaping (Int32) -> Void) -> Void)? = nil,
        hasCoverButton: Bool = false,
        covers: ChatMediaEditorCoverAdapter? = nil,
        editCover: ((CGSize, @escaping (UIImage) -> Void, @escaping () -> Void) -> Void)? = nil,
        hasLivePhotoButton: Bool = false,
        livePhotos: ChatMediaEditorLivePhotoAdapter? = nil,
        sendWhenOnlineAvailable: Signal<Bool, NoError>,
        sendInProgress: Signal<Bool, NoError>,
        keepsDeselectedItems: Bool,
        immediateThumbnail: UIImage?,
        transitionHostView: @escaping () -> UIView?,
        transitionView: @escaping (String) -> UIView?,
        updateHiddenMedia: @escaping (String?) -> Void,
        finishedTransitionIn: @escaping () -> Void,
        willTransitionOut: @escaping () -> Void,
        send: @escaping (_ uniqueId: String, _ silently: Bool, _ scheduleTime: Int32?, _ completion: @escaping () -> Void) -> Bool,
        dismissAll: @escaping () -> Void,
        camera: ChatMediaEditorGalleryCamera? = nil,
        tabPolicy: ChatMediaEditorTabPolicy = .standard
    ) {
        self.doneButton = doneButton
        self.hasSendMenu = hasSendMenu
        self.hasTimer = hasTimer
        self.timers = timers
        self.presentTimerPicker = presentTimerPicker
        self.hasCoverButton = hasCoverButton
        self.covers = covers
        self.editCover = editCover
        self.hasLivePhotoButton = hasLivePhotoButton
        self.livePhotos = livePhotos
        self.sendWhenOnlineAvailable = sendWhenOnlineAvailable
        self.sendInProgress = sendInProgress
        self.keepsDeselectedItems = keepsDeselectedItems
        self.immediateThumbnail = immediateThumbnail
        self.transitionHostView = transitionHostView
        self.transitionView = transitionView
        self.updateHiddenMedia = updateHiddenMedia
        self.finishedTransitionIn = finishedTransitionIn
        self.willTransitionOut = willTransitionOut
        self.send = send
        self.dismissAll = dismissAll
        self.camera = camera
        self.tabPolicy = tabPolicy
    }
}

public struct ChatMediaEditorGalleryTransitionMapping: Equatable {
    public var position: CGPoint
    public var scale: CGPoint
}

public func chatMediaEditorGalleryTransitionMapping(bounds: CGRect, mediaFrame: CGRect, targetFrame: CGRect) -> ChatMediaEditorGalleryTransitionMapping {
    guard mediaFrame.width > 0.0, mediaFrame.height > 0.0 else {
        return ChatMediaEditorGalleryTransitionMapping(position: CGPoint(x: targetFrame.midX, y: targetFrame.midY), scale: CGPoint(x: 1.0, y: 1.0))
    }
    let scale = CGPoint(x: targetFrame.width / mediaFrame.width, y: targetFrame.height / mediaFrame.height)
    let position = CGPoint(
        x: targetFrame.midX - (mediaFrame.midX - bounds.midX) * scale.x,
        y: targetFrame.midY - (mediaFrame.midY - bounds.midY) * scale.y
    )
    return ChatMediaEditorGalleryTransitionMapping(position: position, scale: scale)
}

private func chatMediaEditorAddSpringAnimations(layer: CALayer, fromPosition: CGPoint, toPosition: CGPoint, fromScale: CGPoint, toScale: CGPoint, animatingIn: Bool, removeOnCompletion: Bool) {
    let damping: CGFloat = animatingIn ? 25.0 : 30.0
    let mass: CGFloat = 0.8
    let durationFactor: CGFloat = animatingIn ? 1.8 : 2.0

    func make(_ keyPath: String, from: Any, to: Any) -> CAAnimation? {
        guard let animation = JNWSpringAnimation(keyPath: keyPath) else {
            return nil
        }
        animation.fromValue = from
        animation.toValue = to
        animation.damping = damping
        animation.mass = mass
        animation.durationFactor = durationFactor
        animation.isRemovedOnCompletion = removeOnCompletion
        animation.fillMode = .forwards
        return animation
    }
    if let animation = make("position", from: NSValue(cgPoint: fromPosition), to: NSValue(cgPoint: toPosition)) {
        layer.add(animation, forKey: "chatMediaGalleryPosition")
    }
    if let animation = make("transform.scale.x", from: NSNumber(value: Double(fromScale.x)), to: NSNumber(value: Double(toScale.x))) {
        layer.add(animation, forKey: "chatMediaGalleryScaleX")
    }
    if let animation = make("transform.scale.y", from: NSNumber(value: Double(fromScale.y)), to: NSNumber(value: Double(toScale.y))) {
        layer.add(animation, forKey: "chatMediaGalleryScaleY")
    }
}

extension ChatMediaEditorScreen.Node {
    private func galleryChromeViews(excluding excluded: [UIView]) -> [UIView] {
        return self.view.subviews.filter { view in
            return view !== self.pagerView && !excluded.contains(where: { $0 === view })
        }
    }

    private func gallerySourceFrame(_ sourceView: UIView) -> CGRect {
        if let superview = sourceView.superview {
            return self.view.convert(sourceView.frame, from: superview)
        }
        return self.view.convert(sourceView.frame, from: nil)
    }

    private func installGalleryTransitionCopy(_ sourceView: UIView, sourceFrame: CGRect, mediaFrame: CGRect, page: UIView, aboveGallery: Bool) -> (view: UIView, mediaFrame: CGRect) {
        if let host = self.controller?.gallery?.transitionHostView(), let container = host.superview, host.window != nil {
            sourceView.frame = container.convert(sourceFrame, from: self.view)
            container.insertSubview(sourceView, aboveSubview: host)
            return (sourceView, container.convert(mediaFrame, from: page))
        }
        sourceView.frame = sourceFrame
        if aboveGallery {
            self.view.addSubview(sourceView)
        } else {
            self.view.insertSubview(sourceView, belowSubview: self.pagerView)
        }
        return (sourceView, self.view.convert(mediaFrame, from: page))
    }

    func galleryFocusedItemChanged() {
        guard self.isGalleryTransitionedIn, let gallery = self.controller?.gallery else {
            return
        }
        gallery.updateHiddenMedia(self.pageModel.currentItem.uniqueId)
    }

    func animateGalleryIn() {
        guard let gallery = self.controller?.gallery else {
            self.animateIn()
            return
        }
        let uniqueId = self.pageModel.currentItem.uniqueId
        let index = self.pageModel.currentIndex
        guard let page = self.pagerView.page(at: index), let sourceView = gallery.transitionView(uniqueId), let layout = self.validLayout else {
            self.isGalleryTransitionedIn = true
            gallery.updateHiddenMedia(uniqueId)
            if let handoff = gallery.camera?.bottomHandoff?() {
                self.animateInAdoptingBottomControls(handoff)
            } else {
                self.animateIn()
            }
            gallery.finishedTransitionIn()
            return
        }
        if page.thumbnailView.image == nil, let immediateThumbnail = gallery.immediateThumbnail {
            page.thumbnailView.image = immediateThumbnail
        }
        self.isGalleryTransitionedIn = true
        gallery.updateHiddenMedia(uniqueId)

        let sourceFrame = self.gallerySourceFrame(sourceView)
        let mediaFrame = self.restingPreviewFrame(layout: layout, mediaSize: self.previewMediaSize, isVideo: self.subject.isVideo)
        let scrollView = self.pagerView.scrollView
        let sourceInScroll = scrollView.convert(sourceFrame, from: self.view)
        let mapping = chatMediaEditorGalleryTransitionMapping(bounds: page.bounds, mediaFrame: mediaFrame, targetFrame: sourceInScroll)

        let (copyView, mediaInView) = self.installGalleryTransitionCopy(sourceView, sourceFrame: sourceFrame, mediaFrame: mediaFrame, page: page, aboveGallery: false)
        let copyMapping = chatMediaEditorGalleryTransitionMapping(bounds: copyView.bounds, mediaFrame: copyView.bounds, targetFrame: mediaInView)

        self.view.isUserInteractionEnabled = false
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self, weak copyView] in
            copyView?.removeFromSuperview()
            guard let self else {
                return
            }
            self.view.isUserInteractionEnabled = true
            self.controller?.gallery?.finishedTransitionIn()
            self.transitionInFinished()
        }
        chatMediaEditorAddSpringAnimations(layer: page.layer, fromPosition: mapping.position, toPosition: page.layer.position, fromScale: mapping.scale, toScale: CGPoint(x: 1.0, y: 1.0), animatingIn: true, removeOnCompletion: true)
        chatMediaEditorAddSpringAnimations(layer: copyView.layer, fromPosition: copyView.layer.position, toPosition: copyMapping.position, fromScale: CGPoint(x: 1.0, y: 1.0), toScale: copyMapping.scale, animatingIn: true, removeOnCompletion: false)
        CATransaction.commit()

        page.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.07)
        self.layer.animate(from: UIColor.clear.cgColor, to: UIColor.black.cgColor, keyPath: "backgroundColor", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.15)
        for view in self.galleryChromeViews(excluding: [copyView]) {
            view.layer.animateAlpha(from: 0.0, to: view.alpha, duration: 0.15)
        }
    }

    func animateGalleryOut(velocity: CGFloat, completion: @escaping () -> Void) {
        guard let gallery = self.controller?.gallery else {
            self.animateOut(completion: completion)
            return
        }
        let handBack = gallery.camera?.bottomHandBack?()
        let returnPreviewFrame = gallery.camera?.returnPreviewFrame?()
        gallery.willTransitionOut()
        self.captionPanelView?.onAnimateOut()
        self.view.endEditing(true)
        self.mediaEditor.stop()
        self.resetCurrentPageZoom()

        let uniqueId = self.pageModel.currentItem.uniqueId
        let index = self.pageModel.currentIndex
        let finish: () -> Void = {
            gallery.updateHiddenMedia(nil)
            completion()
        }
        guard let page = self.pagerView.page(at: index), let sourceView = gallery.transitionView(uniqueId), let layout = self.validLayout else {
            switch chatMediaEditorGalleryOutStyle(hasSourceView: false, swipeOffset: self.swipeOffset, velocity: velocity) {
            case .crossfade:
                if let handBack {
                    self.animateOutHandingBack(handBack, previewFrame: returnPreviewFrame, completion: finish)
                } else {
                    self.animateOut(completion: finish)
                }
            case .zoomToSource, .continueSwipe:
                self.animateOutAfterSwipe(velocity: velocity, completion: finish)
            }
            return
        }
        let sourceFrame = self.gallerySourceFrame(sourceView)
        let mediaFrame = self.restingPreviewFrame(layout: layout, mediaSize: self.previewMediaSize, isVideo: self.subject.isVideo)
        let scrollView = self.pagerView.scrollView
        let sourceInScroll = scrollView.convert(sourceFrame, from: self.view)
        let mapping = chatMediaEditorGalleryTransitionMapping(bounds: page.bounds, mediaFrame: mediaFrame, targetFrame: sourceInScroll)

        let (copyView, mediaInView) = self.installGalleryTransitionCopy(sourceView, sourceFrame: sourceFrame, mediaFrame: mediaFrame, page: page, aboveGallery: true)
        let copyMapping = chatMediaEditorGalleryTransitionMapping(bounds: copyView.bounds, mediaFrame: copyView.bounds, targetFrame: mediaInView)

        self.view.isUserInteractionEnabled = false
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak copyView] in
            copyView?.removeFromSuperview()
            finish()
        }
        let fromPosition = page.layer.presentation()?.position ?? page.layer.position
        chatMediaEditorAddSpringAnimations(layer: page.layer, fromPosition: fromPosition, toPosition: mapping.position, fromScale: CGPoint(x: 1.0, y: 1.0), toScale: mapping.scale, animatingIn: false, removeOnCompletion: false)
        chatMediaEditorAddSpringAnimations(layer: copyView.layer, fromPosition: copyMapping.position, toPosition: copyView.layer.position, fromScale: copyMapping.scale, toScale: CGPoint(x: 1.0, y: 1.0), animatingIn: false, removeOnCompletion: false)
        CATransaction.commit()

        page.layer.animateAlpha(from: page.alpha, to: 0.0, duration: 0.1, removeOnCompletion: false)
        let backgroundColor = self.backgroundColor ?? .black
        self.backgroundColor = .clear
        self.layer.animate(from: backgroundColor.cgColor, to: UIColor.clear.cgColor, keyPath: "backgroundColor", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.2)
        for view in self.galleryChromeViews(excluding: [copyView]) {
            view.layer.animateAlpha(from: view.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
        }
        self.animateBottomControlsOut(duration: 0.2)
    }

    private var bottomControlsView: ChatMediaEditorBottomControlsComponent.View? {
        return self.toolbar.view as? ChatMediaEditorBottomControlsComponent.View
    }

    var blurFadedChromeViews: [UIView] {
        return [self.recipientArrowView, self.recipientLabel, self.captionContainerView, self.cameraButton, self.selectionCounterButton, self.selectionCheckButton].compactMap { $0 }
    }

    private func chromeViewsOutsideBottomControls(keepingPager: Bool) -> [UIView] {
        let toolbarView = self.toolbar.view
        let pagerView = self.pagerView
        let blurFaded = self.blurFadedChromeViews
        return self.view.subviews.filter { view in view !== toolbarView && !(keepingPager && view === pagerView) && !blurFaded.contains(where: { $0 === view }) }
    }

    private func currentPageMorphTarget() -> (UIView, CGRect)? {
        guard let page = self.pagerView.page(at: self.pageModel.currentIndex), let layout = self.validLayout else {
            return nil
        }
        let mediaFrame = self.restingPreviewFrame(layout: layout, mediaSize: self.previewMediaSize, isVideo: self.subject.isVideo)
        return (page, self.view.convert(mediaFrame, to: nil))
    }

    func animateInAdoptingBottomControls(_ handoff: ChatMediaEditorCameraHandoff) {
        guard let bottomControlsView = self.bottomControlsView else {
            self.animateIn()
            return
        }
        let morph = handoff.previewFrame.flatMap { previewFrame in self.currentPageMorphTarget().map { ($0.0, $0.1, previewFrame) } }
        let backgroundColor = self.backgroundColor ?? .black
        self.layer.animate(from: UIColor.clear.cgColor, to: backgroundColor.cgColor, keyPath: "backgroundColor", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.25)
        for view in self.chromeViewsOutsideBottomControls(keepingPager: morph != nil) {
            view.layer.animateAlpha(from: 0.0, to: view.alpha, duration: 0.25)
        }
        for view in self.blurFadedChromeViews where view.alpha > 0.0 {
            mediaEditorFadeWithBlur(view: view, isIn: true)
        }
        if let (page, contentFrame, previewFrame) = morph {
            mediaEditorAnimatePreviewMorph(view: page, contentFrame: contentFrame, cameraFrame: previewFrame, toCamera: false)
            handoff.moveViewfinder?(contentFrame, true)
        }
        bottomControlsView.adopt(handoff.bottomControls)
        Queue.mainQueue().after(mediaEditorBottomControlsHandoffMoveDuration, { [weak self] in
            self?.transitionInFinished()
        })
    }

    func animateOutHandingBack(_ handBack: MediaEditorBottomControlsHandBack, previewFrame: CGRect?, completion: @escaping () -> Void) {
        guard let bottomControlsView = self.bottomControlsView else {
            self.animateOut(completion: completion)
            return
        }
        let backgroundColor = self.backgroundColor ?? .black
        self.backgroundColor = .clear
        self.layer.animate(from: backgroundColor.cgColor, to: UIColor.clear.cgColor, keyPath: "backgroundColor", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.2)
        let morph = previewFrame.flatMap { previewFrame in self.currentPageMorphTarget().map { ($0.0, $0.1, previewFrame) } }
        for view in self.chromeViewsOutsideBottomControls(keepingPager: morph != nil) {
            view.layer.animateAlpha(from: view.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
        }
        for view in self.blurFadedChromeViews where view.alpha > 0.0 {
            mediaEditorFadeWithBlur(view: view, isIn: false)
        }
        if let (page, contentFrame, previewFrame) = morph {
            mediaEditorAnimatePreviewMorph(view: page, contentFrame: contentFrame, cameraFrame: previewFrame, toCamera: true)
            self.controller?.gallery?.camera?.moveViewfinder?(contentFrame, false)
            self.pagerView.layer.animateAlpha(from: self.pagerView.alpha, to: 0.0, duration: 0.2, delay: mediaEditorBottomControlsHandoffMoveDuration - 0.2, removeOnCompletion: false)
        }
        bottomControlsView.handBack(handBack)
        Queue.mainQueue().after(mediaEditorBottomControlsHandoffMoveDuration, {
            completion()
        })
    }

    func animateBottomControlsOut(duration: Double) {
        (self.toolbar.view as? ChatMediaEditorBottomControlsComponent.View)?.animateOutAsWhole(duration: duration)
    }

    func animateGalleryOutAfterSend(completion: @escaping () -> Void) {
        guard let gallery = self.controller?.gallery else {
            self.animateOut(completion: completion)
            return
        }
        self.animateOut(completion: {
            gallery.updateHiddenMedia(nil)
            completion()
        })
    }

    func gallerySendSnapshotView() -> UIView? {
        let containerView = self.previewContainerView
        guard containerView.window != nil, let snapshotView = containerView.snapshotView(afterScreenUpdates: true) else {
            return nil
        }
        snapshotView.frame = containerView.convert(containerView.bounds, to: nil)
        Queue.mainQueue().after(0.1) { [weak self] in
            self?.pagerView.alpha = 0.01
        }
        return snapshotView
    }
}
