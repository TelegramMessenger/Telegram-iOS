import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import SolidRoundedButtonNode

final class MediaPickerManageNode: ASDisplayNode {
    enum Subject {
        case limitedMedia
        case camera
    }
    
    private let textNode: ImmediateTextNode
    private let measureButtonNode: ImmediateTextNode
    private let buttonNode: SolidRoundedButtonNode
    
    var pressed: () -> Void = {}
    
    override init() {
        self.textNode = ImmediateTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.textAlignment = .left
        self.textNode.maximumNumberOfLines = 0
        
        self.measureButtonNode = ImmediateTextNode()
        
        self.buttonNode = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(backgroundColor: .black, foregroundColor: .white), fontSize: 15.0, height: 28.0, cornerRadius: 14.0)
        
        super.init()
                
        self.addSubnode(self.textNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.pressed = { [weak self] in
            self?.pressed()
        }
    }
    
    private var theme: PresentationTheme?
    func update(layout: ContainerViewLayout, theme: PresentationTheme, strings: PresentationStrings, subject: Subject, transition: ContainedViewLayoutTransition) -> CGFloat {
        let themeUpdated = self.theme != theme
        self.theme = theme
        
        let text: String
        switch subject {
            case .limitedMedia:
                text = strings.Attachment_LimitedMediaAccessText
            case .camera:
                text = strings.Attachment_CameraAccessText
        }
        
        let title = strings.Attachment_Manage.uppercased()
        self.measureButtonNode.attributedText = NSAttributedString(string: title, font: Font.semibold(15.0), textColor: .white, paragraphAlignment: .center)
        let measureButtonSize = self.measureButtonNode.updateLayout(layout.size)
        
        let buttonWidth = measureButtonSize.width + 26.0
        
        self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(15.0), textColor: theme.list.freeTextColor, paragraphAlignment: .left)
        let textSize = self.textNode.updateLayout(CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - 16.0 - buttonWidth - 26.0, height: layout.size.height))
        let panelHeight = max(64.0, textSize.height + 24.0)
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: layout.safeInsets.left + 16.0, y: floorToScreenPixels((panelHeight - textSize.height) / 2.0) - 5.0), size: textSize))
        
        if themeUpdated {
            self.buttonNode.updateTheme(SolidRoundedButtonTheme(theme: theme))
        }
        
        self.buttonNode.title = title
        let buttonHeight = self.buttonNode.updateLayout(width: buttonWidth, transition: transition)
        transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: layout.size.width - layout.safeInsets.right - buttonWidth - 10.0, y: floorToScreenPixels((panelHeight - buttonHeight) / 2.0) - 5.0), size: CGSize(width: buttonWidth, height: buttonHeight)))
        
        return panelHeight
    }
}
