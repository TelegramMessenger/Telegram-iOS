import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import TelegramCore
import AnimationUI

final class WalletInfoEmptyNode: ASDisplayNode {
    private var presentationData: PresentationData
    
    private let iconNode: ASImageNode
    private let animationNode: AnimatedStickerNode
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let addressNode: ImmediateTextNode
    
    init(presentationData: PresentationData, address: String) {
        self.presentationData = presentationData
        
        self.iconNode = ASImageNode()
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        
        self.animationNode = AnimatedStickerNode()
        
        let title = "Wallet Created"
        let text = "Your wallet address"
        self.iconNode.image = UIImage(bundleImageName: "Wallet/DuckIcon")
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.bold(32.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(16.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.textNode.maximumNumberOfLines = 0
        self.textNode.lineSpacing = 0.1
        self.textNode.textAlignment = .center
        
        self.addressNode = ImmediateTextNode()
        self.addressNode.displaysAsynchronously = false
        self.addressNode.attributedText = NSAttributedString(string: address, font: Font.monospace(16.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
        self.addressNode.maximumNumberOfLines = 0
        self.addressNode.lineSpacing = 0.1
        self.addressNode.textAlignment = .center
        
        super.init()
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.animationNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.addressNode)
    }
    
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let sideInset: CGFloat = 32.0
        let buttonSideInset: CGFloat = 48.0
        let iconSpacing: CGFloat = 5.0
        let titleSpacing: CGFloat = 19.0
        let termsSpacing: CGFloat = 11.0
        let buttonHeight: CGFloat = 50.0
        
        let iconSize: CGSize
        var iconOffset = CGPoint()
        iconSize = self.iconNode.image?.size ?? CGSize(width: 140.0, height: 140.0)
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: .greatestFiniteMagnitude))
        let textSize = self.textNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: .greatestFiniteMagnitude))
        let addressSize = self.addressNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: .greatestFiniteMagnitude))
        
        let contentVerticalOrigin: CGFloat = 0.0
        
        let iconFrame = CGRect(origin: CGPoint(x: floor((width - iconSize.width) / 2.0), y: contentVerticalOrigin), size: iconSize).offsetBy(dx: iconOffset.x, dy: iconOffset.y)
        transition.updateFrameAdditive(node: self.iconNode, frame: iconFrame)
        self.animationNode.updateLayout(size: iconFrame.size)
        transition.updateFrameAdditive(node: self.animationNode, frame: iconFrame)
        let titleFrame = CGRect(origin: CGPoint(x: floor((width - titleSize.width) / 2.0), y: iconFrame.maxY + iconSpacing), size: titleSize)
        transition.updateFrameAdditive(node: self.titleNode, frame: titleFrame)
        let textFrame = CGRect(origin: CGPoint(x: floor((width - textSize.width) / 2.0), y: titleFrame.maxY + titleSpacing), size: textSize)
        transition.updateFrameAdditive(node: self.textNode, frame: textFrame)
        let addressFrame = CGRect(origin: CGPoint(x: floor((width - addressSize.width) / 2.0), y: textFrame.maxY + titleSpacing), size: addressSize)
        transition.updateFrameAdditive(node: self.addressNode, frame: addressFrame)
        
        return addressFrame.maxY
    }
}
