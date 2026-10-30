import Foundation
import UIKit
import Photos
import Display
import ContextUI
import MediaPickerUI
import ChatMediaSend

extension ChatMediaEditorScreen.Node {
    func setupLivePhoto() {
        guard self.isGallery, let gallery = self.controller?.gallery, gallery.hasLivePhotoButton, let livePhotos = gallery.livePhotos else {
            return
        }
        self.livePhotoModel = ChatMediaEditorLivePhotoModel(adapter: livePhotos, selection: self.selectionModel)
        self.setupLivePhotoPlayback()
    }

    var isCurrentItemLiveAsset: Bool {
        guard case let .asset(asset) = self.pageModel.currentItem.source else {
            return false
        }
        return asset.mediaType == .image && asset.mediaSubtypes.contains(.photoLive)
    }

    var isLivePhotoButtonVisible: Bool {
        guard self.livePhotoModel != nil, let gallery = self.controller?.gallery else {
            return false
        }
        return chatMediaEditorLivePhotoButtonIsVisible(hasLivePhotoButton: gallery.hasLivePhotoButton, isLiveAsset: self.isCurrentItemLiveAsset)
    }

    func updateLivePhotoLayout(layout: ContainerViewLayout, safeInsets: UIEdgeInsets, transition: ContainedViewLayoutTransition) {
        guard self.isLivePhotoButtonVisible, let livePhotoModel = self.livePhotoModel else {
            self.livePhotoButton?.removeFromSuperview()
            self.livePhotoButton = nil
            self.livePhotoButtonMode = nil
            self.updateLivePhotoPlayback()
            return
        }
        let button: LivePhotoButton
        var isNew = false
        if let current = self.livePhotoButton {
            button = current
        } else {
            button = LivePhotoButton(context: self.context)
            button.present = { [weak self] controller, _ in
                self?.presentLivePhotoController(controller)
            }
            button.modeUpdated = { [weak self] mode in
                self?.livePhotoModeUpdated(ChatMediaSendLivePhotoMode(legacy: mode))
            }
            self.livePhotoButton = button
            self.view.insertSubview(button, aboveSubview: self.pagerView)
            isNew = true
        }
        let mode = livePhotoModel.mode(for: self.pageModel.currentItem.uniqueId, isLiveAsset: true)
        if self.livePhotoButtonMode != mode {
            self.livePhotoButtonMode = mode
            button.setLivePhotoMode(mode.legacyMode)
        }
        // iPhone Duo: the badge sits under the chat name, wherever its row is (see the frame function).
        var titleRowMaxY: CGFloat?
        if layout.reservedCorners != .none {
            let recipientLayout = chatMediaEditorRecipientLayout(size: layout.size, safeInsets: safeInsets, arrowSize: self.recipientArrowView.image?.size ?? .zero, labelSize: self.recipientLabel.bounds.size, statusIsland: chatMediaEditorStatusIslandRow(layout: layout))
            titleRowMaxY = max(recipientLayout.arrowFrame.maxY, recipientLayout.labelFrame.maxY)
        }
        let buttonFrame = chatMediaEditorLivePhotoButtonFrame(size: layout.size, safeInsets: safeInsets, keyboardHeight: layout.inputHeight ?? 0.0, buttonSize: chatMediaEditorLivePhotoButtonSize, titleRowMaxY: titleRowMaxY, toolbarSide: self.toolbarSide(layout: layout))
        if isNew {
            button.frame = buttonFrame
        } else {
            transition.updateFrame(view: button, frame: buttonFrame)
        }
        let isHidden = self.activeTool != nil || self.isInterfaceHiddenBySwipe || self.isEditingCaption || self.isSelectionRevealDelayed || (layout.inputHeight ?? 0.0) > 0.0 || self.isSending || (self.controller?.isDismissing ?? true)
        let alphaTransition: ContainedViewLayoutTransition = transition.isAnimated ? .animated(duration: 0.2, curve: .linear) : .immediate
        alphaTransition.updateAlpha(layer: button.layer, alpha: isHidden ? 0.0 : 1.0)
        button.isUserInteractionEnabled = !isHidden
        self.updateLivePhotoPlayback()
    }

    private func livePhotoModeUpdated(_ mode: ChatMediaSendLivePhotoMode) {
        guard let livePhotoModel = self.livePhotoModel, self.isLivePhotoButtonVisible, self.activeTool == nil, !self.isSending, !self.isInvalidated else {
            return
        }
        livePhotoModel.modeUpdated(mode, for: self.pageModel.currentItem.uniqueId)
        self.requestLayout(transition: .immediate)
    }

    private func presentLivePhotoController(_ controller: ViewController) {
        guard let screen = self.controller, !screen.isDismissing, !self.isInvalidated else {
            return
        }
        if controller is ContextController {
            screen.presentInGlobalOverlay(controller)
        } else {
            screen.present(controller, in: .window(.root))
        }
    }
}
