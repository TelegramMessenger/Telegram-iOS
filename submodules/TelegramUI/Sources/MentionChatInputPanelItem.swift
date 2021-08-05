import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import TelegramUIPreferences
import AvatarNode
import AccountContext
import ItemListUI

final class MentionChatInputPanelItem: ListViewItem {
    fileprivate let context: AccountContext
    fileprivate let presentationData: ItemListPresentationData
    fileprivate let revealed: Bool
    fileprivate let inverted: Bool
    fileprivate let peer: Peer
    private let peerSelected: (EnginePeer) -> Void
    fileprivate let setPeerIdRevealed: (EnginePeer.Id?) -> Void
    fileprivate let removeRequested: (EnginePeer.Id) -> Void
    
    let selectable: Bool = true
    
    public init(context: AccountContext, presentationData: ItemListPresentationData, inverted: Bool, peer: Peer, revealed: Bool, setPeerIdRevealed: @escaping (PeerId?) -> Void, peerSelected: @escaping (EnginePeer) -> Void, removeRequested: @escaping (PeerId) -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.inverted = inverted
        self.peer = peer
        self.revealed = revealed
        self.setPeerIdRevealed = setPeerIdRevealed
        self.peerSelected = peerSelected
        self.removeRequested = removeRequested
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        let configure = { () -> Void in
            let node = MentionChatInputPanelItemNode()
            
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
            if let nodeValue = node() as? MentionChatInputPanelItemNode {
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
            self.setPeerIdRevealed(nil)
        } else {
            self.peerSelected(EnginePeer(self.peer))
        }
    }
}

private let avatarFont = avatarPlaceholderFont(size: 16.0)

final class MentionChatInputPanelItemNode: ListViewItemNode {
    static let itemHeight: CGFloat = 42.0
        
    private let avatarNode: AvatarNode
    private let textNode: TextNode
    private let topSeparatorNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private var revealNode: ItemListRevealOptionsNode?
    private var revealOptions: [ItemListRevealOption] = []
    private var initialRevealOffset: CGFloat = 0.0
    public private(set) var revealOffset: CGFloat = 0.0
    private var recognizer: ItemListRevealOptionsGestureRecognizer?
    private var hapticFeedback: HapticFeedback?
    
    private var item: MentionChatInputPanelItem?
    
    private var validLayout: (CGSize, CGFloat, CGFloat)?
    
    init() {
        self.avatarNode = AvatarNode(font: avatarFont)
        self.textNode = TextNode()
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.separatorNode)
        
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.textNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = ItemListRevealOptionsGestureRecognizer(target: self, action: #selector(self.revealGesture(_:)))
        self.recognizer = recognizer
        recognizer.allowAnyDirection = false
        self.view.addGestureRecognizer(recognizer)
    }
    
    override public func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? MentionChatInputPanelItem {
            let doLayout = self.asyncLayout()
            let merged = (top: previousItem != nil, bottom: nextItem != nil)
            let (layout, apply) = doLayout(item, params, merged.top, merged.bottom)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply(.None)
        }
    }
    
    func asyncLayout() -> (_ item: MentionChatInputPanelItem, _ params: ListViewItemLayoutParams, _ mergedTop: Bool, _ mergedBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        
        let previousItem = self.item
        
        return { [weak self] item, params, mergedTop, mergedBottom in
            let primaryFont = Font.medium(floor(item.presentationData.fontSize.baseDisplaySize * 14.0 / 17.0))
            let secondaryFont = Font.regular(floor(item.presentationData.fontSize.baseDisplaySize * 14.0 / 17.0))
            
            let leftInset: CGFloat = 55.0 + params.leftInset
            let rightInset: CGFloat = 10.0 + params.rightInset
            
            var updatedInverted: Bool?
            if previousItem?.inverted != item.inverted {
                updatedInverted = item.inverted
            }
            
            let string = NSMutableAttributedString()
            string.append(NSAttributedString(string: item.peer.debugDisplayTitle, font: primaryFont, textColor: item.presentationData.theme.list.itemPrimaryTextColor))
            if let addressName = item.peer.addressName, !addressName.isEmpty {
                string.append(NSAttributedString(string: " @\(addressName)", font: secondaryFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor))
            }
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: string, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - rightInset, height: 100.0), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: HashtagChatInputPanelItemNode.itemHeight), insets: UIEdgeInsets())
            
            return (nodeLayout, { animation in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.validLayout = (nodeLayout.contentSize, params.leftInset, params.rightInset)
                    
                    if let updatedInverted = updatedInverted {
                        if updatedInverted {
                            strongSelf.transform = CATransform3DMakeRotation(CGFloat(Double.pi), 0.0, 0.0, 1.0)
                        } else {
                            strongSelf.transform = CATransform3DIdentity
                        }
                    }
                    
                    strongSelf.separatorNode.backgroundColor = item.presentationData.theme.list.itemPlainSeparatorColor
                    strongSelf.topSeparatorNode.backgroundColor = item.presentationData.theme.list.itemPlainSeparatorColor
                    strongSelf.backgroundColor = item.presentationData.theme.list.plainBackgroundColor
                    strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                    
                    strongSelf.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: EnginePeer(item.peer), emptyColor: item.presentationData.theme.list.mediaPlaceholderColor)
                    
                    let _ = textApply()
                    
                    strongSelf.avatarNode.frame = CGRect(origin: CGPoint(x: params.leftInset + 12.0, y: floor((nodeLayout.contentSize.height - 30.0) / 2.0)), size: CGSize(width: 30.0, height: 30.0))
                    strongSelf.textNode.frame = CGRect(origin: CGPoint(x: leftInset, y: floor((nodeLayout.contentSize.height - textLayout.size.height) / 2.0)), size: textLayout.size)
                    
                    strongSelf.topSeparatorNode.isHidden = mergedTop
                    strongSelf.separatorNode.isHidden = !mergedBottom
                    
                    strongSelf.topSeparatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: item.inverted ? (nodeLayout.contentSize.height - UIScreenPixel) : 0.0), size: CGSize(width: params.width, height: UIScreenPixel))
                    strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: leftInset, y: !item.inverted ? (nodeLayout.contentSize.height - UIScreenPixel) : 0.0), size: CGSize(width: params.width - leftInset, height: UIScreenPixel))
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.width, height: nodeLayout.size.height + UIScreenPixel))
                    
                    if let peer = item.peer as? TelegramUser, let _ = peer.botInfo {
                        strongSelf.setRevealOptions([ItemListRevealOption(key: 0, title: item.presentationData.strings.Common_Delete, icon: .none, color: item.presentationData.theme.list.itemDisclosureActions.destructive.fillColor, textColor: item.presentationData.theme.list.itemDisclosureActions.destructive.foregroundColor)])
                        strongSelf.setRevealOptionsOpened(item.revealed, animated: animation.isAnimated)
                    } else {
                        strongSelf.setRevealOptions([])
                        strongSelf.setRevealOptionsOpened(false, animated: animation.isAnimated)
                    }
                }
            })
        }
    }
    
    func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        if let (_, leftInset, _) = self.validLayout {
            transition.updateFrameAdditive(node: self.avatarNode, frame: CGRect(origin: CGPoint(x: min(offset, 0.0) + 12.0 + leftInset, y: self.avatarNode.frame.minY), size: self.avatarNode.frame.size))
            transition.updateFrameAdditive(node: self.textNode, frame: CGRect(origin: CGPoint(x: min(offset, 0.0) + 55.0 + leftInset, y: self.textNode.frame.minY), size: self.textNode.frame.size))
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
        item.removeRequested(item.peer.id)
    }
    
    private func setupAndAddRevealNode() {
        if !self.revealOptions.isEmpty {
            let revealNode = ItemListRevealOptionsNode(optionSelected: { [weak self] option in
                self?.revealOptionSelected(option, animated: false)
            }, tapticAction: { [weak self] in
                self?.hapticImpact()
            })
            revealNode.setOptions(self.revealOptions, isLeft: false)
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
            item.setPeerIdRevealed(item.peer.id)
        }
    }
    
    func revealOptionsInteractivelyClosed() {
        if let item = self.item {
            item.setPeerIdRevealed(nil)
        }
    }
    
    private func hapticImpact() {
        if self.hapticFeedback == nil {
            self.hapticFeedback = HapticFeedback()
        }
        self.hapticFeedback?.impact(.medium)
    }
}
