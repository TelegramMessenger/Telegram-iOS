import Foundation
import AsyncDisplayKit
import Display

final class ChatTextInputAudioRecordingCancelIndicator: ASDisplayNode {
    private let arrowNode: ASImageNode
    private let labelNode: TextNode
    
    init(theme: PresentationTheme, strings: PresentationStrings) {
        self.arrowNode = ASImageNode()
        self.arrowNode.isLayerBacked = true
        self.arrowNode.displayWithoutProcessing = true
        self.arrowNode.displaysAsynchronously = false
        self.arrowNode.image = PresentationResourcesChat.chatInputPanelMediaRecordingCancelArrowImage(theme)
        
        self.labelNode = TextNode()
        self.labelNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.arrowNode)
        self.addSubnode(self.labelNode)
        
        let makeLayout = TextNode.asyncLayout(self.labelNode)
        let (labelLayout, labelApply) = makeLayout(NSAttributedString(string: strings.Conversation_SlideToCancel, font: Font.regular(14.0), textColor: theme.chat.inputPanel.panelControlColor), nil, 1, .end, CGSize(width: 200.0, height: 100.0), .natural, nil, UIEdgeInsets())
        let _ = labelApply()
        
        let arrowSize = self.arrowNode.image?.size ?? CGSize()
        let height = max(arrowSize.height, labelLayout.size.height)
        self.frame = CGRect(origin: CGPoint(), size: CGSize(width: arrowSize.width + 12.0 + labelLayout.size.width, height: height))
        self.arrowNode.frame = CGRect(origin: CGPoint(x: 0.0, y: floor((height - arrowSize.height) / 2.0)), size: arrowSize)
        self.labelNode.frame = CGRect(origin: CGPoint(x: arrowSize.width + 6.0, y: floor((height - labelLayout.size.height) / 2.0) - UIScreenPixel), size: labelLayout.size)
    }
    
    func updateTheme(theme: PresentationTheme) {
        self.arrowNode.image = PresentationResourcesChat.chatInputPanelMediaRecordingCancelArrowImage(theme)
    }
}
