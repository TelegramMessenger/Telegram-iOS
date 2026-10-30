import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import LegacyComponents
import ContextUI

public let chatMediaEditorCameraButtonSize = CGSize(width: 44.0, height: 44.0)

public func chatMediaEditorCameraButtonFrame(size: CGSize, safeInsets: UIEdgeInsets, reservedCorners: ContainerViewLayoutCorners, toolbarMinY: CGFloat, captionBaseHeight: CGFloat, hasVideoHeader: Bool, hasSelection: Bool, toolbarSide: ChatMediaEditorToolbarSide? = nil) -> CGRect {
    if let toolbarSide {
        let innerEdge = chatMediaEditorLandscapeInnerEdge(size: size, safeInsets: safeInsets, side: toolbarSide)
        let x: CGFloat
        switch toolbarSide {
        case .left:
            x = innerEdge + 1.0
        case .right:
            x = innerEdge - 1.0 - chatMediaEditorCameraButtonSize.width
        }
        return CGRect(origin: CGPoint(x: x, y: safeInsets.top + 1.0 + (hasSelection ? 50.0 : 0.0)), size: chatMediaEditorCameraButtonSize)
    }
    let counterFrame = chatMediaEditorCounterButtonFrame(size: size, safeInsets: safeInsets, reservedCorners: reservedCorners, toolbarMinY: toolbarMinY, captionBaseHeight: captionBaseHeight, hasVideoHeader: hasVideoHeader)
    let centerY = counterFrame.minY + chatMediaEditorCounterCircleFrame.midY
    let safeInsets = chatMediaEditorBottomRowSafeInsets(safeInsets, reservedCorners: reservedCorners)
    return CGRect(origin: CGPoint(x: size.width - 46.0 - safeInsets.right - (hasSelection ? 50.0 : 0.0), y: floor(centerY - chatMediaEditorCameraButtonSize.height / 2.0)), size: chatMediaEditorCameraButtonSize)
}

public func chatMediaEditorCameraReviewConfirmsDiscard(hasCameraButton: Bool, itemCount: Int) -> Bool {
    return hasCameraButton && itemCount > 1
}

public func chatMediaEditorCameraReviewShowsSelection(itemCount: Int) -> Bool {
    return itemCount > 1
}

final class ChatMediaEditorCameraButton: UIButton {
    private let wrapperView: UIView
    private let iconView: UIImageView

    override init(frame: CGRect) {
        self.wrapperView = UIView()
        self.wrapperView.isUserInteractionEnabled = false
        self.iconView = UIImageView(image: TGPhotoEditorInterfaceAssets.cameraIcon())
        self.iconView.contentMode = .center

        super.init(frame: frame)

        self.isExclusiveTouch = true
        self.addSubview(self.wrapperView)
        self.wrapperView.addSubview(self.iconView)
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.wrapperView.bounds = CGRect(origin: .zero, size: self.bounds.size)
        self.wrapperView.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
        self.iconView.frame = CGRect(origin: .zero, size: self.bounds.size)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first, self.bounds.contains(touch.location(in: self)) {
            UIView.animate(withDuration: 0.12, delay: 0.0, options: .curveEaseOut, animations: {
                self.wrapperView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            }, completion: { finished in
                if finished {
                    UIView.animate(withDuration: 0.08, delay: 0.0, options: .curveEaseIn, animations: {
                        self.wrapperView.transform = .identity
                    })
                }
            })
        } else {
            self.wrapperView.transform = .identity
        }
        super.touchesEnded(touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.wrapperView.transform = .identity
        super.touchesCancelled(touches, with: event)
    }
}

extension ChatMediaEditorScreen.Node {
    func setupCameraReview() {
        if let source = self.pageModel.itemsSource as? ChatMediaEditorAppendableItemsSource {
            self.itemsAppendDisposable = source.addAppendListener { [weak self] in
                self?.itemsSourceAppended()
            }
        }
        guard self.isGallery, let camera = self.controller?.gallery?.camera, camera.hasCameraButton else {
            return
        }
        let cameraButton = ChatMediaEditorCameraButton(frame: CGRect(origin: .zero, size: chatMediaEditorCameraButtonSize))
        cameraButton.addTarget(self, action: #selector(self.cameraButtonPressed), for: .touchUpInside)
        self.cameraButton = cameraButton
        self.view.insertSubview(cameraButton, belowSubview: self.captionDimView)
    }

    private func itemsSourceAppended() {
        guard !self.isInvalidated else {
            return
        }
        self.selectionStripItems = self.selectionStripItems.filter { $0.value != nil }
        if self.selectionModel == nil, self.controller?.selection != nil {
            self.setupSelection()
            if let selectionModel = self.selectionModel {
                if let timerModel = self.timerModel {
                    self.timerModel = ChatMediaEditorTimerModel(adapter: timerModel.adapter, selection: selectionModel)
                }
                if let livePhotoModel = self.livePhotoModel {
                    self.livePhotoModel = ChatMediaEditorLivePhotoModel(adapter: livePhotoModel.adapter, selection: selectionModel)
                }
            }
        }
        self.requestLayout(transition: .immediate)
    }

    private var hasCameraReviewSelection: Bool {
        return self.selectionModel?.isEnabled ?? false
    }

    func updateCameraButtonLayout(layout: ContainerViewLayout, safeInsets: UIEdgeInsets, toolbarFrame: CGRect, keyboardHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        guard let cameraButton = self.cameraButton else {
            return
        }
        let captionBaseHeight = self.captionPanelView?.baseHeight() ?? 0.0
        let frame = chatMediaEditorCameraButtonFrame(size: layout.size, safeInsets: safeInsets, reservedCorners: layout.reservedCorners, toolbarMinY: toolbarFrame.minY, captionBaseHeight: captionBaseHeight, hasVideoHeader: self.subject.isVideo, hasSelection: self.hasCameraReviewSelection, toolbarSide: self.toolbarSide(layout: layout))
        transition.updateFrame(view: cameraButton, frame: frame)
        let isHidden = self.activeTool != nil || self.isInterfaceHiddenBySwipe || self.isEditingCaption || keyboardHeight > 0.0 || self.isSending || (self.controller?.isDismissing ?? true)
        let alphaTransition: ContainedViewLayoutTransition = transition.isAnimated ? .animated(duration: 0.2, curve: .linear) : .immediate
        alphaTransition.updateAlpha(layer: cameraButton.layer, alpha: isHidden ? 0.0 : 1.0)
        cameraButton.isUserInteractionEnabled = !isHidden
    }

    @objc private func cameraButtonPressed() {
        guard let controller = self.controller, let camera = controller.gallery?.camera, !self.isSending, !controller.isDismissing, !self.isInvalidated else {
            return
        }
        self.saveCurrentItemEdits()
        camera.returnToCamera()
        controller.dismissAnimated()
    }

    func cancelCameraReview() {
        guard let controller = self.controller, let camera = controller.gallery?.camera, !self.isSending, !controller.isDismissing else {
            return
        }
        guard chatMediaEditorCameraReviewConfirmsDiscard(hasCameraButton: camera.hasCameraButton, itemCount: self.pageModel.itemsSource.count) else {
            camera.discard()
            controller.dismissAnimated()
            return
        }
        if let cameraDiscardMenu = self.cameraDiscardMenu, cameraDiscardMenu.isViewLoaded, cameraDiscardMenu.view.window != nil {
            return
        }
        guard let sourceView = (self.toolbar.view as? ChatMediaEditorBottomControlsComponent.View)?.leftButtonView else {
            return
        }
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkColorPresentationTheme)
        let items: [ContextMenuItem] = [
            .action(ContextMenuActionItem(text: presentationData.strings.Camera_Discard, textColor: .destructive, icon: { _ in
                return nil
            }, action: { [weak controller] f in
                f.dismissWithResult(.default)
                guard let controller, let camera = controller.gallery?.camera, !controller.isDismissing else {
                    return
                }
                camera.discard()
                controller.dismissAnimated()
            }))
        ]
        let contextController = makeContextController(presentationData: presentationData, source: .reference(ChatMediaEditorReferenceContentSource(sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))))
        self.cameraDiscardMenu = contextController
        controller.present(contextController, in: .window(.root))
    }
}
