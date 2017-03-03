import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore

private let closeButtonImage = generateImage(CGSize(width: 12.0, height: 12.0), contextGenerator: { size, context in
    context.clear(CGRect(origin: CGPoint(), size: size))
    context.setStrokeColor(UIColor(0x9099A2).cgColor)
    context.setLineWidth(2.0)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: 1.0, y: 1.0))
    context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - 1.0))
    context.strokePath()
    context.move(to: CGPoint(x: size.width - 1.0, y: 1.0))
    context.addLine(to: CGPoint(x: 1.0, y: size.height - 1.0))
    context.strokePath()
})


private enum ChatReportPeerTitleButton {
    case reportSpam
    
    var title: String {
        switch self {
            case .reportSpam:
                return "Report spam"
        }
    }
}

private func peerButtons(_ state: ChatPresentationInterfaceState) -> [ChatReportPeerTitleButton] {
    return [.reportSpam]
}

final class ChatReportPeerTitlePanelNode: ChatTitleAccessoryPanelNode {
    private let separatorNode: ASDisplayNode
    
    private let closeButton: HighlightableButtonNode
    private var buttons: [(ChatReportPeerTitleButton, UIButton)] = []
    
    override init() {
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = UIColor(red: 0.6953125, green: 0.6953125, blue: 0.6953125, alpha: 1.0)
        self.separatorNode.isLayerBacked = true
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.setImage(closeButtonImage, for: [])
        self.closeButton.hitTestSlop = UIEdgeInsetsMake(-8.0, -8.0, -8.0, -8.0)
        self.closeButton.displaysAsynchronously = false
        
        super.init()
        
        self.backgroundColor = UIColor(0xF5F6F8)
        
        self.addSubnode(self.separatorNode)
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.addSubnode(self.closeButton)
    }
    
    override func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        let panelHeight: CGFloat = 40.0
        
        let rightInset: CGFloat = 18.0
        
        let closeButtonSize = self.closeButton.measure(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.closeButton, frame: CGRect(origin: CGPoint(x: width - rightInset - closeButtonSize.width, y: 14.0), size: closeButtonSize))
        
        let updatedButtons: [ChatReportPeerTitleButton]
        if let _ = interfaceState.peer {
            updatedButtons = peerButtons(interfaceState)
        } else {
            updatedButtons = []
        }
        
        var buttonsUpdated = false
        if self.buttons.count != updatedButtons.count {
            buttonsUpdated = true
        } else {
            for i in 0 ..< updatedButtons.count {
                if self.buttons[i].0 != updatedButtons[i] {
                    buttonsUpdated = true
                    break
                }
            }
        }
        
        if buttonsUpdated {
            for (_, view) in self.buttons {
                view.removeFromSuperview()
            }
            self.buttons.removeAll()
            for button in updatedButtons {
                let view = UIButton()
                view.setTitle(button.title, for: [])
                view.titleLabel?.font = Font.regular(16.0)
                view.setTitleColor(UIColor(0x007ee5), for: [])
                view.setTitleColor(UIColor(0x007ee5).withAlphaComponent(0.7), for: [.highlighted])
                view.addTarget(self, action: #selector(self.buttonPressed(_:)), for: [.touchUpInside])
                self.view.addSubview(view)
                self.buttons.append((button, view))
            }
        }
        
        if !self.buttons.isEmpty {
            let buttonWidth = floor(width / CGFloat(self.buttons.count))
            var nextButtonOrigin: CGFloat = 0.0
            for (_, view) in self.buttons {
                view.frame = CGRect(origin: CGPoint(x: nextButtonOrigin, y: 0.0), size: CGSize(width: buttonWidth, height: panelHeight))
                nextButtonOrigin += buttonWidth
            }
        }
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelHeight - UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel)))
        
        return panelHeight
    }
    
    @objc func buttonPressed(_ view: UIButton) {
        for (button, buttonView) in self.buttons {
            if buttonView === view {
                switch button {
                    case .reportSpam:
                        self.interfaceInteraction?.reportPeer()
                }
                break
            }
        }
    }
    
    @objc func closePressed() {
        self.interfaceInteraction?.dismissReportPeer()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.closeButton.hitTest(CGPoint(x: point.x - self.closeButton.frame.minX, y: point.y - self.closeButton.frame.minY), with: event) {
            return result
        }
        return super.hitTest(point, with: event)
    }
}
