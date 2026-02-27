import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import ChatPresentationInterfaceState

open class ChatInputNode: ASDisplayNode {
    public var interfaceInteraction: ChatPanelInterfaceInteraction?
    open var ready: Signal<Void, NoError> {
        return .single(Void())
    }
    
    open var externalTopPanelContainer: UIView? {
        return nil
    }
    
    public var topBackgroundExtension: CGFloat = 0.0
    public var topBackgroundExtensionUpdated: ((ContainedViewLayoutTransition) -> Void)?
    
    public var hideInput: Bool = false
    public var adjustLayoutForHiddenInput: Bool = false
    public var hideInputUpdated: ((ContainedViewLayoutTransition) -> Void)?
    
    public var followsDefaultHeight: Bool = false
    
    open func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition) {
        
    }
        
    open func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, standardInputHeight: CGFloat, inputHeight: CGFloat, maximumHeight: CGFloat, inputPanelHeight: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, layoutMetrics: LayoutMetrics, deviceMetrics: DeviceMetrics, isVisible: Bool, isExpanded: Bool) -> (CGFloat, CGFloat) {
        return (0.0, 0.0)
    }
}
