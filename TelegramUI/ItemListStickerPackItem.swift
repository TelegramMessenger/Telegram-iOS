import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

struct ItemListStickerPackItemEditing: Equatable {
    let editable: Bool
    let editing: Bool
    let revealed: Bool
    
    static func ==(lhs: ItemListStickerPackItemEditing, rhs: ItemListStickerPackItemEditing) -> Bool {
        if lhs.editable != rhs.editable {
            return false
        }
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.revealed != rhs.revealed {
            return false
        }
        return true
    }
}

enum ItemListStickerPackItemControl: Equatable {
    case none
    case installation(installed: Bool)
    
    static func ==(lhs: ItemListStickerPackItemControl, rhs: ItemListStickerPackItemControl) -> Bool {
        switch lhs {
            case .none:
                if case .none = rhs {
                    return true
                } else {
                    return false
                }
            case let .installation(installed):
                if case .installation(installed) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

final class ItemListStickerPackItem: ListViewItem, ItemListItem {
    let account: Account
    let packInfo: StickerPackCollectionInfo
    let itemCount: Int32
    let topItem: StickerPackItem?
    let unread: Bool
    let control: ItemListStickerPackItemControl
    let editing: ItemListStickerPackItemEditing
    let enabled: Bool
    let sectionId: ItemListSectionId
    let action: (() -> Void)?
    let setPackIdWithRevealedOptions: (ItemCollectionId?, ItemCollectionId?) -> Void
    let addPack: () -> Void
    let removePack: () -> Void
    
    init(account: Account, packInfo: StickerPackCollectionInfo, itemCount: Int32, topItem: StickerPackItem?, unread: Bool, control: ItemListStickerPackItemControl, editing: ItemListStickerPackItemEditing, enabled: Bool, sectionId: ItemListSectionId, action: (() -> Void)?, setPackIdWithRevealedOptions: @escaping (ItemCollectionId?, ItemCollectionId?) -> Void, addPack: @escaping () -> Void, removePack: @escaping () -> Void) {
        self.account = account
        self.packInfo = packInfo
        self.itemCount = itemCount
        self.topItem = topItem
        self.unread = unread
        self.control = control
        self.editing = editing
        self.enabled = enabled
        self.sectionId = sectionId
        self.action = action
        self.setPackIdWithRevealedOptions = setPackIdWithRevealedOptions
        self.addPack = addPack
        self.removePack = removePack
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, () -> Void)) -> Void) {
        async {
            let node = ItemListStickerPackItemNode()
            let (layout, apply) = node.asyncLayout()(self, width, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            completion(node, {
                return (nil, { apply(false) })
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? ItemListStickerPackItemNode {
            Queue.mainQueue().async {
                let makeLayout = node.asyncLayout()
                
                var animated = true
                if case .None = animation {
                    animated = false
                }
                
                async {
                    let (layout, apply) = makeLayout(self, width, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                    Queue.mainQueue().async {
                        completion(layout, {
                            apply(animated)
                        })
                    }
                }
            }
        }
    }
    
    var selectable: Bool = true
    
    func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        self.action?()
    }
}

private let titleFont = Font.bold(15.0)
private let statusFont = Font.regular(14.0)

private func stringForStickerCount(_ count: Int32) -> String {
    if count == 1 {
        return "1 sticker"
    } else {
        return "\(count) stickers"
    }
}

private let plusIcon = generateImage(CGSize(width: 18.0, height: 18.0), rotatedContext: { size, context in
    context.clear(CGRect(origin: CGPoint(), size: size))
    context.setFillColor(UIColor(0x007ee5).cgColor)
    let lineWidth = min(1.5, UIScreenPixel * 4.0)
    context.fill(CGRect(x: floorToScreenPixels((18.0 - lineWidth) / 2.0), y: 0.0, width: lineWidth, height: 18.0))
    context.fill(CGRect(x: 0.0, y: floorToScreenPixels((18.0 - lineWidth) / 2.0), width: 18.0, height: lineWidth))
})

private let checkIcon = generateImage(CGSize(width: 14.0, height: 11.0), rotatedContext: { size, context in
    context.clear(CGRect(origin: CGPoint(), size: size))
    context.setStrokeColor(UIColor(0x8d8c9d).cgColor)
    context.setLineWidth(2.0)
    context.move(to: CGPoint(x: 12.0, y: 1.0))
    context.addLine(to: CGPoint(x: 4.16482734, y: 9.0))
    context.addLine(to: CGPoint(x: 1.0, y: 5.81145833))
    context.strokePath()
})

private let unreadIcon = generateFilledCircleImage(diameter: 6.0, color: UIColor(0x007ee5))

class ItemListStickerPackItemNode: ItemListRevealOptionsItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private var disabledOverlayNode: ASDisplayNode?
    
    fileprivate let imageNode: TransformImageNode
    private let unreadNode: ASImageNode
    private let titleNode: TextNode
    private let statusNode: TextNode
    private let installationActionImageNode: ASImageNode
    private let installationActionNode: HighlightableButtonNode
    
    private var layoutParams: (ItemListStickerPackItem, CGFloat, ItemListNeighbors)?
    
    private var editableControlNode: ItemListEditableControlNode?
    
    private let fetchDisposable = MetaDisposable()
    
    override var canBeSelected: Bool {
        if self.editableControlNode != nil || self.disabledOverlayNode != nil {
            return false
        }
        if let item = self.layoutParams?.0, item.action != nil {
            return super.canBeSelected
        } else {
            return false
        }
    }
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.backgroundColor = UIColor(0xc8c7cc)
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.backgroundColor = UIColor(0xc8c7cc)
        self.bottomStripeNode.isLayerBacked = true
        
        self.imageNode = TransformImageNode()
        self.imageNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        self.titleNode.isLayerBacked = true
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.statusNode = TextNode()
        self.statusNode.isLayerBacked = true
        self.statusNode.contentMode = .left
        self.statusNode.contentsScale = UIScreen.main.scale
        
        self.unreadNode = ASImageNode()
        self.unreadNode.isLayerBacked = true
        self.unreadNode.displaysAsynchronously = false
        self.unreadNode.displayWithoutProcessing = true
        
        self.installationActionImageNode = ASImageNode()
        self.installationActionImageNode.displaysAsynchronously = false
        self.installationActionImageNode.displayWithoutProcessing = true
        self.installationActionImageNode.isLayerBacked = true
        self.installationActionNode = HighlightableButtonNode()
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.backgroundColor = UIColor(0xd9d9d9)
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false)
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.statusNode)
        self.addSubnode(self.unreadNode)
        self.addSubnode(self.installationActionImageNode)
        self.addSubnode(self.installationActionNode)
        
        self.installationActionNode.addTarget(self, action: #selector(self.installationActionPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.fetchDisposable.dispose()
    }
    
    func asyncLayout() -> (_ item: ItemListStickerPackItem, _ width: CGFloat, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeImageLayout = self.imageNode.asyncLayout()
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeStatusLayout = TextNode.asyncLayout(self.statusNode)
        let editableControlLayout = ItemListEditableControlNode.asyncLayout(self.editableControlNode)
        let previousFile = self.layoutParams?.0.topItem?.file
        
        var currentDisabledOverlayNode = self.disabledOverlayNode
        
        return { item, width, neighbors in
            var titleAttributedString: NSAttributedString?
            var statusAttributedString: NSAttributedString?
            
            let packRevealOptions: [ItemListRevealOption]
            if item.editing.editable && item.enabled {
                packRevealOptions = [ItemListRevealOption(key: 0, title: "Remove", icon: nil, color: UIColor(0xff3824))]
            } else {
                packRevealOptions = []
            }
            
            var rightInset: CGFloat = 0.0
            
            var installationActionImage: UIImage?
            switch item.control {
                case .none:
                    break
                case let .installation(installed):
                    rightInset += 50.0
                    if installed {
                        installationActionImage = checkIcon
                    } else {
                        installationActionImage = plusIcon
                    }
            }
            
            var unreadImage: UIImage?
            if item.unread {
                unreadImage = unreadIcon
            }
            
            titleAttributedString = NSAttributedString(string: item.packInfo.title, font: titleFont, textColor: UIColor.black)
            statusAttributedString = NSAttributedString(string: stringForStickerCount(item.itemCount), font: statusFont, textColor: UIColor(0x808080))
            
            let leftInset: CGFloat = 65.0
            
            var editableControlSizeAndApply: (CGSize, () -> ItemListEditableControlNode)?
            
            let editingOffset: CGFloat
            if item.editing.editing {
                let sizeAndApply = editableControlLayout(59.0)
                editableControlSizeAndApply = sizeAndApply
                editingOffset = sizeAndApply.0.width
            } else {
                editingOffset = 0.0
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(titleAttributedString, nil, 1, .end, CGSize(width: width - leftInset - 8.0 - editingOffset - rightInset - 10.0, height: CGFloat.greatestFiniteMagnitude), nil)
            let (statusLayout, statusApply) = makeStatusLayout(statusAttributedString, nil, 1, .end, CGSize(width: width - leftInset - 8.0 - editingOffset - rightInset, height: CGFloat.greatestFiniteMagnitude), nil)
            
            let insets = itemListNeighborsGroupedInsets(neighbors)
            let contentSize = CGSize(width: width, height: 59.0)
            let separatorHeight = UIScreenPixel
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            if !item.enabled {
                if currentDisabledOverlayNode == nil {
                    currentDisabledOverlayNode = ASDisplayNode()
                    currentDisabledOverlayNode?.backgroundColor = UIColor(white: 1.0, alpha: 0.5)
                }
            } else {
                currentDisabledOverlayNode = nil
            }
            
            let file = item.topItem?.file
            var fileUpdated = false
            if let file = file, let previousFile = previousFile {
                fileUpdated = !file.isEqual(previousFile)
            } else if (file != nil) != (previousFile != nil) {
                fileUpdated = true
            }
            
            var imageApply: (() -> Void)?
            if let file = file, let dimensions = file.dimensions {
                let imageBoundingSize = CGSize(width: 34.0, height: 34.0)
                let fileImageSize = dimensions.aspectFitted(imageBoundingSize)
                imageApply = makeImageLayout(TransformImageArguments(corners: ImageCorners(), imageSize: fileImageSize, boundingSize: imageBoundingSize, intrinsicInsets: UIEdgeInsets()))
            }
            
            var updatedImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            var updatedFetchSignal: Signal<Void, NoError>?
            if fileUpdated {
                if let file = file {
                    updatedImageSignal = chatMessageSticker(account: item.account, file: file, small: false)
                    updatedFetchSignal = item.account.postbox.mediaBox.fetchedResource(file.resource)
                } else {
                    updatedImageSignal = .single({ _ in return nil })
                    updatedFetchSignal = .complete()
                }
            }
            
            return (layout, { [weak self] animated in
                if let strongSelf = self {
                    strongSelf.layoutParams = (item, width, neighbors)
                    
                    let revealOffset = strongSelf.revealOffset
                    
                    let transition: ContainedViewLayoutTransition
                    if animated {
                        transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                    } else {
                        transition = .immediate
                    }
                    
                    if let currentDisabledOverlayNode = currentDisabledOverlayNode {
                        if currentDisabledOverlayNode != strongSelf.disabledOverlayNode {
                            strongSelf.disabledOverlayNode = currentDisabledOverlayNode
                            strongSelf.addSubnode(currentDisabledOverlayNode)
                            currentDisabledOverlayNode.alpha = 0.0
                            transition.updateAlpha(node: currentDisabledOverlayNode, alpha: 1.0)
                            currentDisabledOverlayNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height - separatorHeight))
                        } else {
                            transition.updateFrame(node: currentDisabledOverlayNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height - separatorHeight)))
                        }
                    } else if let disabledOverlayNode = strongSelf.disabledOverlayNode {
                        transition.updateAlpha(node: disabledOverlayNode, alpha: 0.0, completion: { [weak disabledOverlayNode] _ in
                            disabledOverlayNode?.removeFromSupernode()
                        })
                        strongSelf.disabledOverlayNode = nil
                    }
                    
                    if let editableControlSizeAndApply = editableControlSizeAndApply {
                        if strongSelf.editableControlNode == nil {
                            let editableControlNode = editableControlSizeAndApply.1()
                            editableControlNode.tapped = {
                                if let strongSelf = self {
                                    strongSelf.setRevealOptionsOpened(true, animated: true)
                                    strongSelf.revealOptionsInteractivelyOpened()
                                }
                            }
                            strongSelf.editableControlNode = editableControlNode
                            strongSelf.insertSubnode(editableControlNode, aboveSubnode: strongSelf.imageNode)
                            let editableControlFrame = CGRect(origin: CGPoint(x: revealOffset, y: 0.0), size: editableControlSizeAndApply.0)
                            editableControlNode.frame = editableControlFrame
                            transition.animatePosition(node: editableControlNode, from: CGPoint(x: editableControlFrame.midX - editableControlFrame.size.width, y: editableControlFrame.midY))
                            editableControlNode.alpha = 0.0
                            transition.updateAlpha(node: editableControlNode, alpha: 1.0)
                        }
                        strongSelf.editableControlNode?.isHidden = !item.editing.editable
                    } else if let editableControlNode = strongSelf.editableControlNode {
                        var editableControlFrame = editableControlNode.frame
                        editableControlFrame.origin.x = -editableControlFrame.size.width
                        strongSelf.editableControlNode = nil
                        transition.updateAlpha(node: editableControlNode, alpha: 0.0)
                        transition.updateFrame(node: editableControlNode, frame: editableControlFrame, completion: { [weak editableControlNode] _ in
                            editableControlNode?.removeFromSupernode()
                        })
                    }
                    
                    imageApply?()
                    
                    let _ = titleApply()
                    let _ = statusApply()
                    
                    let installationActionFrame = CGRect(origin: CGPoint(x: width - 50.0, y: 0.0), size: CGSize(width: 50.0, height: layout.contentSize.height))
                    strongSelf.installationActionNode.frame = installationActionFrame
                    
                    switch item.control {
                        case .none:
                            strongSelf.installationActionNode.isHidden = true
                            strongSelf.installationActionImageNode.isHidden = true
                        case let .installation(installed):
                            strongSelf.installationActionImageNode.isHidden = false
                            strongSelf.installationActionNode.isHidden = false
                            strongSelf.installationActionNode.isUserInteractionEnabled = !installed
                            strongSelf.installationActionNode.setImage(installationActionImage, for: [])
                            if let image = installationActionImage {
                                let imageSize = image.size
                                strongSelf.installationActionImageNode.frame = CGRect(origin: CGPoint(x: installationActionFrame.minX + floor((installationActionFrame.size.width - imageSize.width) / 2.0), y: installationActionFrame.minY + floor((installationActionFrame.size.height - imageSize.height) / 2.0)), size: imageSize)
                            }
                    }
                    
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                    }
                    switch neighbors.top {
                        case .sameSection(false):
                            strongSelf.topStripeNode.isHidden = true
                        default:
                            strongSelf.topStripeNode.isHidden = false
                    }
                    let bottomStripeInset: CGFloat
                    let bottomStripeOffset: CGFloat
                    switch neighbors.bottom {
                        case .sameSection(false):
                            bottomStripeInset = leftInset + editingOffset
                            bottomStripeOffset = -separatorHeight
                        default:
                            bottomStripeInset = 0.0
                            bottomStripeOffset = 0.0
                    }
                    strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                    transition.updateFrame(node: strongSelf.topStripeNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight)))
                    transition.updateFrame(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: layoutSize.width - bottomStripeInset, height: separatorHeight)))
                    
                    if let unreadImage = unreadImage {
                        strongSelf.unreadNode.image = unreadImage
                        strongSelf.unreadNode.isHidden = false
                        strongSelf.unreadNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 16.0), size: unreadImage.size)
                    } else {
                        strongSelf.unreadNode.isHidden = true
                    }
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: (strongSelf.unreadNode.isHidden ? 0.0 : 10.0) + leftInset + revealOffset + editingOffset, y: 11.0), size: titleLayout.size))
                    transition.updateFrame(node: strongSelf.statusNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: 32.0), size: statusLayout.size))
                    
                    transition.updateFrame(node: strongSelf.imageNode, frame: CGRect(origin: CGPoint(x: revealOffset + editingOffset + 15.0, y: 12.0), size: CGSize(width: 34.0, height: 34.0)))
                    
                    if let updatedImageSignal = updatedImageSignal {
                        strongSelf.imageNode.setSignal(account: item.account, signal: updatedImageSignal)
                    }
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: width, height: 59.0 + UIScreenPixel + UIScreenPixel))
                    
                    strongSelf.setRevealOptions(packRevealOptions)
                    strongSelf.setRevealOptionsOpened(item.editing.revealed, animated: animated)
                    
                    if let updatedFetchSignal = updatedFetchSignal {
                        strongSelf.fetchDisposable.set(updatedFetchSignal.start())
                    }
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                var anchorNode: ASDisplayNode?
                if self.bottomStripeNode.supernode != nil {
                    anchorNode = self.bottomStripeNode
                } else if self.topStripeNode.supernode != nil {
                    anchorNode = self.topStripeNode
                } else if self.backgroundNode.supernode != nil {
                    anchorNode = self.backgroundNode
                }
                if let anchorNode = anchorNode {
                    self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: anchorNode)
                } else {
                    self.addSubnode(self.highlightedBackgroundNode)
                }
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
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        let leftInset: CGFloat = 65.0
        let width = self.bounds.size.width
        
        let editingOffset: CGFloat
        if let editableControlNode = self.editableControlNode {
            editingOffset = editableControlNode.bounds.size.width
            var editableControlFrame = editableControlNode.frame
            editableControlFrame.origin.x = offset
            transition.updateFrame(node: editableControlNode, frame: editableControlFrame)
        } else {
            editingOffset = 0.0
        }
        
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: self.titleNode.frame.minY), size: self.titleNode.bounds.size))
        transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset + editingOffset, y: self.statusNode.frame.minY), size: self.statusNode.bounds.size))
        
        transition.updateFrame(node: self.imageNode, frame: CGRect(origin: CGPoint(x: revealOffset + editingOffset + 15.0, y: self.imageNode.frame.minY), size: CGSize(width: 34.0, height: 34.0)))
    }
    
    override func revealOptionsInteractivelyOpened() {
        if let (item, _, _) = self.layoutParams {
            item.setPackIdWithRevealedOptions(item.packInfo.id, nil)
        }
    }
    
    override func revealOptionsInteractivelyClosed() {
        if let (item, _, _) = self.layoutParams {
            item.setPackIdWithRevealedOptions(nil, item.packInfo.id)
        }
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption) {
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
        
        if let (item, _, _) = self.layoutParams {
            item.removePack()
        }
    }
    
    @objc func installationActionPressed() {
        if let (item, _, _) = self.layoutParams {
            item.addPack()
        }
    }
}
