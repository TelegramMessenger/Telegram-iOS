import Foundation
import UIKit
import Photos
import Display
import SwiftSignalKit
import MediaAssetsContext

extension ChatMediaEditorScreen.Node {
    var hasSelectionCheckButton: Bool {
        return self.selectionModel?.isEnabled == true && self.selectionCheckButton != nil
    }

    func setupSelection() {
        guard self.isGallery, let adapter = self.controller?.selection else {
            return
        }
        if self.controller?.gallery?.camera != nil && !chatMediaEditorCameraReviewShowsSelection(itemCount: self.pageModel.itemsSource.count) {
            return
        }
        let model = ChatMediaEditorSelectionModel(adapter: adapter, keepsDeselectedItems: self.controller?.gallery?.keepsDeselectedItems ?? false)
        self.selectionModel = model
        guard model.isEnabled else {
            return
        }
        let colors = self.context.sharedContext.currentPresentationData.with { $0 }.theme.chat.message.selectionControlColors

        let checkButton = ChatMediaEditorCheckButton(style: .gallery, fillColor: colors.fillColor, foregroundColor: colors.foregroundColor)
        checkButton.addTarget(self, action: #selector(self.selectionCheckPressed), for: .touchUpInside)
        self.selectionCheckButton = checkButton

        let stripView = ChatMediaEditorStripView(fillColor: colors.fillColor, foregroundColor: colors.foregroundColor)
        stripView.itemInfo = { [weak self] uniqueId in
            return self?.selectionStripItemInfo(uniqueId)
        }
        stripView.isItemChecked = { [weak model] uniqueId in
            return model?.adapter.isSelected(uniqueId) ?? false
        }
        stripView.itemTapped = { [weak self] uniqueId in
            self?.selectionStripItemTapped(uniqueId)
        }
        stripView.itemCheckPressed = { [weak self] uniqueId, cell in
            self?.selectionStripCheckPressed(uniqueId, cell: cell)
        }
        stripView.reload(items: model.stripItems)
        self.selectionStripView = stripView

        let counterButton = ChatMediaEditorCounterButton(frame: .zero)
        counterButton.addTarget(self, action: #selector(self.selectionCounterPressed), for: .touchUpInside)
        self.selectionCounterButton = counterButton

        self.view.insertSubview(stripView, belowSubview: self.captionDimView)
        self.view.insertSubview(counterButton, belowSubview: self.captionDimView)
        self.view.insertSubview(checkButton, belowSubview: self.captionDimView)

        model.stripUpdated = { [weak self] update in
            guard let self, let model = self.selectionModel else {
                return
            }
            self.selectionStripView?.apply(update: update, items: model.stripItems, animated: true)
        }
        model.selectionUpdated = { [weak self] in
            self?.refreshSelectionControls(animated: true)
        }
        self.refreshSelectionControls(animated: false)
    }

    func refreshSelectionControls(animated: Bool) {
        guard let model = self.selectionModel, model.isEnabled else {
            return
        }
        let state = model.checkState(for: self.pageModel.currentItem.uniqueId)
        if let checkButton = self.selectionCheckButton {
            checkButton.setNumber(state.number, animated: animated)
            checkButton.setChecked(state.isSelected, animated: animated)
        }
        self.selectionStripView?.updateCheckedStates(animated: animated)
        self.updateSelectionCounter(animated: animated)
    }

    private func updateSelectionCounter(animated: Bool) {
        guard let model = self.selectionModel, let counterButton = self.selectionCounterButton else {
            return
        }
        let count = model.selectedCount
        if model.isCounterVisible {
            counterButton.setCount(count, animated: animated && !counterButton.isInternalHidden)
            counterButton.setInternalHidden(false, animated: animated)
        } else {
            counterButton.setInternalHidden(true, animated: animated, completion: { [weak counterButton] in
                counterButton?.setOpen(false, animated: false)
                counterButton?.setCount(count, animated: false)
            })
        }
        if !model.isStripOpen {
            self.selectionStripView?.setInternalHidden(true, animated: animated)
        }
    }

    func updateSelectionLayout(layout: ContainerViewLayout, safeInsets: UIEdgeInsets, toolbarFrame: CGRect, keyboardHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        guard let model = self.selectionModel, model.isEnabled, let checkButton = self.selectionCheckButton, let counterButton = self.selectionCounterButton, let stripView = self.selectionStripView else {
            return
        }
        let captionBaseHeight = self.captionPanelView?.baseHeight() ?? 0.0
        let toolbarSide = self.toolbarSide(layout: layout)
        let checkFrame = chatMediaEditorCheckButtonFrame(size: layout.size, safeInsets: safeInsets, statusIsland: chatMediaEditorStatusIslandRow(layout: layout), toolbarSide: toolbarSide)
        transition.updateFrame(view: checkButton, frame: checkFrame)
        counterButton.frame = chatMediaEditorCounterButtonFrame(size: layout.size, safeInsets: safeInsets, reservedCorners: layout.reservedCorners, toolbarMinY: toolbarFrame.minY, captionBaseHeight: captionBaseHeight, hasVideoHeader: self.subject.isVideo, toolbarSide: toolbarSide)
        let stripFrame = chatMediaEditorStripFrame(size: layout.size, safeInsets: safeInsets, toolbarMinY: toolbarFrame.minY, captionBaseHeight: captionBaseHeight, hasVideoHeader: self.subject.isVideo, cellSize: stripView.cellSize, toolbarSide: toolbarSide)
        stripView.updateToolbarSide(toolbarSide)
        if stripView.frame != stripFrame {
            stripView.frame = stripFrame
        }

        let isHidden = self.activeTool != nil || self.isInterfaceHiddenBySwipe || self.isEditingCaption || self.isSelectionRevealDelayed || keyboardHeight > 0.0 || self.isSending || (self.controller?.isDismissing ?? true)
        let alphaTransition: ContainedViewLayoutTransition = transition.isAnimated ? .animated(duration: 0.2, curve: .linear) : .immediate
        alphaTransition.updateAlpha(layer: checkButton.layer, alpha: isHidden ? 0.0 : 1.0)
        alphaTransition.updateAlpha(layer: counterButton.layer, alpha: isHidden ? 0.0 : 1.0)
        checkButton.isUserInteractionEnabled = !isHidden
        counterButton.isUserInteractionEnabled = !isHidden
        if isHidden != self.isSelectionInterfaceHidden {
            self.isSelectionInterfaceHidden = isHidden
            if isHidden {
                model.setStripOpen(false)
                counterButton.setOpen(false, animated: transition.isAnimated)
                stripView.setInternalHidden(true, animated: transition.isAnimated)
            }
        }
    }

    @objc private func selectionCheckPressed() {
        guard let model = self.selectionModel, let checkButton = self.selectionCheckButton, !self.isSelectionInterfaceHidden else {
            return
        }
        self.toggleSelectionWithHaptic(model: model, uniqueId: self.pageModel.currentItem.uniqueId, sender: checkButton)
        let state = model.checkState(for: self.pageModel.currentItem.uniqueId)
        checkButton.setNumber(state.number, animated: true)
        checkButton.setChecked(state.isSelected, animated: true)
    }

    @objc private func selectionCounterPressed() {
        guard let model = self.selectionModel, let counterButton = self.selectionCounterButton, let stripView = self.selectionStripView, !self.isSelectionInterfaceHidden else {
            return
        }
        HapticFeedback().impact(.light)
        model.setStripOpen(!model.isStripOpen)
        counterButton.setOpen(model.isStripOpen, animated: true)
        stripView.setInternalHidden(!model.isStripOpen, animated: true)
    }

    func handlePageTap(_ page: ChatMediaEditorPageView) {
        if !self.livePhotoPlaybackModel.allowsSelectionTap {
            return
        }
        guard page.index == self.pageModel.currentIndex, !self.subject.isVideo, self.activeTool == nil, !self.isSending, !self.isInvalidated, let model = self.selectionModel, model.isEnabled else {
            return
        }
        self.toggleSelectionWithHaptic(model: model, uniqueId: self.pageModel.currentItem.uniqueId, sender: self.selectionCheckButton)
    }

    private func toggleSelectionWithHaptic(model: ChatMediaEditorSelectionModel, uniqueId: String, sender: AnyObject?) {
        let wasSelected = model.adapter.isSelected(uniqueId)
        let isSelected = model.toggle(uniqueId, sender: sender)
        if chatMediaEditorSelectionToggleHaptic(wasSelected: wasSelected, isSelected: isSelected) {
            HapticFeedback().impact(.light)
        }
    }

    func selectionEditCommitted() {
        guard let before = self.toolStartValues else {
            return
        }
        self.toolStartValues = nil
        let uniqueId = self.pageModel.currentItem.uniqueId
        self.selectionModel?.editCommitted(uniqueId, before: before, after: self.mediaEditor.values, baselineQualityPreset: self.pageModel.store.qualityPresetBaseline(for: uniqueId))
        self.saveCurrentItemEdits()
    }

    func selectionCaptionCommitted(_ caption: NSAttributedString) {
        self.selectionModel?.captionCommitted(caption, for: self.pageModel.currentItem.uniqueId)
    }

    private func selectionStripCheckPressed(_ uniqueId: String, cell: ChatMediaEditorStripCell) {
        guard let model = self.selectionModel else {
            return
        }
        let wasSelected = model.adapter.isSelected(uniqueId)
        cell.setChecked(!wasSelected, animated: true)
        let isSelected = model.toggleFromStrip(uniqueId)
        if chatMediaEditorSelectionToggleHaptic(wasSelected: wasSelected, isSelected: isSelected) {
            HapticFeedback().impact(.light)
        }
        cell.setChecked(isSelected, animated: true)
    }

    private func selectionStripItemTapped(_ uniqueId: String) {
        guard let index = self.pageModel.itemsSource.index(of: uniqueId), index != self.pageModel.currentIndex else {
            return
        }
        self.pagerView.scrollToPage(index, animated: false)
    }

    private func selectionStripItem(_ uniqueId: String) -> ChatMediaEditorItem? {
        if let cached = self.selectionStripItems[uniqueId] {
            return cached
        }
        var result: ChatMediaEditorItem?
        if let index = self.pageModel.itemsSource.index(of: uniqueId) {
            result = self.pageModel.itemsSource.item(at: index)
        } else if let asset = PHAsset.fetchAssets(withLocalIdentifiers: [uniqueId], options: nil).firstObject {
            result = chatMediaEditorAssetItem(uniqueId: uniqueId, asset: asset)
        }
        self.selectionStripItems[uniqueId] = .some(result)
        return result
    }

    private func selectionStripItemInfo(_ uniqueId: String) -> ChatMediaEditorStripItemInfo? {
        guard let item = self.selectionStripItem(uniqueId) else {
            return nil
        }
        let scale = self.view.window?.screen.scale ?? UIScreen.main.scale
        let cellSize = self.selectionStripView?.cellSize ?? CGSize(width: 128.0, height: 128.0)
        let targetSize = CGSize(width: cellSize.width * scale, height: cellSize.height * scale)
        let thumbnail: Signal<UIImage?, NoError>
        var videoDuration: Double?
        if let stored = self.pageModel.store.entry(for: uniqueId)?.thumbnail {
            thumbnail = .single(stored)
        } else {
            switch item.source {
            case let .asset(asset):
                thumbnail = assetImage(asset: asset, targetSize: targetSize, exact: false)
            case let .image(image):
                thumbnail = .single(image)
            case let .imageFile(path, _):
                if let itemThumbnail = item.thumbnail {
                    thumbnail = .single(itemThumbnail)
                } else {
                    thumbnail = chatMediaEditorFileThumbnailSignal(path: path, maxPixelSide: max(targetSize.width, targetSize.height))
                }
            case .video:
                thumbnail = .single(item.thumbnail)
            }
        }
        switch item.source {
        case let .asset(asset):
            if asset.mediaType == .video {
                videoDuration = asset.duration
            }
        case let .video(_, _, duration):
            videoDuration = duration
        case .image, .imageFile:
            break
        }
        return ChatMediaEditorStripItemInfo(thumbnail: thumbnail, videoDuration: videoDuration)
    }
}
