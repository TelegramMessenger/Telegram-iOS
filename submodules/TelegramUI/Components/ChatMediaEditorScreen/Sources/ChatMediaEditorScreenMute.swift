import Foundation
import UIKit
import Display
import SwiftSignalKit
import LegacyComponents
import MediaEditor
import TooltipUI

public let chatMediaEditorMuteButtonSize: CGFloat = 40.0
let chatMediaEditorMuteButtonLeftInset: CGFloat = 16.0
let chatMediaEditorMuteButtonHeaderGap: CGFloat = 34.0

public func chatMediaEditorMuteButtonIsVisible(isGallery: Bool, isVideo: Bool, isAnimation: Bool) -> Bool {
    return isGallery && isVideo && !isAnimation
}

public func chatMediaEditorMuteButtonFrame(headerFrame: CGRect, safeInsets: UIEdgeInsets, toolbarSide: ChatMediaEditorToolbarSide? = nil) -> CGRect {
    if toolbarSide != nil {
        let y = headerFrame.minY - chatMediaEditorMuteButtonHeaderGap - floor((chatMediaEditorVideoHeaderHeight - chatMediaEditorVideoScrubberPanelHeight) / 2.0)
        return CGRect(x: headerFrame.minX + chatMediaEditorMuteButtonLeftInset, y: y, width: chatMediaEditorMuteButtonSize, height: chatMediaEditorMuteButtonSize)
    }
    return CGRect(x: safeInsets.left + chatMediaEditorMuteButtonLeftInset, y: headerFrame.minY - chatMediaEditorMuteButtonHeaderGap, width: chatMediaEditorMuteButtonSize, height: chatMediaEditorMuteButtonSize)
}

private let chatMediaEditorMuteButtonBackground: UIImage? = generateImage(CGSize(width: chatMediaEditorMuteButtonSize, height: chatMediaEditorMuteButtonSize), rotatedContext: { size, context in
    context.clear(CGRect(origin: .zero, size: size))
    context.setFillColor(UIColor(white: 0.0, alpha: 0.5).cgColor)
    context.fillEllipse(in: CGRect(origin: .zero, size: size))
})

extension ChatMediaEditorScreen.Node {
    var isCurrentVideoMuted: Bool {
        return self.subject.isVideo && self.mediaEditor.values.videoIsMuted
    }

    var isVideoScrubberShown: Bool {
        return self.playerState?.tracks.contains(where: { $0.id == 0 }) ?? false
    }

    var isMuteButtonVisible: Bool {
        return !self.isFilePreview && chatMediaEditorMuteButtonIsVisible(isGallery: self.isGallery, isVideo: self.subject.isVideo, isAnimation: self.pageModel.currentItem.isAnimation)
    }

    func updateMuteButton(layout: ContainerViewLayout, safeInsets: UIEdgeInsets, transition: ContainedViewLayoutTransition) {
        guard self.isMuteButtonVisible else {
            self.muteButton?.removeFromSuperview()
            self.muteButton = nil
            self.dismissMuteTooltip()
            return
        }
        let button: UIButton
        if let current = self.muteButton {
            button = current
        } else {
            button = UIButton(type: .custom)
            button.setBackgroundImage(chatMediaEditorMuteButtonBackground, for: .normal)
            button.addTarget(self, action: #selector(self.muteButtonPressed), for: .touchUpInside)
            self.muteButton = button
            self.view.insertSubview(button, aboveSubview: self.pagerView)
            button.frame = self.muteButtonFrame(layout: layout, safeInsets: safeInsets)
        }
        button.setImage(self.isCurrentVideoMuted ? TGPhotoEditorInterfaceAssets.muteActiveIcon() : TGPhotoEditorInterfaceAssets.muteIcon(), for: .normal)
        transition.updateFrame(view: button, frame: self.muteButtonFrame(layout: layout, safeInsets: safeInsets))
        let isHidden = !self.isVideoScrubberShown || self.activeTool != nil || self.isInterfaceHiddenBySwipe || self.isEditingCaption || (layout.inputHeight ?? 0.0) > 0.0 || self.isSending
        transition.updateAlpha(layer: button.layer, alpha: isHidden ? 0.0 : 1.0)
        button.isUserInteractionEnabled = !isHidden
        if isHidden {
            self.dismissMuteTooltip()
        }
    }

    private func muteButtonFrame(layout: ContainerViewLayout, safeInsets: UIEdgeInsets) -> CGRect {
        let toolbarMinY = chatMediaEditorBottomPanelFrame(size: layout.size, safeInsets: safeInsets, toolbarHeight: chatMediaEditorToolbarHeight).minY
        let toolbarSide = self.toolbarSide(layout: layout)
        let headerFrame = chatMediaEditorVideoHeaderFrame(size: layout.size, toolbarMinY: toolbarMinY, captionBaseHeight: self.captionPanelView?.baseHeight() ?? 0.0, safeInsets: safeInsets, toolbarSide: toolbarSide, reservedCorners: layout.reservedCorners)
        return chatMediaEditorMuteButtonFrame(headerFrame: headerFrame, safeInsets: safeInsets, toolbarSide: toolbarSide)
    }

    @objc func muteButtonPressed() {
        guard self.isMuteButtonVisible, self.activeTool == nil, !self.isSending, !self.isInvalidated else {
            return
        }
        let muted = !self.mediaEditor.values.videoIsMuted
        self.mediaEditor.setVideoIsMuted(muted)
        if muted {
            self.mediaEditor.play()
            self.presentMuteTooltip()
        } else {
            self.dismissMuteTooltip()
        }
        self.requestLayout(transition: .immediate)
    }

    private func presentMuteTooltip() {
        guard let controller = self.controller, let button = self.muteButton, !controller.isDismissing, self.view.window != nil else {
            return
        }
        self.dismissMuteTooltip()
        let strings = self.context.sharedContext.currentPresentationData.with { $0 }.strings
        let sourceRect = button.convert(button.bounds, to: nil)
        let tooltipController = TooltipScreen(
            account: self.context.account,
            sharedContext: self.context.sharedContext,
            text: .plain(text: strings.MediaPicker_VideoMuteDescription),
            balancedTextLayout: true,
            style: .customBlur(UIColor(rgb: 0x18181a), 0.0),
            arrowStyle: .small,
            location: .point(sourceRect, .bottom),
            displayDuration: .default,
            inset: chatMediaEditorMuteButtonLeftInset,
            cornerRadius: 10.0,
            shouldDismissOnTouch: { _, _ in
                return .dismiss(consume: false)
            }
        )
        self.muteTooltipController = tooltipController
        self.context.sharedContext.presentGlobalController(tooltipController, nil)
    }

    func dismissMuteTooltip() {
        if let tooltipController = self.muteTooltipController {
            self.muteTooltipController = nil
            tooltipController.dismiss()
        }
    }
}
