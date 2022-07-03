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
    
    var externalTopPanelContainer: UIView?
    
    var topBackgroundExtension: CGFloat = 41.0
    var topBackgroundExtensionUpdated: ((ContainedViewLayoutTransition) -> Void)?
    
    var hideInput: Bool = false
    var hideInputUpdated: ((ContainedViewLayoutTransition) -> Void)?
    
    var expansionFraction: CGFloat = 0.0
    var expansionFractionUpdated: ((ContainedViewLayoutTransition) -> Void)?
    
    func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, standardInputHeight: CGFloat, inputHeight: CGFloat, maximumHeight: CGFloat, inputPanelHeight: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, deviceMetrics: DeviceMetrics, isVisible: Bool) -> (CGFloat, CGFloat) {
        return (0.0, 0.0)
    }
}
