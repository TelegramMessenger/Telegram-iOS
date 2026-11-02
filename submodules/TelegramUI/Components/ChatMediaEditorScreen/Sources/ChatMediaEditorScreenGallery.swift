import Foundation
import UIKit
import Display
import SwiftSignalKit
import AccountContext
import ComponentFlow
import MediaEditorBottomControls
import MediaEditor
import DrawingUI
import MediaAssetsContext
import ChatMediaSend

public func chatMediaEditorPlayButtonIsVisible(isPlaying: Bool, hasPlayed: Bool, isScrubberTracking: Bool) -> Bool {
    return hasPlayed && !isPlaying && !isScrubberTracking
}

let chatMediaEditorPlayButtonImage: UIImage? = generateImage(CGSize(width: 60.0, height: 60.0), rotatedContext: { size, context in
    context.clear(CGRect(origin: .zero, size: size))
    context.setFillColor(UIColor(white: 0.0, alpha: 0.6).cgColor)
    context.fillEllipse(in: CGRect(origin: .zero, size: size))
    context.setFillColor(UIColor.white.cgColor)
    let triangleSize = CGSize(width: 20.0, height: 23.0)
    let origin = CGPoint(x: floor((size.width - triangleSize.width) / 2.0) + 3.0, y: floor((size.height - triangleSize.height) / 2.0))
    context.move(to: origin)
    context.addLine(to: CGPoint(x: origin.x + triangleSize.width, y: origin.y + triangleSize.height / 2.0))
    context.addLine(to: CGPoint(x: origin.x, y: origin.y + triangleSize.height))
    context.closePath()
    context.fillPath()
})

private let chatMediaEditorThumbnailMaxSide: CGFloat = 1280.0

struct ChatMediaEditorItemComponents {
    let subject: ChatMediaEditorSubject
    let canvasSize: CGSize
    let previewView: MediaEditorPreviewView
    let entitiesContainerView: UIView
    let entitiesView: DrawingEntitiesView
    let drawingView: DrawingView
    let selectionContainerView: DrawingSelectionContainerView
    let mediaEditor: MediaEditor
    let qualityPresetBaseline: MediaQualityPreset?

    init(context: AccountContext, item: ChatMediaEditorItem, values: MediaEditorValues?) {
        let subject = chatMediaEditorItemSubject(item, convertedGif: { identifier in
            return ChatMediaSendGifConverter.shared.cachedGif(identifier: identifier)
        })
        self.subject = subject
        let canvasSize = mediaEditorNonStoryCanvasSize(originalDimensions: subject.dimensions)
        self.canvasSize = canvasSize
        self.previewView = MediaEditorPreviewView(frame: .zero)
        self.entitiesContainerView = UIView(frame: CGRect(origin: .zero, size: canvasSize))
        self.entitiesView = DrawingEntitiesView(context: context, size: canvasSize, hasBin: false, isStickerEditor: false)
        self.drawingView = DrawingView(size: canvasSize)
        self.drawingView.isUserInteractionEnabled = false
        self.selectionContainerView = DrawingSelectionContainerView(frame: .zero)
        self.entitiesView.selectionContainerView = self.selectionContainerView

        let setup = chatMediaEditorEditorSetup(subject: subject, peerId: context.account.peerId, isAnimation: item.isAnimation, isMirrored: item.isMirrored)
        self.qualityPresetBaseline = values == nil ? setup.values.qualityPreset : nil
        self.mediaEditor = MediaEditor(context: context, mode: .default, subject: setup.subject, values: values ?? setup.values, hasHistogram: chatMediaEditorHasCurvesHistogram(.item(isVideo: subject.isVideo)))
        if subject.isVideo {
            self.mediaEditor.maxDuration = .greatestFiniteMagnitude
        }
    }
}

extension ChatMediaEditorScreen.Node {
    func setupPager() {
        self.pagerView.pageMediaFrame = { [weak self] index in
            return self?.pageMediaFrame(index: index) ?? .zero
        }
        self.pagerView.configurePage = { [weak self] page in
            self?.configurePage(page)
        }
        self.setupDrawingZoomOut()
        self.pagerView.pageZoomUpdated = { [weak self] page in
            guard let self else {
                return
            }
            if page.isPaintZoomEnabled {
                self.drawingView.updateZoomScale(page.zoomScale)
            }
            self.updatePagerInteraction()
        }
        self.pagerView.pageTapped = { [weak self] page in
            self?.handlePageTap(page)
        }
        self.pagerView.settled = { [weak self] index in
            self?.switchToPage(index)
        }
        self.pagerView.canSwipeDown = { [weak self] in
            return self?.canSwipeDown ?? false
        }
        self.pagerView.swipeDownUpdated = { [weak self] recognizer in
            self?.handleSwipeDown(recognizer)
        }
    }

    func installCurrentItem(values: MediaEditorValues?) {
        self.previewContainerView.insertSubview(self.previewView, belowSubview: self.playButtonView)
        self.previewContainerView.insertSubview(self.entitiesContainerView, belowSubview: self.playButtonView)
        self.entitiesContainerView.addSubview(self.entitiesView)
        self.entitiesView.addSubview(self.drawingView)
        self.previewContainerView.insertSubview(self.selectionContainerView, belowSubview: self.playButtonView)

        self.setupEntitiesViewHooks()
        if let values {
            for entity in values.entities {
                self.entitiesView.add(entity.entity.duplicate(copy: true), announce: false)
            }
            if let drawingData = values.drawing?.pngData() {
                self.drawingView.setup(withDrawing: drawingData)
            }
        }

        self.isCurrentItemDisplayed = false
        let mediaEditor = self.mediaEditor
        mediaEditor.onFirstDisplay = { [weak self, weak mediaEditor] in
            Queue.mainQueue().async {
                guard let self, let mediaEditor, self.mediaEditor === mediaEditor else {
                    return
                }
                self.isCurrentItemDisplayed = true
                self.updateCurrentPageThumbnailVisibility()
            }
        }
        mediaEditor.attachPreviewView(self.previewView, andPlay: true)
        self.sourceLoadStateDisposable = (mediaEditor.sourceLoadState
        |> deliverOnMainQueue).startStrict(next: { [weak self] state in
            self?.updateSourceIndicatorState(chatMediaEditorSourceIndicatorState(state))
        })
        self.updateEntityInteraction()
        self.startGifConversionIfNeeded()
        self.updateFilePreviewInfo()
    }

    var isAwaitingGifConversion: Bool {
        return chatMediaEditorItemAwaitsGifConversion(self.pageModel.currentItem, subject: self.subject)
    }

    private func startGifConversionIfNeeded() {
        let item = self.pageModel.currentItem
        guard chatMediaEditorItemAwaitsGifConversion(item, subject: self.subject), case let .asset(asset) = item.source else {
            self.gifConversionDisposable.set(nil)
            return
        }
        let uniqueId = item.uniqueId
        self.gifConversionDisposable.set((ChatMediaSendGifConverter.shared.convertGif(identifier: asset.localIdentifier)
        |> deliverOnMainQueue).startStrict(next: { [weak self] converted in
            guard let self, converted != nil else {
                return
            }
            self.gifConversionCompleted(uniqueId: uniqueId)
        }))
    }

    private func gifConversionCompleted(uniqueId: String) {
        let item = self.pageModel.currentItem
        guard !self.isInvalidated, item.uniqueId == uniqueId, self.isAwaitingGifConversion, self.activeTool == nil, !self.isSending else {
            return
        }
        let values = self.pageModel.store.entry(for: uniqueId)?.values
        let lockedAspectRatio = self.cropLockedAspectRatio
        self.teardownCurrentItem()
        self.applyItemComponents(ChatMediaEditorItemComponents(context: self.context, item: item, values: values), uniqueId: uniqueId)
        self.cropLockedAspectRatio = lockedAspectRatio
        self.installCurrentItem(values: values)
        self.requestLayout(transition: .immediate)
    }

    private func applyItemComponents(_ components: ChatMediaEditorItemComponents, uniqueId: String) {
        self.pageModel.store.noteQualityPresetBaseline(components.qualityPresetBaseline, for: uniqueId)
        self.subject = components.subject
        self.canvasSize = components.canvasSize
        self.previewView = components.previewView
        self.entitiesContainerView = components.entitiesContainerView
        self.entitiesView = components.entitiesView
        self.drawingView = components.drawingView
        self.selectionContainerView = components.selectionContainerView
        self.mediaEditor = components.mediaEditor
        self.setupDrawingZoomOut()
    }

    func setupDrawingZoomOut() {
        self.drawingView.zoomOut = { [weak self] in
            guard let self, let page = self.pagerView.page(at: self.pageModel.currentIndex), page.isPaintZoomEnabled else {
                return
            }
            page.resetZoom(animated: true)
        }
    }

    private func teardownCurrentItem() {
        self.gifConversionDisposable.set(nil)
        self.dismissMuteTooltip()
        self.playerStateDisposable?.dispose()
        self.playerStateDisposable = nil
        self.playerState = nil
        self.hasStartedPlayback = false
        self.sourceLoadStateDisposable?.dispose()
        self.sourceLoadStateDisposable = nil
        if let progressNode = self.sourceProgressNode {
            self.sourceProgressNode = nil
            progressNode.view.removeFromSuperview()
        }
        self.sourceIndicatorState = .hidden

        self.mediaEditor.onFirstDisplay = {}
        ChatMediaEditorScreen.Node.invalidate(mediaEditor: self.mediaEditor, entitiesView: self.entitiesView)
        self.previewView.removeFromSuperview()
        self.entitiesContainerView.removeFromSuperview()
        self.selectionContainerView.removeFromSuperview()

        self.scrubber.view?.removeFromSuperview()
        self.scrubber = ComponentView<Empty>()
        self.releaseScrubberTracking()
        self.removeCoverEditViews(animated: false)

        self.cropSession = nil
        self.cropView?.removeFromSuperview()
        self.cropView = nil
        self.cropResetButton?.removeFromSuperview()
        self.cropResetButton = nil
        self.cropPreviewFrame = nil
        self.cropWasPlaying = false
        self.cropLockedAspectRatio = nil
        self.qualityPanelView?.removeFromSuperview()
        self.qualityPanelView = nil
        self.qualitySelection = nil
        self.activeTool = nil
        self.previousDrawingData = nil
        self.previousDrawingEntities = nil
        self.previewContainerView.isHidden = false
        self.playButtonView.alpha = 0.0
    }

    func captureCurrentValues() -> MediaEditorValues {
        let entities = self.entitiesView.entities.filter { !($0 is DrawingMediaEntity) }
        let codableEntities = DrawingEntitiesView.encodeEntities(entities, entitiesView: self.entitiesView)
        self.mediaEditor.setDrawingAndEntities(data: nil, image: self.mediaEditor.values.drawing, entities: codableEntities)
        return self.mediaEditor.values
    }

    func switchToPage(_ index: Int) {
        guard index != self.pageModel.currentIndex, !self.isInvalidated else {
            return
        }
        guard self.activeTool == nil, !self.isSending else {
            self.pagerView.scrollToPage(self.pageModel.currentIndex, animated: true)
            return
        }
        let previousIndex = self.pageModel.currentIndex
        let previousItem = self.pageModel.currentItem
        let values = self.captureCurrentValues()
        let previousInput = self.mediaEditor.resultTexture().map { MediaEditorCompositionInput.editorResult($0) }
        let previousEntry = self.pageModel.store.entry(for: previousItem.uniqueId)
        let willSave = chatMediaEditorShouldSaveItem(hasEntry: previousEntry != nil, values: values, baselineQualityPreset: self.pageModel.store.qualityPresetBaseline(for: previousItem.uniqueId))
        guard let restore = self.pageModel.switchPage(to: index, savingValues: values, lockedAspectRatio: self.cropLockedAspectRatio) else {
            return
        }
        if willSave {
            self.thumbnailReporter?.itemSaved(previousItem.uniqueId, previousValues: previousEntry?.values, values: values)
        }
        self.composeThumbnailIfNeeded(uniqueId: previousItem.uniqueId, values: values, input: previousInput)

        self.teardownCurrentItem()
        self.applyItemComponents(ChatMediaEditorItemComponents(context: self.context, item: restore.item, values: restore.values), uniqueId: restore.item.uniqueId)
        self.cropLockedAspectRatio = restore.lockedAspectRatio
        self.installCurrentItem(values: restore.values)

        if let page = self.pagerView.page(at: previousIndex) {
            if let thumbnail = self.pageModel.storedThumbnail(at: previousIndex) {
                page.thumbnailDisposable.set(nil)
                page.thumbnailView.image = thumbnail
            }
            page.thumbnailView.isHidden = false
        }
        self.switchCaption(to: restore.item.uniqueId)
        self.refreshSelectionControls(animated: false)
        self.galleryFocusedItemChanged()
        self.requestLayout(transition: .immediate)
        self.scheduleTimerTooltipIfNeeded()
    }

    func saveCurrentItemEdits() {
        guard self.isGallery, !self.isInvalidated else {
            return
        }
        let item = self.pageModel.currentItem
        let values = self.captureCurrentValues()
        let previousValues = self.pageModel.store.entry(for: item.uniqueId)?.values
        guard self.pageModel.save(values: values, lockedAspectRatio: self.cropLockedAspectRatio) else {
            return
        }
        self.thumbnailReporter?.itemSaved(item.uniqueId, previousValues: previousValues, values: values)
        self.composeThumbnailIfNeeded(uniqueId: item.uniqueId, values: values, input: self.mediaEditor.resultTexture().map { .editorResult($0) })
    }

    private func composeThumbnailIfNeeded(uniqueId: String, values: MediaEditorValues, input: MediaEditorCompositionInput?) {
        guard chatMediaEditorValuesHaveVisualEdits(values), self.pageModel.store.entry(for: uniqueId)?.thumbnail == nil, let input else {
            return
        }
        let hasReporter = self.thumbnailReporter != nil
        makeChatEditorImageComposition(accountContext: self.context, input: input, values: values, time: .zero, maxOutputSide: chatMediaEditorThumbnailMaxSide, completion: { [weak self] image in
            guard let image else {
                return
            }
            Queue.concurrentDefaultQueue().async {
                let storedImage = chatMediaEditorCompactThumbnail(image)
                let gridThumbnail = hasReporter ? chatMediaEditorGridThumbnail(image) : nil
                Queue.mainQueue().async {
                    guard let self, !self.isInvalidated else {
                        return
                    }
                    guard self.pageModel.storeThumbnail(storedImage, uniqueId: uniqueId, values: values) else {
                        return
                    }
                    if let reporter = self.thumbnailReporter, let gridThumbnail {
                        reporter.thumbnailStored(storedImage, gridThumbnail: gridThumbnail, for: uniqueId, store: self.pageModel.store)
                    }
                    if let index = self.pageModel.itemsSource.index(of: uniqueId), index != self.pageModel.currentIndex {
                        self.pagerView.reloadPage(at: index)
                    }
                }
            }
        })
    }

    private func pageMediaFrame(index: Int) -> CGRect {
        guard let layout = self.validLayout else {
            return .zero
        }
        if index == self.pageModel.currentIndex {
            return self.restingPreviewFrame(layout: layout, mediaSize: self.previewMediaSize, isVideo: self.subject.isVideo)
        }
        let item = self.pageModel.itemsSource.item(at: index)
        let mediaSize: CGSize
        if let values = self.pageModel.store.entry(for: item.uniqueId)?.values {
            mediaSize = chatMediaEditorPreviewMediaSize(values: values)
        } else {
            mediaSize = item.source.dimensions.cgSize
        }
        return self.restingPreviewFrame(layout: layout, mediaSize: mediaSize, isVideo: item.source.isVideo || item.isAnimation)
    }

    private func pageThumbnailSignal(item: ChatMediaEditorItem) -> Signal<UIImage?, NoError> {
        if let thumbnail = self.pageModel.store.entry(for: item.uniqueId)?.thumbnail {
            return .single(thumbnail)
        }
        var targetSize = CGSize(width: chatMediaEditorThumbnailMaxSide, height: chatMediaEditorThumbnailMaxSide)
        if let layout = self.validLayout {
            let scale = self.view.window?.screen.scale ?? UIScreen.main.scale
            targetSize = CGSize(width: layout.size.width * scale, height: layout.size.height * scale)
        }
        switch item.source {
        case let .asset(asset):
            return assetImage(asset: asset, targetSize: targetSize, exact: false)
        case let .image(image):
            return .single(image)
        case let .imageFile(path, _):
            return .single(item.thumbnail) |> then(chatMediaEditorFileThumbnailSignal(path: path, maxPixelSide: max(targetSize.width, targetSize.height)))
        case .video:
            return .single(item.thumbnail)
        }
    }

    private func configurePage(_ page: ChatMediaEditorPageView) {
        let index = page.index
        guard index >= 0, index < self.pageModel.itemsSource.count else {
            return
        }
        let item = self.pageModel.itemsSource.item(at: index)
        page.thumbnailView.image = nil
        page.thumbnailDisposable.set((self.pageThumbnailSignal(item: item)
        |> deliverOnMainQueue).startStrict(next: { [weak page] image in
            page?.thumbnailView.image = image
        }))
        page.thumbnailView.isHidden = self.isCurrentPageThumbnailHidden(index: index)
    }

    private func isCurrentPageThumbnailHidden(index: Int) -> Bool {
        return index == self.pageModel.currentIndex && (self.isCurrentItemDisplayed || self.activeTool != nil)
    }

    func updateCurrentPageThumbnailVisibility() {
        for (index, page) in self.pagerView.pages {
            page.thumbnailView.isHidden = self.isCurrentPageThumbnailHidden(index: index)
        }
    }

    func updatePagerLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let spacing = chatMediaEditorPagerPageSpacing
        (self.isGallery ? transition : .immediate).updateFrame(view: self.pagerView, frame: CGRect(x: -spacing / 2.0, y: self.keyboardPagerOffset, width: layout.size.width + spacing, height: layout.size.height))
        self.pagerView.update(size: layout.size, count: self.pageModel.itemsSource.count, currentIndex: self.pageModel.currentIndex)
        if let page = self.pagerView.page(at: self.pageModel.currentIndex), self.previewContainerView.superview !== page.contentView {
            page.contentView.insertSubview(self.previewContainerView, aboveSubview: page.thumbnailView)
        }
        self.updateCurrentPageThumbnailVisibility()
    }

    private var isPagerIdle: Bool {
        return self.activeTool == nil && !self.isSending && !self.isEditingCaption && !(self.controller?.isDismissing ?? true)
    }

    var canSwipeDown: Bool {
        guard self.isGallery, self.isPagerIdle, self.controller?.gallery?.camera == nil else {
            return false
        }
        return !(self.pagerView.page(at: self.pageModel.currentIndex)?.isZoomed ?? false)
    }

    func updatePagerInteraction() {
        let isIdle = self.isPagerIdle && !self.isSwipingDown
        self.pagerView.setScrollEnabled(self.isGallery && isIdle && self.pageModel.itemsSource.count > 1)
        let currentIndex = self.pageModel.currentIndex
        let isPainting = self.activeTool == .paint && !self.isSending && !(self.controller?.isDismissing ?? true)
        for (index, page) in self.pagerView.pages {
            if index == currentIndex, isPainting || page.isPaintZoomEnabled, let layout = self.validLayout {
                page.update(mediaFrame: isPainting ? self.previewFrame(layout: layout) : self.restingPreviewFrame(layout: layout, mediaSize: self.previewMediaSize, isVideo: self.subject.isVideo))
            }
            let isPaintZoomEnabled = isPainting && index == currentIndex
            if page.shouldBeginPaintZoom == nil {
                page.shouldBeginPaintZoom = { [weak self] in
                    guard let self else {
                        return false
                    }
                    return !self.entitiesView.hasSelection && !self.entitiesView.isEditingText
                }
            }
            if page.isPaintZoomEnabled != isPaintZoomEnabled {
                page.isPaintZoomEnabled = isPaintZoomEnabled
                if index == currentIndex {
                    self.drawingView.updateZoomScale(isPaintZoomEnabled ? page.zoomScale : 1.0)
                }
            }
            page.isZoomEnabled = self.isGallery && isIdle && index == currentIndex && !self.subject.isVideo
            page.isTapEnabled = self.isGallery && isIdle && index == currentIndex && !self.subject.isVideo && (self.selectionModel?.isEnabled ?? false)
        }
        self.previewTapRecognizer.isEnabled = self.subject.isVideo
        let isZoomed = self.pagerView.page(at: currentIndex)?.isZoomed ?? false
        self.pagerView.swipeDownRecognizer.isEnabled = self.isGallery && (isIdle || self.isSwipingDown) && !isZoomed
    }

    var isPagerMoving: Bool {
        if self.pagerView.isScrolling {
            return true
        }
        if let page = self.pagerView.page(at: self.pageModel.currentIndex), page.zoomScrollView.isZooming || page.zoomScrollView.isZoomBouncing {
            return true
        }
        return false
    }

    func resetCurrentPageZoom() {
        self.pagerView.page(at: self.pageModel.currentIndex)?.resetZoom(animated: false)
    }

    func updatePlayButton(transition: ContainedViewLayoutTransition) {
        let size = CGSize(width: 60.0, height: 60.0)
        let bounds = self.previewContainerView.bounds
        transition.updateFrame(view: self.playButtonView, frame: CGRect(origin: CGPoint(x: floor(bounds.midX - size.width / 2.0), y: floor(bounds.midY - size.height / 2.0)), size: size))
        var isVisible = false
        if self.isGallery, self.subject.isVideo, self.activeTool == nil, !self.isSending, let playerState = self.playerState {
            isVisible = chatMediaEditorPlayButtonIsVisible(isPlaying: playerState.isPlaying, hasPlayed: self.hasStartedPlayback, isScrubberTracking: self.isScrubberTracking)
        }
        transition.updateAlpha(layer: self.playButtonView.layer, alpha: isVisible ? 1.0 : 0.0)
    }

    func skipUnavailablePage() -> Bool {
        let count = self.pageModel.itemsSource.count
        guard self.isGallery, count > 1 else {
            return false
        }
        let currentIndex = self.pageModel.currentIndex
        let targetIndex = currentIndex + 1 < count ? currentIndex + 1 : currentIndex - 1
        self.pagerView.scrollToPage(targetIndex, animated: true)
        return true
    }

    private func handleSwipeDown(_ recognizer: ChatMediaEditorSwipeDownGestureRecognizer) {
        switch recognizer.state {
        case .began, .changed:
            if !self.isSwipingDown {
                self.isSwipingDown = true
                self.coveredContent.setIsSwipingDown(true)
                self.updatePagerInteraction()
            }
            let offset = recognizer.translation.y
            self.swipeOffset = offset
            self.pagerView.setSwipeOffset(offset)
            self.backgroundColor = UIColor(white: 0.0, alpha: chatMediaEditorSwipeDownBackgroundAlpha(translation: offset))
            let isHidden = chatMediaEditorSwipeDownProgress(translation: offset) > 0.0
            if isHidden != self.isInterfaceHiddenBySwipe {
                self.isInterfaceHiddenBySwipe = isHidden
                self.requestLayout(transition: .animated(duration: 0.2, curve: .easeInOut))
                for view in self.blurFadedChromeViews {
                    ComponentTransition.animateTransientBlur(layer: view.layer, fromRadius: isHidden ? 0.0 : mediaEditorBottomControlsHandoffBlurRadius, toRadius: isHidden ? mediaEditorBottomControlsHandoffBlurRadius : 0.0, duration: 0.2)
                }
            }
        case .ended, .cancelled:
            let offset = recognizer.translation.y
            let velocity = recognizer.velocity.y
            if recognizer.state == .ended, chatMediaEditorSwipeDownShouldDismiss(translation: offset, velocity: velocity), let controller = self.controller {
                controller.dismissAfterSwipe(velocity: velocity)
                return
            }
            self.isSwipingDown = false
            self.swipeOffset = 0.0
            UIView.animate(withDuration: 0.3, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
                self.pagerView.setSwipeOffset(0.0)
                self.backgroundColor = .black
            }, completion: { [weak self] _ in
                guard let self, !self.isSwipingDown else {
                    return
                }
                self.coveredContent.setIsSwipingDown(false)
            })
            if self.isInterfaceHiddenBySwipe {
                for view in self.blurFadedChromeViews {
                    ComponentTransition.animateTransientBlur(layer: view.layer, fromRadius: mediaEditorBottomControlsHandoffBlurRadius, toRadius: 0.0, duration: 0.2)
                }
            }
            self.isInterfaceHiddenBySwipe = false
            self.requestLayout(transition: .animated(duration: 0.2, curve: .easeInOut))
        default:
            break
        }
    }

    func animateOutAfterSwipe(velocity: CGFloat, completion: @escaping () -> Void) {
        self.captionPanelView?.onAnimateOut()
        self.view.endEditing(true)
        let direction = chatMediaEditorSwipeDownDismissDirection(translation: self.swipeOffset, velocity: velocity)
        let target = direction * self.bounds.height
        let distance = abs(target - self.swipeOffset)
        let duration = max(0.12, min(0.3, Double(distance / max(1.0, abs(velocity)))))
        UIView.animate(withDuration: duration, delay: 0.0, options: [.curveEaseOut], animations: {
            self.pagerView.setSwipeOffset(target)
            self.backgroundColor = .clear
        }, completion: { _ in
            completion()
        })
    }
}
