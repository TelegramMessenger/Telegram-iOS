import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import AccountContext
import PremiumUI
import AttachmentUI

public class PremiumGiftAttachmentScreen: PremiumGiftScreen, AttachmentContainable {
    public var requestAttachmentMenuExpansion: () -> Void = {}
    public var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void = { _ in }
    public var cancelPanGesture: () -> Void = { }
    public var isContainerPanning: () -> Bool = { return false }
    public var isContainerExpanded: () -> Bool = { return false }
    
    public var mediaPickerContext: AttachmentMediaPickerContext? {
        return PremiumGiftContext(controller: self)
    }
}

private final class PremiumGiftContext: AttachmentMediaPickerContext {
    private weak var controller: PremiumGiftScreen?
    
    var selectionCount: Signal<Int, NoError> {
        return .single(0)
    }
    
    var caption: Signal<NSAttributedString?, NoError> {
        return .single(nil)
    }
    
    public var loadingProgress: Signal<CGFloat?, NoError> {
        return .single(nil)
    }
    
    public var mainButtonState: Signal<AttachmentMainButtonState?, NoError> {
        return self.controller?.mainButtonStatePromise.get() ?? .single(nil)
    }
    
    init(controller: PremiumGiftScreen) {
        self.controller = controller
    }
            
    func setCaption(_ caption: NSAttributedString) {
    }
    
    func send(mode: AttachmentMediaPickerSendMode, attachmentMode: AttachmentMediaPickerAttachmentMode) {
    }
    
    func schedule() {
    }
    
    func mainButtonAction() {
        self.controller?.mainButtonPressed()
    }
}
