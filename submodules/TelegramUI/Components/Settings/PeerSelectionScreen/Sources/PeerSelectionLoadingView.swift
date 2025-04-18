import Foundation
import UIKit
import Display
import HierarchyTrackingLayer
import TelegramPresentationData
import AccountContext
import ContactsPeerItem
import ItemListUI
import TelegramCore

final class ShimmerEffectView: UIView {
    private var currentBackgroundColor: UIColor?
    private var currentForegroundColor: UIColor?
    private let imageViewContainer: UIView
    private let imageView: UIImageView
    private let hierarchyTrackingLayer: HierarchyTrackingLayer
    
    private var absoluteLocation: (CGRect, CGSize)?
    private var isCurrentlyInHierarchy = false
    private var shouldBeAnimating = false
    
    override init(frame: CGRect) {
        self.hierarchyTrackingLayer = HierarchyTrackingLayer()
        
        self.imageViewContainer = UIView()
        
        self.imageView = UIImageView()
        self.imageView.contentMode = .scaleToFill
        
        super.init(frame: frame)
        
        self.layer.addSublayer(self.hierarchyTrackingLayer)
        
        self.clipsToBounds = true
        
        self.imageViewContainer.addSubview(self.imageView)
        self.addSubview(self.imageViewContainer)
        
        self.hierarchyTrackingLayer.didEnterHierarchy = { [weak self] in
            self?.didEnterHierarchy()
        }
        self.hierarchyTrackingLayer.didExitHierarchy = { [weak self] in
            self?.didExitHierarchy()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func didEnterHierarchy() {
        self.isCurrentlyInHierarchy = true
        self.updateAnimation()
    }
    
    private func didExitHierarchy() {
        self.isCurrentlyInHierarchy = false
        self.updateAnimation()
    }
    
    func update(backgroundColor: UIColor, foregroundColor: UIColor) {
        if let currentBackgroundColor = self.currentBackgroundColor, currentBackgroundColor.isEqual(backgroundColor), let currentForegroundColor = self.currentForegroundColor, currentForegroundColor.isEqual(foregroundColor) {
            return
        }
        self.currentBackgroundColor = backgroundColor
        self.currentForegroundColor = foregroundColor
        
        self.imageView.image = generateImage(CGSize(width: 4.0, height: 320.0), opaque: true, scale: 1.0, rotatedContext: { size, context in
            context.setFillColor(backgroundColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: size))
            
            context.clip(to: CGRect(origin: CGPoint(), size: size))
            
            let transparentColor = foregroundColor.withAlphaComponent(0.0).cgColor
            let peakColor = foregroundColor.cgColor
            
            var locations: [CGFloat] = [0.0, 0.5, 1.0]
            let colors: [CGColor] = [transparentColor, peakColor, transparentColor]
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            
            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        })
    }
    
    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        if let absoluteLocation = self.absoluteLocation, absoluteLocation.0 == rect && absoluteLocation.1 == containerSize {
            return
        }
        let sizeUpdated = self.absoluteLocation?.1 != containerSize
        let frameUpdated = self.absoluteLocation?.0 != rect
        self.absoluteLocation = (rect, containerSize)
        
        if sizeUpdated {
            if self.shouldBeAnimating {
                self.imageView.layer.removeAnimation(forKey: "shimmer")
                self.addImageAnimation()
            }
        }
        
        if frameUpdated {
            self.imageViewContainer.frame = CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: containerSize)
        }
        
        self.updateAnimation()
    }
    
    private func updateAnimation() {
        let shouldBeAnimating = self.isCurrentlyInHierarchy && self.absoluteLocation != nil
        if shouldBeAnimating != self.shouldBeAnimating {
            self.shouldBeAnimating = shouldBeAnimating
            if shouldBeAnimating {
                self.addImageAnimation()
            } else {
                self.imageView.layer.removeAnimation(forKey: "shimmer")
            }
        }
    }
    
    private func addImageAnimation() {
        guard let containerSize = self.absoluteLocation?.1 else {
            return
        }
        let gradientHeight: CGFloat = 250.0
        self.imageView.frame = CGRect(origin: CGPoint(x: 0.0, y: -gradientHeight), size: CGSize(width: containerSize.width, height: gradientHeight))
        let animation = self.imageView.layer.makeAnimation(from: 0.0 as NSNumber, to: (containerSize.height + gradientHeight) as NSNumber, keyPath: "position.y", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 1.3 * 1.0, delay: 0.0, mediaTimingFunction: nil, removeOnCompletion: true, additive: true)
        animation.repeatCount = Float.infinity
        animation.beginTime = 1.0
        self.imageView.layer.add(animation, forKey: "shimmer")
    }
}

final class PeerSelectionLoadingView: UIView {
    private let backgroundColorView: UIView
    private let effectView: ShimmerEffectView
    private let maskImageView: UIImageView
    private var currentParams: (size: CGSize, presentationData: PresentationData)?
    
    override init(frame: CGRect) {
        self.backgroundColorView = UIView()
        self.effectView = ShimmerEffectView()
        self.maskImageView = UIImageView()
        
        super.init(frame: frame)
        
        self.isUserInteractionEnabled = false
        
        self.addSubview(self.backgroundColorView)
        self.addSubview(self.effectView)
        self.addSubview(self.maskImageView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(context: AccountContext, size: CGSize, presentationData: PresentationData, transition: ContainedViewLayoutTransition) {
        if self.currentParams?.size != size || self.currentParams?.presentationData !== presentationData {
            self.currentParams = (size, presentationData)
            
            let peer1: EnginePeer = .user(TelegramUser(id: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(0)), accessHash: nil, firstName: "FirstName", lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil))
            
            let items = (0 ..< 1).map { _ -> ContactsPeerItem in
                return ContactsPeerItem(
                    presentationData: ItemListPresentationData(presentationData),
                    style: .plain,
                    sectionId: 0,
                    sortOrder: .firstLast,
                    displayOrder: .firstLast,
                    context: context,
                    peerMode: .peer,
                    peer: .peer(peer: peer1, chatPeer: peer1),
                    status: .custom(string: NSAttributedString(string: "status"), multiline: false, isActive: false, icon: nil),
                    badge: nil,
                    requiresPremiumForMessaging: false,
                    enabled: true,
                    selection: .none,
                    selectionPosition: .left,
                    editing: ContactsPeerItemEditing(editable: false, editing: false, revealed: false),
                    options: [],
                    additionalActions: [],
                    actionIcon: .none,
                    index: nil,
                    header: nil,
                    action: { _ in },
                    disabledAction: nil,
                    setPeerIdWithRevealedOptions: nil,
                    deletePeer: nil,
                    itemHighlighting: nil,
                    contextAction: nil,
                    arrowAction: nil,
                    animationCache: nil,
                    animationRenderer: nil,
                    storyStats: nil,
                    openStories: nil
                )
            }
            
            var itemNodes: [ContactsPeerItemNode] = []
            for i in 0 ..< items.count {
                items[i].nodeConfiguredForParams(async: { f in f() }, params: ListViewItemLayoutParams(width: size.width, leftInset: 0.0, rightInset: 0.0, availableHeight: 100.0), synchronousLoads: false, previousItem: i == 0 ? nil : items[i - 1], nextItem: (i == items.count - 1) ? nil : items[i + 1], completion: { node, apply in
                    if let itemNode = node as? ContactsPeerItemNode {
                        itemNodes.append(itemNode)
                    }
                    apply().1(ListViewItemApply(isOnScreen: true))
                })
            }
            
            self.backgroundColorView.backgroundColor = presentationData.theme.list.mediaPlaceholderColor
            
            let maskSize = CGSize(width: size.width, height: round(size.height / itemNodes[0].contentSize.height) * itemNodes[0].contentSize.height)
            
            self.maskImageView.image = generateImage(size, rotatedContext: { size, context in
                context.setFillColor(presentationData.theme.chatList.backgroundColor.cgColor)
                context.fill(CGRect(origin: CGPoint(), size: size))
                
                let size = maskSize
                
                var currentY: CGFloat = 0.0
                let fakeLabelPlaceholderHeight: CGFloat = 8.0
                
                func fillLabelPlaceholderRect(origin: CGPoint, width: CGFloat) {
                    let startPoint = origin
                    let diameter = fakeLabelPlaceholderHeight
                    context.fillEllipse(in: CGRect(origin: startPoint, size: CGSize(width: diameter, height: diameter)))
                    context.fillEllipse(in: CGRect(origin: CGPoint(x: startPoint.x + width - diameter, y: startPoint.y), size: CGSize(width: diameter, height: diameter)))
                    context.fill(CGRect(origin: CGPoint(x: startPoint.x + diameter / 2.0, y: startPoint.y), size: CGSize(width: width - diameter, height: diameter)))
                }
                
                while currentY < size.height {
                    let sampleIndex = 0
                    let itemHeight: CGFloat = itemNodes[sampleIndex].contentSize.height
                    
                    context.setBlendMode(.copy)
                    context.setFillColor(UIColor.clear.cgColor)
                    
                    if !itemNodes[sampleIndex].avatarNode.isHidden {
                        context.fillEllipse(in: itemNodes[sampleIndex].avatarNode.view.convert(itemNodes[sampleIndex].avatarNode.bounds, to: itemNodes[sampleIndex].view).offsetBy(dx: 0.0, dy: currentY))
                    }
                    
                    let titleFrame = itemNodes[sampleIndex].titleNode.frame.offsetBy(dx: 0.0, dy: currentY)
                    fillLabelPlaceholderRect(origin: CGPoint(x: titleFrame.minX, y: floor(titleFrame.midY - fakeLabelPlaceholderHeight / 2.0)), width: 100.0)
                    
                    let textFrame = itemNodes[sampleIndex].statusNode.textNode.frame.offsetBy(dx: 0.0, dy: currentY)
                    fillLabelPlaceholderRect(origin: CGPoint(x: textFrame.minX, y: currentY + itemHeight - floor(itemNodes[sampleIndex].titleNode.frame.midY - fakeLabelPlaceholderHeight / 2.0) - fakeLabelPlaceholderHeight), width: 40.0)
                    
                    context.setBlendMode(.normal)
                    context.setFillColor(presentationData.theme.chatList.itemSeparatorColor.cgColor)
                    context.fill(itemNodes[sampleIndex].separatorNode.frame.offsetBy(dx: 0.0, dy: currentY))
                    
                    currentY += itemHeight
                }
            })
            
            self.effectView.update(backgroundColor: presentationData.theme.list.mediaPlaceholderColor, foregroundColor: presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4))
            self.effectView.updateAbsoluteRect(CGRect(origin: CGPoint(), size: size), within: size)
        }
        transition.updateFrame(view: self.backgroundColorView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
        transition.updateFrame(view: self.maskImageView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
        transition.updateFrame(view: self.effectView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
    }
}
