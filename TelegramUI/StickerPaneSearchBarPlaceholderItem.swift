import Foundation
import AsyncDisplayKit
import UIKit
import Display

private let templateLoupeIcon = UIImage(bundleImageName: "Components/Search Bar/Loupe")

private func generateLoupeIcon(color: UIColor) -> UIImage? {
    return generateTintedImage(image: templateLoupeIcon, color: color)
}

final class StickerPaneSearchBarPlaceholderItem: GridItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let activate: () -> Void
    
    let section: GridSection? = nil
    let fillsRowWithHeight: CGFloat? = 56.0
    
    init(theme: PresentationTheme, strings: PresentationStrings, activate: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.activate = activate
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = StickerPaneSearchBarPlaceholderNode()
        node.activate = self.activate
        node.setup(theme: self.theme, strings: self.strings)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? StickerPaneSearchBarPlaceholderNode else {
            assertionFailure()
            return
        }
        node.activate = self.activate
        node.setup(theme: self.theme, strings: self.strings)
    }
}

final class StickerPaneSearchBarPlaceholderNode: GridItemNode {
    private var currentState: (PresentationTheme, PresentationStrings)?
    var activate: (() -> Void)?
    
    let backgroundNode: ASImageNode
    let labelNode: ImmediateTextNode
    let iconNode: ASImageNode
    
    override init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.isUserInteractionEnabled = false
        
        self.labelNode = ImmediateTextNode()
        self.labelNode.displaysAsynchronously = false
        self.labelNode.isUserInteractionEnabled = false
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.iconNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    func setup(theme: PresentationTheme, strings: PresentationStrings) {
        if self.currentState?.0 !== theme || self.currentState?.1 !== strings {
            self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 33.0, color: theme.chat.inputMediaPanel.stickersSearchBackgroundColor)
            self.iconNode.image = generateLoupeIcon(color: theme.chat.inputMediaPanel.stickersSearchControlColor)
            self.labelNode.attributedText = NSAttributedString(string: strings.Stickers_Search, font: Font.regular(14.0), textColor: theme.chat.inputMediaPanel.stickersSearchPlaceholderColor)
        }
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        let backgroundFrame = CGRect(origin: CGPoint(x: 8.0, y: 12.0), size: CGSize(width: bounds.width - 8.0 * 2.0, height: 33.0))
        self.backgroundNode.frame = backgroundFrame
        
        let textSize = self.labelNode.updateLayout(bounds.size)
        let textFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + floor((backgroundFrame.width - textSize.width) / 2.0), y: backgroundFrame.minY + floor((backgroundFrame.height - textSize.height) / 2.0)), size: textSize)
        self.labelNode.frame = textFrame
        
        if let iconImage = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: textFrame.minX - iconImage.size.width - 5.0, y: floorToScreenPixels(textFrame.midY - iconImage.size.height / 2.0)), size: iconImage.size)
        }
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.activate?()
        }
    }
}
