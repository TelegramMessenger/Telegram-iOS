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
        
        self.addSubnode(self.titleNode)
        self.titleNode.attributedText = NSAttributedString(string: code, font: sectionTitleFont, textColor: theme.chat.inputMediaPanel.stickersSectionTextColor)
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        let titleSize = self.titleNode.measure(CGSize(width: bounds.size.width - 24.0, height: CGFloat.greatestFiniteMagnitude))
        self.titleNode.frame = CGRect(origin: CGPoint(x: 12.0, y: 9.0), size: titleSize)
    }
}

final class StickerPaneSearchStickerItem: GridItem {
    let account: Account
    let code: String?
    let stickerItem: FoundStickerItem
    let selected: (ASDisplayNode, CGRect) -> Void
    let inputNodeInteraction: ChatMediaInputNodeInteraction
    
    let section: GridSection?
    
    init(account: Account, code: String?, stickerItem: FoundStickerItem, inputNodeInteraction: ChatMediaInputNodeInteraction, theme: PresentationTheme, selected: @escaping (ASDisplayNode, CGRect) -> Void) {
        self.account = account
        self.stickerItem = stickerItem
        self.inputNodeInteraction = inputNodeInteraction
        self.selected = selected
        self.code = code
        self.section = nil
    }
    
    func node(layout: GridNodeLayout, synchronousLoad: Bool) -> GridItemNode {
        let node = StickerPaneSearchStickerItemNode()
        node.inputNodeInteraction = self.inputNodeInteraction
        node.setup(account: self.account, stickerItem: self.stickerItem, code: self.code)
        node.selected = self.selected
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? StickerPaneSearchStickerItemNode else {
            assertionFailure()
            return
        }
        node.inputNodeInteraction = self.inputNodeInteraction
        node.setup(account: self.account, stickerItem: self.stickerItem, code: self.code)
        node.selected = self.selected
    }
}

private let textFont = Font.regular(20.0)

final class StickerPaneSearchStickerItemNode: GridItemNode {
    private var currentState: (Account, FoundStickerItem, CGSize)?
    let imageNode: TransformImageNode
    private(set) var animationNode: AnimatedStickerNode?
    private let textNode: ASTextNode
    
    private let stickerFetchedDisposable = MetaDisposable()
    
    var currentIsPreviewing = false
    
    override var isVisibleInGrid: Bool {
        didSet {
            self.updateVisibility()
        }
    }
    
    private var isPlaying = false
    
    var inputNodeInteraction: ChatMediaInputNodeInteraction?
    var selected: ((ASDisplayNode, CGRect) -> Void)?
    
    var stickerItem: FoundStickerItem? {
        return self.currentState?.1
    }
    
    override init() {
        self.imageNode = TransformImageNode()
        self.textNode = ASTextNode()
        self.textNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.textNode)
        self.textNode.maximumNumberOfLines = 1
    }
    
    deinit {
        self.stickerFetchedDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.imageNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageNodeTap(_:))))
    }
    
    func setup(account: Account, stickerItem: FoundStickerItem, code: String?) {
        if self.currentState == nil || self.currentState!.0 !== account || self.currentState!.1 != stickerItem {
            self.textNode.attributedText = NSAttributedString(string: code ?? "", font: textFont, textColor: .black)
            
            if let dimensions = stickerItem.file.dimensions {
                if stickerItem.file.isAnimatedSticker || stickerItem.file.isVideoSticker {
                    if self.animationNode == nil {
                        let animationNode = AnimatedStickerNode()
                        animationNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageNodeTap(_:))))
                        self.animationNode = animationNode
                        self.insertSubnode(animationNode, belowSubnode: self.textNode)
                    }
                    let dimensions = stickerItem.file.dimensions ?? PixelDimensions(width: 512, height: 512)
                    let fittedDimensions = dimensions.cgSize.aspectFitted(CGSize(width: 160.0, height: 160.0))
                    self.animationNode?.setup(source: AnimatedStickerResourceSource(account: account, resource: stickerItem.file.resource, isVideo: stickerItem.file.isVideoSticker), width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), mode: .cached)
                    self.animationNode?.visibility = self.isVisibleInGrid
                    self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: account, fileReference: stickerPackFileReference(stickerItem.file), resource: stickerItem.file.resource).start())
                } else {
                    if let animationNode = self.animationNode {
                        animationNode.visibility = false
                        self.animationNode = nil
                        animationNode.removeFromSupernode()
                    }
                    self.imageNode.setSignal(chatMessageSticker(account: account, file: stickerItem.file, small: true))
                    self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: account, fileReference: stickerPackFileReference(stickerItem.file), resource: chatMessageStickerResource(file: stickerItem.file, small: true)).start())
                }
                
                self.currentState = (account, stickerItem, dimensions.cgSize)
                self.setNeedsLayout()
            }
        }
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        let boundingSize = bounds.insetBy(dx: 6.0, dy: 6.0).size
        
        if let (_, _, mediaDimensions) = self.currentState {
            let imageSize = mediaDimensions.aspectFitted(boundingSize)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
            
            let imageFrame = CGRect(origin: CGPoint(x: floor((bounds.size.width - imageSize.width) / 2.0), y: (bounds.size.height - imageSize.height) / 2.0), size: imageSize)
            self.imageNode.frame = imageFrame
            
            if let animationNode = self.animationNode {
                animationNode.frame = imageFrame
                animationNode.updateLayout(size: imageSize)
            }
            
            let textSize = self.textNode.measure(CGSize(width: bounds.size.width - 24.0, height: CGFloat.greatestFiniteMagnitude))
            self.textNode.frame = CGRect(origin: CGPoint(x: bounds.size.width - textSize.width, y: bounds.size.height - textSize.height), size: textSize)
        }
    }
    
    @objc func imageNodeTap(_ recognizer: UITapGestureRecognizer) {
        self.selected?(self, self.bounds)
    }
    
    func transitionNode() -> ASDisplayNode? {
        return self.imageNode
    }
    
    func updateVisibility() {
        let isPlaying = self.isVisibleInGrid
        if self.isPlaying != isPlaying {
            self.isPlaying = isPlaying
            self.animationNode?.visibility = isPlaying
        }
    }
    
    func updatePreviewing(animated: Bool) {
        var isPreviewing = false
        if let (_, item, _) = self.currentState, let interaction = self.inputNodeInteraction {
            isPreviewing = interaction.previewedStickerPackItem == .found(item)
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
