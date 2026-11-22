import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import LegacyComponents
import ContextUI
import MediaPickerUI
import MediaEditor
import MediaCropComponent

public struct ChatMediaEditorCropSession {
    public let entry: MediaCropState
    public var current: MediaCropState

    public init(entry: MediaCropState) {
        self.entry = entry
        self.current = entry
    }

    public func committed() -> MediaCropState {
        return self.current
    }

    public func cancelled() -> MediaCropState {
        return self.entry
    }
}

public func chatMediaEditorCropState(values: MediaEditorValues) -> MediaCropState {
    var state = MediaCropState(originalSize: values.originalDimensions.cgSize)
    if let cropRect = values.cropRect, cropRect.width > 0.0, cropRect.height > 0.0 {
        state.cropRect = cropRect
    }
    state.rotation = values.cropRotation
    state.orientation = values.cropOrientation ?? .up
    state.mirrored = values.cropMirroring
    state.perspective = values.cropPerspective
    return state
}

public func chatMediaEditorValues(_ values: MediaEditorValues, applying state: MediaCropState) -> MediaEditorValues {
    let fullRect = CGRect(origin: .zero, size: state.originalSize)
    let rect: CGRect? = mediaCropRectsEqual(state.cropRect, fullRect, epsilon: CGFloat(Float.ulpOfOne)) ? nil : state.cropRect
    let orientation: MediaCropOrientation? = state.orientation == .up ? nil : state.orientation
    return values.withUpdatedCrop(rect: rect, rotation: state.rotation, orientation: orientation, mirroring: state.mirrored, perspective: state.perspective)
}

public func chatMediaEditorIdCardInitialValues(peerId: EnginePeer.Id, dimensions: PixelDimensions) -> MediaEditorValues {
    let values = chatMediaEditorValues(peerId: peerId, originalDimensions: dimensions, qualityPreset: .compressedVeryHigh)
    var state = MediaCropState(originalSize: dimensions.cgSize)
    state.cropRect = passportIdCardCropRect(imageSize: dimensions.cgSize)
    return chatMediaEditorValues(values, applying: state)
}

public func chatMediaEditorPreviewMediaSize(values: MediaEditorValues) -> CGSize {
    return mediaCropDisplayedSize(chatMediaEditorCropState(values: values))
}

public enum ChatMediaEditorTabPolicy {
    case standard
    case filePreview
    case cropOnly
}

public func chatMediaEditorToolbarTabs(showsQuality: Bool = false, policy: ChatMediaEditorTabPolicy = .standard) -> [TGPhotoEditorTab] {
    switch policy {
    case .standard:
        return showsQuality ? [.cropTab, .paintTab, .toolsTab, .qualityTab] : [.cropTab, .paintTab, .toolsTab]
    case .filePreview:
        return []
    case .cropOnly:
        return [.cropTab]
    }
}

public func chatMediaEditorCropToolbarTabs() -> [TGPhotoEditorTab] {
    return [.rotateTab, .mirrorTab, .aspectRatioTab]
}

public func chatMediaEditorCropStateHasChanges(_ state: MediaCropState, baselineMirrored: Bool) -> Bool {
    var state = state
    state.mirrored = state.mirrored != baselineMirrored
    return !state.isDefault
}

public struct ChatMediaEditorCropControlsLayout: Equatable {
    public let selector: CGRect
    public let rotationDial: CGRect
    public let rotationDialScale: CGFloat
    public let resetButton: CGRect
    public let rotationDialAxis: MediaCropDialAxis
}

private let chatMediaEditorCropResetButtonHeight: CGFloat = 24.0
private let chatMediaEditorCropDialResetSpacing: CGFloat = 14.0

public func chatMediaEditorCropControlsLayout(size: CGSize, safeInsets: UIEdgeInsets, toolbarHeight: CGFloat, hasRotationWheel: Bool, hasPerspective: Bool = false, resetButtonWidth: CGFloat, toolbarSide: ChatMediaEditorToolbarSide? = nil) -> ChatMediaEditorCropControlsLayout {
    let container = chatMediaEditorCropContainerFrame(size: size, safeInsets: safeInsets, toolbarHeight: toolbarHeight, hasRotationWheel: hasRotationWheel, hasPerspective: hasPerspective, toolbarSide: toolbarSide)
    if let toolbarSide {
        let column = chatMediaEditorLandscapeColumnFrame(size: size, safeInsets: safeInsets, side: toolbarSide)
        let resetStripMinX: CGFloat
        let dialMinX: CGFloat
        let selectorMinX: CGFloat
        switch toolbarSide {
        case .left:
            resetStripMinX = column.maxX
            dialMinX = resetStripMinX + chatMediaEditorCropLandscapeResetStripWidth
            selectorMinX = dialMinX + chatMediaEditorCropLandscapeDialStripWidth + chatMediaEditorCropSelectorDialSpacing
        case .right:
            resetStripMinX = column.minX - chatMediaEditorCropLandscapeResetStripWidth
            dialMinX = resetStripMinX - chatMediaEditorCropLandscapeDialStripWidth
            selectorMinX = dialMinX - chatMediaEditorCropSelectorDialSpacing - mediaCropAdjustmentSelectorHeight
        }
        let showsSelector = hasRotationWheel && hasPerspective
        return ChatMediaEditorCropControlsLayout(
            selector: showsSelector ? CGRect(x: selectorMinX, y: container.minY, width: mediaCropAdjustmentSelectorHeight, height: container.height) : .zero,
            rotationDial: hasRotationWheel ? CGRect(x: dialMinX, y: container.minY, width: chatMediaEditorCropLandscapeDialStripWidth, height: container.height) : .zero,
            rotationDialScale: 1.0,
            resetButton: CGRect(x: resetStripMinX + floor((chatMediaEditorCropLandscapeResetStripWidth - resetButtonWidth) / 2.0), y: container.minY + floor((container.height - chatMediaEditorCropResetButtonHeight) / 2.0), width: resetButtonWidth, height: chatMediaEditorCropResetButtonHeight),
            rotationDialAxis: .vertical(clockwise: toolbarSide == .left)
        )
    }
    let areaBottom = mediaCropAvailableArea(container: container).maxY
    let panelTop = size.height - safeInsets.bottom - toolbarHeight
    let showsSelector = hasRotationWheel && hasPerspective
    let selectorBlockHeight = showsSelector ? mediaCropAdjustmentSelectorHeight + chatMediaEditorCropSelectorDialSpacing : 0.0
    let dialBlockHeight = hasRotationWheel ? mediaCropRotationDialHeight + chatMediaEditorCropDialResetSpacing : 0.0
    let blockHeight = selectorBlockHeight + dialBlockHeight + chatMediaEditorCropResetButtonHeight
    let top = floor(areaBottom + (panelTop - areaBottom - blockHeight) / 2.0)
    var controlsMinX = container.minX
    var controlsWidth = container.width
    var rotationDialScale: CGFloat = 1.0
    if safeInsets.left != safeInsets.right {
        controlsMinX = 0.0
        controlsWidth = size.width
        let rulerHalfWidth = (mediaCropMaximumWheelAngle / mediaCropDialDegreesPerTick).rounded() * mediaCropDialTickSpacing
        rotationDialScale = (size.width / 2.0) / rulerHalfWidth
    }
    return ChatMediaEditorCropControlsLayout(
        selector: showsSelector ? CGRect(x: controlsMinX, y: top, width: controlsWidth, height: mediaCropAdjustmentSelectorHeight) : .zero,
        rotationDial: CGRect(x: controlsMinX, y: top + selectorBlockHeight, width: controlsWidth, height: mediaCropRotationDialHeight),
        rotationDialScale: rotationDialScale,
        resetButton: CGRect(x: floor((size.width - resetButtonWidth) / 2.0), y: top + selectorBlockHeight + dialBlockHeight, width: resetButtonWidth, height: chatMediaEditorCropResetButtonHeight),
        rotationDialAxis: .horizontal
    )
}

public func chatMediaEditorCropHasSessionChanges(entry: MediaCropState, current: MediaCropState) -> Bool {
    if entry.orientation != current.orientation || entry.mirrored != current.mirrored {
        return true
    }
    if abs(entry.rotation - current.rotation) > 0.0001 {
        return true
    }
    if entry.lockedAspectRatio != current.lockedAspectRatio {
        return true
    }
    if abs(entry.perspective.vertical - current.perspective.vertical) > 0.0001 || abs(entry.perspective.horizontal - current.perspective.horizontal) > 0.0001 {
        return true
    }
    let epsilon = max(1.0, max(entry.originalSize.width, entry.originalSize.height) * 0.005)
    return !mediaCropRectsEqual(entry.cropRect, current.cropRect, epsilon: epsilon)
}

public func chatMediaEditorCropShowsReset(state: MediaCropState, baselineMirrored: Bool) -> Bool {
    if state.lockedAspectRatio != nil {
        return true
    }
    return chatMediaEditorCropStateHasChanges(state, baselineMirrored: baselineMirrored)
}

public func chatMediaEditorCropHighlightedTabs(state: MediaCropState, baselineMirrored: Bool = false) -> TGPhotoEditorTab {
    var tabs: TGPhotoEditorTab = []
    if state.mirrored != baselineMirrored {
        tabs.insert(.mirrorTab)
    }
    if let lockedAspectRatio = state.lockedAspectRatio, lockedAspectRatio > CGFloat(Float.ulpOfOne) {
        tabs.insert(.aspectRatioTab)
    }
    return tabs
}

public func chatMediaEditorPaintEntityInitialRotation(state: MediaCropState) -> CGFloat {
    return -mediaCropContentAngle(state)
}

public func chatMediaEditorPaintEntityAdditionalScale(state: MediaCropState) -> CGFloat {
    guard state.originalSize.width > 0.0 else {
        return 1.0
    }
    return mediaCropDisplayedSize(state).width / state.originalSize.width
}

public struct ChatMediaEditorCropPreviewPlacement: Equatable {
    public var center: CGPoint
    public var scale: CGFloat
    public var angle: CGFloat
    public var perspective: MediaEditorPerspectiveHomography

    public var mediaTransform: CATransform3D {
        return CATransform3DConcat(self.perspective.transform3D(), CATransform3DMakeRotation(self.angle, 0.0, 0.0, 1.0))
    }
}

public func chatMediaEditorCropPreviewPlacement(state: MediaCropState, frameSize: CGSize) -> ChatMediaEditorCropPreviewPlacement {
    let placement = mediaCropContentPlacement(cropRect: state.cropRect, state: state, frame: CGRect(origin: .zero, size: frameSize))
    let mediaSize = CGSize(width: state.originalSize.width * placement.scale, height: state.originalSize.height * placement.scale)
    return ChatMediaEditorCropPreviewPlacement(center: placement.center, scale: placement.scale, angle: mediaCropContentAngle(state), perspective: MediaEditorPerspectiveHomography(perspective: state.perspective, size: mediaSize))
}

func chatMediaEditorTabSet(_ tabs: [TGPhotoEditorTab]) -> TGPhotoEditorTab {
    return tabs.reduce(into: TGPhotoEditorTab()) { result, tab in
        result.insert(tab)
    }
}

let chatMediaEditorPreviewMaxDrawableSide: CGFloat = 3072.0
private let chatMediaEditorCropEnterDuration: Double = 0.3
private let chatMediaEditorCropFadeDuration: Double = 0.2
private let chatMediaEditorCropCloseFadeDuration: Double = 0.1
private let chatMediaEditorCropAspectApplyDelay: Double = 0.1

final class ChatMediaEditorCropResetButton: UIButton {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.bounds.insetBy(dx: -10.0, dy: -10.0).contains(point)
    }
}

final class ChatMediaEditorReferenceContentSource: ContextReferenceContentSource {
    private weak var sourceView: UIView?

    init(sourceView: UIView) {
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        guard let sourceView = self.sourceView else {
            return nil
        }
        return ContextControllerReferenceViewInfo(referenceView: sourceView, contentAreaInScreenSpace: mainWindowScreenBounds, actionsPosition: .top)
    }
}

extension ChatMediaEditorScreen.Node {
    var committedCropState: MediaCropState {
        var state = chatMediaEditorCropState(values: self.mediaEditor.values)
        state.lockedAspectRatio = self.cropLockedAspectRatio
        return state
    }

    var previewMediaSize: CGSize {
        return chatMediaEditorPreviewMediaSize(values: self.mediaEditor.values)
    }

    var hasCropChanges: Bool {
        let values = self.mediaEditor.values
        return chatMediaEditorCropStateHasChanges(chatMediaEditorCropState(values: values), baselineMirrored: values.videoIsMirrored)
    }

    var isCropping: Bool {
        return self.activeTool == .crop
    }

    func updatePreviewContent(size: CGSize, transition: ContainedViewLayoutTransition) {
        let state = chatMediaEditorCropState(values: self.mediaEditor.values)
        let placement = chatMediaEditorCropPreviewPlacement(state: state, frameSize: size)
        let mediaSize = CGSize(width: state.originalSize.width * placement.scale, height: state.originalSize.height * placement.scale)

        let screenScale = self.view.window?.screen.scale ?? UIScreen.main.scale
        let maxSide = max(mediaSize.width, mediaSize.height)
        let contentScale = maxSide > 0.0 ? min(screenScale, chatMediaEditorPreviewMaxDrawableSide / maxSide) : screenScale
        if abs(self.previewView.contentScaleFactor - contentScale) > 0.001 {
            self.previewView.contentScaleFactor = contentScale
        }

        let previewTransform = CATransform3DConcat(CATransform3DMakeScale(state.mirrored ? -1.0 : 1.0, 1.0, 1.0), placement.mediaTransform)
        transition.updateBounds(layer: self.previewView.layer, bounds: CGRect(origin: .zero, size: mediaSize))
        transition.updatePosition(layer: self.previewView.layer, position: placement.center)
        transition.updateTransform(layer: self.previewView.layer, transform: previewTransform)
        self.previewView.setNeedsLayout()

        let entitiesScale = self.canvasSize.width > 0.0 ? mediaSize.width / self.canvasSize.width : 1.0
        self.entitiesContainerView.bounds = CGRect(origin: .zero, size: self.canvasSize)
        transition.updatePosition(layer: self.entitiesContainerView.layer, position: placement.center)
        transition.updateTransform(layer: self.entitiesContainerView.layer, transform: CGAffineTransform(scaleX: entitiesScale, y: entitiesScale).concatenating(CGAffineTransform(rotationAngle: placement.angle)))

        self.selectionContainerView.bounds = CGRect(origin: .zero, size: size)
        transition.updatePosition(layer: self.selectionContainerView.layer, position: CGPoint(x: size.width / 2.0, y: size.height / 2.0))
        transition.updateTransform(layer: self.selectionContainerView.layer, transform: CGAffineTransform(rotationAngle: placement.angle))
    }

    func cropContainerFrame(layout: ContainerViewLayout) -> CGRect {
        return chatMediaEditorCropContainerFrame(size: layout.size, safeInsets: self.editorSafeInsets(layout: layout), toolbarHeight: chatMediaEditorToolbarHeight, hasRotationWheel: !self.subject.isVideo, hasPerspective: !self.subject.isVideo, toolbarSide: self.toolbarSide(layout: layout))
    }

    func cropControlsLayout(layout: ContainerViewLayout, resetButtonWidth: CGFloat) -> ChatMediaEditorCropControlsLayout {
        return chatMediaEditorCropControlsLayout(size: layout.size, safeInsets: self.editorSafeInsets(layout: layout), toolbarHeight: chatMediaEditorToolbarHeight, hasRotationWheel: !self.subject.isVideo, hasPerspective: !self.subject.isVideo, resetButtonWidth: resetButtonWidth, toolbarSide: self.toolbarSide(layout: layout))
    }

    func updateCropLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let controlsLayout = self.cropControlsLayout(layout: layout, resetButtonWidth: self.cropResetButton?.bounds.width ?? 0.0)
        if let cropView = self.cropView {
            cropView.frame = CGRect(origin: .zero, size: layout.size)
            cropView.update(containerFrame: self.cropContainerFrame(layout: layout), rotationDialFrame: controlsLayout.rotationDial, rotationDialScale: controlsLayout.rotationDialScale, rotationDialAxis: controlsLayout.rotationDialAxis, selectorFrame: controlsLayout.selector, transition: ComponentTransition(transition))
        }
        if let resetButton = self.cropResetButton {
            self.applyCropResetButtonLayout(resetButton, controlsLayout: controlsLayout, transition: transition)
        }
    }

    private func applyCropResetButtonLayout(_ resetButton: UIView, controlsLayout: ChatMediaEditorCropControlsLayout, transition: ContainedViewLayoutTransition) {
        let frame = controlsLayout.resetButton
        var rotation: CGFloat = 0.0
        if case let .vertical(clockwise) = controlsLayout.rotationDialAxis, frame.width > chatMediaEditorCropLandscapeResetStripWidth {
            rotation = clockwise ? CGFloat.pi / 2.0 : -CGFloat.pi / 2.0
        }
        if rotation == 0.0 && resetButton.transform.isIdentity {
            transition.updateFrame(view: resetButton, frame: frame)
            return
        }
        let targetTransform = CGAffineTransform(rotationAngle: rotation)
        if resetButton.transform != targetTransform {
            resetButton.transform = targetTransform
            resetButton.bounds = CGRect(origin: .zero, size: frame.size)
            resetButton.center = CGPoint(x: frame.midX, y: frame.midY)
            return
        }
        transition.updateBounds(layer: resetButton.layer, bounds: CGRect(origin: .zero, size: frame.size))
        transition.updatePosition(layer: resetButton.layer, position: CGPoint(x: frame.midX, y: frame.midY))
    }

    private func cropSourceImage() -> UIImage? {
        if let image = self.mediaEditor.resultImage {
            return image
        }
        if case let .image(image) = self.subject {
            return image
        }
        return nil
    }

    private func cropOverlayImage() -> UIImage? {
        let hasEntities = self.entitiesView.entities.contains(where: { !($0 is DrawingMediaEntity) })
        guard self.mediaEditor.values.drawing != nil || hasEntities else {
            return nil
        }
        let canvasSize = self.canvasSize
        guard canvasSize.width > 0.0, canvasSize.height > 0.0 else {
            return nil
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        let entitiesView = self.entitiesView
        return UIGraphicsImageRenderer(size: canvasSize, format: format).image { _ in
            entitiesView.drawHierarchy(in: CGRect(origin: .zero, size: canvasSize), afterScreenUpdates: false)
        }
    }

    func openCrop() {
        guard self.activeTool == nil, !self.isSending, !self.isInvalidated, let controller = self.controller, !controller.isDismissing, let layout = self.validLayout else {
            return
        }
        guard let image = self.cropSourceImage() else {
            return
        }
        if self.entitiesView.hasSelection {
            self.entitiesView.selectEntity(nil)
        }
        self.toolStartValues = self.mediaEditor.values
        if self.subject.isVideo {
            self.cropWasPlaying = self.mediaEditor.isPlaying
            self.mediaEditor.stop()
        }

        let entry = self.committedCropState
        let cropView = MediaCropView(image: image, overlayImage: self.cropOverlayImage(), state: entry, hasRotationWheel: !self.subject.isVideo, hasPerspective: !self.subject.isVideo)
        cropView.resetMirrored = self.mediaEditor.values.videoIsMirrored
        cropView.stateUpdated = { [weak self] state in
            self?.cropStateUpdated(state)
        }
        cropView.interactionBegan = { [weak self] in
            self?.setInteractionTracking(true, source: "crop")
        }
        cropView.interactionEnded = { [weak self] in
            self?.setInteractionTracking(false, source: "crop")
        }
        cropView.alpha = 0.0
        cropView.layer.allowsGroupOpacity = true
        self.view.insertSubview(cropView, aboveSubview: self.pagerView)
        cropView.frame = CGRect(origin: .zero, size: layout.size)
        let initialControlsLayout = self.cropControlsLayout(layout: layout, resetButtonWidth: 0.0)
        cropView.update(containerFrame: self.cropContainerFrame(layout: layout), rotationDialFrame: initialControlsLayout.rotationDial, rotationDialScale: initialControlsLayout.rotationDialScale, rotationDialAxis: initialControlsLayout.rotationDialAxis, selectorFrame: initialControlsLayout.selector, transition: .immediate)
        self.cropView = cropView
        self.cropSession = ChatMediaEditorCropSession(entry: entry)
        self.cropPreviewFrame = cropView.cropFrameInSelf

        let resetButton = ChatMediaEditorCropResetButton(type: .custom)
        resetButton.isExclusiveTouch = true
        resetButton.titleLabel?.font = UIFont.systemFont(ofSize: 13.0)
        resetButton.setTitleColor(.white, for: .normal)
        resetButton.setTitle(self.context.sharedContext.currentPresentationData.with { $0 }.strings.PhotoEditor_CropReset, for: .normal)
        resetButton.sizeToFit()
        self.applyCropResetButtonLayout(resetButton, controlsLayout: self.cropControlsLayout(layout: layout, resetButtonWidth: ceil(resetButton.bounds.width)), transition: .immediate)
        resetButton.addTarget(self, action: #selector(self.cropResetPressed), for: .touchUpInside)
        resetButton.alpha = 0.0
        self.view.insertSubview(resetButton, aboveSubview: cropView)
        self.cropResetButton = resetButton

        self.activeTool = .crop
        self.updateEntityInteraction()
        self.requestLayout(transition: .animated(duration: chatMediaEditorCropEnterDuration, curve: .easeInOut))

        let showsReset = chatMediaEditorCropShowsReset(state: entry, baselineMirrored: cropView.resetMirrored)
        resetButton.isUserInteractionEnabled = showsReset
        UIView.animate(withDuration: chatMediaEditorCropEnterDuration, delay: 0.0, options: [.curveEaseInOut], animations: {
            resetButton.alpha = showsReset ? 1.0 : 0.0
        })
        UIView.animate(withDuration: chatMediaEditorCropFadeDuration, delay: chatMediaEditorCropEnterDuration, options: [.curveEaseInOut], animations: {
            cropView.alpha = 1.0
        }, completion: { [weak self, weak cropView] _ in
            guard let self, let cropView, self.cropView === cropView else {
                return
            }
            self.previewContainerView.isHidden = true
        })
    }

    private func cropStateUpdated(_ state: MediaCropState) {
        self.cropSession?.current = state
        self.updateCropResetVisibility(state: state)
        self.requestLayout(transition: .immediate)
    }

    private func updateCropResetVisibility(state: MediaCropState) {
        guard let resetButton = self.cropResetButton, let cropView = self.cropView else {
            return
        }
        let showsReset = chatMediaEditorCropShowsReset(state: state, baselineMirrored: cropView.resetMirrored)
        if resetButton.isUserInteractionEnabled == showsReset {
            return
        }
        resetButton.isUserInteractionEnabled = showsReset
        UIView.animate(withDuration: chatMediaEditorCropFadeDuration, delay: 0.0, options: [.beginFromCurrentState, .curveEaseInOut], animations: {
            resetButton.alpha = showsReset ? 1.0 : 0.0
        })
    }

    func cropToolbarTabPressed(_ tab: TGPhotoEditorTab) {
        guard let cropView = self.cropView else {
            return
        }
        if tab == .rotateTab {
            cropView.rotate90(animated: true)
        } else if tab == .mirrorTab {
            cropView.toggleMirror()
        } else if tab == .aspectRatioTab {
            self.cropAspectRatioPressed()
        }
    }

    @objc private func cropResetPressed() {
        guard let cropView = self.cropView else {
            return
        }
        cropView.reset(animated: true)
    }

    private func cropAspectRatioPressed() {
        guard let cropView = self.cropView, let controller = self.controller, !cropView.isAnimating else {
            return
        }
        if cropView.state.lockedAspectRatio != nil {
            cropView.setLockedAspectRatio(nil, animated: true)
            return
        }
        cropView.confirm(animated: true)
        guard let sourceView = (self.toolbar.view as? ChatMediaEditorBottomControlsComponent.View)?.middleItemView(id: chatMediaEditorBottomControlsTabId(.aspectRatioTab)) else {
            return
        }

        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkColorPresentationTheme)
        let displayedSize = mediaCropDisplayedSize(cropView.state)
        let strings = (original: presentationData.strings.PhotoEditor_CropAspectRatioOriginal, square: presentationData.strings.PhotoEditor_CropAspectRatioSquare)
        var items: [ContextMenuItem] = []
        for preset in mediaCropAspectPresets {
            items.append(.action(ContextMenuActionItem(text: mediaCropPresetTitle(preset, displayedSize: displayedSize, strings: strings), icon: { _ in
                return nil
            }, action: { [weak self] _, f in
                f(.default)
                Queue.mainQueue().after(chatMediaEditorCropAspectApplyDelay, {
                    self?.applyCropAspectPreset(preset)
                })
            })))
        }
        let contextController = makeContextController(
            context: self.context,
            presentationData: presentationData,
            source: .reference(ChatMediaEditorReferenceContentSource(sourceView: sourceView)),
            items: .single(ContextController.Items(content: .list(items)))
        )
        controller.presentInGlobalOverlay(contextController)
    }

    private func applyCropAspectPreset(_ preset: MediaCropAspectPreset) {
        guard let cropView = self.cropView else {
            return
        }
        cropView.setLockedAspectRatio(mediaCropLockedRatio(for: preset, state: cropView.state), animated: true)
    }

    func commitCrop() {
        guard let cropView = self.cropView, var session = self.cropSession else {
            return
        }
        if cropView.isTracking || cropView.isAnimating {
            return
        }
        cropView.confirmImmediately()
        session.current = cropView.state
        let state = session.committed()
        self.cropLockedAspectRatio = state.lockedAspectRatio
        let values = chatMediaEditorValues(self.mediaEditor.values, applying: state)
        self.mediaEditor.setCrop(rect: values.cropRect, rotation: values.cropRotation, orientation: values.cropOrientation, mirroring: values.cropMirroring, perspective: values.cropPerspective)
        self.selectionEditCommitted()
        self.closeCrop(fromFrame: cropView.cropFrameInSelf)
    }

    func cancelCrop() {
        guard let cropView = self.cropView, let session = self.cropSession, let controller = self.controller else {
            return
        }
        if cropView.isTracking || cropView.isAnimating {
            return
        }
        if let cropDiscardMenu = self.cropDiscardMenu, cropDiscardMenu.isViewLoaded, cropDiscardMenu.view.window != nil {
            return
        }
        guard cropView.hasPendingConfirmation || chatMediaEditorCropHasSessionChanges(entry: session.entry, current: cropView.state) else {
            self.discardCrop()
            return
        }
        guard let sourceView = (self.toolbar.view as? ChatMediaEditorBottomControlsComponent.View)?.leftButtonView else {
            self.discardCrop()
            return
        }
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
        let items: [ContextMenuItem] = [
            .action(ContextMenuActionItem(text: presentationData.strings.PhotoEditor_DiscardChanges, textColor: .destructive, icon: { _ in
                return nil
            }, action: { [weak self] f in
                f.dismissWithResult(.default)
                self?.discardCrop()
            }))
        ]
        let contextController = makeContextController(presentationData: presentationData, source: .reference(ChatMediaEditorReferenceContentSource(sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))))
        self.cropDiscardMenu = contextController
        controller.present(contextController, in: .window(.root))
    }

    private func discardCrop() {
        guard self.cropView != nil, let session = self.cropSession else {
            return
        }
        self.cropLockedAspectRatio = session.cancelled().lockedAspectRatio
        self.closeCrop(fromFrame: nil)
    }

    private func closeCrop(fromFrame: CGRect?) {
        guard let cropView = self.cropView else {
            return
        }
        if let fromFrame {
            self.cropPreviewFrame = fromFrame
            self.requestLayout(transition: .immediate)
        }
        self.previewContainerView.isHidden = false

        self.cropView = nil
        self.cropSession = nil
        self.cropPreviewFrame = nil
        cropView.interactionBegan = nil
        cropView.interactionEnded = nil
        self.setInteractionTracking(false, source: "crop")
        let resetButton = self.cropResetButton
        self.cropResetButton = nil
        self.activeTool = nil
        self.updateEntityInteraction()

        if fromFrame != nil {
            self.requestLayout(transition: mediaCropSpringTransition(mediaCropPopSpring(speed: 12.0, bounciness: 1.0)))
        } else {
            self.requestLayout(transition: .animated(duration: chatMediaEditorCropFadeDuration, curve: .easeInOut))
        }

        cropView.layer.allowsGroupOpacity = true
        UIView.animate(withDuration: chatMediaEditorCropCloseFadeDuration, delay: 0.0, options: [.curveEaseOut], animations: {
            cropView.alpha = 0.0
        })
        UIView.animate(withDuration: chatMediaEditorCropFadeDuration, delay: 0.0, options: [.curveEaseInOut], animations: {
            resetButton?.alpha = 0.0
        }, completion: { _ in
            cropView.removeFromSuperview()
            resetButton?.removeFromSuperview()
        })

        if self.subject.isVideo && self.cropWasPlaying && self.canResumePlayback {
            self.mediaEditor.play()
        }
        self.cropWasPlaying = false
    }
}
