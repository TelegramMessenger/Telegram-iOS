import Foundation
import UIKit
import Display
import SwiftSignalKit
import MediaPickerUI
import TooltipUI

extension ChatMediaEditorScreen.Node {
    func setupTimer() {
        guard self.isGallery, let timers = self.controller?.gallery?.timers else {
            return
        }
        self.timerModel = ChatMediaEditorTimerModel(adapter: timers, selection: self.selectionModel)
    }

    var currentItemTimer: Int32? {
        return self.timerModel?.timer(for: self.pageModel.currentItem.uniqueId)
    }

    func captionTimerUpdated(_ value: NSNumber?) {
        guard let timerModel = self.timerModel, !self.isInvalidated else {
            return
        }
        timerModel.timerUpdated(value?.int32Value, for: self.pageModel.currentItem.uniqueId)
        self.requestLayout(transition: .immediate)
    }

    var currentItemHasAnyTimer: Bool {
        return self.timerModel?.hasAnyTimer(currentId: self.pageModel.currentItem.uniqueId) ?? false
    }

    var sendMenuHasTimer: Bool {
        guard let gallery = self.controller?.gallery else {
            return false
        }
        return gallery.hasTimer && gallery.presentTimerPicker != nil && self.timerModel != nil
    }

    func sendWithTimer() {
        guard let controller = self.controller, let presentTimerPicker = controller.gallery?.presentTimerPicker, self.timerModel != nil, !self.isSending, !controller.isDismissing else {
            return
        }
        presentTimerPicker({ [weak self] time in
            guard let self, let timerModel = self.timerModel, let controller = self.controller, !self.isSending, !controller.isDismissing, !self.isInvalidated else {
                return
            }
            timerModel.applySendTimer(time, currentId: self.pageModel.currentItem.uniqueId)
            self.captionPanelView?.setTimeout(self.currentItemTimer ?? 0, isVideo: self.subject.isVideo, isCaptionAbove: self.isCaptionAbove)
            self.send(silentPosting: false, scheduleTime: 0)
        })
    }

    func scheduleTimerTooltipIfNeeded() {
        guard self.isGallery, let gallery = self.controller?.gallery, self.timerTooltipController == nil, !self.isTimerTooltipPending else {
            return
        }
        guard ChatMediaEditorTimerTooltipCounter(defaults: .standard).shouldDisplay(hasTimer: gallery.hasTimer) else {
            return
        }
        self.isTimerTooltipPending = true
        Queue.mainQueue().after(chatMediaEditorTimerTooltipDelay, { [weak self] in
            guard let self else {
                return
            }
            self.isTimerTooltipPending = false
            self.presentTimerTooltip()
        })
    }

    private func presentTimerTooltip() {
        guard let controller = self.controller, let gallery = controller.gallery, !self.isInvalidated, !controller.isDismissing, !self.isSending, self.activeTool == nil, self.timerTooltipController == nil, self.view.window != nil else {
            return
        }
        let counter = ChatMediaEditorTimerTooltipCounter(defaults: .standard)
        guard counter.shouldDisplay(hasTimer: gallery.hasTimer), let toolbarView = self.toolbar.view as? ChatMediaEditorBottomControlsComponent.View, let sourceRect = toolbarView.rightButtonFrame(in: nil) else {
            return
        }
        let strings = self.context.sharedContext.currentPresentationData.with { $0 }.strings
        let tooltipController = TooltipScreen(
            account: self.context.account,
            sharedContext: self.context.sharedContext,
            text: .plain(text: strings.Media_SendingOptionsTooltip),
            style: .customBlur(UIColor(rgb: 0x18181a), 0.0),
            location: .point(sourceRect, .bottom),
            displayDuration: .custom(chatMediaEditorTimerTooltipDuration),
            shouldDismissOnTouch: { _, _ in
                return .dismiss(consume: false)
            }
        )
        self.timerTooltipController = tooltipController
        counter.noteDisplayed()
        self.context.sharedContext.presentGlobalController(tooltipController, nil)
    }

    func suppressTimerTooltip() {
        ChatMediaEditorTimerTooltipCounter(defaults: .standard).suppress()
        self.dismissTimerTooltip()
    }

    func dismissTimerTooltip() {
        if let tooltipController = self.timerTooltipController {
            self.timerTooltipController = nil
            tooltipController.dismiss()
        }
    }
}
