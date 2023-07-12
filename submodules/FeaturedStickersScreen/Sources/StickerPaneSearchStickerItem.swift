import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox
import TelegramPresentationData
import StickerResources
import AccountContext
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import ChatPresentationInterfaceState
import EmojiTextAttachmentView
import TextFormat

final class StickerPaneSearchStickerSection: GridSection {
    let code: String
    let theme: PresentationTheme
    let height: CGFloat = 26.0
    
    var hashValue: Int {
        return self.code.hashValue
    }
    
    init(code: String, theme: PresentationTheme) {
        self.code = code
        self.theme = theme
    }
    
    func isEqual(to: GridSection) -> Bool {
        if let to = to as? StickerPaneSearchStickerSection {
            return self.code == to.code && self.theme === to.theme
        } else {
            return false
        }
    }
    
    func node() -> ASDisplayNode {
        return StickerPaneSearchStickerSectionNode(code: self.code, theme: self.theme)
    }
}

private let sectionTitleFont = Font.medium(12.0)

final class StickerPaneSearchStickerSectionNode: ASDisplayNode {
    let titleNode: ASTextNode
    
    init(code: String, theme: PresentationTheme) {
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.titleNode.attributedText = NSAttributedString(string: code, font: sectionTitleFont, textColor: theme.chat.inputMediaPanel.stickersSectionTextColor)
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
        
        self.addSubnode(self.titleNode)
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        let titleSize = self.titleNode.measure(CGSize(width: bounds.size.width - 24.0, height: CGFloat.greatestFiniteMagnitude))
        self.titleNode.frame = CGRect(origin: CGPoint(x: 12.0, y: 9.0), size: titleSize)
    }
}

public final class StickerPaneSearchStickerItem: GridItem {
    public let context: AccountContext
    public let theme: PresentationTheme
    public let code: String?
    public let stickerItem: FoundStickerItem
    public let selected: (ASDisplayNode, CALayer, CGRect) -> Void
    public let inputNodeInteraction: ChatMediaInputNodeInteraction
    
    public let section: GridSection?
    
    public init(context: AccountContext, theme: PresentationTheme, code: String?, stickerItem: FoundStickerItem, inputNodeInteraction: ChatMediaInputNodeInteraction, selected: @escaping (ASDisplayNode, CALayer, CGRect) -> Void) {
        self.context = context
        self.theme = theme
        self.stickerItem = stickerItem
        self.inputNodeInteraction = inputNodeInteraction
        self.selected = selected
        self.code = code
        self.section = nil
    }
    
    public func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = StickerPaneSearchStickerItemNode()
        node.inputNodeInteraction = self.inputNodeInteraction
        node.setup(context: self.context, theme: self.theme, stickerItem: self.stickerItem, code: self.code)
        node.selected = self.selected
        return node
    }
    
    public func update(node: GridItemNode) {
        guard let node = node as? StickerPaneSearchStickerItemNode else {
            assertionFailure()
            return
        }
        node.inputNodeInteraction = self.inputNodeInteraction
        node.setup(context: self.context, theme: self.theme, stickerItem: self.stickerItem, code: self.code)
        node.selected = self.selected
    }
}

private let textFont = Font.regular(20.0)

public final class StickerPaneSearchStickerItemNode: GridItemNode {
    private var currentState: (AccountContext, FoundStickerItem, CGSize)?
    var itemLayer: InlineStickerItemLayer?
    private let textNode: ASTextNode
    
    private let stickerFetchedDisposable = MetaDisposable()
    
    public var currentIsPreviewing = false
    
    public override var isVisibleInGrid: Bool {
        didSet {
            self.updateVisibility()
        }
    }
    
    private var isPlaying = false
    
    public var inputNodeInteraction: ChatMediaInputNodeInteraction?
    public var selected: ((ASDisplayNode, CALayer, CGRect) -> Void)?
        
    public var stickerItem: FoundStickerItem? {
        return self.currentState?.1
    }
    
    public override init() {
        self.textNode = ASTextNode()
        self.textNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.textNode.maximumNumberOfLines = 1
        
        self.addSubnode(self.textNode)
    }
    
    deinit {
        self.stickerFetchedDisposable.dispose()
    }
    
    public override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageNodeTap(_:))))
    }
    
    func setup(context: AccountContext, theme: PresentationTheme, stickerItem: FoundStickerItem, code: String?) {
        if self.currentState == nil || self.currentState!.0 !== context || self.currentState!.1 != stickerItem {
            self.textNode.attributedText = NSAttributedString(string: code ?? "", font: textFont, textColor: .black)
            
            let file = stickerItem.file
            let itemDimensions = file.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0)
            let playbackItemSize = CGSize(width: 96.0, height: 96.0)
             
            let itemPlaybackSize = itemDimensions.aspectFitted(playbackItemSize)
            
            let itemLayer: InlineStickerItemLayer
            if let current = self.itemLayer {
                itemLayer = current
                itemLayer.dynamicColor = .white
            } else {
                itemLayer = InlineStickerItemLayer(
                    context: context,
                    userLocation: .other,
                    attemptSynchronousLoad: false,
                    emoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: file.fileId.id, file: file),
                    file: file,
                    cache: context.animationCache,
                    renderer: context.animationRenderer,
                    placeholderColor: theme.chat.inputPanel.primaryTextColor.withMultipliedAlpha(0.1),
                    pointSize: itemPlaybackSize,
                    dynamicColor: .white
                )
                self.itemLayer = itemLayer
                self.layer.insertSublayer(itemLayer, at: 0)
            }
            
            self.currentState = (context, stickerItem, itemDimensions)
            self.setNeedsLayout()
            self.updateVisibility()
        }
    }
    
    public override func layout() {
        super.layout()
        
        let bounds = self.bounds
        let boundingSize = bounds.insetBy(dx: 6.0, dy: 6.0).size
        
        if let (_, _, itemDimensions) = self.currentState {
            let itemSize = itemDimensions.aspectFitted(boundingSize)
            let itemFrame = CGRect(origin: CGPoint(x: floor((bounds.size.width - itemSize.width) / 2.0), y: (bounds.size.height - itemSize.height) / 2.0), size: itemSize)
            if let itemLayer = self.itemLayer {
                itemLayer.frame = itemFrame
            }
            let textSize = self.textNode.measure(CGSize(width: bounds.size.width - 24.0, height: CGFloat.greatestFiniteMagnitude))
            self.textNode.frame = CGRect(origin: CGPoint(x: bounds.size.width - textSize.width, y: bounds.size.height - textSize.height), size: textSize)
        }
    }
    
    @objc func imageNodeTap(_ recognizer: UITapGestureRecognizer) {
        guard let itemLayer = self.itemLayer else {
            return
        }
        self.selected?(self, itemLayer, self.bounds)
    }
    
    public func transitionNode() -> ASDisplayNode? {
        return self
    }
    
    public func updateVisibility() {
        guard let context = self.currentState?.0 else {
            return
        }
        
        let isPlaying = self.isVisibleInGrid && context.sharedContext.energyUsageSettings.loopStickers
        if self.isPlaying != isPlaying, let itemLayer = self.itemLayer {
            self.isPlaying = isPlaying
            itemLayer.isVisibleForAnimations = isPlaying
        }
    }
    
    public func updatePreviewing(animated: Bool) {
        var isPreviewing = false
        if let (_, item, _) = self.currentState, let interaction = self.inputNodeInteraction {
            isPreviewing = interaction.previewedStickerPackItemFile?.id == item.file.id
        }
        if self.currentIsPreviewing != isPreviewing {
            self.currentIsPreviewing = isPreviewing
            
            if isPreviewing {
                self.layer.sublayerTransform = CATransform3DMakeScale(0.8, 0.8, 1.0)
                if animated {
                    self.layer.animateSpring(from: 1.0 as NSNumber, to: 0.8 as NSNumber, keyPath: "sublayerTransform.scale", duration: 0.4)
                }
            } else {
                self.layer.sublayerTransform = CATransform3DIdentity
                if animated {
                    self.layer.animateSpring(from: 0.8 as NSNumber, to: 1.0 as NSNumber, keyPath: "sublayerTransform.scale", duration: 0.5)
                }
            }
        }
    }
}
