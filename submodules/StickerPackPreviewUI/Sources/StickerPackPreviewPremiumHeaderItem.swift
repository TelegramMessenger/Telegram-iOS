import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AppBundle

final class StickerPackPreviewPremiumHeaderItem: GridItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let count: Int32
    
    let section: GridSection? = nil
    let fillsRowWithHeight: (CGFloat, Bool)? = (15.0, true)
    
    init(theme: PresentationTheme, strings: PresentationStrings, count: Int32) {
        self.theme = theme
        self.strings = strings
        self.count = count
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = StickerPackPreviewPremiumHeaderItemNode()
        node.setup(theme: self.theme, strings: self.strings, count: self.count)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? StickerPackPreviewPremiumHeaderItemNode else {
            assertionFailure()
            return
        }
        node.setup(theme: self.theme, strings: self.strings, count: self.count)
    }
}

final class StickerPackPreviewPremiumHeaderItemNode: GridItemNode {
    private var currentState: (PresentationTheme, PresentationStrings, Int32)?
    
    let labelNode: ImmediateTextNode
    
    override init() {
        self.labelNode = ImmediateTextNode()
        self.labelNode.displaysAsynchronously = false
        self.labelNode.isUserInteractionEnabled = false
        
        super.init()
                
        self.addSubnode(self.labelNode)
    }
    
    
    func setup(theme: PresentationTheme, strings: PresentationStrings, count: Int32) {
        if self.currentState?.0 !== theme || self.currentState?.1 !== strings || self.currentState?.2 != count {
            self.labelNode.attributedText = NSAttributedString(string: strings.StickerPack_PremiumStickers(count), font: Font.medium(12.0), textColor: theme.actionSheet.controlAccentColor)
            self.currentState = (theme, strings, count)
        }
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        let textSize = self.labelNode.updateLayout(bounds.size)
        let textFrame = CGRect(origin: CGPoint(x: floor((bounds.width - textSize.width) / 2.0), y: floor((bounds.height - textSize.height) / 2.0)), size: textSize)
        self.labelNode.frame = textFrame
    }
}
