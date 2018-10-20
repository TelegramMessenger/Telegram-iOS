import Foundation
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox

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
        self.titleNode.isLayerBacked = true
        
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
    let selected: () -> Void
    let inputNodeInteraction: ChatMediaInputNodeInteraction
    
    let section: GridSection?
    
    init(account: Account, code: String?, stickerItem: FoundStickerItem, inputNodeInteraction: ChatMediaInputNodeInteraction, theme: PresentationTheme, selected: @escaping () -> Void) {
        self.account = account
        self.stickerItem = stickerItem
        self.inputNodeInteraction = inputNodeInteraction
        self.selected = selected
        if let code = code {
            self.code = code
            self.section = StickerPaneSearchStickerSection(code: code, theme: theme)
        } else {
            self.code = nil
            self.section = nil
        }
    }
    
    func node(layout: GridNodeLayout) -> GridItemNode {
        let node = StickerPaneSearchStickerItemNode()
        node.inputNodeInteraction = self.inputNodeInteraction
        node.setup(account: self.account, stickerItem: self.stickerItem)
        node.selected = self.selected
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? StickerPaneSearchStickerItemNode else {
            assertionFailure()
            return
        }
        node.inputNodeInteraction = self.inputNodeInteraction
        node.setup(account: self.account, stickerItem: self.stickerItem)
        node.selected = self.selected
    }
}

final class StickerPaneSearchStickerItemNode: GridItemNode {
    private var currentState: (Account, FoundStickerItem, CGSize)?
    private let imageNode: TransformImageNode
    
    private let stickerFetchedDisposable = MetaDisposable()
    
    var currentIsPreviewing = false
    
    var inputNodeInteraction: ChatMediaInputNodeInteraction?
    var selected: (() -> Void)?
    
    var stickerItem: FoundStickerItem? {
        return self.currentState?.1
    }
    
    override init() {
        self.imageNode = TransformImageNode()
        
        super.init()
        
        self.addSubnode(self.imageNode)
    }
    
    deinit {
        stickerFetchedDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.imageNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageNodeTap(_:))))
    }
    
    func setup(account: Account, stickerItem: FoundStickerItem) {
        if self.currentState == nil || self.currentState!.0 !== account || self.currentState!.1 != stickerItem {
            if let dimensions = stickerItem.file.dimensions {
                self.imageNode.setSignal(chatMessageSticker(account: account, file: stickerItem.file, small: true))
                self.stickerFetchedDisposable.set(freeMediaFileResourceInteractiveFetched(account: account, fileReference: stickerPackFileReference(stickerItem.file), resource: chatMessageStickerResource(file: stickerItem.file, small: true)).start())
                
                self.currentState = (account, stickerItem, dimensions)
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
            self.imageNode.frame = CGRect(origin: CGPoint(x: floor((bounds.size.width - imageSize.width) / 2.0), y: (bounds.size.height - imageSize.height) / 2.0), size: imageSize)
        }
    }
    
    @objc func imageNodeTap(_ recognizer: UITapGestureRecognizer) {
        self.selected?()
    }
    
    func transitionNode() -> ASDisplayNode? {
        return self.imageNode
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
