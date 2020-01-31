import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import AvatarNode
import TelegramStringFormatting
import PhoneNumberFormat
import AppBundle
import PresentationDataUtils
import NotificationMuteSettingsUI
import NotificationSoundSelectionUI
import OverlayStatusController
import ShareController

private let avatarFont = avatarPlaceholderFont(size: 28.0)

private enum PeerInfoHeaderButtonKey: Hashable {
    case message
    case call
    case mute
    case more
}

private enum PeerInfoHeaderButtonIcon {
    case message
    case call
    case mute
    case unmute
    case more
}

private final class PeerInfoHeaderButtonNode: HighlightableButtonNode {
    let key: PeerInfoHeaderButtonKey
    private let action: (PeerInfoHeaderButtonNode) -> Void
    private let backgroundNode: ASImageNode
    private let textNode: ImmediateTextNode
    
    private var theme: PresentationTheme?
    private var icon: PeerInfoHeaderButtonIcon?
    
    init(key: PeerInfoHeaderButtonKey, action: @escaping (PeerInfoHeaderButtonNode) -> Void) {
        self.key = key
        self.action = action
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.textNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.layer.removeAnimation(forKey: "opacity")
                    strongSelf.alpha = 0.4
                } else {
                    strongSelf.alpha = 1.0
                    strongSelf.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func buttonPressed() {
        self.action(self)
    }
    
    func update(size: CGSize, text: String, icon: PeerInfoHeaderButtonIcon, isExpanded: Bool, presentationData: PresentationData, transition: ContainedViewLayoutTransition) {
        if self.theme != presentationData.theme || self.icon != icon {
            self.theme = presentationData.theme
            self.icon = icon
            self.backgroundNode.image = generateImage(CGSize(width: 40.0, height: 40.0), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(presentationData.theme.list.itemAccentColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                context.setBlendMode(.copy)
                context.setFillColor(UIColor.clear.cgColor)
                let imageName: String
                switch icon {
                case .message:
                    imageName = "Chat/Context Menu/Message"
                case .call:
                    imageName = "Chat/Context Menu/Call"
                case .mute:
                    imageName = "Chat/Context Menu/Muted"
                case .unmute:
                    imageName = "Chat/Context Menu/Unmute"
                case .more:
                    imageName = "Chat/Context Menu/More"
                }
                if let image = UIImage(bundleImageName: imageName) {
                    let imageRect = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size)
                    context.clip(to: imageRect, mask: image.cgImage!)
                    context.fill(imageRect)
                }
            })
        }
        
        self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(12.0), textColor: presentationData.theme.list.itemAccentColor)
        let titleSize = self.textNode.updateLayout(CGSize(width: 120.0, height: .greatestFiniteMagnitude))
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: size))
        transition.updateFrameAdditiveToCenter(node: self.textNode, frame: CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: size.height + 6.0), size: titleSize))
    }
}

private final class PeerInfoHeaderNode: ASDisplayNode {
    private var context: AccountContext
    private var presentationData: PresentationData?
    
    private let avatarNode: AvatarNode
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    private var buttonNodes: [PeerInfoHeaderButtonKey: PeerInfoHeaderButtonNode] = [:]
    private let backgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    
    var performButtonAction: ((PeerInfoHeaderButtonKey) -> Void)?
    
    init(context: AccountContext) {
        self.context = context
        
        self.avatarNode = AvatarNode(font: avatarFont)
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        
        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.displaysAsynchronously = false
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
    }
    
    func update(width: CGFloat, statusBarHeight: CGFloat, navigationHeight: CGFloat, presentationData: PresentationData, peer: Peer?, cachedData: CachedPeerData?, notificationSettings: TelegramPeerNotificationSettings?, presence: TelegramUserPresence?, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.presentationData = presentationData
        
        self.backgroundNode.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        self.separatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let avatarSize: CGFloat = 100.0
        let defaultButtonSize: CGFloat = 40.0
        let defaultMaxButtonSpacing: CGFloat = 40.0
        
        var buttonKeys: [PeerInfoHeaderButtonKey] = []
        
        if let peer = peer {
            buttonKeys.append(.message)
            buttonKeys.append(.call)
            buttonKeys.append(.mute)
            buttonKeys.append(.more)
            
            self.avatarNode.setPeer(context: self.context, theme: presentationData.theme, peer: peer, displayDimensions: CGSize(width: avatarSize, height: avatarSize))
            
            self.titleNode.attributedText = NSAttributedString(string: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), font: Font.medium(24.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
            
            let presence = presence ?? TelegramUserPresence(status: .none, lastActivity: 0)
            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
            let (subtitleString, activity) = stringAndActivityForUserPresence(strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, presence: presence, relativeTo: Int32(timestamp), expanded: true)
            let subtitleColor: UIColor
            if activity {
                subtitleColor = presentationData.theme.list.itemAccentColor
            } else {
                subtitleColor = presentationData.theme.list.itemSecondaryTextColor
            }
            self.subtitleNode.attributedText = NSAttributedString(string: subtitleString, font: Font.regular(15.0), textColor: subtitleColor)
        }
        
        let textSideInset: CGFloat = 16.0
        
        var height: CGFloat = navigationHeight
        height += 212.0
        
        let avatarFrame = CGRect(origin: CGPoint(x: floor((width - avatarSize) / 2.0), y: statusBarHeight + 10.0), size: CGSize(width: avatarSize, height: avatarSize))
        transition.updateFrame(node: self.avatarNode, frame: avatarFrame)
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: width - textSideInset * 2.0, height: .greatestFiniteMagnitude))
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: width - textSideInset * 2.0, height: .greatestFiniteMagnitude))
        
        let titleFrame = CGRect(origin: CGPoint(x: floor((width - titleSize.width) / 2.0), y: avatarFrame.maxY + 10.0), size: titleSize)
        let subtitleFrame = CGRect(origin: CGPoint(x: floor((width - subtitleSize.width) / 2.0), y: titleFrame.maxY + 1.0), size: subtitleSize)
        transition.updateFrameAdditiveToCenter(node: self.titleNode, frame: titleFrame)
        transition.updateFrameAdditiveToCenter(node: self.subtitleNode, frame: subtitleFrame)
        
        let buttonSpacing: CGFloat = min(defaultMaxButtonSpacing, width - floor(CGFloat(buttonKeys.count) * defaultButtonSize / CGFloat(buttonKeys.count + 1)))
        let buttonsWidth = buttonSpacing * CGFloat(buttonKeys.count - 1) + CGFloat(buttonKeys.count) * defaultButtonSize
        var buttonRightOrigin = CGPoint(x: floor((width - buttonsWidth) / 2.0) + buttonsWidth, y: height - 74.0)
        for buttonKey in buttonKeys.reversed() {
            let buttonNode: PeerInfoHeaderButtonNode
            var wasAdded = false
            if let current = self.buttonNodes[buttonKey] {
                buttonNode = current
            } else {
                wasAdded = true
                buttonNode = PeerInfoHeaderButtonNode(key: buttonKey, action: { [weak self] buttonNode in
                    self?.buttonPressed(buttonNode)
                })
                self.buttonNodes[buttonKey] = buttonNode
                self.addSubnode(buttonNode)
            }
            
            let buttonFrame = CGRect(origin: CGPoint(x: buttonRightOrigin.x - defaultButtonSize, y: buttonRightOrigin.y), size: CGSize(width: defaultButtonSize, height: defaultButtonSize))
            buttonRightOrigin.x -= defaultButtonSize + buttonSpacing
            let buttonTransition: ContainedViewLayoutTransition = wasAdded ? .immediate : transition
            buttonTransition.updateFrame(node: buttonNode, frame: buttonFrame)
            let buttonText: String
            let buttonIcon: PeerInfoHeaderButtonIcon
            switch buttonKey {
            case .message:
                buttonText = "Message"
                buttonIcon = .message
            case .call:
                buttonText = "Call"
                buttonIcon = .call
            case .mute:
                if let notificationSettings = notificationSettings, case .muted = notificationSettings.muteState {
                    buttonText = "Unmute"
                    buttonIcon = .unmute
                } else {
                    buttonText = "Mute"
                    buttonIcon = .mute
                }
            case .more:
                buttonText = "More"
                buttonIcon = .more
            }
            buttonNode.update(size: buttonFrame.size, text: buttonText, icon: buttonIcon, isExpanded: false, presentationData: presentationData, transition: buttonTransition)
        }
        
        for key in self.buttonNodes.keys {
            if !buttonKeys.contains(key) {
                if let buttonNode = self.buttonNodes[key] {
                    self.buttonNodes.removeValue(forKey: key)
                    buttonNode.removeFromSupernode()
                }
            }
        }
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -1000.0), size: CGSize(width: width, height: 1000.0 + height)))
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: height), size: CGSize(width: width, height: UIScreenPixel)))
        
        return height
    }
    
    private func buttonPressed(_ buttonNode: PeerInfoHeaderButtonNode) {
        self.performButtonAction?(buttonNode.key)
    }
}

protocol PeerInfoPaneNode: ASDisplayNode {
    var isReady: Signal<Bool, NoError> { get }
    
    func update(size: CGSize, isScrollingLockedAtTop: Bool, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition)
    func scrollToTop() -> Bool
    func findLoadedMessage(id: MessageId) -> Message?
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
}

private final class PeerInfoPaneWrapper {
    let key: PeerInfoPaneKey
    let node: PeerInfoPaneNode
    private var appliedParams: (CGSize, Bool, PresentationData)?
    
    init(key: PeerInfoPaneKey, node: PeerInfoPaneNode) {
        self.key = key
        self.node = node
    }
    
    func update(size: CGSize, isScrollingLockedAtTop: Bool, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        if let (currentSize, currentIsScrollingLockedAtTop, currentPresentationData) = self.appliedParams {
            if currentSize == size && currentIsScrollingLockedAtTop == isScrollingLockedAtTop && currentPresentationData === presentationData {
                return
            }
        }
        self.appliedParams = (size, isScrollingLockedAtTop, presentationData)
        self.node.update(size: size, isScrollingLockedAtTop: isScrollingLockedAtTop, presentationData: presentationData, synchronous: synchronous, transition: transition)
    }
}

private enum PeerInfoPaneKey {
    case media
    case files
    case links
    case music
}

private final class PeerInfoPaneTabsContainerPaneNode: ASDisplayNode {
    private let pressed: () -> Void
    
    private let titleNode: ImmediateTextNode
    private let buttonNode: HighlightTrackingButtonNode
    
    init(pressed: @escaping () -> Void) {
        self.pressed = pressed
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.titleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleNode.alpha = 0.4
                } else {
                    strongSelf.titleNode.alpha = 1.0
                    strongSelf.titleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    @objc private func buttonPressed() {
        self.pressed()
    }
    
    func updateText(_ title: String, isSelected: Bool, presentationData: PresentationData) {
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.medium(14.0), textColor: isSelected ? presentationData.theme.list.itemAccentColor : presentationData.theme.list.itemSecondaryTextColor)
    }
    
    func updateLayout(height: CGFloat) -> CGFloat {
        let titleSize = self.titleNode.updateLayout(CGSize(width: 200.0, height: .greatestFiniteMagnitude))
        self.titleNode.frame = CGRect(origin: CGPoint(x: 0.0, y: floor((height - titleSize.height) / 2.0)), size: titleSize)
        return titleSize.width
    }
    
    func updateArea(size: CGSize, sideInset: CGFloat) {
        self.buttonNode.frame = CGRect(origin: CGPoint(x: -sideInset, y: 0.0), size: CGSize(width: size.width + sideInset * 2.0, height: size.height))
    }
}

private struct PeerInfoPaneSpecifier: Equatable {
    var key: PeerInfoPaneKey
    var title: String
}

private final class PeerInfoPaneTabsContainerNode: ASDisplayNode {
    private let scrollNode: ASScrollNode
    private var paneNodes: [PeerInfoPaneKey: PeerInfoPaneTabsContainerPaneNode] = [:]
    private let selectedLineNode: ASImageNode
    
    private var currentParams: ([PeerInfoPaneSpecifier], PeerInfoPaneKey?, PresentationData)?
    
    var requestSelectPane: ((PeerInfoPaneKey) -> Void)?
    
    override init() {
        self.scrollNode = ASScrollNode()
        
        self.selectedLineNode = ASImageNode()
        self.selectedLineNode.displaysAsynchronously = false
        self.selectedLineNode.displayWithoutProcessing = true
        
        super.init()
        
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.scrollsToTop = false
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        
        self.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.selectedLineNode)
    }
    
    func update(size: CGSize, presentationData: PresentationData, paneList: [PeerInfoPaneSpecifier], selectedPane: PeerInfoPaneKey?, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: size))
        
        if self.currentParams?.2.theme !== presentationData.theme {
            self.selectedLineNode.image = generateImage(CGSize(width: 7.0, height: 4.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(presentationData.theme.list.itemAccentColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.width)))
            })?.stretchableImage(withLeftCapWidth: 4, topCapHeight: 1)
        }
        
        if self.currentParams?.0 != paneList || self.currentParams?.1 != selectedPane || self.currentParams?.2 !== presentationData {
            self.currentParams = (paneList, selectedPane, presentationData)
            for specifier in paneList {
                let paneNode: PeerInfoPaneTabsContainerPaneNode
                var wasAdded = false
                if let current = self.paneNodes[specifier.key] {
                    paneNode = current
                } else {
                    wasAdded = true
                    paneNode = PeerInfoPaneTabsContainerPaneNode(pressed: { [weak self] in
                        self?.paneSelected(specifier.key)
                    })
                    self.paneNodes[specifier.key] = paneNode
                    self.scrollNode.addSubnode(paneNode)
                }
                paneNode.updateText(specifier.title, isSelected: selectedPane == specifier.key, presentationData: presentationData)
            }
            var removeKeys: [PeerInfoPaneKey] = []
            for (key, _) in self.paneNodes {
                if !paneList.contains(where: { $0.key == key }) {
                    removeKeys.append(key)
                }
            }
            for key in removeKeys {
                if let paneNode = self.paneNodes.removeValue(forKey: key) {
                    paneNode.removeFromSupernode()
                }
            }
        }
        
        var tabSizes: [(CGSize, PeerInfoPaneTabsContainerPaneNode)] = []
        var totalRawTabSize: CGFloat = 0.0
        
        var selectedFrame: CGRect?
        for specifier in paneList {
            guard let paneNode = self.paneNodes[specifier.key] else {
                continue
            }
            let paneNodeWidth = paneNode.updateLayout(height: size.height)
            let paneNodeSize = CGSize(width: paneNodeWidth, height: size.height)
            tabSizes.append((paneNodeSize, paneNode))
            totalRawTabSize += paneNodeSize.width
        }
        
        let spacing: CGFloat = 32.0
        if totalRawTabSize + CGFloat(tabSizes.count + 1) * spacing <= size.width {
            let singleTabSpace = floor((size.width - spacing * 2.0) / CGFloat(tabSizes.count))
            
            for i in 0 ..< tabSizes.count {
                let (paneNodeSize, paneNode) = tabSizes[i]
                let leftOffset = spacing + CGFloat(i) * singleTabSpace + floor((singleTabSpace - paneNodeSize.width) / 2.0)
                
                let paneFrame = CGRect(origin: CGPoint(x: leftOffset, y: floor((size.height - paneNodeSize.height) / 2.0)), size: paneNodeSize)
                paneNode.frame = paneFrame
                let areaSideInset = floor((singleTabSpace - paneFrame.size.width) / 2.0)
                paneNode.updateArea(size: paneFrame.size, sideInset: areaSideInset)
                paneNode.hitTestSlop = UIEdgeInsets(top: 0.0, left: -areaSideInset, bottom: 0.0, right: -areaSideInset)
                
                if paneList[i].key == selectedPane {
                    selectedFrame = paneFrame
                }
            }
            self.scrollNode.view.contentSize = CGSize(width: size.width, height: size.height)
        } else {
            let sideInset: CGFloat = 16.0
            var leftOffset: CGFloat = sideInset
            for i in 0 ..< tabSizes.count {
                let (paneNodeSize, paneNode) = tabSizes[i]
                let paneFrame = CGRect(origin: CGPoint(x: leftOffset, y: floor((size.height - paneNodeSize.height) / 2.0)), size: paneNodeSize)
                paneNode.frame = paneFrame
                paneNode.updateArea(size: paneFrame.size, sideInset: spacing)
                paneNode.hitTestSlop = UIEdgeInsets(top: 0.0, left: -spacing, bottom: 0.0, right: -spacing)
                if paneList[i].key == selectedPane {
                    selectedFrame = paneFrame
                }
                leftOffset += paneNodeSize.width + spacing
            }
            self.scrollNode.view.contentSize = CGSize(width: leftOffset + sideInset, height: size.height)
        }
        
        if let selectedFrame = selectedFrame {
            self.selectedLineNode.isHidden = false
            transition.updateFrame(node: self.selectedLineNode, frame: CGRect(origin: CGPoint(x: selectedFrame.minX, y: size.height - 4.0), size: CGSize(width: selectedFrame.width, height: 4.0)))
        } else {
            self.selectedLineNode.isHidden = true
        }
    }
    
    private func paneSelected(_ key: PeerInfoPaneKey) {
        self.requestSelectPane?(key)
    }
}

private final class PeerInfoPaneContainerNode: ASDisplayNode {
    private let context: AccountContext
    private let peerId: PeerId
    
    private let coveringBackgroundNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let tabsContainerNode: PeerInfoPaneTabsContainerNode
    private let tapsSeparatorNode: ASDisplayNode
    
    let isReady = Promise<Bool>()
    var didSetIsReady = false
    
    private var currentParams: (size: CGSize, isScrollingLockedAtTop: Bool, presentationData: PresentationData)?
    
    private var availablePanes: [PeerInfoPaneKey] = []
    private var currentPaneKey: PeerInfoPaneKey?
    private var currentPane: PeerInfoPaneWrapper?
    
    private var candidatePane: (PeerInfoPaneWrapper, Disposable)?
    
    var openMessage: ((MessageId) -> Bool)?
    
    init(context: AccountContext, peerId: PeerId) {
        self.context = context
        self.peerId = peerId
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.coveringBackgroundNode = ASDisplayNode()
        self.coveringBackgroundNode.isLayerBacked = true
        
        self.tabsContainerNode = PeerInfoPaneTabsContainerNode()
        
        self.tapsSeparatorNode = ASDisplayNode()
        self.tapsSeparatorNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.coveringBackgroundNode)
        self.addSubnode(self.tabsContainerNode)
        self.addSubnode(self.tapsSeparatorNode)
        
        self.availablePanes = [.media, .files, .links, .music]
        self.currentPaneKey = .media
        
        self.tabsContainerNode.requestSelectPane = { [weak self] key in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.currentPaneKey == key {
                return
            }
            
            let paneNode: PeerInfoPaneNode
            switch key {
            case .media:
                paneNode = PeerInfoVisualMediaPaneNode(context: strongSelf.context, openMessage: { id in
                    return self?.openMessage?(id) ?? false
                }, peerId: strongSelf.peerId)
            case .files:
                paneNode = PeerInfoListPaneNode(context: strongSelf.context, openMessage: { id in
                    return self?.openMessage?(id) ?? false
                }, peerId: strongSelf.peerId, tagMask: .file)
            case .links:
                paneNode = PeerInfoListPaneNode(context: strongSelf.context, openMessage: { id in
                    return self?.openMessage?(id) ?? false
                }, peerId: strongSelf.peerId, tagMask: .webPage)
            case .music:
                paneNode = PeerInfoListPaneNode(context: strongSelf.context, openMessage: { id in
                    return self?.openMessage?(id) ?? false
                }, peerId: strongSelf.peerId, tagMask: .music)
            }
            
            if let (_, disposable) = strongSelf.candidatePane {
                disposable.dispose()
            }
            
            let disposable = MetaDisposable()
            strongSelf.candidatePane = (PeerInfoPaneWrapper(key: key, node: paneNode), disposable)
            
            if let (size, isScrollingLockedAtTop, presentationData) = strongSelf.currentParams {
                strongSelf.update(size: size, isScrollingLockedAtTop: isScrollingLockedAtTop, presentationData: presentationData, transition: .immediate)
            }
            
            disposable.set((paneNode.isReady
            |> take(1)
            |> deliverOnMainQueue).start(next: { _ in
                guard let strongSelf = self else {
                    return
                }
                if let (candidatePane, _) = strongSelf.candidatePane {
                    let previousPane = strongSelf.currentPane
                    strongSelf.candidatePane = nil
                    strongSelf.currentPaneKey = candidatePane.key
                    strongSelf.currentPane = candidatePane
                    
                    if let (size, isScrollingLockedAtTop, presentationData) = strongSelf.currentParams {
                        strongSelf.update(size: size, isScrollingLockedAtTop: isScrollingLockedAtTop, presentationData: presentationData, transition: .animated(duration: 0.35, curve: .spring))
                        
                        if let previousPane = previousPane {
                            let directionToRight: Bool
                            if let previousIndex = strongSelf.availablePanes.index(of: previousPane.key), let updatedIndex = strongSelf.availablePanes.index(of: candidatePane.key) {
                                directionToRight = previousIndex < updatedIndex
                            } else {
                                directionToRight = false
                            }
                            
                            let offset: CGFloat = directionToRight ? previousPane.node.bounds.width : -previousPane.node.bounds.width
                            candidatePane.node.layer.animatePosition(from: CGPoint(x: offset, y: 0.0), to: CGPoint(), duration: 0.35, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                            let previousNode = previousPane.node
                            previousNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: -offset, y: 0.0), duration: 0.35, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { [weak previousNode] _ in
                                previousNode?.removeFromSupernode()
                            })
                        }
                    } else {
                        if let previousPane = previousPane {
                            previousPane.node.removeFromSupernode()
                        }
                    }
                }
            }))
        }
    }
    
    func scrollToTop() -> Bool {
        if let currentPane = self.currentPane {
            return currentPane.node.scrollToTop()
        } else {
            return false
        }
    }
    
    func findLoadedMessage(id: MessageId) -> Message? {
        return self.currentPane?.node.findLoadedMessage(id: id)
    }
    
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return self.currentPane?.node.transitionNodeForGallery(messageId: messageId, media: media)
    }
    
    func update(size: CGSize, isScrollingLockedAtTop: Bool, presentationData: PresentationData, transition: ContainedViewLayoutTransition) {
        self.currentParams = (size, isScrollingLockedAtTop, presentationData)
        
        transition.updateAlpha(node: self.coveringBackgroundNode, alpha: isScrollingLockedAtTop ? 0.0 : 1.0)
        
        self.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        self.coveringBackgroundNode.backgroundColor = presentationData.theme.rootController.navigationBar.backgroundColor
        self.separatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        self.tapsSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let tabsHeight: CGFloat = 48.0
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel)))
        transition.updateFrame(node: self.coveringBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: tabsHeight)))
        
        transition.updateFrame(node: self.tapsSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: tabsHeight - UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel)))
        
        transition.updateFrame(node: self.tabsContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: tabsHeight)))
        self.tabsContainerNode.update(size: CGSize(width: size.width, height: tabsHeight), presentationData: presentationData, paneList: self.availablePanes.map { key in
            let title: String
            switch key {
            case .media:
                title = "Media"
            case .files:
                title = "Files"
            case .links:
                title = "Links"
            case .music:
                title = "Audio"
            }
            return PeerInfoPaneSpecifier(key: key, title: title)
        }, selectedPane: self.currentPaneKey, transition: transition)
        
        let paneFrame = CGRect(origin: CGPoint(x: 0.0, y: tabsHeight), size: CGSize(width: size.width, height: size.height - tabsHeight))
        
        if self.currentPane?.key != self.currentPaneKey {
            if let currentPane = self.currentPane {
                currentPane.node.removeFromSupernode()
                self.currentPane = nil
            }
            
            if let currentPaneKey = self.currentPaneKey {
                let paneNode: PeerInfoPaneNode
                switch currentPaneKey {
                case .media:
                    paneNode = PeerInfoVisualMediaPaneNode(context: self.context, openMessage: { [weak self] id in
                        return self?.openMessage?(id) ?? false
                    }, peerId: self.peerId)
                case .files:
                    paneNode = PeerInfoListPaneNode(context: self.context, openMessage: { [weak self] id in
                        return self?.openMessage?(id) ?? false
                    }, peerId: self.peerId, tagMask: .file)
                case .links:
                    paneNode = PeerInfoListPaneNode(context: self.context, openMessage: { [weak self]  id in
                        return self?.openMessage?(id) ?? false
                    }, peerId: self.peerId, tagMask: .webPage)
                case .music:
                    paneNode = PeerInfoListPaneNode(context: self.context, openMessage: { [weak self]  id in
                        return self?.openMessage?(id) ?? false
                    }, peerId: self.peerId, tagMask: .music)
                }
                self.currentPane = PeerInfoPaneWrapper(key: currentPaneKey, node: paneNode)
            }
        }
        
        if let currentPane = self.currentPane {
            let paneWasAdded = currentPane.node.supernode == nil
            if paneWasAdded {
                self.addSubnode(currentPane.node)
            }
            
            let paneTransition: ContainedViewLayoutTransition = paneWasAdded ? .immediate : transition
            paneTransition.updateFrame(node: currentPane.node, frame: paneFrame)
            currentPane.update(size: paneFrame.size, isScrollingLockedAtTop: isScrollingLockedAtTop, presentationData: presentationData, synchronous: paneWasAdded, transition: paneTransition)
        }
        if let (candidatePane, _) = self.candidatePane {
            let paneTransition: ContainedViewLayoutTransition = .immediate
            paneTransition.updateFrame(node: candidatePane.node, frame: paneFrame)
            candidatePane.update(size: paneFrame.size, isScrollingLockedAtTop: isScrollingLockedAtTop, presentationData: presentationData, synchronous: true, transition: paneTransition)
        }
        if !self.didSetIsReady {
            self.didSetIsReady = true
            if let currentPane = self.currentPane {
                self.isReady.set(currentPane.node.isReady)
            } else {
                self.isReady.set(.single(true))
            }
        }
    }
}

protocol PeerInfoScreenItem: class {
    var id: AnyHashable { get }
    func node() -> PeerInfoScreenItemNode
}

class PeerInfoScreenItemNode: ASDisplayNode {
    var bringToFrontForHighlight: (() -> Void)?
    
    func update(width: CGFloat, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, transition: ContainedViewLayoutTransition) -> CGFloat {
        preconditionFailure()
    }
}

private final class PeerInfoScreenItemSectionContainerNode: ASDisplayNode {
    let id: AnyHashable
    
    private let backgroundNode: ASDisplayNode
    private let topSeparatorNode: ASDisplayNode
    private let bottomSeparatorNode: ASDisplayNode
    
    private var currentItems: [PeerInfoScreenItem] = []
    private var itemNodes: [AnyHashable: PeerInfoScreenItemNode] = [:]
    
    init(id: AnyHashable) {
        self.id = id
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.isLayerBacked = true
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.bottomSeparatorNode)
    }
    
    func update(width: CGFloat, presentationData: PresentationData, items: [PeerInfoScreenItem], transition: ContainedViewLayoutTransition) -> CGFloat {
        self.backgroundNode.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        self.topSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        var contentHeight: CGFloat = 0.0
        
        for i in 0 ..< items.count {
            let item = items[i]
            
            let itemNode: PeerInfoScreenItemNode
            var wasAdded = false
            if let current = self.itemNodes[item.id] {
                itemNode = current
            } else {
                wasAdded = true
                itemNode = item.node()
                self.itemNodes[item.id] = itemNode
                self.addSubnode(itemNode)
                itemNode.bringToFrontForHighlight = { [weak self, weak itemNode] in
                    guard let strongSelf = self, let itemNode = itemNode else {
                        return
                    }
                    strongSelf.view.bringSubviewToFront(itemNode.view)
                }
            }
            
            let itemTransition: ContainedViewLayoutTransition = wasAdded ? .immediate : transition
            
            let itemHeight = itemNode.update(width: width, presentationData: presentationData, item: item, topItem: i == 0 ? nil : items[i - 1], bottomItem: (i == items.count - 1) ? nil : items[i + 1], transition: itemTransition)
            let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: width, height: itemHeight))
            itemTransition.updateFrame(node: itemNode, frame: itemFrame)
            if wasAdded {
                itemNode.alpha = 0.0
                transition.updateAlpha(node: itemNode, alpha: 1.0)
            }
            contentHeight += itemHeight
        }
        
        var removeIds: [AnyHashable] = []
        for (id, _) in self.itemNodes {
            if !items.contains(where: { $0.id == id }) {
                removeIds.append(id)
            }
        }
        for id in removeIds {
            if let itemNode = self.itemNodes[id] {
                transition.updateAlpha(node: itemNode, alpha: 0.0, completion: { [weak itemNode] _ in
                    itemNode?.removeFromSupernode()
                })
            }
        }
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: contentHeight)))
        transition.updateFrame(node: self.topSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel)))
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: width, height: UIScreenPixel)))
        
        return contentHeight
    }
}

private final class PeerInfoScreenData {
    let peer: Peer?
    let cachedData: CachedPeerData?
    let presence: TelegramUserPresence?
    let notificationSettings: TelegramPeerNotificationSettings?
    
    init(
        peer: Peer?,
        cachedData: CachedPeerData?,
        presence: TelegramUserPresence?,
        notificationSettings: TelegramPeerNotificationSettings?
    ) {
        self.peer = peer
        self.cachedData = cachedData
        self.presence = presence
        self.notificationSettings = notificationSettings
    }
}

private enum PeerInfoScreenInputData: Equatable {
    case none
    case user
}

private func peerInfoScreenData(context: AccountContext, peerId: PeerId) -> Signal<PeerInfoScreenData, NoError> {
    return context.account.postbox.combinedView(keys: [.basicPeer(peerId)])
    |> map { view -> PeerInfoScreenInputData in
        guard let peer = (view.views[.basicPeer(peerId)] as? BasicPeerView)?.peer else {
            return .none
        }
        if let _ = peer as? TelegramUser {
            return .user
        } else {
            preconditionFailure()
        }
    }
    |> distinctUntilChanged
    |> mapToSignal { inputData -> Signal<PeerInfoScreenData, NoError> in
        switch inputData {
        case .none:
            return .single(PeerInfoScreenData(
                peer: nil,
                cachedData: nil,
                presence: nil,
                notificationSettings: nil
            ))
        case .user:
            return context.account.viewTracker.peerView(peerId, updateData: true)
            |> map { view -> PeerInfoScreenData in
                return PeerInfoScreenData(
                    peer: view.peers[peerId],
                    cachedData: view.cachedData,
                    presence: view.peerPresences[peerId] as? TelegramUserPresence,
                    notificationSettings: view.notificationSettings as? TelegramPeerNotificationSettings
                )
            }
        }
    }
}

private final class PeerInfoInteraction {
    let openUsername: (String) -> Void
    let openPhone: (String) -> Void
    
    init(
        openUsername: @escaping (String) -> Void,
        openPhone: @escaping (String) -> Void
    ) {
        self.openUsername = openUsername
        self.openPhone = openPhone
    }
}

private func peerInfoSectionItems(data: PeerInfoScreenData?, presentationData: PresentationData, interaction: PeerInfoInteraction) -> [PeerInfoScreenItem] {
    var items: [PeerInfoScreenItem] = []
    if let user = data?.peer as? TelegramUser {
        if let cachedData = data?.cachedData as? CachedUserData {
            if let about = cachedData.about {
                items.append(PeerInfoScreenLabeledValueItem(id: 0, label: "bio", text: about, textColor: .primary, textBehavior: .multiLine(maxLines: 10), action: nil))
            }
        }
        if let username = user.username {
            items.append(PeerInfoScreenLabeledValueItem(id: 1, label: "username", text: "@\(username)", textColor: .accent, action: {
                interaction.openUsername(username)
            }))
        }
        if let phone = user.phone {
            items.append(PeerInfoScreenLabeledValueItem(id: 2, label: "mobile", text: "\(formatPhoneNumber(phone))", textColor: .accent, action: {
                interaction.openPhone(phone)
            }))
        }
    }
    return items
}

private final class PeerInfoNavigationNode: ASDisplayNode {
    private let backgroundNode: ASDisplayNode
    private let separatorContainerNode: ASDisplayNode
    private let separatorCoveringNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private let titleNode: ImmediateTextNode
    
    private var currentParams: (PresentationData, Peer?)?
    
    override init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        
        self.separatorContainerNode = ASDisplayNode()
        self.separatorContainerNode.isLayerBacked = true
        self.separatorContainerNode.clipsToBounds = true
        
        self.separatorCoveringNode = ASDisplayNode()
        self.separatorCoveringNode.isLayerBacked = true
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.titleNode = ImmediateTextNode()
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        
        self.separatorContainerNode.addSubnode(self.separatorNode)
        self.separatorContainerNode.addSubnode(self.separatorCoveringNode)
        self.addSubnode(self.separatorContainerNode)
        
        self.addSubnode(self.titleNode)
    }
    
    func update(size: CGSize, statusBarHeight: CGFloat, navigationHeight: CGFloat, offset: CGFloat, paneContainerOffset: CGFloat, presentationData: PresentationData, peer: Peer?, transition: ContainedViewLayoutTransition) {
        if let (currentPresentationData, currentPeer) = self.currentParams {
            if currentPresentationData !== presentationData || currentPeer !== peer {
                if let peer = peer {
                    self.titleNode.attributedText = NSAttributedString(string: peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder), font: Font.semibold(17.0), textColor: presentationData.theme.rootController.navigationBar.primaryTextColor)
                }
            }
        }
        
        if self.currentParams?.0.theme !== presentationData.theme {
            self.backgroundNode.backgroundColor = presentationData.theme.rootController.navigationBar.backgroundColor
            self.separatorNode.backgroundColor = presentationData.theme.rootController.navigationBar.separatorColor
            self.separatorCoveringNode.backgroundColor = presentationData.theme.rootController.navigationBar.backgroundColor
        }
        
        self.currentParams = (presentationData, peer)
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: size.width - 100.0, height: .greatestFiniteMagnitude))
        let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: statusBarHeight + floor((navigationHeight - statusBarHeight - titleSize.height) / 2.0)), size: titleSize)
        transition.updateFrameAdditiveToCenter(node: self.titleNode, frame: titleFrame)
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: size))
        transition.updateFrame(node: self.separatorContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: size.height), size: CGSize(width: size.width, height: UIScreenPixel)))
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: UIScreenPixel)))
        transition.updateFrame(node: self.separatorCoveringNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -offset + paneContainerOffset - size.height), size: CGSize(width: size.width, height: 10.0 + UIScreenPixel)))
        
        let revealOffset: CGFloat = 100.0
        let progress: CGFloat = max(0.0, min(1.0, offset / revealOffset))
        
        transition.updateAlpha(node: self.backgroundNode, alpha: progress)
        transition.updateAlpha(node: self.separatorNode, alpha: progress)
        transition.updateAlpha(node: self.titleNode, alpha: progress)
    }
}

private final class PeerInfoScreenNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private weak var controller: PeerInfoScreen?
    
    private let context: AccountContext
    private let peerId: PeerId
    private var presentationData: PresentationData
    private let scrollNode: ASScrollNode
    
    private let navigationNode: PeerInfoNavigationNode
    private let headerNode: PeerInfoHeaderNode
    private let infoSection: PeerInfoScreenItemSectionContainerNode
    private let paneContainerNode: PeerInfoPaneContainerNode
    private var isPaneAreaExpanded: Bool = false
    private var ignoreScrolling: Bool = false
    
    private var _interaction: PeerInfoInteraction?
    private var interaction: PeerInfoInteraction {
        return self._interaction!
    }
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    private var data: PeerInfoScreenData?
    private var dataDisposable: Disposable?
    
    private let _ready = Promise<Bool>()
    var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    init(controller: PeerInfoScreen, context: AccountContext, peerId: PeerId) {
        self.controller = controller
        self.context = context
        self.peerId = peerId
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.scrollNode = ASScrollNode()
        
        self.navigationNode = PeerInfoNavigationNode()
        self.headerNode = PeerInfoHeaderNode(context: context)
        self.infoSection = PeerInfoScreenItemSectionContainerNode(id: 0)
        self.paneContainerNode = PeerInfoPaneContainerNode(context: context, peerId: peerId)
        
        super.init()
        
        self._interaction = PeerInfoInteraction(
            openUsername: { [weak self] value in
                self?.openUsername(value: value)
            },
            openPhone: { [weak self] value in
                self?.openPhone(value: value)
            }
        )
        
        self.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        
        self.scrollNode.view.showsVerticalScrollIndicator = false
        if #available(iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        self.scrollNode.view.scrollsToTop = false
        self.scrollNode.view.delegate = self
        self.addSubnode(self.scrollNode)
        self.addSubnode(self.navigationNode)
        
        self.scrollNode.addSubnode(self.headerNode)
        self.scrollNode.addSubnode(self.infoSection)
        self.scrollNode.addSubnode(self.paneContainerNode)
        
        self.paneContainerNode.openMessage = { [weak self] id in
            return self?.openMessage(id: id) ?? false
        }
        
        self.headerNode.performButtonAction = { [weak self] key in
            self?.performButtonAction(key: key)
        }
        
        self.dataDisposable = (peerInfoScreenData(context: context, peerId: peerId)
        |> deliverOnMainQueue).start(next: { [weak self] data in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateData(data)
        })
    }
    
    deinit {
        self.dataDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
    }
    
    private func updateData(_ data: PeerInfoScreenData) {
        self.data = data
        if let (layout, navigationHeight) = self.validLayout {
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate)
        }
    }
    
    func scrollToTop() {
        if self.isPaneAreaExpanded {
            if !self.paneContainerNode.scrollToTop() {
                
            }
        } else {
            self.scrollNode.view.setContentOffset(CGPoint(), animated: true)
        }
    }
    
    private func openMessage(id: MessageId) -> Bool {
        guard let galleryMessage = self.paneContainerNode.findLoadedMessage(id: id), let controller = self.controller, let navigationController = controller.navigationController as? NavigationController else {
            return false
        }
        self.view.endEditing(true)
        
        return self.context.sharedContext.openChatMessage(OpenChatMessageParams(context: self.context, message: galleryMessage, standalone: false, reverseMessageGalleryOrder: true, navigationController: navigationController, dismissInput: { [weak self] in
            self?.view.endEditing(true)
        }, present: { [weak self] c, a in
            self?.controller?.present(c, in: .window(.root), with: a, blockInteraction: true)
        }, transitionNode: { [weak self] messageId, media in
            guard let strongSelf = self else {
                return nil
            }
            return strongSelf.paneContainerNode.transitionNodeForGallery(messageId: messageId, media: media)
        }, addToTransitionSurface: { [weak self] view in
            guard let strongSelf = self else {
                return
            }
            strongSelf.view.addSubview(view)
        }, openUrl: { url in
            //self?.openUrl(url)
        }, openPeer: { peer, navigation in
            //self?.controllerInteraction?.openPeer(peer.id, navigation, nil)
        }, callPeer: { peerId in
            //self?.controllerInteraction?.callPeer(peerId)
        }, enqueueMessage: { _ in
        }, sendSticker: nil, setupTemporaryHiddenMedia: { _, _, _ in }, chatAvatarHiddenMedia: { _, _ in }))
    }
    
    private func performButtonAction(key: PeerInfoHeaderButtonKey) {
        guard let controller = self.controller else {
            return
        }
        switch key {
        case .message:
            if let navigationController = controller.navigationController as? NavigationController {
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(self.peerId)))
            }
        case .call:
            self.requestCall()
        case .mute:
            let peerId = self.peerId
            let _ = (self.context.account.postbox.transaction { transaction -> (TelegramPeerNotificationSettings, GlobalNotificationSettings) in
                let peerSettings: TelegramPeerNotificationSettings = (transaction.getPeerNotificationSettings(peerId) as? TelegramPeerNotificationSettings) ?? TelegramPeerNotificationSettings.defaultSettings
                let globalSettings: GlobalNotificationSettings = (transaction.getPreferencesEntry(key: PreferencesKeys.globalNotifications) as? GlobalNotificationSettings) ?? GlobalNotificationSettings.defaultSettings
                return (peerSettings, globalSettings)
            }
            |> deliverOnMainQueue).start(next: { [weak self] peerSettings, globalSettings in
                guard let strongSelf = self else {
                    return
                }
                let soundSettings: NotificationSoundSettings?
                if case .default = peerSettings.messageSound {
                    soundSettings = NotificationSoundSettings(value: nil)
                } else {
                    soundSettings = NotificationSoundSettings(value: peerSettings.messageSound)
                }
                let muteSettingsController = notificationMuteSettingsController(presentationData: strongSelf.presentationData, notificationSettings: globalSettings.effective.groupChats, soundSettings: soundSettings, openSoundSettings: {
                    guard let strongSelf = self else {
                        return
                    }
                    let soundController = notificationSoundSelectionController(context: strongSelf.context, isModal: true, currentSound: peerSettings.messageSound, defaultSound: globalSettings.effective.groupChats.sound, completion: { sound in
                        guard let strongSelf = self else {
                            return
                        }
                        let _ = updatePeerNotificationSoundInteractive(account: strongSelf.context.account, peerId: strongSelf.peerId, sound: sound).start()
                    })
                    strongSelf.controller?.present(soundController, in: .window(.root))
                }, updateSettings: { value in
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = updatePeerMuteSetting(account: strongSelf.context.account, peerId: strongSelf.peerId, muteInterval: value).start()
                })
                strongSelf.controller?.present(muteSettingsController, in: .window(.root))
            })
        case .more:
            let actionSheet = ActionSheetController(presentationData: self.presentationData)
            let dismissAction: () -> Void = { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            }
            var reportSpam = false
            var deleteChat = false
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.UserInfo_StartSecretChat, color: .accent, action: { [weak self] in
                        dismissAction()
                        self?.openStartSecretChat()
                    })
                ]),
                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, action: { dismissAction() })])
            ])
            controller.present(actionSheet, in: .window(.root))
        }
    }
    
    private func openStartSecretChat() {
        let peerId = self.peerId
        let _ = (self.context.account.postbox.transaction { transaction -> (Peer?, PeerId?) in
            let peer = transaction.getPeer(peerId)
            let filteredPeerIds = Array(transaction.getAssociatedPeerIds(peerId)).filter { $0.namespace == Namespaces.Peer.SecretChat }
            var activeIndices: [ChatListIndex] = []
            for associatedId in filteredPeerIds {
                if let state = (transaction.getPeer(associatedId) as? TelegramSecretChat)?.embeddedState {
                    switch state {
                        case .active, .handshake:
                            if let (_, index) = transaction.getPeerChatListIndex(associatedId) {
                                activeIndices.append(index)
                            }
                        default:
                            break
                    }
                }
            }
            activeIndices.sort()
            if let index = activeIndices.last {
                return (peer, index.messageIndex.id.peerId)
            } else {
                return (peer, nil)
            }
        }
        |> deliverOnMainQueue).start(next: { [weak self] peer, currentPeerId in
            guard let strongSelf = self else {
                return
            }
            if let currentPeerId = currentPeerId {
                if let navigationController = (strongSelf.controller?.navigationController as? NavigationController) {
                    strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(currentPeerId)))
                }
            } else if let controller = strongSelf.controller {
                let displayTitle = peer?.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder) ?? ""
                controller.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.UserInfo_StartSecretChatConfirmation(displayTitle).0, actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.UserInfo_StartSecretChatStart, action: {
                    guard let strongSelf = self else {
                        return
                    }
                    var createSignal = createSecretChat(account: strongSelf.context.account, peerId: peerId)
                    var cancelImpl: (() -> Void)?
                    let progressSignal = Signal<Never, NoError> { subscriber in
                        if let strongSelf = self {
                            let statusController = OverlayStatusController(theme: strongSelf.presentationData.theme, type: .loading(cancelled: {
                                cancelImpl?()
                            }))
                            strongSelf.controller?.present(statusController, in: .window(.root))
                            return ActionDisposable { [weak controller] in
                                Queue.mainQueue().async() {
                                    controller?.dismiss()
                                }
                            }
                        } else {
                            return EmptyDisposable
                        }
                    }
                    |> runOn(Queue.mainQueue())
                    |> delay(0.15, queue: Queue.mainQueue())
                    let progressDisposable = progressSignal.start()
                    
                    createSignal = createSignal
                    |> afterDisposed {
                        Queue.mainQueue().async {
                            progressDisposable.dispose()
                        }
                    }
                    let createSecretChatDisposable = MetaDisposable()
                    cancelImpl = {
                        createSecretChatDisposable.set(nil)
                    }
                    
                    createSecretChatDisposable.set((createSignal
                    |> deliverOnMainQueue).start(next: { peerId in
                        guard let strongSelf = self else {
                            return
                        }
                        if let navigationController = (strongSelf.controller?.navigationController as? NavigationController) {
                            strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(strongSelf.peerId)))
                        }
                    }, error: { _ in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.controller?.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    }))
                })]), in: .window(.root))
            }
        })
    }
    
    private func openUsername(value: String) {
        let shareController = ShareController(context: context, subject: .url("\(value)"))
        self.controller?.present(shareController, in: .window(.root))
    }
    
    private func requestCall() {
        guard let peer = self.data?.peer as? TelegramUser, let cachedUserData = self.data?.cachedData as? CachedUserData else {
            return
        }
        if cachedUserData.callsPrivate {
            self.controller?.present(textAlertController(context: self.context, title: self.presentationData.strings.Call_ConnectionErrorTitle, text: self.presentationData.strings.Call_PrivacyErrorMessage(peer.compactDisplayTitle).0, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
            return
        }
            
        let callResult = self.context.sharedContext.callManager?.requestCall(account: self.context.account, peerId: peer.id, endCurrentIfAny: false)
        if let callResult = callResult, case let .alreadyInProgress(currentPeerId) = callResult {
            if currentPeerId == peer.id {
                self.context.sharedContext.navigateToCurrentCall()
            } else {
                let _ = (self.context.account.postbox.transaction { transaction -> (Peer?, Peer?) in
                    return (transaction.getPeer(peer.id), transaction.getPeer(currentPeerId))
                }
                |> deliverOnMainQueue).start(next: { [weak self] peer, current in
                    guard let strongSelf = self else {
                        return
                    }
                    if let peer = peer, let current = current {
                        strongSelf.controller?.present(textAlertController(context: strongSelf.context, title: strongSelf.presentationData.strings.Call_CallInProgressTitle, text: strongSelf.presentationData.strings.Call_CallInProgressMessage(current.compactDisplayTitle, peer.compactDisplayTitle).0, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                            guard let strongSelf = self else {
                                return
                            }
                            let _ = strongSelf.context.sharedContext.callManager?.requestCall(account: strongSelf.context.account, peerId: peer.id, endCurrentIfAny: true)
                        })]), in: .window(.root))
                    }
                })
            }
        }
    }
    
    private func openPhone(value: String) {
        let _ = (getUserPeer(postbox: self.context.account.postbox, peerId: peerId)
        |> deliverOnMainQueue).start(next: { [weak self] peer, _ in
            guard let strongSelf = self else {
                return
            }
            if let peer = peer as? TelegramUser, let peerPhoneNumber = peer.phone, formatPhoneNumber(value) == formatPhoneNumber(peerPhoneNumber) {
                let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData)
                let dismissAction: () -> Void = { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                }
                actionSheet.setItemGroups([
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.UserInfo_TelegramCall, action: {
                            dismissAction()
                            self?.requestCall()
                        }),
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.UserInfo_PhoneCall, action: {
                            dismissAction()
                            
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.context.sharedContext.applicationBindings.openUrl("tel:\(formatPhoneNumber(value).replacingOccurrences(of: " ", with: ""))")
                        }),
                    ]),
                    ActionSheetItemGroup(items: [ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, action: { dismissAction() })])
                ])
                strongSelf.controller?.present(actionSheet, in: .window(.root))
            } else {
                strongSelf.context.sharedContext.applicationBindings.openUrl("tel:\(formatPhoneNumber(value).replacingOccurrences(of: " ", with: ""))")
            }
        })
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationHeight)
        
        self.ignoreScrolling = true
        
        transition.updateFrame(node: self.navigationNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: navigationHeight)))
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let sectionSpacing: CGFloat = 24.0
        
        var contentHeight: CGFloat = 0.0
        
        let headerHeight = self.headerNode.update(width: layout.size.width, statusBarHeight: layout.statusBarHeight ?? 0.0, navigationHeight: navigationHeight, presentationData: self.presentationData, peer: self.data?.peer, cachedData: self.data?.cachedData, notificationSettings: self.data?.notificationSettings, presence: self.data?.presence, transition: transition)
        transition.updateFrame(node: self.headerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: layout.size.width, height: headerHeight)))
        contentHeight += headerHeight
        contentHeight += sectionSpacing
        
        let infoSectionHeight = self.infoSection.update(width: layout.size.width, presentationData: self.presentationData, items: peerInfoSectionItems(data: self.data, presentationData: self.presentationData, interaction: self.interaction), transition: transition)
        let infoSectionFrame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: layout.size.width, height: infoSectionHeight))
        transition.updateFrame(node: self.infoSection, frame: infoSectionFrame)
        contentHeight += infoSectionHeight
        contentHeight += sectionSpacing
        
        let paneContainerSize = CGSize(width: layout.size.width, height: layout.size.height - navigationHeight)
        self.paneContainerNode.update(size: paneContainerSize, isScrollingLockedAtTop: !self.isPaneAreaExpanded, presentationData: self.presentationData, transition: transition)
        transition.updateFrame(node: self.paneContainerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: paneContainerSize))
        contentHeight += layout.size.height - navigationHeight
        
        self.scrollNode.view.contentSize = CGSize(width: layout.size.width, height: contentHeight)
        
        if self.isPaneAreaExpanded {
            transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(x: 0.0, y: contentHeight - self.scrollNode.bounds.height), size: self.scrollNode.bounds.size))
        } else {
            let maxOffsetY = max(0.0, contentHeight - floor(self.scrollNode.bounds.height * 1.5))
            if self.scrollNode.view.contentOffset.y > maxOffsetY {
                //transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(x: 0.0, y: maxOffsetY), size: self.scrollNode.bounds.size))
            }
        }
        
        self.ignoreScrolling = false
        self.updateNavigation(transition: transition)
        
        if !self.didSetReady && self.data != nil {
            self.didSetReady = true
            self._ready.set(self.paneContainerNode.isReady.get())
        }
    }
    
    private func updateNavigation(transition: ContainedViewLayoutTransition) {
        let offsetY = self.scrollNode.view.contentOffset.y
        
        if offsetY <= 1.0 {
            self.scrollNode.view.bounces = true
        } else {
            self.scrollNode.view.bounces = false
        }
        
        if let (layout, navigationHeight) = self.validLayout {
            self.navigationNode.update(size: CGSize(width: layout.size.width, height: navigationHeight), statusBarHeight: layout.statusBarHeight ?? 0.0, navigationHeight: navigationHeight, offset: offsetY, paneContainerOffset: self.paneContainerNode.frame.minY, presentationData: self.presentationData, peer: self.data?.peer, transition: transition)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if self.ignoreScrolling {
            return
        }
        self.updateNavigation(transition: .immediate)
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard let (_, navigationHeight) = self.validLayout else {
            return
        }
        let snapDurationFactor = max(0.5, min(1.5, abs(velocity.y) * 0.8))
        
        var snapToOffset: CGFloat?
        let offset = targetContentOffset.pointee.y
        
        let headerMaxOffset = self.headerNode.bounds.height - navigationHeight
        let collapsedPanesOffset = max(0.0, scrollView.contentSize.height - floor(scrollNode.bounds.height * 1.5))
        let expandedPanesOffset = scrollView.contentSize.height - self.scrollNode.bounds.height
        
        if offset > collapsedPanesOffset {
            if velocity.y < 0.0 {
                var targetOffset = collapsedPanesOffset
                if targetOffset < headerMaxOffset {
                    targetOffset = 0.0
                }
                snapToOffset = targetOffset
            } else {
                snapToOffset = expandedPanesOffset
            }
        } else if offset < headerMaxOffset && offset > 0.0 {
            let directionIsDown: Bool
            if abs(velocity.y) > 0.2 {
                directionIsDown = velocity.y >= 0.0
            } else {
                directionIsDown = offset >= headerMaxOffset / 2.0
            }
            
            if directionIsDown {
                snapToOffset = headerMaxOffset
            } else {
                snapToOffset = 0.0
            }
        } else if self.isPaneAreaExpanded && offset < expandedPanesOffset {
            let directionIsDown: Bool
            if abs(velocity.y) > 0.2 {
                directionIsDown = velocity.y >= 0.0
            } else {
                directionIsDown = offset >= headerMaxOffset / 2.0
            }
            
            if directionIsDown {
                snapToOffset = headerMaxOffset
            } else {
                snapToOffset = 0.0
            }
        }
        
        if let snapToOffset = snapToOffset {
            targetContentOffset.pointee = scrollView.contentOffset
            DispatchQueue.main.async {
                let isPaneAreaExpanded = abs(snapToOffset - expandedPanesOffset) < CGFloat.ulpOfOne ? true : false
                self.isPaneAreaExpanded = isPaneAreaExpanded
                let currentOffset = scrollView.contentOffset
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.3 * Double(1.0 / snapDurationFactor), curve: .spring)
                self.ignoreScrolling = true
                transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(x: 0.0, y: snapToOffset), size: self.scrollNode.bounds.size))
                self.ignoreScrolling = false
                if let (layout, navigationHeight) = self.validLayout {
                    self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: transition)
                }
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        var currentParent: UIView? = result
        var enableScrolling = true
        while true {
            if currentParent == nil || currentParent === self.view {
                break
            }
            if let scrollView = currentParent as? UIScrollView {
                if scrollView === self.scrollNode.view {
                    break
                }
                if scrollView.isDecelerating && scrollView.contentOffset.y < -scrollView.contentInset.top {
                    return self.scrollNode.view
                }
            } else if let listView = currentParent as? ListViewBackingView, let listNode = listView.target {
                if listNode.scroller.isDecelerating && listNode.scroller.contentOffset.y < listNode.scroller.contentInset.top {
                    return self.scrollNode.view
                }
            }
            currentParent = currentParent?.superview
        }
        return result
    }
}

public final class PeerInfoScreen: ViewController {
    private let context: AccountContext
    private let peerId: PeerId
    
    private var presentationData: PresentationData
    
    private var controllerNode: PeerInfoScreenNode {
        return self.displayNode as! PeerInfoScreenNode
    }
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    public init(context: AccountContext, peerId: PeerId) {
        self.context = context
        self.peerId = peerId
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let baseNavigationBarPresentationData = NavigationBarPresentationData(presentationData: self.presentationData)
        super.init(navigationBarPresentationData: NavigationBarPresentationData(
            theme: NavigationBarTheme(
                buttonColor: baseNavigationBarPresentationData.theme.buttonColor,
                disabledButtonColor: baseNavigationBarPresentationData.theme.disabledButtonColor,
                primaryTextColor: baseNavigationBarPresentationData.theme.primaryTextColor,
                backgroundColor: .clear,
                separatorColor: .clear,
                badgeBackgroundColor: baseNavigationBarPresentationData.theme.badgeBackgroundColor,
                badgeStrokeColor: baseNavigationBarPresentationData.theme.badgeStrokeColor,
                badgeTextColor: baseNavigationBarPresentationData.theme.badgeTextColor
        ), strings: baseNavigationBarPresentationData.strings))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.scrollToTop = { [weak self] in
            self?.controllerNode.scrollToTop()
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = PeerInfoScreenNode(controller: self, context: self.context, peerId: self.peerId)
        
        self._ready.set(self.controllerNode.ready.get())
        
        super.displayNodeDidLoad()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout: layout, navigationHeight: self.navigationHeight, transition: transition)
    }
}

private func getUserPeer(postbox: Postbox, peerId: PeerId) -> Signal<(Peer?, CachedPeerData?), NoError> {
    return postbox.transaction { transaction -> (Peer?, CachedPeerData?) in
        guard let peer = transaction.getPeer(peerId) else {
            return (nil, nil)
        }
        var resultPeer: Peer?
        if let peer = peer as? TelegramSecretChat {
            resultPeer = transaction.getPeer(peer.regularPeerId)
        } else {
            resultPeer = peer
        }
        return (resultPeer, resultPeer.flatMap({ transaction.getPeerCachedData(peerId: $0.id) }))
    }
}
