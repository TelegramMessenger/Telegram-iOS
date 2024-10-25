import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import AvatarNode
import AccountContext

final class HashtagChatInputPanelItem: ListViewItem {
    fileprivate let context: AccountContext
    fileprivate let presentationData: ItemListPresentationData
    fileprivate let peer: EnginePeer?
    fileprivate let title: String
    fileprivate let text: String?
    fileprivate let badge: String?
    fileprivate let hashtag: String
    fileprivate let revealed: Bool
    fileprivate let isAdditionalRecent: Bool
    fileprivate let setHashtagRevealed: (String?) -> Void
    private let hashtagSelected: (String) -> Void
    fileprivate let removeRequested: (String) -> Void
    
    let selectable: Bool = true
    
    public init(context: AccountContext, presentationData: ItemListPresentationData, peer: EnginePeer?, title: String, text: String?, badge: String? = nil, hashtag: String, revealed: Bool, isAdditionalRecent: Bool, setHashtagRevealed: @escaping (String?) -> Void, hashtagSelected: @escaping (String) -> Void, removeRequested: @escaping (String) -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.peer = peer
        self.title = title
        self.text = text
        self.badge = badge
        self.hashtag = hashtag
        self.revealed = revealed
        self.isAdditionalRecent = isAdditionalRecent
        self.setHashtagRevealed = setHashtagRevealed
        self.hashtagSelected = hashtagSelected
        self.removeRequested = removeRequested
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        let configure = { () -> Void in
            let node = HashtagChatInputPanelItemNode()
            
            let nodeLayout = node.asyncLayout()
            let (top, bottom) = (previousItem != nil, nextItem != nil)
            let (layout, apply) = nodeLayout(self, params, top, bottom)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(.None) })
                })
            }
        }
        if Thread.isMainThread {
            async {
                configure()
            }
        } else {
            configure()
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? HashtagChatInputPanelItemNode {
                let nodeLayout = nodeValue.asyncLayout()
                
                async {
                    let (top, bottom) = (previousItem != nil, nextItem != nil)
                    
                    let (layout, apply) = nodeLayout(self, params, top, bottom)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animation)
                        })
                    }
                }
            } else {
                assertionFailure()
            }
        }
    }
    
    func selected(listView: ListView) {
        if self.revealed {
            self.setHashtagRevealed(nil)
        } else {
//            if self.isAdditionalRecent {
//                self.hashtagSelected(self.hashtag)
//            } else {
                self.hashtagSelected(self.hashtag + " ")
//            }
        }
    }
}

private let avatarFont = avatarPlaceholderFont(size: 16.0)

final class HashtagChatInputPanelItemNode: ListViewItemNode {
    static let itemHeight: CGFloat = 42.0
    
    private let iconBackgroundLayer = SimpleLayer()
    private let iconLayer = SimpleLayer()
    private var avatarNode: AvatarNode?
    
    private let badgeBackgroundLayer = SimpleLayer()
    
    private let titleNode: TextNode
    private let textNode: TextNode
    private let badgeNode: TextNode
    private let topSeparatorNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
  
    private var revealNode: ItemListRevealOptionsNode?
    private var revealOptions: [ItemListRevealOption] = []
    private var initialRevealOffset: CGFloat = 0.0
    public private(set) var revealOffset: CGFloat = 0.0
    private var recognizer: ItemListRevealOptionsGestureRecognizer?
    private var hapticFeedback: HapticFeedback?
    
    private let activateAreaNode: AccessibilityAreaNode
    
    private var item: HashtagChatInputPanelItem?
    
    private var validLayout: (CGSize, CGFloat, CGFloat)?
    
    init() {
        self.iconBackgroundLayer.cornerRadius = 15.0
        self.badgeBackgroundLayer.cornerRadius = 4.0
        
        self.titleNode = TextNode()
        self.textNode = TextNode()
        self.badgeNode = TextNode()
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.activateAreaNode = AccessibilityAreaNode()
        self.activateAreaNode.accessibilityTraits = [.button]
        
        super.init(layerBacked: false, dynamicBounce: false)
                
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        
        self.addSubnode(self.activateAreaNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.layer.addSublayer(self.iconBackgroundLayer)
        self.iconBackgroundLayer.addSublayer(self.iconLayer)
        
        self.view.layer.addSublayer(self.badgeBackgroundLayer)
        self.addSubnode(self.badgeNode)
        
        let recognizer = ItemListRevealOptionsGestureRecognizer(target: self, action: #selector(self.revealGesture(_:)))
        self.recognizer = recognizer
        recognizer.allowAnyDirection = false
        self.view.addGestureRecognizer(recognizer)
    }
    
    override public func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? HashtagChatInputPanelItem {
            let doLayout = self.asyncLayout()
            let merged = (top: previousItem != nil, bottom: nextItem != nil)
            let (layout, apply) = doLayout(item, params, merged.top, merged.bottom)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply(.None)
        }
    }
    
    func asyncLayout() -> (_ item: HashtagChatInputPanelItem, _ params: ListViewItemLayoutParams, _ mergedTop: Bool, _ mergedBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let makeBadgeLayout = TextNode.asyncLayout(self.badgeNode)
        
        return { [weak self] item, params, mergedTop, mergedBottom in
            let titleFont = Font.semibold(floor(item.presentationData.fontSize.baseDisplaySize * 14.0 / 17.0))
            let textFont = Font.regular(floor(item.presentationData.fontSize.baseDisplaySize * 14.0 / 17.0))
            let badgeFont = Font.medium(floor(item.presentationData.fontSize.baseDisplaySize * 10.0 / 17.0))
            
            let leftInset: CGFloat = 15.0 + params.leftInset
            let textLeftInset: CGFloat = 40.0
            let baseWidth = params.width - params.leftInset - params.rightInset - textLeftInset
            
            let (badgeLayout, badgeApply) = makeBadgeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.badge ?? "", font: badgeFont, textColor: item.presentationData.theme.list.itemCheckColors.foregroundColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: baseWidth, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: titleFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: baseWidth - badgeLayout.size.width, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.text ?? "", font: textFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: baseWidth, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: HashtagChatInputPanelItemNode.itemHeight), insets: UIEdgeInsets())
            
            return (nodeLayout, { animation in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.validLayout = (nodeLayout.contentSize, params.leftInset, params.rightInset)
                                        
                    let revealOffset = strongSelf.revealOffset
                    
                    if strongSelf.iconLayer.contents == nil {
                        strongSelf.iconLayer.contents = UIImage(bundleImageName: "Chat/Hashtag/SuggestHashtag")?.cgImage
                    }
                    strongSelf.iconBackgroundLayer.backgroundColor = item.presentationData.theme.list.itemAccentColor.cgColor
                    strongSelf.iconLayer.layerTintColor = item.presentationData.theme.list.itemCheckColors.foregroundColor.cgColor
                    strongSelf.badgeBackgroundLayer.backgroundColor = item.presentationData.theme.list.itemAccentColor.cgColor
                    
                    strongSelf.separatorNode.backgroundColor = item.presentationData.theme.list.itemPlainSeparatorColor
                    strongSelf.topSeparatorNode.backgroundColor = item.presentationData.theme.list.itemPlainSeparatorColor
                    strongSelf.backgroundColor = item.presentationData.theme.list.plainBackgroundColor
                    strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                    
                    let _ = titleApply()
                    let _ = textApply()
                    let _ = badgeApply()
                    
                    if textLayout.size.height > 0.0 {
                        let combinedHeight = titleLayout.size.height + textLayout.size.height
                        strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset + textLeftInset, y: floor((nodeLayout.contentSize.height - combinedHeight) / 2.0)), size: titleLayout.size)
                        strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftInset + textLeftInset, y: floor((nodeLayout.contentSize.height - combinedHeight) / 2.0) + combinedHeight - textLayout.size.height), size: textLayout.size)
                    } else {
                        strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: revealOffset + leftInset + textLeftInset, y: floor((nodeLayout.contentSize.height - titleLayout.size.height) / 2.0)), size: titleLayout.size)
                    }
                    
                    if badgeLayout.size.height > 0.0 {
                        let badgeFrame = CGRect(origin: CGPoint(x: strongSelf.titleNode.frame.maxX + 8.0, y: floorToScreenPixels(strongSelf.titleNode.frame.midY - badgeLayout.size.height / 2.0)), size: badgeLayout.size)
                        let badgeBackgroundFrame = badgeFrame.insetBy(dx: -3.0, dy: -2.0)
                        
                        strongSelf.badgeNode.frame = badgeFrame
                        strongSelf.badgeBackgroundLayer.frame = badgeBackgroundFrame
                    }
                    
                    strongSelf.topSeparatorNode.isHidden = mergedTop
                    strongSelf.separatorNode.isHidden = !mergedBottom
                    
                    let iconSize = CGSize(width: 30.0, height: 30.0)
                    strongSelf.iconBackgroundLayer.frame = CGRect(origin: CGPoint(x: params.leftInset + 12.0, y: floor((nodeLayout.contentSize.height - 30.0) / 2.0)), size: iconSize)
                    strongSelf.iconLayer.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 30.0, height: 30.0))
                    
                    if let peer = item.peer {
                        strongSelf.iconBackgroundLayer.isHidden = true
                        let avatarNode: AvatarNode
                        if let current = strongSelf.avatarNode {
                            avatarNode = current
                        } else {
                            avatarNode = AvatarNode(font: avatarFont)
                            strongSelf.addSubnode(avatarNode)
                            strongSelf.avatarNode = avatarNode
                        }
                        avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: peer)
                        avatarNode.frame = strongSelf.iconBackgroundLayer.frame
                    } else {
                        strongSelf.iconBackgroundLayer.isHidden = false
                    }
                    
                    strongSelf.topSeparatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.width, height: UIScreenPixel))
                    strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset + textLeftInset, y: nodeLayout.contentSize.height - UIScreenPixel), size: CGSize(width: params.width - leftInset - textLeftInset, height: UIScreenPixel))
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.width, height: nodeLayout.size.height + UIScreenPixel))
                    
                    strongSelf.activateAreaNode.accessibilityLabel = item.title
                    strongSelf.activateAreaNode.frame = CGRect(origin: .zero, size: nodeLayout.size)
                    
                    strongSelf.setRevealOptions([ItemListRevealOption(key: 0, title: item.presentationData.strings.Common_Delete, icon: .none, color: item.presentationData.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.presentationData.theme.list.itemDisclosureActions.destructive.foregroundColor)])
                    strongSelf.setRevealOptionsOpened(item.revealed, animated: animation.isAnimated)
                }
            })
        }
    }
    
    func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        if let (_, leftInset, _) = self.validLayout {
            transition.updateFrameAdditive(layer: self.iconBackgroundLayer, frame: CGRect(origin: CGPoint(x: min(offset, 0.0) + 12.0 + leftInset, y: self.iconBackgroundLayer.frame.minY), size: self.iconBackgroundLayer.frame.size))
            transition.updateFrameAdditive(node: self.titleNode, frame: CGRect(origin: CGPoint(x: min(offset, 0.0) + 15.0 + 40.0 + leftInset, y: self.titleNode.frame.minY), size: self.titleNode.frame.size))
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
        if let _ = self.revealNode, self.revealOffset != 0 {
            return
        }
        
        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: self.separatorNode)
            }
        } else {
            if self.highlightedBackgroundNode.supernode != nil {
                if animated {
                    self.highlightedBackgroundNode.layer.animateAlpha(from: self.highlightedBackgroundNode.alpha, to: 0.0, duration: 0.4, completion: { [weak self] completed in
                        if let strongSelf = self {
                            if completed {
                                strongSelf.highlightedBackgroundNode.removeFromSupernode()
                            }
                        }
                    })
                    self.highlightedBackgroundNode.alpha = 0.0
                } else {
                    self.highlightedBackgroundNode.removeFromSupernode()
                }
            }
        }
    }
    
    func setRevealOptions(_ options: [ItemListRevealOption]) {
        if self.revealOptions == options {
            return
        }
        let wasEmpty = self.revealOptions.isEmpty
        self.revealOptions = options
        let isEmpty = options.isEmpty
        if options.isEmpty {
            if let _ = self.revealNode {
                self.recognizer?.becomeCancelled()
                self.updateRevealOffsetInternal(offset: 0.0, transition: .animated(duration: 0.3, curve: .spring))
            }
        }
        if wasEmpty != isEmpty {
            self.recognizer?.isEnabled = !isEmpty
        }
    }
    
    private func setRevealOptionsOpened(_ value: Bool, animated: Bool) {
        if value != !self.revealOffset.isZero {
            if !self.revealOffset.isZero {
                self.recognizer?.becomeCancelled()
            }
            let transition: ContainedViewLayoutTransition
            if animated {
                transition = .animated(duration: 0.3, curve: .spring)
            } else {
                transition = .immediate
            }
            if value {
                if self.revealNode == nil {
                    self.setupAndAddRevealNode()
                    if let revealNode = self.revealNode, revealNode.isNodeLoaded, let _ = self.validLayout {
                        revealNode.layout()
                        let revealSize = revealNode.bounds.size
                        self.updateRevealOffsetInternal(offset: -revealSize.width, transition: transition)
                    }
                }
            } else if !self.revealOffset.isZero {
                self.updateRevealOffsetInternal(offset: 0.0, transition: transition)
            }
        }
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let item = self.item {
            if let _ = item.text {
                return false
            }
        }
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let recognizer = self.recognizer, otherGestureRecognizer == recognizer {
            return true
        } else {
            return false
        }
    }
    
    @objc func revealGesture(_ recognizer: ItemListRevealOptionsGestureRecognizer) {
        guard let (size, _, _) = self.validLayout else {
            return
        }
        switch recognizer.state {
        case .began:
            if let revealNode = self.revealNode {
                let revealSize = revealNode.bounds.size
                let location = recognizer.location(in: self.view)
                if location.x > size.width - revealSize.width {
                    recognizer.becomeCancelled()
                } else {
                    self.initialRevealOffset = self.revealOffset
                }
            } else {
                if self.revealOptions.isEmpty {
                    recognizer.becomeCancelled()
                }
                self.initialRevealOffset = self.revealOffset
            }
        case .changed:
            var translation = recognizer.translation(in: self.view)
            translation.x += self.initialRevealOffset
            if self.revealNode == nil && translation.x.isLess(than: 0.0) {
                self.setupAndAddRevealNode()
                self.revealOptionsInteractivelyOpened()
            }
            self.updateRevealOffsetInternal(offset: translation.x, transition: .immediate)
            if self.revealNode == nil {
                self.revealOptionsInteractivelyClosed()
            }
        case .ended, .cancelled:
            guard let recognizer = self.recognizer else {
                break
            }
            
            if let revealNode = self.revealNode {
                let velocity = recognizer.velocity(in: self.view)
                let revealSize = revealNode.bounds.size
                var reveal = false
                if abs(velocity.x) < 100.0 {
                    if self.initialRevealOffset.isZero && self.revealOffset < 0.0 {
                        reveal = true
                    } else if self.revealOffset < -revealSize.width {
                        reveal = true
                    } else {
                        reveal = false
                    }
                } else {
                    if velocity.x < 0.0 {
                        reveal = true
                    } else {
                        reveal = false
                    }
                }
                self.updateRevealOffsetInternal(offset: reveal ? -revealSize.width : 0.0, transition: .animated(duration: 0.3, curve: .spring))
                if !reveal {
                    self.revealOptionsInteractivelyClosed()
                }
            }
        default:
            break
        }
    }
    
    private func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        guard let item = self.item else {
            return
        }
        item.removeRequested(item.hashtag)
    }
    
    private func setupAndAddRevealNode() {
        if !self.revealOptions.isEmpty {
            let revealNode = ItemListRevealOptionsNode(optionSelected: { [weak self] option in
                self?.revealOptionSelected(option, animated: false)
            }, tapticAction: { [weak self] in
                self?.hapticImpact()
            })
            revealNode.setOptions(self.revealOptions, isLeft: false, enableAnimations: true)
            self.revealNode = revealNode
            
            if let (size, _, rightInset) = self.validLayout {
                var revealSize = revealNode.measure(CGSize(width: CGFloat.greatestFiniteMagnitude, height: size.height))
                revealSize.width += rightInset
                
                revealNode.frame = CGRect(origin: CGPoint(x: size.width + max(self.revealOffset, -revealSize.width), y: 0.0), size: revealSize)
                revealNode.updateRevealOffset(offset: 0.0, sideInset: -rightInset, transition: .immediate)
            }
            
            self.addSubnode(revealNode)
        }
    }
    
    private func updateRevealOffsetInternal(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.revealOffset = offset
        guard let (size, _, rightInset) = self.validLayout else {
            return
        }
        
        if let revealNode = self.revealNode {
            let revealSize = revealNode.bounds.size
            
            let revealFrame = CGRect(origin: CGPoint(x: size.width + max(self.revealOffset, -revealSize.width), y: 0.0), size: revealSize)
            let revealNodeOffset = -max(self.revealOffset, -revealSize.width)
            revealNode.updateRevealOffset(offset: revealNodeOffset, sideInset: -rightInset, transition: transition)
            
            if CGFloat(0.0).isLessThanOrEqualTo(offset) {
                self.revealNode = nil
                transition.updateFrame(node: revealNode, frame: revealFrame, completion: { [weak revealNode] _ in
                    revealNode?.removeFromSupernode()
                })
            } else {
                transition.updateFrame(node: revealNode, frame: revealFrame)
            }
        }
        self.updateRevealOffset(offset: offset, transition: transition)
    }
    
    func revealOptionsInteractivelyOpened() {
        if let item = self.item {
            item.setHashtagRevealed(item.text)
        }
    }
    
    func revealOptionsInteractivelyClosed() {
        if let item = self.item {
            item.setHashtagRevealed(nil)
        }
    }
    
    private func hapticImpact() {
        if self.hapticFeedback == nil {
            self.hapticFeedback = HapticFeedback()
        }
        self.hapticFeedback?.impact(.medium)
    }
}
