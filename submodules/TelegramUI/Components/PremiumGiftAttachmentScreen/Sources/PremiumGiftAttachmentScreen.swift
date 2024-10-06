import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import AccountContext
import AttachmentUI
import GiftOptionsScreen

public class PremiumGiftAttachmentScreen: GiftOptionsScreen, AttachmentContainable {
    public var requestAttachmentMenuExpansion: () -> Void = {}
    public var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void = { _ in }
    public var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void = { _, _ in }
    public var updateTabBarVisibility: (Bool, ContainedViewLayoutTransition) -> Void = { _, _ in }
    public var cancelPanGesture: () -> Void = { }
    public var isContainerPanning: () -> Bool = { return false }
    public var isContainerExpanded: () -> Bool = { return false }
    public var isMinimized: Bool = false
    
    public var mediaPickerContext: AttachmentMediaPickerContext? {
        return PremiumGiftContext(controller: self)
    }
}

private final class PremiumGiftContext: AttachmentMediaPickerContext {
    private weak var controller: GiftOptionsScreen?
        
    public var mainButtonState: Signal<AttachmentMainButtonState?, NoError> {
        return .single(nil)
    }
    
    init(controller: GiftOptionsScreen) {
        self.controller = controller
    }
    
    func mainButtonAction() {
    }
}
