import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

private let defaultBackgroundColor: UIColor = UIColor(white: 1.0, alpha: 1.0)
private let highlightedBackgroundColor: UIColor = UIColor(white: 0.9, alpha: 1.0)
private let separatorColor: UIColor = UIColor(0xbcbbc1)

final class StickerPackPreviewControllerNode: ASDisplayNode, UIScrollViewDelegate {
    private let account: Account
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private let dimNode: ASDisplayNode
    
    private let wrappingScrollNode: ASScrollNode
    private let cancelButtonNode: HighlightTrackingButtonNode
    
    private let contentContainerNode: ASDisplayNode
    private let contentBackgroundNode: ASDisplayNode
    private let contentGridNode: GridNode
    private let installActionButtonNode: HighlightTrackingButtonNode
    private let installActionSeparatorNode: ASDisplayNode
    private let contentTitleNode: ASTextNode
    private let contentSeparatorNode: ASDisplayNode
    
    private var activityIndicatorView: UIActivityIndicatorView?
    
    var dismiss: (() -> Void)?
    var cancel: (() -> Void)?
    
    let ready = Promise<Bool>()
    private var didSetReady = false
    
    private var stickerPack: LoadedStickerPack?
    private var stickerPackUpdated = false
    
    private var didSetItems = false
    
    init(account: Account) {
        self.account = account
        
        self.wrappingScrollNode = ASScrollNode()
        self.wrappingScrollNode.view.alwaysBounceVertical = true
        self.wrappingScrollNode.view.delaysContentTouches = false
        self.wrappingScrollNode.view.canCancelContentTouches = true
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        
        self.cancelButtonNode = HighlightTrackingButtonNode()
        self.cancelButtonNode.cornerRadius = 16.0
        self.cancelButtonNode.clipsToBounds = true
        
        self.contentContainerNode = ASDisplayNode()
        self.contentContainerNode.cornerRadius = 16.0
        self.contentContainerNode.clipsToBounds = true
        self.contentContainerNode.isOpaque = false
        
        self.contentBackgroundNode = ASDisplayNode()
        self.contentBackgroundNode.cornerRadius = 16.0
        self.contentBackgroundNode.clipsToBounds = true
        self.contentBackgroundNode.backgroundColor = defaultBackgroundColor
        
        self.contentGridNode = GridNode()
        
        self.installActionButtonNode = HighlightTrackingButtonNode()
            
        self.contentTitleNode = ASTextNode()
        
        self.contentSeparatorNode = ASDisplayNode()
        self.contentSeparatorNode.isLayerBacked = true
        self.contentSeparatorNode.displaysAsynchronously = false
        self.contentSeparatorNode.backgroundColor = separatorColor
        
        self.installActionSeparatorNode = ASDisplayNode()
        self.installActionSeparatorNode.isLayerBacked = true
        self.installActionSeparatorNode.displaysAsynchronously = false
        self.installActionSeparatorNode.backgroundColor = separatorColor
        
        super.init(viewBlock: {
            return UITracingLayerView()
        }, didLoad: nil)
        
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        self.addSubnode(self.dimNode)
        
        self.wrappingScrollNode.view.delegate = self
        self.addSubnode(self.wrappingScrollNode)
        
        self.cancelButtonNode.setTitle("Cancel", with: Font.medium(20.0), with: UIColor(0x007ee5), for: .normal)
        self.cancelButtonNode.backgroundColor = defaultBackgroundColor
        self.cancelButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.cancelButtonNode.backgroundColor = highlightedBackgroundColor
                } else {
                    UIView.animate(withDuration: 0.3, animations: {
                        strongSelf.cancelButtonNode.backgroundColor = defaultBackgroundColor
                    })
                }
            }
        }
        
        self.installActionButtonNode.backgroundColor = defaultBackgroundColor
        self.installActionButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.installActionButtonNode.backgroundColor = highlightedBackgroundColor
                } else {
                    UIView.animate(withDuration: 0.3, animations: {
                        strongSelf.installActionButtonNode.backgroundColor = defaultBackgroundColor
                    })
                }
            }
        }
        
        self.wrappingScrollNode.addSubnode(self.cancelButtonNode)
        self.cancelButtonNode.addTarget(self, action: #selector(self.cancelButtonPressed), forControlEvents: .touchUpInside)
        
        self.installActionButtonNode.addTarget(self, action: #selector(self.installActionButtonPressed), forControlEvents: .touchUpInside)
        
        self.wrappingScrollNode.addSubnode(self.contentBackgroundNode)
        
        self.wrappingScrollNode.addSubnode(self.contentContainerNode)
        self.contentContainerNode.addSubnode(self.contentGridNode)
        self.contentContainerNode.addSubnode(self.installActionSeparatorNode)
        self.contentContainerNode.addSubnode(self.installActionButtonNode)
        self.wrappingScrollNode.addSubnode(self.contentTitleNode)
        self.wrappingScrollNode.addSubnode(self.contentSeparatorNode)
        
        self.contentGridNode.presentationLayoutUpdated = { [weak self] presentationLayout, transition in
            self?.gridPresentationLayoutUpdated(presentationLayout, transition: transition)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        transition.updateFrame(node: self.wrappingScrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        var insets = layout.insets(options: [.statusBar])
        insets.top = max(10.0, insets.top)
        
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let bottomInset: CGFloat = 10.0
        let buttonHeight: CGFloat = 57.0
        let sectionSpacing: CGFloat = 8.0
        let titleAreaHeight: CGFloat = 51.0
        
        let width = min(layout.size.width, layout.size.height) - 20.0
        
        let sideInset = floor((layout.size.width - width) / 2.0)
        
        transition.updateFrame(node: self.cancelButtonNode, frame: CGRect(origin: CGPoint(x: sideInset, y: layout.size.height - bottomInset - buttonHeight), size: CGSize(width: width, height: buttonHeight)))
        
        let maximumContentHeight = layout.size.height - insets.top - bottomInset - buttonHeight - sectionSpacing
        
        let contentContainerFrame = CGRect(origin: CGPoint(x: sideInset, y: insets.top), size: CGSize(width: width, height: maximumContentHeight))
        let contentFrame = contentContainerFrame.insetBy(dx: 12.0, dy: 0.0)
        
        var insertItems: [GridNodeInsertItem] = []
        
        var itemCount = 0
        var animateIn = false
        
        if let stickerPack = self.stickerPack {
            switch stickerPack {
                case .fetching, .none:
                    if self.activityIndicatorView == nil {
                        let activityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: .gray)
                        self.activityIndicatorView = activityIndicatorView
                        self.view.addSubview(activityIndicatorView)
                        activityIndicatorView.startAnimating()
                    }
                case let .result(info, items, _):
                    if let activityIndicatorView = self.activityIndicatorView {
                        activityIndicatorView.removeFromSuperview()
                        activityIndicatorView.stopAnimating()
                    }
                    itemCount = items.count
                    if !self.didSetItems {
                        self.contentTitleNode.attributedText = NSAttributedString(string: info.title, font: Font.medium(20.0), textColor: .black)
                        
                        self.didSetItems = true
                        animateIn = true
                        for i in 0 ..< items.count {
                            insertItems.append(GridNodeInsertItem(index: i, item: StickerPackPreviewGridItem(account: self.account, stickerItem: items[i] as! StickerPackItem), previousIndex: nil))
                        }
                    }
            }
        }
        
        //self.contentGridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: insertItems, updateItems: [], scrollToItem: nil, updateLayout: nil, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        
        let titleSize = self.contentTitleNode.measure(contentContainerFrame.size)
        let titleFrame = CGRect(origin: CGPoint(x: contentContainerFrame.minX + floor((contentContainerFrame.size.width - titleSize.width) / 2.0), y: self.contentBackgroundNode.frame.minY + 15.0), size: titleSize)
        let deltaTitlePosition = CGPoint(x: titleFrame.midX - self.contentTitleNode.frame.midX, y: titleFrame.midY - self.contentTitleNode.frame.midY)
        self.contentTitleNode.frame = titleFrame
        transition.animatePosition(node: self.contentTitleNode, from: CGPoint(x: titleFrame.midX + deltaTitlePosition.x, y: titleFrame.midY + deltaTitlePosition.y))
        
        transition.updateFrame(node: self.contentTitleNode, frame: titleFrame)
        transition.updateFrame(node: self.contentSeparatorNode, frame: CGRect(origin: CGPoint(x: contentContainerFrame.minX, y: self.contentBackgroundNode.frame.minY + titleAreaHeight), size: CGSize(width: contentContainerFrame.size.width, height: UIScreenPixel)))
        
        let itemsPerRow = 4
        let itemWidth = floor(contentFrame.size.width / CGFloat(itemsPerRow))
        let rowCount = itemCount / itemsPerRow + (itemCount % itemsPerRow != 0 ? 1 : 0)
        
        let minimallyRevealedRowCount: CGFloat = 3.5
        let initiallyRevealedRowCount = min(minimallyRevealedRowCount, CGFloat(rowCount))
        
        let topInset = max(0.0, contentFrame.size.height - initiallyRevealedRowCount * itemWidth - titleAreaHeight)
        let bottomGridInset = buttonHeight
        
        transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)
        
        if let activityIndicatorView = activityIndicatorView {
            transition.updateFrame(layer: activityIndicatorView.layer, frame: CGRect(origin: CGPoint(x: contentFrame.minX + floor((contentFrame.width - activityIndicatorView.bounds.size.width) / 2.0), y: contentFrame.maxY - activityIndicatorView.bounds.size.height - 34.0), size: activityIndicatorView.bounds.size))
        }
        
        transition.updateFrame(node: self.installActionButtonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentContainerFrame.size.height - buttonHeight), size: CGSize(width: contentContainerFrame.size.width, height: buttonHeight)))
        transition.updateFrame(node: self.installActionSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentContainerFrame.size.height - buttonHeight - UIScreenPixel), size: CGSize(width: contentContainerFrame.size.width, height: UIScreenPixel)))
        
        self.contentGridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: insertItems, updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: contentFrame.size, insets: UIEdgeInsets(top: topInset, left: 0.0, bottom: bottomGridInset, right: 0.0), preloadSize: 80.0, itemSize: CGSize(width: itemWidth, height: itemWidth)), transition: transition), stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        transition.updateFrame(node: self.contentGridNode, frame: CGRect(origin: CGPoint(x: floor((contentContainerFrame.size.width - contentFrame.size.width) / 2.0), y: titleAreaHeight), size: CGSize(width: contentFrame.size.width, height: max(32.0, contentFrame.size.height - titleAreaHeight))))
        
        if animateIn {
            var durationOffset = 0.0
            self.contentGridNode.forEachRow { itemNodes in
                for itemNode in itemNodes {
                    itemNode.layer.animatePosition(from: CGPoint(x: 0.0, y: 4.0), to: CGPoint(), duration: 0.4 + durationOffset, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                    if let itemNode = itemNode as? StickerPackPreviewGridItemNode {
                        itemNode.animateIn()
                    }
                }
                durationOffset += 0.04
            }
        
            self.contentGridNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.installActionButtonNode.titleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.installActionSeparatorNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            let gridPosition = self.contentGridNode.layer.position
            self.contentGridNode.layer.animatePosition(from: CGPoint(x: gridPosition.x, y: gridPosition.y + topInset - buttonHeight), to: gridPosition, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
        }
        
        if let _ = self.stickerPack, self.stickerPackUpdated {
            self.dequeueUpdateStickerPack()
        }
    }
    
    private func gridPresentationLayoutUpdated(_ presentationLayout: GridNodeCurrentPresentationLayout, transition: ContainedViewLayoutTransition) {
        if let (layout, _) = self.containerLayout {
            var insets = layout.insets(options: [.statusBar])
            insets.top = max(10.0, insets.top)
            
            let bottomInset: CGFloat = 10.0
            let buttonHeight: CGFloat = 57.0
            let sectionSpacing: CGFloat = 8.0
            let titleAreaHeight: CGFloat = 51.0
            
            let width = min(layout.size.width, layout.size.height) - 20.0
            
            let sideInset = floor((layout.size.width - width) / 2.0)
            
            let maximumContentHeight = layout.size.height - insets.top - bottomInset - buttonHeight - sectionSpacing
            let contentFrame = CGRect(origin: CGPoint(x: sideInset, y: insets.top), size: CGSize(width: width, height: maximumContentHeight))
             
            var backgroundFrame = CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY - presentationLayout.contentOffset.y), size: contentFrame.size)
            if backgroundFrame.minY < contentFrame.minY {
                backgroundFrame.origin.y = contentFrame.minY
            }
            if backgroundFrame.maxY > contentFrame.maxY {
                backgroundFrame.size.height += contentFrame.maxY - backgroundFrame.maxY
            }
            if backgroundFrame.size.height < buttonHeight + 32.0 {
                backgroundFrame.origin.y -= buttonHeight + 32.0 - backgroundFrame.size.height
                backgroundFrame.size.height = buttonHeight + 32.0
            }
            var compactFrame = true
            if let stickerPack = self.stickerPack, case .result = stickerPack {
                compactFrame = false
            }
            if compactFrame {
                backgroundFrame = CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.maxY - buttonHeight - 32.0), size: CGSize(width: contentFrame.size.width, height: buttonHeight + 32.0))
            }
            transition.updateFrame(node: self.contentBackgroundNode, frame: backgroundFrame)
            
            let titleSize = self.contentTitleNode.bounds.size
            let titleFrame = CGRect(origin: CGPoint(x: contentFrame.minX + floor((contentFrame.size.width - titleSize.width) / 2.0), y: backgroundFrame.minY + 15.0), size: titleSize)
            transition.updateFrame(node: self.contentTitleNode, frame: titleFrame)
            
            transition.updateFrame(node: self.contentSeparatorNode, frame: CGRect(origin: CGPoint(x: contentFrame.minX, y: backgroundFrame.minY + titleAreaHeight), size: CGSize(width: contentFrame.size.width, height: UIScreenPixel)))
            
            if !compactFrame && CGFloat(0.0).isLessThanOrEqualTo(presentationLayout.contentOffset.y) {
                self.contentSeparatorNode.alpha = 1.0
            } else {
                self.contentSeparatorNode.alpha = 0.0
            }
        }
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancelButtonPressed()
        }
    }
    
    @objc func cancelButtonPressed() {
        self.cancel?()
    }
    
    @objc func installActionButtonPressed() {
        if let stickerPack = self.stickerPack {
            switch stickerPack {
                case let .result(info, items, installed):
                    if installed {
                        let _ = removeStickerPackInteractively(postbox: self.account.postbox, id: info.id).start()
                    } else {
                        let _ = addStickerPackInteractively(postbox: self.account.postbox, info: info, items: items).start()
                        self.cancelButtonPressed()
                }
                default:
                    break
            }
        }
    }
    
    func animateIn() {
        self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
        
        let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
        
        let dimPosition = self.dimNode.layer.position
        self.dimNode.layer.animatePosition(from: CGPoint(x: dimPosition.x, y: dimPosition.y - offset), to: dimPosition, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.layer.animateBoundsOriginYAdditive(from: -offset, to: 0.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut() {
        var dimCompleted = false
        var offsetCompleted = false
        
        let completion: () -> Void = { [weak self] in
            if let strongSelf = self, dimCompleted && offsetCompleted {
                strongSelf.dismiss?()
            }
        }
        
        self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
            dimCompleted = true
            completion()
        })
        
        let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
        let dimPosition = self.dimNode.layer.position
        self.dimNode.layer.animatePosition(from: dimPosition, to: CGPoint(x: dimPosition.x, y: dimPosition.y - offset), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        self.layer.animateBoundsOriginYAdditive(from: 0.0, to: -offset, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            offsetCompleted = true
            completion()
        })
    }
    
    func updateStickerPack(_ stickerPack: LoadedStickerPack) {
        self.stickerPack = stickerPack
        self.stickerPackUpdated = true
        if let _ = self.containerLayout {
            self.dequeueUpdateStickerPack()
        }
        switch stickerPack {
            case .none, .fetching:
                self.installActionSeparatorNode.alpha = 0.0
                self.installActionButtonNode.setTitle("", with: Font.medium(20.0), with: UIColor(0x007ee5), for: .normal)
            case let .result(info, _, installed):
                self.installActionSeparatorNode.alpha = 1.0
                if installed {
                    let text: String
                    if info.id.namespace == Namespaces.ItemCollection.CloudStickerPacks {
                        text = "Remove \(info.count) stickers"
                    } else {
                        text = "Remove \(info.count) masks"
                    }
                    self.installActionButtonNode.setTitle(text, with: Font.regular(20.0), with: UIColor(0xff3b30), for: .normal)
                } else {
                    let text: String
                    if info.id.namespace == Namespaces.ItemCollection.CloudStickerPacks {
                        text = "Add \(info.count) stickers"
                    } else {
                        text = "Add \(info.count) masks"
                    }
                    self.installActionButtonNode.setTitle(text, with: Font.regular(20.0), with: UIColor(0x007ee5), for: .normal)
                }
        }
    }
    
    func dequeueUpdateStickerPack() {
        if let (layout, navigationBarHeight) = self.containerLayout, let _ = stickerPack, self.stickerPackUpdated {
            self.stickerPackUpdated = false
            
            let transition: ContainedViewLayoutTransition
            if self.didSetReady {
                transition = .animated(duration: 0.4, curve: .spring)
            } else {
                transition = .immediate
            }
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
            
            if !self.didSetReady {
                self.didSetReady = true
                self.ready.set(.single(true))
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.installActionButtonNode.hitTest(self.installActionButtonNode.convert(point, from: self), with: event) {
            return result
        }
        return super.hitTest(point, with: event)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        let contentOffset = scrollView.contentOffset
        let additionalTopHeight = max(0.0, -contentOffset.y)
        
        if additionalTopHeight >= 30.0 {
            self.cancelButtonPressed()
        }
    }
}
