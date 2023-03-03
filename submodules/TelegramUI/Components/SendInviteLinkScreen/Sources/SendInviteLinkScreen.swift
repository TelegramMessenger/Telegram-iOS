import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import TelegramCore
import MultilineTextComponent
import Postbox
import SolidRoundedButtonComponent
import PresentationDataUtils
import Markdown
import UndoUI

private final class SendInviteLinkScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let link: String?
    let peers: [EnginePeer]
    let peerPresences: [EnginePeer.Id: EnginePeer.Presence]
    
    init(
        context: AccountContext,
        link: String?,
        peers: [EnginePeer],
        peerPresences: [EnginePeer.Id: EnginePeer.Presence]
    ) {
        self.context = context
        self.link = link
        self.peers = peers
        self.peerPresences = peerPresences
    }
    
    static func ==(lhs: SendInviteLinkScreenComponent, rhs: SendInviteLinkScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.link != rhs.link {
            return false
        }
        if lhs.peers != rhs.peers {
            return false
        }
        if lhs.peerPresences != rhs.peerPresences {
            return false
        }
        return true
    }
    
    private struct ItemLayout: Equatable {
        var containerSize: CGSize
        var containerInset: CGFloat
        var bottomInset: CGFloat
        var topInset: CGFloat
        
        init(containerSize: CGSize, containerInset: CGFloat, bottomInset: CGFloat, topInset: CGFloat) {
            self.containerSize = containerSize
            self.containerInset = containerInset
            self.bottomInset = bottomInset
            self.topInset = topInset
        }
    }
    
    private final class ScrollView: UIScrollView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return super.hitTest(point, with: event)
        }
    }
    
    final class View: UIView, UIScrollViewDelegate {
        private let dimView: UIView
        private let backgroundLayer: SimpleLayer
        private let navigationBarContainer: SparseContainerView
        private let scrollView: ScrollView
        private let scrollContentClippingView: SparseContainerView
        private let scrollContentView: UIView
        
        private let iconBackgroundView: UIView
        private let iconView: UIImageView
        
        private let title = ComponentView<Empty>()
        private let leftButton = ComponentView<Empty>()
        private let descriptionText = ComponentView<Empty>()
        private let actionButton = ComponentView<Empty>()
        
        private let itemContainerView: UIView
        private var items: [AnyHashable: ComponentView<Empty>] = [:]
        
        private var selectedItems = Set<EnginePeer.Id>()
        
        private let bottomOverscrollLimit: CGFloat
        
        private var ignoreScrolling: Bool = false
        
        private var component: SendInviteLinkScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        private var itemLayout: ItemLayout?
        
        private var topOffsetDistance: CGFloat?
        
        override init(frame: CGRect) {
            self.bottomOverscrollLimit = 200.0
            
            self.dimView = UIView()
            
            self.backgroundLayer = SimpleLayer()
            self.backgroundLayer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            self.backgroundLayer.cornerRadius = 10.0
            
            self.navigationBarContainer = SparseContainerView()
            
            self.scrollView = ScrollView()
            
            self.scrollContentClippingView = SparseContainerView()
            self.scrollContentClippingView.clipsToBounds = true
            
            self.scrollContentView = UIView()
            
            self.iconBackgroundView = UIView()
            self.iconView = UIImageView(image: UIImage(bundleImageName: "Chat/Links/LargeLink")?.withRenderingMode(.alwaysTemplate))
            
            self.itemContainerView = UIView()
            self.itemContainerView.clipsToBounds = true
            self.itemContainerView.layer.cornerRadius = 10.0
            
            super.init(frame: frame)
            
            self.addSubview(self.dimView)
            self.layer.addSublayer(self.backgroundLayer)
            
            self.addSubview(self.navigationBarContainer)
            
            self.scrollView.delaysContentTouches = true
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.scrollView.contentInsetAdjustmentBehavior = .never
            }
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            
            self.addSubview(self.scrollContentClippingView)
            self.scrollContentClippingView.addSubview(self.scrollView)
            
            self.scrollContentView.addSubview(self.iconBackgroundView)
            self.scrollContentView.addSubview(self.iconView)
            
            self.scrollView.addSubview(self.scrollContentView)
            
            self.scrollContentView.addSubview(self.itemContainerView)
            
            self.dimView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            guard let itemLayout = self.itemLayout, let topOffsetDistance = self.topOffsetDistance else {
                return
            }
            
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            topOffset = max(0.0, topOffset)
            
            if topOffset < topOffsetDistance {
                targetContentOffset.pointee.y = scrollView.contentOffset.y
                scrollView.setContentOffset(CGPoint(x: 0.0, y: itemLayout.topInset), animated: true)
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if !self.bounds.contains(point) {
                return nil
            }
            if !self.backgroundLayer.frame.contains(point) {
                return self.dimView
            }
            
            if let result = self.navigationBarContainer.hitTest(self.convert(point, to: self.navigationBarContainer), with: event) {
                return result
            }
            
            let result = super.hitTest(point, with: event)
            return result
        }
        
        @objc private func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                guard let environment = self.environment, let controller = environment.controller() else {
                    return
                }
                controller.dismiss()
            }
        }
        
        private func updateScrolling(transition: Transition) {
            guard let environment = self.environment, let controller = environment.controller(), let itemLayout = self.itemLayout else {
                return
            }
            var topOffset = -self.scrollView.bounds.minY + itemLayout.topInset
            topOffset = max(0.0, topOffset)
            transition.setTransform(layer: self.backgroundLayer, transform: CATransform3DMakeTranslation(0.0, topOffset + itemLayout.containerInset, 0.0))
            
            transition.setPosition(view: self.navigationBarContainer, position: CGPoint(x: 0.0, y: topOffset + itemLayout.containerInset))
            
            let topOffsetDistance: CGFloat = min(200.0, floor(itemLayout.containerSize.height * 0.25))
            self.topOffsetDistance = topOffsetDistance
            var topOffsetFraction = topOffset / topOffsetDistance
            topOffsetFraction = max(0.0, min(1.0, topOffsetFraction))
            
            let transitionFactor: CGFloat = 1.0 - topOffsetFraction
            controller.updateModalStyleOverlayTransitionFactor(transitionFactor, transition: transition.containedViewLayoutTransition)
        }
        
        func animateIn() {
            self.dimView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            let animateOffset: CGFloat = self.backgroundLayer.frame.minY
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.backgroundLayer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            if let actionButtonView = self.actionButton.view {
                actionButtonView.layer.animatePosition(from: CGPoint(x: 0.0, y: animateOffset), to: CGPoint(), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            }
        }
        
        func animateOut(completion: @escaping () -> Void) {
            let animateOffset: CGFloat = self.backgroundLayer.frame.minY
            
            self.dimView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            self.scrollContentClippingView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true, completion: { _ in
                completion()
            })
            self.backgroundLayer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            self.navigationBarContainer.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            if let actionButtonView = self.actionButton.view {
                actionButtonView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: animateOffset), duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, additive: true)
            }
        }
        
        func update(component: SendInviteLinkScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            
            let resetScrolling = self.scrollView.bounds.width != availableSize.width
            
            let sideInset: CGFloat = 16.0
            
            if self.component == nil {
                for peer in component.peers {
                    self.selectedItems.insert(peer.id)
                }
            }
            
            self.component = component
            self.state = state
            self.environment = environment
            
            if themeUpdated {
                self.dimView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                self.backgroundLayer.backgroundColor = environment.theme.list.blocksBackgroundColor.cgColor
                self.iconBackgroundView.backgroundColor = environment.theme.list.itemCheckColors.fillColor
                self.iconView.tintColor = environment.theme.list.itemCheckColors.foregroundColor
                self.itemContainerView.backgroundColor = environment.theme.list.itemBlocksBackgroundColor
                
                var locations: [NSNumber] = []
                var colors: [CGColor] = []
                let numStops = 6
                for i in 0 ..< numStops {
                    let step = CGFloat(i) / CGFloat(numStops - 1)
                    locations.append(step as NSNumber)
                    colors.append(environment.theme.list.blocksBackgroundColor.withAlphaComponent(1.0 - step * step).cgColor)
                }
            }
            
            transition.setFrame(view: self.dimView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            var contentHeight: CGFloat = 0.0
            
            let leftButtonSize = self.leftButton.update(
                transition: transition,
                component: AnyComponent(Button(
                    content: AnyComponent(Text(text: environment.strings.SendInviteLink_SkipAction, font: Font.regular(17.0), color: environment.theme.list.itemAccentColor)),
                    action: { [weak self] in
                        guard let self, let controller = self.environment?.controller() else {
                            return
                        }
                        controller.dismiss()
                    }
                ).minSize(CGSize(width: 44.0, height: 56.0))),
                environment: {},
                containerSize: CGSize(width: 120.0, height: 100.0)
            )
            let leftButtonFrame = CGRect(origin: CGPoint(x: 16.0, y: 0.0), size: leftButtonSize)
            if let leftButtonView = self.leftButton.view {
                if leftButtonView.superview == nil {
                    self.navigationBarContainer.addSubview(leftButtonView)
                }
                transition.setFrame(view: leftButtonView, frame: leftButtonFrame)
                
                leftButtonView.isHidden = (self.selectedItems.isEmpty || component.link == nil) ? true : false
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.link != nil ? environment.strings.SendInviteLink_InviteTitle : environment.strings.SendInviteLink_LinkUnavailableTitle, font: Font.semibold(17.0), textColor: environment.theme.list.itemPrimaryTextColor))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - leftButtonFrame.maxX * 2.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: 18.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.navigationBarContainer.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            contentHeight += 44.0
            
            contentHeight += 22.0
            
            let iconBackgroundSize = CGSize(width: 68.0, height: 48.0)
            let iconBackgroundFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - iconBackgroundSize.width) * 0.5), y: contentHeight), size: iconBackgroundSize)
            transition.setFrame(view: self.iconBackgroundView, frame: iconBackgroundFrame)
            transition.setCornerRadius(layer: self.iconBackgroundView.layer, cornerRadius: min(iconBackgroundFrame.width, iconBackgroundFrame.height) * 0.5)
            if let icon = self.iconView.image {
                let scaleFraction: CGFloat = 0.5
                let iconSize = CGSize(width: floor(icon.size.width * scaleFraction), height: floor(icon.size.height * scaleFraction))
                transition.setFrame(view: self.iconView, frame: CGRect(origin: CGPoint(x: floor(iconBackgroundFrame.minX + (iconBackgroundFrame.width - iconSize.width) * 0.5), y: floor(iconBackgroundFrame.minY + (iconBackgroundFrame.height - iconSize.height) * 0.5)), size: iconSize))
            }
            
            contentHeight += iconBackgroundSize.height
            
            contentHeight += 26.0
            
            let text: String
            if component.link != nil {
                if component.peers.count == 1 {
                    text = environment.strings.SendInviteLink_TextAvailableSingleUser(component.peers[0].displayTitle(strings: environment.strings, displayOrder: .firstLast)).string
                } else {
                    text = environment.strings.SendInviteLink_TextAvailableMultipleUsers(Int32(component.peers.count))
                }
            } else {
                if component.peers.count == 1 {
                    text = environment.strings.SendInviteLink_TextUnavailableSingleUser(component.peers[0].displayTitle(strings: environment.strings, displayOrder: .firstLast)).string
                } else {
                    text = environment.strings.SendInviteLink_TextUnavailableMultipleUsers(Int32(component.peers.count))
                }
            }
            
            let body = MarkdownAttributeSet(font: Font.regular(15.0), textColor: environment.theme.list.freeTextColor)
            let bold = MarkdownAttributeSet(font: Font.semibold(15.0), textColor: environment.theme.list.freeTextColor)
            
            let descriptionTextSize = self.descriptionText.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .markdown(text: text, attributes: MarkdownAttributes(
                        body: body,
                        bold: bold,
                        link: body,
                        linkAttribute: { _ in nil }
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 16.0 * 2.0, height: 1000.0)
            )
            let descriptionTextFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - descriptionTextSize.width) * 0.5), y: contentHeight), size: descriptionTextSize)
            if let descriptionTextView = self.descriptionText.view {
                if descriptionTextView.superview == nil {
                    self.scrollContentView.addSubview(descriptionTextView)
                }
                transition.setFrame(view: descriptionTextView, frame: descriptionTextFrame)
            }
            
            contentHeight += descriptionTextFrame.height
            contentHeight += 13.0
            
            var singleItemHeight: CGFloat = 0.0
            
            var itemsHeight: CGFloat = 0.0
            var validIds: [AnyHashable] = []
            for i in 0 ..< component.peers.count {
                let peer = component.peers[i]
                
                for _ in 0 ..< 1 {
                    //let id: AnyHashable = AnyHashable("\(peer.id)_\(j)")
                    let id = AnyHashable(peer.id)
                    validIds.append(id)
                    
                    let item: ComponentView<Empty>
                    var itemTransition = transition
                    if let current = self.items[id] {
                        item = current
                    } else {
                        itemTransition = .immediate
                        item = ComponentView()
                        self.items[id] = item
                    }
                    
                    let itemSize = item.update(
                        transition: itemTransition,
                        component: AnyComponent(PeerListItemComponent(
                            context: component.context,
                            theme: environment.theme,
                            strings: environment.strings,
                            sideInset: 0.0,
                            title: peer.displayTitle(strings: environment.strings, displayOrder: .firstLast),
                            peer: peer,
                            presence: component.peerPresences[peer.id],
                            selectionState: component.link == nil ? .none : .editing(isSelected: self.selectedItems.contains(peer.id)),
                            hasNext: i != component.peers.count - 1,
                            action: { [weak self] peer in
                                guard let self else {
                                    return
                                }
                                if self.selectedItems.contains(peer.id) {
                                    self.selectedItems.remove(peer.id)
                                } else {
                                    self.selectedItems.insert(peer.id)
                                }
                                self.state?.updated(transition: Transition(animation: .curve(duration: 0.3, curve: .easeInOut)))
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                    )
                    let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: itemsHeight), size: itemSize)
                    
                    if let itemView = item.view {
                        if itemView.superview == nil {
                            self.itemContainerView.addSubview(itemView)
                        }
                        itemTransition.setFrame(view: itemView, frame: itemFrame)
                    }
                    
                    itemsHeight += itemSize.height
                    singleItemHeight = itemSize.height
                }
            }
            var removeIds: [AnyHashable] = []
            for (id, item) in self.items {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    item.view?.removeFromSuperview()
                }
            }
            for id in removeIds {
                self.items.removeValue(forKey: id)
            }
            transition.setFrame(view: self.itemContainerView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: CGSize(width: availableSize.width - sideInset * 2.0, height: itemsHeight)))
            
            var initialContentHeight = contentHeight
            initialContentHeight += min(itemsHeight, floor(singleItemHeight * 2.5))
            
            contentHeight += itemsHeight
            contentHeight += 24.0
            initialContentHeight += 24.0
            
            let actionButtonTitle: String
            if component.link != nil {
                actionButtonTitle = self.selectedItems.isEmpty ? environment.strings.SendInviteLink_ActionSkip : environment.strings.SendInviteLink_ActionInvite
            } else {
                actionButtonTitle = environment.strings.SendInviteLink_ActionClose
            }
            
            let actionButtonSize = self.actionButton.update(
                transition: transition,
                component: AnyComponent(SolidRoundedButtonComponent(
                    title: actionButtonTitle,
                    badge: (self.selectedItems.isEmpty || component.link == nil) ? nil : "\(self.selectedItems.count)",
                    theme: SolidRoundedButtonComponent.Theme(theme: environment.theme),
                    font: .bold,
                    fontSize: 17.0,
                    height: 50.0,
                    cornerRadius: 11.0,
                    gloss: false,
                    animationName: nil,
                    iconPosition: .right,
                    iconSpacing: 4.0,
                    action: { [weak self] in
                        guard let self, let component = self.component, let controller = self.environment?.controller() else {
                            return
                        }
                        if self.selectedItems.isEmpty {
                            controller.dismiss()
                        } else if let link = component.link {
                            let selectedPeers = component.peers.filter { self.selectedItems.contains($0.id) }
                            
                            let _ = enqueueMessagesToMultiplePeers(account: component.context.account, peerIds: Array(self.selectedItems), threadIds: [:], messages: [.message(text: link, attributes: [], inlineStickers: [:], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])]).start()
                            let text: String
                            if selectedPeers.count == 1 {
                                text = environment.strings.Conversation_ShareLinkTooltip_Chat_One(selectedPeers[0].displayTitle(strings: environment.strings, displayOrder: .firstLast).replacingOccurrences(of: "*", with: "")).string
                            } else if selectedPeers.count == 2 {
                                text = environment.strings.Conversation_ShareLinkTooltip_TwoChats_One(selectedPeers[0].displayTitle(strings: environment.strings, displayOrder: .firstLast).replacingOccurrences(of: "*", with: ""), selectedPeers[1].displayTitle(strings: environment.strings, displayOrder: .firstLast).replacingOccurrences(of: "*", with: "")).string
                            } else {
                                text = environment.strings.Conversation_ShareLinkTooltip_ManyChats_One(selectedPeers[0].displayTitle(strings: environment.strings, displayOrder: .firstLast).replacingOccurrences(of: "*", with: ""), "\(selectedPeers.count - 1)").string
                            }
                            
                            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                            controller.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: false, text: text), elevatedLayout: false, action: { _ in return false }), in: .window(.root))
                            
                            controller.dismiss()
                        } else {
                            controller.dismiss()
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
            )
            let bottomPanelHeight = 14.0 + environment.safeInsets.bottom + actionButtonSize.height
            let actionButtonFrame = CGRect(origin: CGPoint(x: sideInset, y: availableSize.height - bottomPanelHeight), size: actionButtonSize)
            if let actionButtonView = self.actionButton.view {
                if actionButtonView.superview == nil {
                    self.addSubview(actionButtonView)
                }
                transition.setFrame(view: actionButtonView, frame: actionButtonFrame)
            }
            
            contentHeight += bottomPanelHeight
            initialContentHeight += bottomPanelHeight
            
            let containerInset: CGFloat = environment.statusBarHeight + 10.0
            let topInset: CGFloat = max(0.0, availableSize.height - containerInset - initialContentHeight)
            
            let scrollContentHeight = max(topInset + contentHeight, availableSize.height - containerInset)
            
            self.scrollContentClippingView.layer.cornerRadius = 10.0
            
            self.itemLayout = ItemLayout(containerSize: availableSize, containerInset: containerInset, bottomInset: environment.safeInsets.bottom, topInset: topInset)
            
            transition.setFrame(view: self.scrollContentView, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset + containerInset), size: CGSize(width: availableSize.width, height: contentHeight)))
            
            transition.setPosition(layer: self.backgroundLayer, position: CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0))
            transition.setBounds(layer: self.backgroundLayer, bounds: CGRect(origin: CGPoint(), size: availableSize))
            
            let scrollClippingFrame = CGRect(origin: CGPoint(x: sideInset, y: containerInset + 56.0), size: CGSize(width: availableSize.width - sideInset * 2.0, height: actionButtonFrame.minY - 24.0 - (containerInset + 56.0)))
            transition.setPosition(view: self.scrollContentClippingView, position: scrollClippingFrame.center)
            transition.setBounds(view: self.scrollContentClippingView, bounds: CGRect(origin: CGPoint(x: scrollClippingFrame.minX, y: scrollClippingFrame.minY), size: scrollClippingFrame.size))
            
            self.ignoreScrolling = true
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: availableSize.height - containerInset)))
            let contentSize = CGSize(width: availableSize.width, height: scrollContentHeight)
            if contentSize != self.scrollView.contentSize {
                self.scrollView.contentSize = contentSize
            }
            if resetScrolling {
                self.scrollView.bounds = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: availableSize)
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public class SendInviteLinkScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private let link: String?
    private let peers: [EnginePeer]
    
    private var isDismissed: Bool = false
    
    private var presenceDisposable: Disposable?
    
    public init(context: AccountContext, peer: EnginePeer, link: String?, peers: [EnginePeer]) {
        self.context = context
        
        var link = link
        if link == nil, let addressName = peer.addressName {
            link = "https://t.me/\(addressName)"
        }
        
        self.link = link
        self.peers = peers
        
        super.init(context: context, component: SendInviteLinkScreenComponent(context: context, link: link, peers: peers, peerPresences: [:]), navigationBarAppearance: .none)
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
        
        self.presenceDisposable = (context.engine.data.subscribe(EngineDataMap(
            peers.map(\.id).map(TelegramEngine.EngineData.Item.Peer.Presence.init(id:))
        ))
        |> deliverOnMainQueue).start(next: { [weak self] presences in
            guard let self else {
                return
            }
            var parsedPresences: [EnginePeer.Id: EnginePeer.Presence] = [:]
            for (id, presence) in presences {
                if let presence {
                    parsedPresences[id] = presence
                }
            }
            self.updateComponent(component: AnyComponent(SendInviteLinkScreenComponent(context: context, link: link, peers: peers, peerPresences: parsedPresences)), transition: .immediate)
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presenceDisposable?.dispose()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveModalDismiss = true
        
        if let componentView = self.node.hostView.componentView as? SendInviteLinkScreenComponent.View {
            componentView.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
            
            if let componentView = self.node.hostView.componentView as? SendInviteLinkScreenComponent.View {
                componentView.animateOut(completion: { [weak self] in
                    completion?()
                    self?.dismiss(animated: false)
                })
            } else {
                self.dismiss(animated: false)
            }
        }
    }
}
