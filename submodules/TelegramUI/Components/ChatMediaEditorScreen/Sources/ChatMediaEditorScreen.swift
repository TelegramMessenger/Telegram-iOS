import Foundation
import UIKit
import CoreMedia
import Photos
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import ComponentFlow
import MediaEditorBottomControls
import TelegramPresentationData
import LegacyComponents
import LegacyMediaPickerUI
import MediaPickerUI
import MediaEditor
import MediaEditorScreen
import DrawingUI
import MediaCropComponent
import ChatMediaSend
import PresentationDataUtils
import RadialStatusNode
import TooltipUI

public enum ChatMediaEditorSubject {
    case image(UIImage)
    case video(path: String, dimensions: PixelDimensions, duration: Double)
    case asset(PHAsset)

    var dimensions: PixelDimensions {
        switch self {
        case let .image(image):
            return PixelDimensions(width: Int32(round(image.size.width * image.scale)), height: Int32(round(image.size.height * image.scale)))
        case let .video(_, dimensions, _):
            return dimensions
        case let .asset(asset):
            return PixelDimensions(width: Int32(asset.pixelWidth), height: Int32(asset.pixelHeight))
        }
    }

    var duration: Double {
        switch self {
        case let .video(_, _, duration):
            return duration
        case let .asset(asset):
            return asset.mediaType == .video ? asset.duration : 0.0
        case .image:
            return 0.0
        }
    }

    var isVideo: Bool {
        switch self {
        case .video:
            return true
        case let .asset(asset):
            return asset.mediaType == .video
        case .image:
            return false
        }
    }

    var itemSource: ChatMediaEditorItemSource {
        switch self {
        case let .image(image):
            return .image(image)
        case let .video(path, dimensions, duration):
            return .video(path: path, dimensions: dimensions, duration: duration)
        case let .asset(asset):
            return .asset(asset)
        }
    }
}

public enum ChatMediaEditorInitialTool {
    case none
    case paint
    case tools
    case caption
}

let chatMediaEditorToolbarHeight: CGFloat = 49.0

final class ChatMediaEditorPassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if result === self {
            return nil
        }
        return result
    }
}

enum ChatMediaEditorActiveTool: Equatable {
    case crop
    case paint
    case tools
    case quality
    case cover
}

let chatMediaEditorCaptionPanelSpacing: CGFloat = 10.0

public func chatMediaEditorRestingPreviewFrame(size: CGSize, safeInsets: UIEdgeInsets, mediaSize: CGSize, captionPanelHeight: CGFloat, keepsToBand: Bool = false, toolbarSide: ChatMediaEditorToolbarSide? = nil, reservedCorners: ContainerViewLayoutCorners = .none) -> CGRect {
    var safeInsets = safeInsets
    if toolbarSide == nil && !keepsToBand && safeInsets.left != safeInsets.right {
        safeInsets.left = 0.0
        safeInsets.right = 0.0
    }
    return chatMediaEditorLayout(
        size: size,
        safeInsets: safeInsets,
        mediaSize: mediaSize,
        toolbarHeight: chatMediaEditorToolbarHeight,
        captionPanelHeight: captionPanelHeight,
        keyboardHeight: 0.0,
        toolbarSide: toolbarSide,
        reservedCorners: reservedCorners
    ).previewFrame
}

let chatMediaEditorScheduleWhenOnlineTimestamp: Int32 = 0x7ffffffe

public final class ChatMediaEditorScreen: ViewController, ChatMediaGalleryController {
    final class Node: ASDisplayNode {
        weak var controller: ChatMediaEditorScreen?
        let context: AccountContext
        let pageModel: ChatMediaEditorPageModel
        let isGallery: Bool
        var subject: ChatMediaEditorSubject
        var canvasSize: CGSize

        let pagerView: ChatMediaEditorPagerView
        let previewContainerView: UIView
        var previewView: MediaEditorPreviewView
        var entitiesContainerView: UIView
        var entitiesView: DrawingEntitiesView
        var drawingView: DrawingView
        var selectionContainerView: DrawingSelectionContainerView
        var mediaEditor: MediaEditor
        let playButtonView: UIImageView
        var isCurrentItemDisplayed = false
        var isInterfaceHiddenBySwipe = false
        var isSwipingDown = false

        let toolbar = ComponentView<Empty>()
        var scrubber = ComponentView<Empty>()
        var playerState: MediaEditorPlayerState?
        var hasStartedPlayback = false
        var playerStateDisposable: Disposable?
        var playerStateFramesCount: Int?
        var sourceLoadStateDisposable: Disposable?
        let gifConversionDisposable = MetaDisposable()
        var sourceIndicatorState: ChatMediaEditorSourceIndicatorState = .hidden
        var sourceProgressNode: RadialStatusNode?
        private var isSourceProgressRevealPending = false
        let captionDimView: UIView
        let captionContainerView: ChatMediaEditorPassthroughView
        let recipientArrowView: UIImageView
        let recipientLabel: UILabel
        private(set) var captionPanelView: TGCaptionPanelView?

        private(set) var isCaptionAbove = false
        private(set) var isEditingCaption = false
        var interactionTracking = ChatMediaEditorTrackingSet()
        var swipeOffset: CGFloat = 0.0
        private(set) var isSending = false
        private var isGallerySendInProgress = false
        private var gallerySendInProgressDisposable: Disposable?
        private(set) var isInvalidated = false
        private(set) var validLayout: ContainerViewLayout?

        var activeTool: ChatMediaEditorActiveTool? {
            didSet {
                if self.activeTool != nil {
                    self.dismissTimerTooltip()
                    self.dismissMuteTooltip()
                }
                if (oldValue == nil) != (self.activeTool == nil) {
                    self.blurChromeForTool(isHiding: self.activeTool != nil)
                }
                if oldValue != self.activeTool {
                    self.updatePortraitLock()
                }
            }
        }

        private func blurChromeForTool(isHiding: Bool) {
            let views: [UIView] = self.blurFadedChromeViews + [self.muteButton, self.coverButton, self.livePhotoButton].compactMap { $0 }
            for view in views where view.window != nil {
                ComponentTransition.animateTransientBlur(layer: view.layer, fromRadius: isHiding ? 0.0 : mediaEditorBottomControlsHandoffBlurRadius, toRadius: isHiding ? mediaEditorBottomControlsHandoffBlurRadius : 0.0, duration: 0.2)
            }
        }
        var drawingScreen: DrawingScreen?
        var toolsScreen: MediaToolsScreen?
        var toolsSection: ChatMediaEditorToolsTab = .adjustments
        var paintMode: ChatMediaEditorPaintTab = .draw
        var paintControlsVisible = true
        var lastHighlightedToolsTabs: Set<ChatMediaEditorToolsTab> = []
        private var lastBottomControlsSideItems: (ChatMediaEditorBottomControlsLeftItem, ChatMediaEditorBottomControlsRightItem)?
        private var lastBottomControlsSideItemsChange: Double?
        var qualityPanelView: ChatMediaEditorQualityPanelView?
        var qualitySelection: MediaQualityPreset?
        var previousDrawingData: Data?
        var previousDrawingEntities: [DrawingEntity]?
        var entityGestureRecognizers: [UIGestureRecognizer] = []

        var cropLockedAspectRatio: CGFloat?
        var cropSession: ChatMediaEditorCropSession?
        var cropView: MediaCropView?
        var cropResetButton: UIButton?
        weak var cropDiscardMenu: ViewController?
        weak var cameraDiscardMenu: ViewController?
        var cropPreviewFrame: CGRect?
        var cropWasPlaying = false

        var selectionModel: ChatMediaEditorSelectionModel?
        var selectionCheckButton: ChatMediaEditorCheckButton?
        var selectionCounterButton: ChatMediaEditorCounterButton?
        var selectionStripView: ChatMediaEditorStripView?
        var isSelectionInterfaceHidden = false
        var selectionStripItems: [String: ChatMediaEditorItem?] = [:]
        var toolStartValues: MediaEditorValues?
        let previewTapRecognizer = UITapGestureRecognizer()

        var captionModel: ChatMediaEditorCaptionModel?
        var timerModel: ChatMediaEditorTimerModel?
        weak var timerTooltipController: TooltipScreen?
        weak var muteTooltipController: TooltipScreen?
        var muteButton: UIButton?
        var coverModel: ChatMediaEditorCoverModel?
        var coverButton: ChatMediaEditorCoverButton?
        var coverEditView: ChatMediaEditorCoverEditView?
        var coverScrubber = ComponentView<Empty>()
        var coverPosition: Double?
        var isCapturingCover = false
        var livePhotoModel: ChatMediaEditorLivePhotoModel?
        var livePhotoButton: LivePhotoButton?
        var livePhotoButtonMode: ChatMediaSendLivePhotoMode?
        let livePhotoPlaybackModel = ChatMediaEditorLivePhotoPlaybackModel()
        var livePhotoPlayer: ChatMediaEditorLivePhotoPlayer?
        var livePhotoPressRecognizer: UILongPressGestureRecognizer?
        let livePhotoGestureDelegate = ChatMediaEditorLivePhotoGestureDelegate()
        var isTimerTooltipPending = false
        let thumbnailReporter: ChatMediaEditorEditedThumbnailReporter?
        var isSelectionRevealDelayed = false
        var selectionRevealTimer: SwiftSignalKit.Timer?
        var isGalleryTransitionedIn = false
        let coveredContent = ChatMediaEditorCoveredContent()
        var cameraButton: ChatMediaEditorCameraButton?
        var itemsAppendDisposable: Disposable?
        var filePreviewInfo: (uniqueId: String, text: String)?
        var filePreviewInfoDisposable: SDisposable?

        init(controller: ChatMediaEditorScreen) {
            self.controller = controller
            self.context = controller.context
            self.pageModel = ChatMediaEditorPageModel(itemsSource: controller.itemsSource, store: controller.store, initialIndex: controller.initialIndex)
            self.isGallery = controller.isGallery
            self.thumbnailReporter = ChatMediaEditorEditedThumbnailReporter.make(isGallery: controller.isGallery, adapter: controller.captions)

            let restore = self.pageModel.restore()
            let components = ChatMediaEditorItemComponents(context: controller.context, item: restore.item, values: restore.values)
            controller.store.noteQualityPresetBaseline(components.qualityPresetBaseline, for: restore.item.uniqueId)
            self.subject = components.subject
            self.canvasSize = components.canvasSize
            self.previewView = components.previewView
            self.entitiesContainerView = components.entitiesContainerView
            self.entitiesView = components.entitiesView
            self.drawingView = components.drawingView
            self.selectionContainerView = components.selectionContainerView
            self.mediaEditor = components.mediaEditor
            self.cropLockedAspectRatio = restore.lockedAspectRatio

            self.pagerView = ChatMediaEditorPagerView(frame: .zero)
            self.previewContainerView = UIView()
            self.previewContainerView.clipsToBounds = true

            self.playButtonView = UIImageView(image: chatMediaEditorPlayButtonImage)
            self.playButtonView.isUserInteractionEnabled = false
            self.playButtonView.alpha = 0.0

            self.captionDimView = UIView()
            self.captionDimView.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
            self.captionDimView.alpha = 0.0

            self.captionContainerView = ChatMediaEditorPassthroughView()

            self.recipientArrowView = UIImageView(image: TGComponentsImageNamed("PhotoPickerArrow"))
            self.recipientLabel = UILabel()
            self.recipientLabel.backgroundColor = .clear
            self.recipientLabel.font = Font.bold(13.0)
            self.recipientLabel.textColor = .white
            self.recipientLabel.text = controller.recipientName
            self.recipientLabel.isUserInteractionEnabled = false
            self.recipientLabel.sizeToFit()

            super.init()

            self.backgroundColor = .black
        }

        override func didLoad() {
            super.didLoad()

            self.coveredContent.setCoveringView(self.view)
            self.view.addSubview(self.pagerView)
            self.previewContainerView.addSubview(self.playButtonView)
            self.setupPager()
            self.pagerView.trackingUpdated = { [weak self] source, isTracking in
                self?.setInteractionTracking(isTracking, source: source)
            }
            self.setupPaintGestures()
            self.setupVideo()
            self.installCurrentItem(values: self.pageModel.restore().values)
            self.setupSelection()
            self.setupTimer()
            self.setupCover()
            self.setupLivePhoto()
            self.setupCameraReview()
            if let gallery = self.controller?.gallery {
                self.gallerySendInProgressDisposable = gallery.sendInProgress.startStrict(next: { [weak self] inProgress in
                    self?.gallerySendInProgressUpdated(inProgress)
                })
            }

            if let recipientName = self.controller?.recipientName, !recipientName.isEmpty {
                self.view.addSubview(self.recipientArrowView)
                self.view.addSubview(self.recipientLabel)
            }

            self.captionDimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.captionDimTapped)))
            self.view.addSubview(self.captionDimView)

            if let controller = self.controller, let captionPanelView = controller.getCaptionPanelView() {
                self.captionPanelView = captionPanelView
                if self.isGallery, let captions = controller.captions {
                    let captionModel = ChatMediaEditorCaptionModel(adapter: captions, currentId: self.pageModel.currentItem.uniqueId)
                    self.captionModel = captionModel
                    self.isCaptionAbove = captionModel.isCaptionAbove
                    captionPanelView.setTimeout(self.currentItemTimer ?? 0, isVideo: self.subject.isVideo, isCaptionAbove: self.isCaptionAbove)
                    captionPanelView.setCaption(captionModel.currentCaption)
                    if self.timerModel != nil {
                        captionPanelView.timerUpdated = { [weak self] value in
                            self?.captionTimerUpdated(value)
                        }
                    }
                } else {
                    captionPanelView.setTimeout(0, isVideo: self.subject.isVideo, isCaptionAbove: false)
                    captionPanelView.setCaption(controller.initialCaption)
                }
                captionPanelView.sendPressed = { [weak self] _ in
                    self?.updateIsEditingCaption(false)
                }
                captionPanelView.focusUpdated = { [weak self] focused in
                    self?.updateIsEditingCaption(focused)
                }
                captionPanelView.heightUpdated = { [weak self] animated in
                    self?.requestLayout(transition: animated ? .animated(duration: 0.3, curve: .easeInOut) : .immediate)
                }
                captionPanelView.captionIsAboveUpdated = { [weak self] value in
                    guard let self else {
                        return
                    }
                    self.isCaptionAbove = value
                    self.captionModel?.isCaptionAbove = value
                    self.requestLayout(transition: .animated(duration: 0.3, curve: .easeInOut))
                }
                self.view.addSubview(self.captionContainerView)
                self.captionContainerView.addSubview(captionPanelView.view)
            }
        }

        @objc private func captionDimTapped() {
            let _ = self.endCaptionEditing()
        }

        // With a hardware keyboard the bottom row stays reachable while the caption is edited: what it starts ends the
        // editing first, which commits the caption. False when the panel keeps the input (a caption over the limit).
        private func endCaptionEditing() -> Bool {
            guard self.isEditingCaption else {
                return true
            }
            guard self.captionPanelView?.dismissInput() ?? true else {
                return false
            }
            self.updateIsEditingCaption(false)
            return true
        }

        private func updateIsEditingCaption(_ isEditing: Bool) {
            guard self.isEditingCaption != isEditing else {
                return
            }
            self.isEditingCaption = isEditing
            self.captionEditingUpdated(isEditing)
            self.requestLayout(transition: .animated(duration: 0.3, curve: .easeInOut))
        }

        func activateCaptionInput() {
            if let layout = self.validLayout, self.toolbarSide(layout: layout) != nil {
                return
            }
            self.captionPanelView?.activateInput()
        }

        func animateIn() {
            self.view.layer.allowsGroupOpacity = true
            self.view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, completion: { [weak self] _ in
                self?.view.layer.allowsGroupOpacity = false
                self?.transitionInFinished()
            })
        }

        func transitionInFinished() {
            self.coveredContent.transitionInFinished()
        }

        func animateOut(completion: @escaping () -> Void) {
            self.captionPanelView?.onAnimateOut()
            self.view.endEditing(true)
            self.animateBottomControlsOut(duration: 0.2)
            for view in self.blurFadedChromeViews where view.alpha > 0.0 {
                mediaEditorFadeWithBlur(view: view, isIn: false)
            }
            self.view.layer.allowsGroupOpacity = true
            self.view.layer.animateAlpha(from: self.view.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                completion()
            })
        }

        func updateSourceIndicatorState(_ state: ChatMediaEditorSourceIndicatorState) {
            guard self.sourceIndicatorState != state, !self.isInvalidated else {
                return
            }
            let previousState = self.sourceIndicatorState
            self.sourceIndicatorState = state
            switch state {
            case let .progress(progress):
                if let progressNode = self.sourceProgressNode {
                    progressNode.transitionToState(.progress(color: .white, lineWidth: nil, value: CGFloat(max(0.027, min(1.0, progress))), cancelEnabled: false, animateRotation: true))
                } else if !self.isSourceProgressRevealPending {
                    self.isSourceProgressRevealPending = true
                    Queue.mainQueue().after(chatMediaEditorSourceProgressRevealDelay, { [weak self] in
                        guard let self else {
                            return
                        }
                        self.isSourceProgressRevealPending = false
                        self.revealSourceProgressIfNeeded()
                    })
                }
            case .hidden, .unavailable:
                if let progressNode = self.sourceProgressNode {
                    self.sourceProgressNode = nil
                    progressNode.transitionToState(.none, completion: { [weak progressNode] in
                        progressNode?.view.removeFromSuperview()
                    })
                }
                if case .unavailable = state, previousState != .unavailable {
                    self.presentSourceUnavailableAlert()
                }
            }
        }

        private func revealSourceProgressIfNeeded() {
            guard !self.isInvalidated, self.sourceProgressNode == nil, case let .progress(progress) = self.sourceIndicatorState else {
                return
            }
            let progressNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.6))
            progressNode.isUserInteractionEnabled = false
            self.sourceProgressNode = progressNode
            self.previewContainerView.addSubview(progressNode.view)
            self.requestLayout(transition: .immediate)
            progressNode.transitionToState(.progress(color: .white, lineWidth: nil, value: CGFloat(max(0.027, min(1.0, progress))), cancelEnabled: false, animateRotation: true))
        }

        private func presentSourceUnavailableAlert() {
            guard let controller = self.controller else {
                return
            }
            let strings = self.context.sharedContext.currentPresentationData.with { $0 }.strings
            let alert = textAlertController(
                context: self.context,
                forceTheme: defaultDarkColorPresentationTheme,
                title: nil,
                text: strings.Story_Editor_MediaUnavailable,
                actions: [TextAlertAction(type: .defaultAction, title: strings.Common_OK, action: { [weak self, weak controller] in
                    if let self, self.skipUnavailablePage() {
                        return
                    }
                    controller?.dismissAnimated()
                })],
                dismissOnOutsideTap: false
            )
            controller.present(alert, in: .window(.root))
        }

        private func updateSourceProgressLayout(transition: ContainedViewLayoutTransition) {
            guard let progressNode = self.sourceProgressNode else {
                return
            }
            let size = CGSize(width: 50.0, height: 50.0)
            let bounds = self.previewContainerView.bounds
            transition.updateFrame(node: progressNode, frame: CGRect(origin: CGPoint(x: floor(bounds.midX - size.width / 2.0), y: floor(bounds.midY - size.height / 2.0)), size: size))
        }

        deinit {
            self.playerStateDisposable?.dispose()
            self.sourceLoadStateDisposable?.dispose()
            self.gifConversionDisposable.dispose()
            self.gallerySendInProgressDisposable?.dispose()
            self.itemsAppendDisposable?.dispose()
            self.filePreviewInfoDisposable?.dispose()
            self.selectionRevealTimer?.invalidate()
            if self.coveredContent.isHiding {
                let coveredContent = self.coveredContent
                Queue.mainQueue().async {
                    coveredContent.restore()
                }
            }
            if !self.isInvalidated {
                let mediaEditor = self.mediaEditor
                let entitiesView = self.entitiesView
                Queue.mainQueue().async {
                    Node.invalidate(mediaEditor: mediaEditor, entitiesView: entitiesView)
                }
            }
        }

        static func invalidate(mediaEditor: MediaEditor, entitiesView: DrawingEntitiesView) {
            mediaEditor.stop()
            mediaEditor.invalidate()
            entitiesView.invalidate()
        }

        func invalidate() {
            guard !self.isInvalidated else {
                return
            }
            self.isInvalidated = true
            self.coveredContent.invalidate()
            self.dismissTimerTooltip()
            self.dismissMuteTooltip()
            self.removeCoverEditViews(animated: false)
            self.destroyLivePhotoPlayer()
            self.playerStateDisposable?.dispose()
            self.playerStateDisposable = nil
            self.sourceLoadStateDisposable?.dispose()
            self.sourceLoadStateDisposable = nil
            self.gifConversionDisposable.set(nil)
            self.filePreviewInfoDisposable?.dispose()
            self.filePreviewInfoDisposable = nil
            Node.invalidate(mediaEditor: self.mediaEditor, entitiesView: self.entitiesView)
        }

        func requestLayout(transition: ContainedViewLayoutTransition) {
            if let layout = self.validLayout {
                self.containerLayoutUpdated(layout: layout, transition: transition)
            }
        }

        func containerLayoutUpdated(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
            self.validLayout = layout
            self.coveredContent.apply()

            let toolbarSide = self.toolbarSide(layout: layout)
            if toolbarSide != nil, self.isEditingCaption {
                let _ = self.captionPanelView?.dismissInput()
                if self.isEditingCaption {
                    self.view.endEditing(true)
                }
            }

            let keyboardHeight = layout.inputHeight ?? 0.0
            let safeInsets = self.editorSafeInsets(layout: layout)
            let captionPanelHeight = (self.captionPanelView?.baseHeight() ?? 0.0) + chatMediaEditorCaptionPanelSpacing
            let editorLayout = chatMediaEditorLayout(
                size: layout.size,
                safeInsets: safeInsets,
                mediaSize: self.previewMediaSize,
                toolbarHeight: chatMediaEditorToolbarHeight,
                captionPanelHeight: captionPanelHeight,
                keyboardHeight: keyboardHeight,
                toolbarSide: toolbarSide,
                reservedCorners: layout.reservedCorners
            )

            self.updatePagerLayout(layout: layout, transition: transition)
            let previewFrame = self.previewFrame(layout: layout)
            transition.updateFrame(view: self.previewContainerView, frame: previewFrame)
            self.updatePreviewContent(size: previewFrame.size, transition: transition)
            self.updateSourceProgressLayout(transition: transition)
            self.entitiesView.frame = CGRect(origin: .zero, size: self.canvasSize)
            self.drawingView.frame = CGRect(origin: .zero, size: self.canvasSize)

            transition.updateFrame(view: self.captionDimView, frame: CGRect(origin: .zero, size: layout.size))

            let isToolActive = self.activeTool != nil
            let isInterfaceHidden = self.isInterfaceHiddenBySwipe
            if let captionPanelView = self.captionPanelView {
                let containerFrame = CGRect(origin: .zero, size: layout.size)
                let isCaptionVisible = chatMediaEditorCaptionIsVisible(toolbarSide: toolbarSide, isToolActive: isToolActive, isInterfaceHidden: isInterfaceHidden)
                let isCaptionInteractive = chatMediaEditorCaptionIsVisible(toolbarSide: toolbarSide, isToolActive: isToolActive, isInterfaceHidden: false) && !self.isSending
                transition.updateFrame(view: self.captionContainerView, frame: containerFrame)
                transition.updateFrame(view: captionPanelView.view, frame: containerFrame)
                transition.updateAlpha(layer: captionPanelView.view.layer, alpha: isCaptionVisible ? 1.0 : 0.0)
                self.captionContainerView.isUserInteractionEnabled = isCaptionInteractive
                let bottomInset = layout.size.height - chatMediaEditorBottomPanelFrame(size: layout.size, safeInsets: safeInsets, toolbarHeight: chatMediaEditorToolbarHeight).minY + chatMediaEditorCaptionPanelSpacing
                let _ = captionPanelView.updateContainerLayoutSize?(layout.size, safeAreaInset: safeInsets, bottomInset: bottomInset, keyboardHeight: keyboardHeight, animated: transition.isAnimated)
            }
            let coveringKeyboardHeight = chatMediaEditorEffectiveKeyboardHeight(inputHeight: keyboardHeight, captionAdditionalInputHeight: self.captionPanelView?.additionalInputHeight ?? 0.0)
            transition.updateAlpha(layer: self.captionDimView.layer, alpha: chatMediaEditorCaptionDimIsVisible(isEditingCaption: self.isEditingCaption, keyboardHeight: coveringKeyboardHeight) ? 1.0 : 0.0)

            let recipientLayout = chatMediaEditorRecipientLayout(size: layout.size, safeInsets: safeInsets, arrowSize: self.recipientArrowView.image?.size ?? .zero, labelSize: self.recipientLabel.bounds.size, statusIsland: chatMediaEditorStatusIslandRow(layout: layout), toolbarSide: toolbarSide)
            transition.updateFrame(view: self.recipientArrowView, frame: recipientLayout.arrowFrame)
            transition.updateFrame(view: self.recipientLabel, frame: recipientLayout.labelFrame)
            let recipientAlpha: CGFloat = isToolActive || isInterfaceHidden || self.isEditingCaption || keyboardHeight > 0.0 ? 0.0 : 0.6
            transition.updateAlpha(layer: self.recipientArrowView.layer, alpha: recipientAlpha)
            transition.updateAlpha(layer: self.recipientLabel.layer, alpha: recipientAlpha)

            self.updateToolbar(frame: editorLayout.toolbarFrame, side: toolbarSide, keyboardHeight: coveringKeyboardHeight, transition: ComponentTransition(transition))
            self.updateSelectionLayout(layout: layout, safeInsets: safeInsets, toolbarFrame: editorLayout.toolbarFrame, keyboardHeight: keyboardHeight, transition: transition)
            self.updateCameraButtonLayout(layout: layout, safeInsets: safeInsets, toolbarFrame: editorLayout.toolbarFrame, keyboardHeight: keyboardHeight, transition: transition)
            self.updateScrubber(layout: layout, safeInsets: safeInsets, transition: ComponentTransition(transition))
            self.updateMuteButton(layout: layout, safeInsets: safeInsets, transition: transition)
            self.updateCoverLayout(layout: layout, safeInsets: safeInsets, transition: transition)
            self.updateLivePhotoLayout(layout: layout, safeInsets: safeInsets, transition: transition)
            self.updateCropLayout(layout: layout, transition: transition)
            self.updateQualityLayout(layout: layout, transition: transition)
            self.updatePlayButton(transition: transition)
            self.updatePagerInteraction()
            self.updateToolsLayoutStyle(layout: layout)
            self.updateEmbeddedToolLayout(layout: layout, transition: transition)
        }

        private func updateToolbar(frame: CGRect, side: ChatMediaEditorToolbarSide?, keyboardHeight: CGFloat, transition: ComponentTransition) {
            guard let controller = self.controller else {
                return
            }
            let isCropping = self.isCropping
            let isEditingQuality = self.isEditingQuality
            let mode: ChatMediaEditorBottomControlsMode
            if isCropping {
                mode = .crop(highlightedTabs: chatMediaEditorCropHighlightedTabs(state: self.cropSession?.current ?? self.committedCropState, baselineMirrored: self.mediaEditor.values.videoIsMirrored))
            } else if isEditingQuality {
                mode = .quality
            } else if self.activeTool == .tools {
                mode = .tools(selected: self.toolsSection, highlighted: self.highlightedToolsTabs)
            } else if self.activeTool == .paint {
                mode = .paint(selected: self.paintMode)
            } else {
                mode = .gallery(activeTab: self.activeToolbarTab)
            }
            let buttonsHidden = chatMediaEditorBottomControlsAreHidden(mode: mode, keyboardHeight: keyboardHeight, paintControlsVisible: self.paintControlsVisible)
            let isToolToolbar: Bool
            if case .gallery = mode {
                isToolToolbar = false
            } else {
                isToolToolbar = true
            }
            let items = chatMediaEditorBottomControlsItems(
                mode: mode,
                isGallery: self.isGallery,
                isVideo: self.subject.isVideo,
                showsQuality: self.showsQualityTab,
                policy: self.tabPolicy,
                sendButton: chatMediaEditorBottomControlsRightItem(doneButton: controller.gallery?.doneButton ?? TGPhotoEditorDoneButtonSend),
                highlightedTabs: self.highlightedToolbarTabs,
                disabledTabs: chatMediaEditorDisabledToolbarTabs(isVideo: self.subject.isVideo, values: self.mediaEditor.values),
                qualityHighQuality: self.captionModel?.isHighQualityPhoto ?? false,
                qualityPreset: self.toolbarVideoQualityPreset
            )
            if let lastSideItems = self.lastBottomControlsSideItems, lastSideItems.0 != items.left || lastSideItems.1 != items.right {
                self.lastBottomControlsSideItemsChange = CFAbsoluteTimeGetCurrent()
            }
            self.lastBottomControlsSideItems = (items.left, items.right)
            let strings = self.context.sharedContext.currentPresentationData.with { $0 }.strings
            let isBusy = self.isSending || controller.isDismissing
            let toolbarSize = self.toolbar.update(
                transition: transition,
                component: AnyComponent(
                    ChatMediaEditorBottomControlsComponent(
                        items: items,
                        isHidden: buttonsHidden,
                        isMiddleEnabled: !self.isAwaitingGifConversion,
                        areSideButtonsEnabled: !isBusy,
                        isRightEnabled: !isBusy,
                        infoString: self.qualityInfoString ?? self.filePreviewInfoString,
                        paintModeTitle: { tab in
                            switch tab {
                            case .draw:
                                return strings.Paint_Draw
                            case .sticker:
                                return strings.Paint_Sticker
                            case .text:
                                return strings.Paint_Text
                            }
                        },
                        leftPressed: { [weak self, weak controller] in
                            guard let self, chatMediaEditorBottomControlsSideTapAllowed(now: CFAbsoluteTimeGetCurrent(), lastSideItemsChange: self.lastBottomControlsSideItemsChange) else {
                                return
                            }
                            switch self.activeTool {
                            case .crop:
                                self.cancelCrop()
                            case .quality:
                                self.cancelQuality()
                            case .tools:
                                self.closeTools(apply: false)
                            case .paint:
                                self.drawingScreen?.requestExternalDismiss(sourceView: (self.toolbar.view as? ChatMediaEditorBottomControlsComponent.View)?.leftButtonView)
                            case .cover, .none:
                                let _ = self.endCaptionEditing()
                                controller?.cancel()
                            }
                        },
                        rightPressed: { [weak self] in
                            guard let self, chatMediaEditorBottomControlsSideTapAllowed(now: CFAbsoluteTimeGetCurrent(), lastSideItemsChange: self.lastBottomControlsSideItemsChange) else {
                                return
                            }
                            switch self.activeTool {
                            case .crop:
                                self.commitCrop()
                            case .quality:
                                self.commitQuality()
                            case .tools:
                                self.closeTools(apply: true)
                            case .paint:
                                self.drawingScreen?.requestExternalApply()
                            case .cover, .none:
                                self.send(silentPosting: false, scheduleTime: 0)
                            }
                        },
                        rightLongPressed: isToolToolbar || !(controller.gallery?.hasSendMenu ?? true) ? nil : { [weak self] sourceView in
                            guard let self else {
                                return
                            }
                            if self.isGallery {
                                self.suppressTimerTooltip()
                            }
                            self.presentSendMenu(sourceView: sourceView)
                        },
                        middlePressed: { [weak self] action in
                            guard let self else {
                                return
                            }
                            switch action {
                            case let .tab(tab):
                                self.toolbarTabPressed(tab)
                            case let .tools(tab):
                                self.selectToolsSection(tab)
                            case let .paint(tab):
                                self.selectPaintMode(tab)
                            }
                        },
                        accessibilityStrings: strings,
                        side: side
                    )
                ),
                environment: {},
                forceUpdate: true,
                containerSize: frame.size
            )
            if let toolbarView = self.toolbar.view {
                if toolbarView.superview == nil {
                    self.view.insertSubview(toolbarView, belowSubview: self.captionDimView)
                }
                transition.setFrame(view: toolbarView, frame: CGRect(origin: frame.origin, size: toolbarSize))
                let toolbarVisible = self.activeTool != .cover && !self.isInterfaceHiddenBySwipe
                transition.setAlpha(view: toolbarView, alpha: toolbarVisible ? 1.0 : 0.0)
                toolbarView.isUserInteractionEnabled = toolbarVisible
            }
        }

        func previewFrame(layout: ContainerViewLayout) -> CGRect {
            let safeInsets = self.editorSafeInsets(layout: layout)
            if let activeTool = self.activeTool {
                let kind: ChatMediaEditorToolPreviewKind
                switch activeTool {
                case .crop:
                    if let cropPreviewFrame = self.cropPreviewFrame {
                        return cropPreviewFrame
                    }
                    kind = .tools
                case .paint:
                    kind = .paint
                case .tools:
                    kind = .chatTools
                case .quality:
                    kind = .quality
                case .cover:
                    return self.restingPreviewFrame(layout: layout, mediaSize: self.previewMediaSize, isVideo: self.subject.isVideo, keepsToBand: true)
                }
                return chatMediaEditorToolPreviewFrame(kind: kind, size: layout.size, safeInsets: safeInsets, mediaSize: self.previewMediaSize, toolbarHeight: chatMediaEditorToolbarHeight, toolbarSide: kind == .chatTools || kind == .quality ? self.toolbarSide(layout: layout) : nil)
            }
            return self.restingPreviewFrame(layout: layout, mediaSize: self.previewMediaSize, isVideo: self.subject.isVideo)
        }

        func restingPreviewFrame(layout: ContainerViewLayout, mediaSize: CGSize, isVideo: Bool, keepsToBand: Bool = false) -> CGRect {
            let captionPanelHeight = (self.captionPanelView?.baseHeight() ?? 0.0) + chatMediaEditorCaptionPanelSpacing
            return chatMediaEditorRestingPreviewFrame(
                size: layout.size,
                safeInsets: self.editorSafeInsets(layout: layout),
                mediaSize: mediaSize,
                captionPanelHeight: captionPanelHeight,
                keepsToBand: keepsToBand,
                toolbarSide: self.toolbarSide(layout: layout),
                reservedCorners: layout.reservedCorners
            )
        }

        func editorSafeInsets(layout: ContainerViewLayout) -> UIEdgeInsets {
            var safeInsets = layout.safeInsets
            if layout.intrinsicInsets.bottom > 0.0 {
                safeInsets.bottom = layout.intrinsicInsets.bottom
            } else if let onScreenNavigationHeight = layout.deviceMetrics.onScreenNavigationHeight(inLandscape: layout.size.width > layout.size.height, systemOnScreenNavigationHeight: nil), onScreenNavigationHeight > 0.0 {
                safeInsets.bottom = onScreenNavigationHeight
            }
            return safeInsets
        }

        private var activeToolbarTab: TGPhotoEditorTab {
            switch self.activeTool {
            case .crop:
                return .cropTab
            case .paint:
                return .paintTab
            case .tools:
                return .toolsTab
            case .quality:
                return .qualityTab
            case .cover, .none:
                return []
            }
        }

        private var highlightedToolbarTabs: TGPhotoEditorTab {
            var tabs: TGPhotoEditorTab = []
            if self.hasCropChanges {
                tabs.insert(.cropTab)
            }
            if self.hasPaintChanges {
                tabs.insert(.paintTab)
            }
            if self.hasToolsChanges {
                tabs.insert(.toolsTab)
            }
            return tabs
        }

        func openInitialTool(_ tool: ChatMediaEditorInitialTool) {
            if tool != .none {
                self.resetCurrentPageZoom()
            }
            switch tool {
            case .paint:
                self.openPaint()
            case .tools:
                self.openTools()
            case .caption:
                self.activateCaptionInput()
            case .none:
                break
            }
        }

        func toolbarTabPressed(_ tab: TGPhotoEditorTab) {
            if self.isCropping {
                self.cropToolbarTabPressed(tab)
                return
            }
            guard let controller = self.controller, chatMediaEditorCanOpenTool(isToolActive: self.activeTool != nil, isSending: self.isSending, isDismissing: controller.isDismissing, isPagerMoving: self.isPagerMoving) else {
                return
            }
            guard self.endCaptionEditing() else {
                return
            }
            if tab == .qualityTab {
                self.qualityTabPressed()
                return
            }
            self.resetCurrentPageZoom()
            if tab == .cropTab {
                self.openCrop()
            } else if tab == .paintTab {
                self.openPaint()
            } else if tab == .toolsTab {
                self.openTools()
            }
        }

        private func presentSendMenu(sourceView: UIView?) {
            guard let controller = self.controller, let sourceView, !self.isSending, !controller.isDismissing else {
                return
            }
            guard self.endCaptionEditing() else {
                return
            }
            if let gallery = controller.gallery {
                let _ = (gallery.sendWhenOnlineAvailable
                |> take(1)
                |> deliverOnMainQueue).startStandalone(next: { [weak self] sendWhenOnlineAvailable in
                    self?.presentSendMenu(sourceView: sourceView, canSendWhenOnline: sendWhenOnlineAvailable)
                })
                return
            }
            self.presentSendMenu(sourceView: sourceView, canSendWhenOnline: true)
        }

        private func presentSendMenu(sourceView: UIView, canSendWhenOnline: Bool) {
            guard let controller = self.controller, !self.isSending, !controller.isDismissing else {
                return
            }
            let presenter = makeLegacyMediaPickerSendActionMenuPresenter(context: self.context, presentInGlobalOverlay: { [weak controller] menuController in
                controller?.presentInGlobalOverlay(menuController)
            })
            let options = chatMediaEditorSendMenuOptions(hasSchedule: controller.hasSchedule, sendWhenOnlineAvailable: canSendWhenOnline, hasTimer: self.sendMenuHasTimer, hasAnyTimer: self.currentItemHasAnyTimer)
            let _ = presenter(
                sourceView,
                controller.hasSilentPosting,
                options.canSendWhenOnline,
                options.canSchedule,
                controller.reminder,
                options.hasTimer,
                { [weak self] in
                    self?.send(silentPosting: true, scheduleTime: 0)
                },
                { [weak self] in
                    self?.send(silentPosting: false, scheduleTime: chatMediaEditorScheduleWhenOnlineTimestamp)
                },
                { [weak self, weak controller] in
                    controller?.presentSchedulePicker({ time, silentPosting in
                        self?.send(silentPosting: silentPosting, scheduleTime: time)
                    })
                },
                { [weak self] in
                    self?.sendWithTimer()
                }
            )
        }

        func send(silentPosting: Bool, scheduleTime: Int32) {
            guard let controller = self.controller, !self.isSending, !controller.isDismissing, !self.isInvalidated else {
                return
            }
            guard self.endCaptionEditing() else {
                return
            }
            self.dismissTimerTooltip()
            self.dismissMuteTooltip()
            if self.isGallery {
                guard let gallery = controller.gallery else {
                    return
                }
                self.saveCurrentItemEdits()
                let didSend = gallery.send(self.pageModel.currentItem.uniqueId, silentPosting, scheduleTime == 0 ? nil : scheduleTime, { [weak controller] in
                    controller?.dismissAfterGallerySend()
                })
                if !didSend {
                    HapticFeedback().error()
                } else if self.isGallerySendInProgress {
                    self.updateIsGallerySending(true)
                }
                return
            }

            let values = self.captureCurrentValues()
            let stickers = chatMediaSendCollectStickers(entities: values.entities)
            let caption = self.captionPanelView?.caption() ?? NSAttributedString()
            let isCaptionAbove = self.isCaptionAbove

            let completeWithResult: (ChatMediaEditorResult) -> Void = { [weak controller] result in
                guard let controller else {
                    return
                }
                controller.completion(result, silentPosting, scheduleTime, isCaptionAbove)
                controller.dismissAnimated()
            }

            switch self.subject {
            case let .image(image):
                self.sendImage(input: self.mediaEditor.resultTexture().map { .editorResult($0) } ?? .image(image), values: values, caption: caption, stickers: stickers, completion: completeWithResult)
            case let .video(path, _, duration):
                self.isSending = true
                self.requestLayout(transition: .immediate)
                self.sendVideo(path: path, duration: duration, values: values, caption: caption, stickers: stickers, completion: completeWithResult)
            case .asset:
                assertionFailure("single-item asset sending is not supported")
            }
        }

        private func gallerySendInProgressUpdated(_ inProgress: Bool) {
            self.isGallerySendInProgress = inProgress
            if !inProgress {
                self.updateIsGallerySending(false)
            }
        }

        private func updateIsGallerySending(_ isSending: Bool) {
            guard self.isGallery, self.isSending != isSending, !self.isInvalidated else {
                return
            }
            if isSending {
                let _ = self.captionPanelView?.dismissInput()
            }
            self.isSending = isSending
            self.requestLayout(transition: .immediate)
        }

        private func sendImage(input: MediaEditorCompositionInput, values: MediaEditorValues, caption: NSAttributedString, stickers: [TelegramMediaFile], completion: @escaping (ChatMediaEditorResult) -> Void) {
            self.isSending = true
            self.requestLayout(transition: .immediate)
            let nominalDimensions = chatMediaEditorCroppedNominalDimensions(values: values)
            makeChatEditorImageComposition(accountContext: self.context, input: input, values: values, time: .zero, maxOutputSide: chatMediaEditorImageMaxSide(forceHd: chatMediaEditorSendsForceHd), completion: { [weak self] resultImage in
                guard let self, let controller = self.controller, !controller.isDismissing, !self.isInvalidated else {
                    return
                }
                guard let resultImage else {
                    self.isSending = false
                    self.requestLayout(transition: .immediate)
                    return
                }
                completion(ChatMediaEditorResult(
                    media: .image(image: resultImage, nominalDimensions: nominalDimensions),
                    thumbnail: resultImage,
                    caption: caption,
                    stickers: stickers
                ))
            })
        }
    }

    let context: AccountContext
    let itemsSource: ChatMediaEditorItemsSource
    let store: ChatMediaEditorItemStore
    let initialIndex: Int
    let isGallery: Bool
    let selection: ChatMediaEditorSelectionAdapter?
    let captions: ChatMediaEditorCaptionAdapter?
    let initialTool: ChatMediaEditorInitialTool
    let initialCaption: NSAttributedString
    let recipientName: String?
    let getCaptionPanelView: () -> TGCaptionPanelView?
    let hasSilentPosting: Bool
    let hasSchedule: Bool
    let reminder: Bool
    let presentSchedulePicker: (@escaping (Int32, Bool) -> Void) -> Void
    let gallery: ChatMediaEditorGalleryConfiguration?
    let completion: (ChatMediaEditorResult, Bool, Int32, Bool) -> Void

    private var didAppear = false
    private(set) var isDismissing = false

    var node: Node {
        return self.displayNode as! Node
    }

    public init(
        context: AccountContext,
        subject: ChatMediaEditorSubject,
        initialTool: ChatMediaEditorInitialTool,
        initialCaption: NSAttributedString,
        recipientName: String?,
        getCaptionPanelView: @escaping () -> TGCaptionPanelView?,
        hasSilentPosting: Bool,
        hasSchedule: Bool,
        reminder: Bool,
        presentSchedulePicker: @escaping (@escaping (Int32, Bool) -> Void) -> Void,
        isAnimation: Bool = false,
        completion: @escaping (ChatMediaEditorResult, _ silentPosting: Bool, _ scheduleTime: Int32, _ isCaptionAbove: Bool) -> Void
    ) {
        self.context = context
        self.itemsSource = ChatMediaEditorListSource(items: [chatMediaEditorSingleItem(subject: subject, isAnimation: isAnimation)])
        self.store = ChatMediaEditorItemStore()
        self.initialIndex = 0
        self.isGallery = false
        self.selection = nil
        self.captions = nil
        self.gallery = nil
        self.initialTool = initialTool
        self.initialCaption = initialCaption
        self.recipientName = recipientName
        self.getCaptionPanelView = getCaptionPanelView
        self.hasSilentPosting = hasSilentPosting
        self.hasSchedule = hasSchedule
        self.reminder = reminder
        self.presentSchedulePicker = presentSchedulePicker
        self.completion = completion

        super.init(navigationBarPresentationData: nil)

        self.setupController()
    }

    public init(
        context: AccountContext,
        itemsSource: ChatMediaEditorItemsSource,
        initialIndex: Int,
        store: ChatMediaEditorItemStore,
        selection: ChatMediaEditorSelectionAdapter?,
        captions: ChatMediaEditorCaptionAdapter,
        recipientName: String?,
        getCaptionPanelView: @escaping () -> TGCaptionPanelView?,
        hasSilentPosting: Bool,
        hasSchedule: Bool,
        reminder: Bool,
        presentSchedulePicker: @escaping (@escaping (Int32, Bool) -> Void) -> Void,
        gallery: ChatMediaEditorGalleryConfiguration?,
        completion: @escaping (ChatMediaEditorResult, _ silentPosting: Bool, _ scheduleTime: Int32, _ isCaptionAbove: Bool) -> Void
    ) {
        precondition(itemsSource.count > 0)
        self.context = context
        self.itemsSource = itemsSource
        self.store = store
        self.initialIndex = max(0, min(itemsSource.count - 1, initialIndex))
        self.isGallery = true
        self.selection = selection
        self.captions = captions
        self.gallery = gallery
        self.initialTool = .none
        self.initialCaption = NSAttributedString()
        self.recipientName = recipientName
        self.getCaptionPanelView = getCaptionPanelView
        self.hasSilentPosting = hasSilentPosting
        self.hasSchedule = hasSchedule
        self.reminder = reminder
        self.presentSchedulePicker = presentSchedulePicker
        self.completion = completion

        super.init(navigationBarPresentationData: nil)

        self.setupController()
    }

    private func setupController() {
        self.statusBar.statusBarStyle = .White
        self.supportedOrientations = chatMediaEditorSupportedOrientations(locksPortrait: false)
        self.blocksBackgroundWhenInOverlay = true
        self.acceptsFocusWhenInOverlay = true
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self)
        self.displayNodeDidLoad()
        self.view.disablesInteractiveTransitionGestureRecognizer = true
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.node.coveredContent.setIsVisible(true)
        if !self.didAppear {
            self.didAppear = true
            if self.gallery != nil {
                self.node.animateGalleryIn()
                self.node.scheduleTimerTooltipIfNeeded()
            } else {
                self.node.animateIn()
            }
            self.node.openInitialTool(self.initialTool)
        }
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.node.containerLayoutUpdated(layout: layout, transition: transition)
    }

    func cancel() {
        guard !self.node.isSending else {
            return
        }
        if self.gallery?.camera != nil {
            self.node.cancelCameraReview()
            return
        }
        self.dismissAnimated()
    }

    func dismissAnimated() {
        guard !self.isDismissing else {
            return
        }
        self.isDismissing = true
        self.node.coveredContent.dismissBegan()
        self.node.requestLayout(transition: .immediate)
        if self.gallery != nil {
            self.node.animateGalleryOut(velocity: 0.0, completion: { [weak self] in
                self?.dismiss(completion: nil)
            })
        } else {
            self.node.animateOut(completion: { [weak self] in
                self?.dismiss(completion: nil)
            })
        }
    }

    func dismissAfterGallerySend() {
        guard !self.isDismissing else {
            return
        }
        self.isDismissing = true
        self.node.coveredContent.dismissBegan()
        self.node.requestLayout(transition: .immediate)
        let dismissAll = self.gallery?.dismissAll
        self.node.animateGalleryOutAfterSend(completion: { [weak self] in
            self?.dismiss(completion: nil)
        })
        dismissAll?()
    }

    func dismissAfterSwipe(velocity: CGFloat) {
        guard !self.isDismissing else {
            return
        }
        self.isDismissing = true
        self.node.coveredContent.dismissBegan()
        self.node.requestLayout(transition: .immediate)
        if self.gallery != nil {
            self.node.animateGalleryOut(velocity: velocity, completion: { [weak self] in
                self?.dismiss(completion: nil)
            })
        } else {
            self.node.animateOutAfterSwipe(velocity: velocity, completion: { [weak self] in
                self?.dismiss(completion: nil)
            })
        }
    }

    public func sendTransitionSnapshotView() -> UIView? {
        guard self.isNodeLoaded else {
            return nil
        }
        return self.node.gallerySendSnapshotView()
    }

    public func dismissGallery() {
        self.dismissAnimated()
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if self.isNodeLoaded {
            self.node.coveredContent.setIsVisible(false)
        }
    }

    override public func dismiss(completion: (() -> Void)? = nil) {
        if self.isNodeLoaded {
            self.node.invalidate()
        }
        super.dismiss(completion: completion)
    }
}
