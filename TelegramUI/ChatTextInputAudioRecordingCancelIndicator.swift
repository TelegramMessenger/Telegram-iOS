import Foundation
import AsyncDisplayKit
import Display

private let arrowImage = UIImage(bundleImageName: "Chat/Input/Text/AudioRecordingCancelArrow")?.precomposed()

final class ChatTextInputAudioRecordingCancelIndicator: ASDisplayNode {
    private let arrowNode: ASImageNode
    private let labelNode: TextNode
    
    override init() {
        self.arrowNode = ASImageNode()
        self.arrowNode.isLayerBacked = true
        self.arrowNode.displayWithoutProcessing = true
        self.arrowNode.displaysAsynchronously = false
        self.arrowNode.image = arrowImage
        
        self.labelNode = TextNode()
        self.labelNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.arrowNode)
        self.addSubnode(self.labelNode)
        
        let makeLayout = TextNode.asyncLayout(self.labelNode)
        let (labelLayout, labelApply) = makeLayout(NSAttributedString(string: "Slide to cancel", font: Font.regular(14.0), textColor: UIColor(0xaaaab2)), nil, 1, .end, CGSize(width: 200.0, height: 100.0), nil)
        labelApply()
        
        let arrowSize = arrowImage?.size ?? CGSize()
        let height = max(arrowSize.height, labelLayout.size.height)
        self.frame = CGRect(origin: CGPoint(), size: CGSize(width: arrowSize.width + 12.0 + labelLayout.size.width, height: height))
        self.arrowNode.frame = CGRect(origin: CGPoint(x: 0.0, y: floor((height - arrowSize.height) / 2.0)), size: arrowSize)
        self.labelNode.frame = CGRect(origin: CGPoint(x: arrowSize.width + 6.0, y: floor((height - labelLayout.size.height) / 2.0) - UIScreenPixel), size: labelLayout.size)
    }
}
