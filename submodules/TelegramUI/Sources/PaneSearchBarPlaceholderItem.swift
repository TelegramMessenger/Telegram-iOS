import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AppBundle

private let templateLoupeIcon = UIImage(bundleImageName: "Components/Search Bar/Loupe")

private func generateLoupeIcon(color: UIColor) -> UIImage? {
    return generateTintedImage(image: templateLoupeIcon, color: color)
}

enum PaneSearchBarType {
    case stickers
    case gifs
}

final class PaneSearchBarPlaceholderItem: GridItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let type: PaneSearchBarType
    let activate: () -> Void
    
    let section: GridSection? = nil
    let fillsRowWithHeight: (CGFloat, Bool)? = (56.0, true)
    
    init(theme: PresentationTheme, strings: PresentationStrings, type: PaneSearchBarType, activate: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.type = type
        self.activate = activate
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = PaneSearchBarPlaceholderNode()
        node.activate = self.activate
        node.setup(theme: self.theme, strings: self.strings, type: self.type)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? PaneSearchBarPlaceholderNode else {
            assertionFailure()
            return
        }
        node.activate = self.activate
        node.setup(theme: self.theme, strings: self.strings, type: self.type)
    }
}

final class PaneSearchBarPlaceholderNode: GridItemNode {
    private var currentState: (PresentationTheme, PresentationStrings, PaneSearchBarType)?
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
        
        self.isAccessibilityElement = true
        self.accessibilityTraits = .searchField
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.iconNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    func setup(theme: PresentationTheme, strings: PresentationStrings, type: PaneSearchBarType) {
        if self.currentState?.0 !== theme || self.currentState?.1 !== strings || self.currentState?.2 != type {
            self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 36.0, color: theme.chat.inputMediaPanel.stickersSearchBackgroundColor)
            self.iconNode.image = generateLoupeIcon(color: theme.chat.inputMediaPanel.stickersSearchControlColor)
            let placeholder: String
            switch type {
                case .stickers:
                    placeholder = strings.Stickers_Search
                case .gifs:
                    placeholder = strings.Gif_Search
            }
            self.labelNode.attributedText = NSAttributedString(string: placeholder, font: Font.regular(17.0), textColor: theme.chat.inputMediaPanel.stickersSearchPlaceholderColor)
            self.accessibilityLabel = placeholder
            self.currentState = (theme, strings, type)
        }
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        let backgroundFrame = CGRect(origin: CGPoint(x: 8.0, y: 12.0), size: CGSize(width: bounds.width - 8.0 * 2.0, height: 36.0))
        self.backgroundNode.frame = backgroundFrame
        
        let textSize = self.labelNode.updateLayout(bounds.size)
        let textFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + floor((backgroundFrame.width - textSize.width) / 2.0), y: backgroundFrame.minY + floor((backgroundFrame.height - textSize.height) / 2.0)), size: textSize)
        self.labelNode.frame = textFrame
        
        if let iconImage = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: textFrame.minX - iconImage.size.width - 6.0, y: floorToScreenPixels(textFrame.midY - iconImage.size.height / 2.0)), size: iconImage.size)
        }
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.activate?()
        }
    }
}
