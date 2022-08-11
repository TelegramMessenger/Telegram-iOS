import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit
import ChatPresentationInterfaceState

final class DeleteChatInputPanelNode: ChatInputPanelNode {
    private let button: HighlightableButtonNode
    
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    override init() {
        self.button = HighlightableButtonNode()
        self.button.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.button)
        
        self.button.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: [.touchUpInside])
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            return self.button.view
        } else {
            return nil
        }
    }
    
    @objc func buttonPressed() {
        self.interfaceInteraction?.deleteChat()
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, additionalSideInsets: UIEdgeInsets, maxHeight: CGFloat, isSecondary: Bool, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        if self.presentationInterfaceState != interfaceState {
            self.presentationInterfaceState = interfaceState
            
            self.button.setAttributedTitle(NSAttributedString(string: interfaceState.strings.GroupInfo_DeleteAndExit, font: Font.regular(17.0), textColor: interfaceState.theme.chat.inputPanel.panelControlDestructiveColor), for: [])
        }
        
        let buttonSize = self.button.measure(CGSize(width: width - leftInset - rightInset - 10.0, height: 100.0))
        
        let panelHeight = defaultHeight(metrics: metrics)
        
        self.button.frame = CGRect(origin: CGPoint(x: leftInset + floor((width - leftInset - rightInset - buttonSize.width) / 2.0), y: floor((panelHeight - buttonSize.height) / 2.0)), size: buttonSize)
        
        return panelHeight
    }
    
    override func minimalHeight(interfaceState: ChatPresentationInterfaceState, metrics: LayoutMetrics) -> CGFloat {
        return defaultHeight(metrics: metrics)
    }
}
