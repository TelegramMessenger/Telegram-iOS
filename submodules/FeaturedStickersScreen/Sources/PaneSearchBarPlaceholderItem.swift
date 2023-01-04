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

public enum PaneSearchBarType {
    case stickers
    case gifs
}

public final class PaneSearchBarPlaceholderItem: GridItem {
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let type: PaneSearchBarType
    public let activate: () -> Void
    
    public let section: GridSection? = nil
    public let fillsRowWithHeight: (CGFloat, Bool)? = (56.0, true)
    
    public init(theme: PresentationTheme, strings: PresentationStrings, type: PaneSearchBarType, activate: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.type = type
        self.activate = activate
    }
    
    public func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = PaneSearchBarPlaceholderNode()
        node.activate = self.activate
        node.setup(theme: self.theme, strings: self.strings, type: self.type)
        return node
    }
    
    public func update(node: GridItemNode) {
        guard let node = node as? PaneSearchBarPlaceholderNode else {
            assertionFailure()
            return
        }
        node.activate = self.activate
        node.setup(theme: self.theme, strings: self.strings, type: self.type)
    }
}

public final class PaneSearchBarPlaceholderNode: GridItemNode {
    private var currentState: (PresentationTheme, PresentationStrings, PaneSearchBarType)?
    public var activate: (() -> Void)?
    
    public let backgroundNode: ASImageNode
    public let labelNode: ImmediateTextNode
    public let iconNode: ASImageNode
    
    public override init() {
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
    
    public override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    public func setup(theme: PresentationTheme, strings: PresentationStrings, type: PaneSearchBarType) {
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
    
    public override func layout() {
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
