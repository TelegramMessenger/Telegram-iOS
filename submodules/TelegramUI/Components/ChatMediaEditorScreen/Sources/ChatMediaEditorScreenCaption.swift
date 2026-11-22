import Foundation
import UIKit
import Display
import SwiftSignalKit

extension ChatMediaEditorScreen.Node {
    func captionEditingUpdated(_ isEditing: Bool) {
        guard self.isGallery else {
            return
        }
        self.selectionRevealTimer?.invalidate()
        self.selectionRevealTimer = nil
        if isEditing {
            self.isSelectionRevealDelayed = false
            if self.subject.isVideo, self.mediaEditor.isPlaying {
                self.mediaEditor.stop()
            }
        } else {
            self.isSelectionRevealDelayed = true
            let timer = SwiftSignalKit.Timer(timeout: chatMediaEditorCaptionSelectionRevealDelay, repeat: false, completion: { [weak self] in
                guard let self else {
                    return
                }
                self.selectionRevealTimer = nil
                self.isSelectionRevealDelayed = false
                self.requestLayout(transition: .animated(duration: 0.2, curve: .linear))
            }, queue: Queue.mainQueue())
            self.selectionRevealTimer = timer
            timer.start()
            self.commitCurrentCaption()
        }
    }

    func commitCurrentCaption() {
        guard let captionModel = self.captionModel, let captionPanelView = self.captionPanelView else {
            return
        }
        let caption = captionPanelView.caption()
        captionModel.commit(caption)
        self.selectionCaptionCommitted(caption)
    }

    func switchCaption(to uniqueId: String) {
        guard let captionModel = self.captionModel, let captionPanelView = self.captionPanelView else {
            return
        }
        captionPanelView.setTimeout(self.currentItemTimer ?? 0, isVideo: self.subject.isVideo, isCaptionAbove: self.isCaptionAbove)
        captionPanelView.setCaption(captionModel.switchItem(to: uniqueId))
    }

    var keyboardPagerOffset: CGFloat {
        guard self.isGallery, let layout = self.validLayout else {
            return 0.0
        }
        return chatMediaEditorKeyboardPagerOffset(keyboardHeight: layout.inputHeight ?? 0.0)
    }
}
