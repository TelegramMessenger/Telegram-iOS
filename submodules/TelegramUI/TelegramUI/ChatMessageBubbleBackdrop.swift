import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramPresentationData

final class ChatMessageBubbleBackdrop: ASDisplayNode {
    private let backgroundContent: ASDisplayNode
    
    private var currentType: ChatMessageBackgroundType?
    private var theme: ChatPresentationThemeData?
    
    override init() {
        self.backgroundContent = ASDisplayNode()
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.backgroundContent)
    }
    
    func setType(type: ChatMessageBackgroundType, theme: ChatPresentationThemeData, mediaBox: MediaBox, essentialGraphics: PrincipalThemeEssentialGraphics) {
        if self.currentType != type || self.theme != theme {
            self.currentType = type
            self.theme = theme
            
            switch type {
            case .none:
                self.backgroundContent.contents = nil
            case .incoming:
                self.backgroundContent.contents = essentialGraphics.incomingBubbleGradientImage?.cgImage
            case .outgoing:
                self.backgroundContent.contents = essentialGraphics.outgoingBubbleGradientImage?.cgImage
            }
        }
    }
    
    func update(rect: CGRect, within containerSize: CGSize) {
        self.backgroundContent.frame = CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: containerSize)
    }
    
    func offset(value: CGFloat, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {
        let transition: ContainedViewLayoutTransition = .animated(duration: duration, curve: animationCurve)
        transition.animatePositionAdditive(node: self.backgroundContent, offset: CGPoint(x: 0.0, y: -value))
    }
}
