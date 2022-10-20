import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import ChatPresentationInterfaceState

class ChatInputNode: ASDisplayNode {
    var interfaceInteraction: ChatPanelInterfaceInteraction?
    var ready: Signal<Void, NoError> {
        return .single(Void())
    }
    
    var externalTopPanelContainer: UIView? {
        return nil
    }
    
    var topBackgroundExtension: CGFloat = 0.0
    var topBackgroundExtensionUpdated: ((ContainedViewLayoutTransition) -> Void)?
    
    var hideInput: Bool = false
    var adjustLayoutForHiddenInput: Bool = false
    var hideInputUpdated: ((ContainedViewLayoutTransition) -> Void)?
    
    var followsDefaultHeight: Bool = false
    
    func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, standardInputHeight: CGFloat, inputHeight: CGFloat, maximumHeight: CGFloat, inputPanelHeight: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, deviceMetrics: DeviceMetrics, isVisible: Bool, isExpanded: Bool) -> (CGFloat, CGFloat) {
        return (0.0, 0.0)
    }
}
