import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData

final class StickerPanePeerSpecificSetupGridItem: GridItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let setup: () -> Void
    let dismiss: (() -> Void)?

    let section: GridSection? = nil
    let fillsRowWithDynamicHeight: ((CGFloat) -> CGFloat)?
    
    init(theme: PresentationTheme, strings: PresentationStrings, setup: @escaping () -> Void, dismiss: (() -> Void)?) {
        self.theme = theme
        self.strings = strings
        self.setup = setup
        self.dismiss = dismiss
        self.fillsRowWithDynamicHeight = { width in
            let makeDescriptionLayout = TextNode.asyncLayout(nil)
            let params = ListViewItemLayoutParams(width: width, leftInset: 0.0, rightInset: 0.0, availableHeight: 0.0)
            let leftInset: CGFloat = 12.0
            let rightInset: CGFloat = 16.0
            let (descriptionLayout, _) = makeDescriptionLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: strings.Stickers_GroupStickersHelp, font: statusFont, textColor: .black), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - leftInset - rightInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            return 71.0 + descriptionLayout.size.height
        }
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = StickerPanePeerSpecificSetupGridItemNode()
        node.setup(item: self)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? StickerPanePeerSpecificSetupGridItemNode else {
            assertionFailure()
            return
        }
        node.setup(item: self)
    }
}

private let titleFont = Font.medium(12.0)
private let statusFont = Font.regular(14.0)
private let buttonFont = Font.medium(13.0)

class StickerPanePeerSpecificSetupGridItemNode: GridItemNode {
    private let titleNode: TextNode
    private let descriptionNode: TextNode
    private let installTextNode: TextNode
    private let installBackgroundNode: ASImageNode
    private let installButtonNode: HighlightTrackingButtonNode
    private let dismissButtonNode: HighlightTrackingButtonNode
    
    private var item: StickerPanePeerSpecificSetupGridItem?
    private var appliedItem: StickerPanePeerSpecificSetupGridItem?
    
    override init() {
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.descriptionNode = TextNode()
        self.descriptionNode.isUserInteractionEnabled = false
        self.descriptionNode.contentMode = .left
        self.descriptionNode.contentsScale = UIScreen.main.scale
        
        self.installTextNode = TextNode()
        self.installTextNode.isUserInteractionEnabled = false
        self.installTextNode.contentMode = .left
        self.installTextNode.contentsScale = UIScreen.main.scale
        
        self.installBackgroundNode = ASImageNode()
        self.installBackgroundNode.isLayerBacked = true
        self.installBackgroundNode.displayWithoutProcessing = true
        self.installBackgroundNode.displaysAsynchronously = false
        
        self.installButtonNode = HighlightTrackingButtonNode()
        self.dismissButtonNode = HighlightTrackingButtonNode()
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.descriptionNode)
        self.addSubnode(self.installBackgroundNode)
        self.addSubnode(self.installTextNode)
        self.addSubnode(self.installButtonNode)
        self.addSubnode(self.dismissButtonNode)
        
        self.installButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.installBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.installBackgroundNode.alpha = 0.4
                    strongSelf.installTextNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.installTextNode.alpha = 0.4
                } else {
                    strongSelf.installBackgroundNode.alpha = 1.0
                    strongSelf.installBackgroundNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.installTextNode.alpha = 1.0
                    strongSelf.installTextNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.installButtonNode.addTarget(self, action: #selector(self.installPressed), forControlEvents: .touchUpInside)
        
        self.dismissButtonNode.addTarget(self, action: #selector(self.dismissPressed), forControlEvents: .touchUpInside)
    }
    
    func setup(item: StickerPanePeerSpecificSetupGridItem) {
        self.item = item
        self.setNeedsLayout()
    }
    
    override func layout() {
        super.layout()
        guard let item = self.item else {
            return
        }
        
        let params = ListViewItemLayoutParams(width: self.bounds.size.width, leftInset: 0.0, rightInset: 0.0, availableHeight: self.bounds.size.height)
        
        let makeInstallLayout = TextNode.asyncLayout(self.installTextNode)
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeDescriptionLayout = TextNode.asyncLayout(self.descriptionNode)
        
        let currentItem = self.appliedItem
        self.appliedItem = item
        
        var updateButtonBackgroundImage: UIImage?
        if currentItem?.theme !== item.theme {
            updateButtonBackgroundImage = PresentationResourcesChat.chatInputMediaPanelAddPackButtonImage(item.theme)
            self.dismissButtonNode.setImage(PresentationResourcesChat.chatInputMediaPanelGridDismissImage(item.theme), for: [])
        }
        
        let leftInset: CGFloat = 12.0
        let rightInset: CGFloat = 16.0
        let topOffset: CGFloat = 9.0
        let textSpacing: CGFloat = 3.0
        let buttonSpacing: CGFloat = 6.0
        
        let (installLayout, installApply) = makeInstallLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.strings.Stickers_GroupChooseStickerPack, font: buttonFont, textColor: item.theme.list.itemCheckColors.foregroundColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        
        let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.strings.Stickers_GroupStickers.uppercased(), font: titleFont, textColor: item.theme.chat.inputMediaPanel.stickersSectionTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - leftInset - rightInset - 20.0 - installLayout.size.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        
        let (descriptionLayout, descriptionApply) = makeDescriptionLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.strings.Stickers_GroupStickersHelp, font: statusFont, textColor: item.theme.chat.inputMediaPanel.stickersSectionTextColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - leftInset - rightInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        
        self.item = item
        
        let _ = installApply()
        let _ = titleApply()
        let _ = descriptionApply()
        
        if let updateButtonBackgroundImage = updateButtonBackgroundImage {
            self.installBackgroundNode.image = updateButtonBackgroundImage
        }
        
        let installWidth: CGFloat = installLayout.size.width + 20.0
        let buttonFrame = CGRect(origin: CGPoint(x: params.leftInset + leftInset, y: topOffset + titleLayout.size.height + textSpacing + descriptionLayout.size.height + buttonSpacing), size: CGSize(width: installWidth, height: 32.0))
        self.installBackgroundNode.frame = buttonFrame
        self.installTextNode.frame = CGRect(origin: CGPoint(x: buttonFrame.minX + floor((buttonFrame.width - installLayout.size.width) / 2.0), y: buttonFrame.minY + floor((buttonFrame.height - installLayout.size.height) / 2.0)), size: installLayout.size)
        self.installButtonNode.frame = buttonFrame
        
        let titleFrame = CGRect(origin: CGPoint(x: params.leftInset + leftInset, y: topOffset), size: titleLayout.size)
        let dismissButtonSize = CGSize(width: 12.0, height: 12.0)
        self.dismissButtonNode.frame = CGRect(origin: CGPoint(x: params.width - params.rightInset - rightInset - dismissButtonSize.width, y: topOffset - 1.0), size: dismissButtonSize)
        self.dismissButtonNode.isHidden = item.dismiss == nil
        self.titleNode.frame = titleFrame
        self.descriptionNode.frame = CGRect(origin: CGPoint(x: params.leftInset + leftInset, y: topOffset + titleLayout.size.height + textSpacing), size: descriptionLayout.size)
    }
    
    @objc private func installPressed() {
        if let item = self.item {
            item.setup()
        }
    }
    
    @objc private func dismissPressed() {
        if let item = self.item {
            item.dismiss?()
        }
    }
}
