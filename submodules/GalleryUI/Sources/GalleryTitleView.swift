import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramStringFormatting

private let titleFont = Font.medium(15.0)
private let dateFont = Font.regular(14.0)

final class GalleryTitleView: UIView, NavigationBarTitleView {    
    private let authorNameNode: ASTextNode
    private let dateNode: ASTextNode
    
    override init(frame: CGRect) {
        self.authorNameNode = ASTextNode()
        self.authorNameNode.displaysAsynchronously = false
        self.authorNameNode.maximumNumberOfLines = 1
        
        self.dateNode = ASTextNode()
        self.dateNode.displaysAsynchronously = false
        self.dateNode.maximumNumberOfLines = 1
        
        super.init(frame: frame)
        
        self.addSubnode(self.authorNameNode)
        self.addSubnode(self.dateNode)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setMessage(_ message: Message, presentationData: PresentationData, accountPeerId: PeerId) {
        let authorNameText = stringForFullAuthorName(message: EngineMessage(message), strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder, accountPeerId: accountPeerId)
        let dateText = humanReadableStringForTimestamp(strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, timestamp: message.timestamp).string
        
        self.authorNameNode.attributedText = NSAttributedString(string: authorNameText, font: titleFont, textColor: .white)
        self.dateNode.attributedText = NSAttributedString(string: dateText, font: dateFont, textColor: .white)
    }
    
    func updateLayout(size: CGSize, clearBounds: CGRect, transition: ContainedViewLayoutTransition) {
        let leftInset: CGFloat = 0.0
        let rightInset: CGFloat = 0.0
        
        let authorNameSize = self.authorNameNode.measure(CGSize(width: max(1.0, size.width - 8.0 * 2.0 - leftInset - rightInset), height: CGFloat.greatestFiniteMagnitude))
        let dateSize = self.dateNode.measure(CGSize(width: max(1.0, size.width - 8.0 * 2.0), height: CGFloat.greatestFiniteMagnitude))
        
        if authorNameSize.height.isZero {
            self.dateNode.frame = CGRect(origin: CGPoint(x: floor((size.width - dateSize.width) / 2.0), y: floor((size.height - dateSize.height) / 2.0)), size: dateSize)
        } else {
            let labelsSpacing: CGFloat = 0.0
            self.authorNameNode.frame = CGRect(origin: CGPoint(x: floor((size.width - authorNameSize.width) / 2.0), y: floor((size.height - dateSize.height - authorNameSize.height - labelsSpacing) / 2.0)), size: authorNameSize)
            self.dateNode.frame = CGRect(origin: CGPoint(x: floor((size.width - dateSize.width) / 2.0), y: floor((size.height - dateSize.height - authorNameSize.height - labelsSpacing) / 2.0) + authorNameSize.height + labelsSpacing), size: dateSize)
        }
    }
    
    func animateLayoutTransition() {
        
    }
}
