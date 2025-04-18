import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TextFormat
import UrlEscaping
import PhotoResources
import AccountContext
import WallpaperBackgroundNode
import ChatControllerInteraction
import ChatMessageBubbleContentNode
import CountrySelectionUI
import TelegramStringFormatting
import MergedAvatarsNode
import ChatControllerInteraction
import TextNodeWithEntities

public final class ChatUserInfoItem: ListViewItem {
    fileprivate let peer: EnginePeer
    fileprivate let verification: PeerVerification?
    fileprivate let registrationDate: String?
    fileprivate let phoneCountry: String?
    fileprivate let groupsInCommonCount: Int32
    fileprivate let controllerInteraction: ChatControllerInteraction
    fileprivate let presentationData: ChatPresentationData
    fileprivate let context: AccountContext
    
    public init(
        peer: EnginePeer,
        verification: PeerVerification?,
        registrationDate: String?,
        phoneCountry: String?,
        groupsInCommonCount: Int32,
        controllerInteraction: ChatControllerInteraction,
        presentationData: ChatPresentationData,
        context: AccountContext
    ) {
        self.peer = peer
        self.verification = verification
        self.registrationDate = registrationDate
        self.phoneCountry = phoneCountry
        self.groupsInCommonCount = groupsInCommonCount
        self.controllerInteraction = controllerInteraction
        self.presentationData = presentationData
        self.context = context
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        let configure = {
            let node = ChatUserInfoItemNode()
            
            let nodeLayout = node.asyncLayout()
            let (layout, apply) = nodeLayout(self, params)
            
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
            if let nodeValue = node() as? ChatUserInfoItemNode {
                let nodeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = nodeLayout(self, params)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(animation)
                        })
                    }
                }
            }
        }
    }
}

public final class ChatUserInfoItemNode: ListViewItemNode, ASGestureRecognizerDelegate {
    public var controllerInteraction: ChatControllerInteraction?
    
    public let offsetContainer: ASDisplayNode
    public let titleNode: TextNode
    public let subtitleNode: TextNode
    
    private let registrationDateTitleTextNode: TextNode
    private let registrationDateValueTextNode: TextNode
    private var registrationDateText: String?
    
    private let phoneCountryTitleTextNode: TextNode
    private let phoneCountryValueTextNode: TextNode
    private var phoneCountryText: String?
    
    private let groupsTitleTextNode: TextNode
    private let groupsValueTextNode: TextNode
    private let groupsButtonNode: HighlightTrackingButtonNode
    private let groupsAvatarsNode: MergedAvatarsNode
    private let groupsArrowNode: ASImageNode
    
    private var groupsInCommonContext: GroupsInCommonContext?
    private var groupsInCommonDisposable: Disposable?
    private var groupsInCommon: [Peer] = []
    
    private let disclaimerTextNode: TextNodeWithEntities
    
    private var theme: ChatPresentationThemeData?
    
    private var wallpaperBackgroundNode: WallpaperBackgroundNode?
    private var backgroundContent: WallpaperBubbleBackgroundNode?
    
    private var absolutePosition: (CGRect, CGSize)?
    
    private var item: ChatUserInfoItem?
    
    public init() {
        self.offsetContainer = ASDisplayNode()
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.subtitleNode = TextNode()
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.displaysAsynchronously = false
        
        self.registrationDateTitleTextNode = TextNode()
        self.registrationDateTitleTextNode.isUserInteractionEnabled = false
        self.registrationDateTitleTextNode.displaysAsynchronously = false
        self.registrationDateValueTextNode = TextNode()
        self.registrationDateValueTextNode.isUserInteractionEnabled = false
        self.registrationDateValueTextNode.displaysAsynchronously = false
        
        self.phoneCountryTitleTextNode = TextNode()
        self.phoneCountryTitleTextNode.isUserInteractionEnabled = false
        self.phoneCountryTitleTextNode.displaysAsynchronously = false
        self.phoneCountryValueTextNode = TextNode()
        self.phoneCountryValueTextNode.isUserInteractionEnabled = false
        self.phoneCountryValueTextNode.displaysAsynchronously = false
        
        self.groupsTitleTextNode = TextNode()
        self.groupsTitleTextNode.isUserInteractionEnabled = false
        self.groupsTitleTextNode.displaysAsynchronously = false
        self.groupsValueTextNode = TextNode()
        self.groupsValueTextNode.isUserInteractionEnabled = false
        self.groupsValueTextNode.displaysAsynchronously = false
        
        self.groupsAvatarsNode = MergedAvatarsNode()
        
        self.groupsArrowNode = ASImageNode()
        self.groupsArrowNode.displaysAsynchronously = false
        
        self.groupsButtonNode = HighlightTrackingButtonNode()
        
        self.disclaimerTextNode = TextNodeWithEntities()
        self.disclaimerTextNode.textNode.isUserInteractionEnabled = false
        self.disclaimerTextNode.textNode.displaysAsynchronously = false
        
        super.init(layerBacked: false, dynamicBounce: true, rotated: true)
        
        self.transform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
        
        self.addSubnode(self.offsetContainer)
        self.offsetContainer.addSubnode(self.titleNode)
        self.offsetContainer.addSubnode(self.subtitleNode)
        self.offsetContainer.addSubnode(self.disclaimerTextNode.textNode)
        self.offsetContainer.addSubnode(self.groupsAvatarsNode)
        self.offsetContainer.addSubnode(self.groupsArrowNode)
        self.offsetContainer.addSubnode(self.groupsButtonNode)
        self.wantsTrailingItemSpaceUpdates = true
        
        self.groupsButtonNode.highligthedChanged = { [weak self] highlighted in
            if let self {
                if highlighted {
                    self.groupsValueTextNode.layer.removeAnimation(forKey: "opacity")
                    self.groupsValueTextNode.alpha = 0.4
                    
                    self.groupsAvatarsNode.layer.removeAnimation(forKey: "opacity")
                    self.groupsAvatarsNode.alpha = 0.4
                    
                    self.groupsArrowNode.layer.removeAnimation(forKey: "opacity")
                    self.groupsArrowNode.alpha = 0.4
                } else {
                    self.groupsValueTextNode.alpha = 1.0
                    self.groupsValueTextNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    
                    self.groupsAvatarsNode.alpha = 1.0
                    self.groupsAvatarsNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    
                    self.groupsArrowNode.alpha = 1.0
                    self.groupsArrowNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.groupsButtonNode.addTarget(self, action: #selector(self.groupsPressed), forControlEvents: .touchUpInside)
    }
                
    override public func didLoad() {
        super.didLoad()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        tapRecognizer.delegate = self.wrappedGestureRecognizerDelegate
        self.offsetContainer.view.addGestureRecognizer(tapRecognizer)
    }
    
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer.view === self.offsetContainer.view {
            let location = gestureRecognizer.location(in: self.offsetContainer.view)
            if let backgroundContent = self.backgroundContent, backgroundContent.frame.contains(location) {
                return true
            }
            return false
        }
        return true
    }
    
    @objc private func tapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
        guard let item = self.item else {
            return
        }
        item.controllerInteraction.openPeer(item.peer, .info(nil), nil, .default)
    }
    
    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        super.updateAbsoluteRect(rect, within: containerSize)
        
        self.absolutePosition = (rect, containerSize)
        if let backgroundContent = self.backgroundContent {
            var backgroundFrame = backgroundContent.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += containerSize.height - rect.minY
            backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
        }
    }
    
    @objc private func groupsPressed() {
        guard let item = self.item else {
            return
        }
        item.controllerInteraction.openPeer(item.peer, .info(ChatControllerInteractionNavigateToPeer.InfoParams(switchToGroupsInCommon: true)), nil, .default)
    }
    
    public func asyncLayout() -> (_ item: ChatUserInfoItem, _ width: ListViewItemLayoutParams) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        let makeRegistrationDateTitleLayout = TextNode.asyncLayout(self.registrationDateTitleTextNode)
        let makeRegistrationDateValueLayout = TextNode.asyncLayout(self.registrationDateValueTextNode)
        let makePhoneCountryTitleLayout = TextNode.asyncLayout(self.phoneCountryTitleTextNode)
        let makePhoneCountryValueLayout = TextNode.asyncLayout(self.phoneCountryValueTextNode)
        let makeGroupsTitleLayout = TextNode.asyncLayout(self.groupsTitleTextNode)
        let makeGroupsValueLayout = TextNode.asyncLayout(self.groupsValueTextNode)
        let makeDisclaimerLayout = TextNodeWithEntities.asyncLayout(self.disclaimerTextNode)

        let currentItem = self.item
        let currentRegistrationDateText = self.registrationDateText
        let currentPhoneCountryText = self.phoneCountryText
        
        return { [weak self] item, params in
            let themeUpdated = item.presentationData.theme !== currentItem?.presentationData.theme
                            
            var backgroundSize = CGSize(width: 240.0, height: 0.0)
            
            let verticalItemInset: CGFloat = 10.0
            let horizontalInset: CGFloat = 10.0 + params.leftInset
            let horizontalContentInset: CGFloat = 16.0
            let verticalInset: CGFloat = 17.0
            let verticalSpacing: CGFloat = 6.0
            let paragraphSpacing: CGFloat = 3.0
            let attributeSpacing: CGFloat = 10.0
            
            let primaryTextColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper).primaryText
            let subtitleColor = primaryTextColor.withAlphaComponent(item.presentationData.theme.theme.overallDarkAppearance ? 0.7 : 0.8)
            
            backgroundSize.height += verticalInset
            
            let constrainedWidth = params.width - (horizontalInset + horizontalContentInset) * 2.0
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.peer.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder), font: Font.semibold(15.0), textColor: primaryTextColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: constrainedWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            backgroundSize.height += titleLayout.size.height
            backgroundSize.height += verticalSpacing
            
            let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Chat_NonContactUser_Subtitle, font: Font.regular(13.0), textColor: subtitleColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: constrainedWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            backgroundSize.height += subtitleLayout.size.height
            backgroundSize.height += verticalSpacing + paragraphSpacing
            
            let infoConstrainedSize = CGSize(width: constrainedWidth * 0.7, height: CGFloat.greatestFiniteMagnitude)
            
            var maxTitleWidth: CGFloat = 0.0
            var maxValueWidth: CGFloat = 0.0
            
            var phoneCountryText: String?
            let phoneCountryTitleLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            let phoneCountryValueLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            if let phoneCountry = item.phoneCountry {
                if let currentPhoneCountryText {
                    phoneCountryText = currentPhoneCountryText
                } else {
                    var countryName = ""
                    let countriesConfiguration = item.context.currentCountriesConfiguration.with { $0 }
                    if phoneCountry == "FT" {
                        countryName = item.presentationData.strings.Chat_NonContactUser_AnonymousNumber
                    } else if let country = countriesConfiguration.countries.first(where: { $0.id == phoneCountry }) {
                        countryName = country.localizedName ?? country.name
                    } else if phoneCountry == "TS" {
                        countryName = "Test"
                    }
                    phoneCountryText = emojiFlagForISOCountryCode(phoneCountry) + " " + countryName
                }
                phoneCountryTitleLayoutAndApply = makePhoneCountryTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Chat_NonContactUser_PhoneNumber, font: Font.regular(13.0), textColor: subtitleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: infoConstrainedSize, alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                phoneCountryValueLayoutAndApply = makePhoneCountryValueLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: phoneCountryText ?? "", font: Font.semibold(13.0), textColor: primaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: infoConstrainedSize, alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                backgroundSize.height += verticalSpacing
                backgroundSize.height += phoneCountryValueLayoutAndApply?.0.size.height ?? 0
                
                maxTitleWidth = max(maxTitleWidth, (phoneCountryTitleLayoutAndApply?.0.size.width ?? 0))
                maxValueWidth = max(maxValueWidth, (phoneCountryValueLayoutAndApply?.0.size.width ?? 0))
            } else {
                phoneCountryTitleLayoutAndApply = nil
                phoneCountryValueLayoutAndApply = nil
            }
            
            var registrationDateText: String?
            let registrationDateTitleLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            let registrationDateValueLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            if let registrationDate = item.registrationDate {
                if let currentRegistrationDateText {
                    registrationDateText = currentRegistrationDateText
                } else {
                    let components = registrationDate.components(separatedBy: ".")
                    if components.count == 2, let first = Int32(components[0]), let second = Int32(components[1]) {
                        let month = first - 1
                        let year = second - 1900
                        registrationDateText = stringForMonth(strings: item.presentationData.strings, month: month, ofYear: year)
                    } else {
                        registrationDateText = ""
                    }
                }
                registrationDateTitleLayoutAndApply = makeRegistrationDateTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Chat_NonContactUser_Registration, font: Font.regular(13.0), textColor: subtitleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: infoConstrainedSize, alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                registrationDateValueLayoutAndApply = makeRegistrationDateValueLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: registrationDateText ?? "", font: Font.semibold(13.0), textColor: primaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: infoConstrainedSize, alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                backgroundSize.height += verticalSpacing
                backgroundSize.height += registrationDateValueLayoutAndApply?.0.size.height ?? 0
                
                maxTitleWidth = max(maxTitleWidth, (registrationDateTitleLayoutAndApply?.0.size.width ?? 0))
                maxValueWidth = max(maxValueWidth, (registrationDateValueLayoutAndApply?.0.size.width ?? 0))
            } else {
                registrationDateTitleLayoutAndApply = nil
                registrationDateValueLayoutAndApply = nil
            }
            
            let avatarImageSize: CGFloat = 18.0
            let avatarSpacing: CGFloat = 9.0
            let avatarBorder: CGFloat = 1.0
                        
            let groupsValueText: NSMutableAttributedString
            let groupsInCommonCount = item.groupsInCommonCount
            var estimatedValueOffset: CGFloat = 0.0
            if groupsInCommonCount > 0 {
                groupsValueText = NSMutableAttributedString(string: item.presentationData.strings.Chat_NonContactUser_GroupsCount(groupsInCommonCount), font: Font.semibold(13.0), textColor: primaryTextColor)
                estimatedValueOffset = avatarImageSize + CGFloat(min(2, max(0, item.groupsInCommonCount - 1))) * avatarSpacing + 4.0 + 10.0
            } else {
                groupsValueText = NSMutableAttributedString(string: "", font: Font.semibold(13.0), textColor: primaryTextColor)
            }
                
            let groupsTitleLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            let groupsValueLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            if !groupsValueText.string.isEmpty {
                groupsTitleLayoutAndApply = makeGroupsTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Chat_NonContactUser_Groups, font: Font.regular(13.0), textColor: subtitleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: infoConstrainedSize, alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                groupsValueLayoutAndApply = makeGroupsValueLayout(TextNodeLayoutArguments(attributedString: groupsValueText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: infoConstrainedSize, alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                backgroundSize.height += verticalSpacing
                backgroundSize.height += groupsValueLayoutAndApply?.0.size.height ?? 0.0
                
                maxTitleWidth = max(maxTitleWidth, groupsTitleLayoutAndApply?.0.size.width ?? 0)
                maxValueWidth = max(maxValueWidth, (groupsValueLayoutAndApply?.0.size.width ?? 0) + estimatedValueOffset)
            } else {
                groupsTitleLayoutAndApply = nil
                groupsValueLayoutAndApply = nil
            }

            backgroundSize.width = horizontalContentInset * 2.0 + maxTitleWidth + attributeSpacing + maxValueWidth
            
            let disclaimerText: NSMutableAttributedString
            if let verification = item.verification {
                disclaimerText = NSMutableAttributedString(string: " #   \(verification.description)", font: Font.regular(13.0), textColor: subtitleColor)
                if let range = disclaimerText.string.range(of: "#") {
                    disclaimerText.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: verification.iconFileId, file: nil), range: NSRange(range, in: disclaimerText.string))
                    disclaimerText.addAttribute(.foregroundColor, value: subtitleColor, range: NSRange(range, in: disclaimerText.string))
                    disclaimerText.addAttribute(.baselineOffset, value: 2.0, range: NSRange(range, in: disclaimerText.string))
                }
            } else {
                disclaimerText = NSMutableAttributedString(string: " #   \(item.presentationData.strings.Chat_NonContactUser_Disclaimer)", font: Font.regular(13.0), textColor: subtitleColor)
                if let range = disclaimerText.string.range(of: "#") {
                    disclaimerText.addAttribute(.attachment, value: PresentationResourcesChat.chatUserInfoWarningIcon(item.presentationData.theme.theme)!, range: NSRange(range, in: disclaimerText.string))
                    disclaimerText.addAttribute(.foregroundColor, value: subtitleColor, range: NSRange(range, in: disclaimerText.string))
                    disclaimerText.addAttribute(.baselineOffset, value: 2.0, range: NSRange(range, in: disclaimerText.string))
                }
            }
            
            let (disclaimerLayout, disclaimerApply) = makeDisclaimerLayout(TextNodeLayoutArguments(attributedString: disclaimerText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: backgroundSize.width - horizontalContentInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            backgroundSize.height += verticalSpacing * 2.0 + paragraphSpacing
            backgroundSize.height += disclaimerLayout.size.height
            
            backgroundSize.height += verticalInset
         
            let backgroundFrame = CGRect(origin: CGPoint(x: floor((params.width - backgroundSize.width) / 2.0), y: verticalItemInset + 4.0), size: backgroundSize)

            let itemLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: backgroundSize.height + verticalItemInset * 2.0), insets: UIEdgeInsets())
            return (itemLayout, { _ in
                if let strongSelf = self {
                    strongSelf.item = item
                    strongSelf.theme = item.presentationData.theme
                    
                    if themeUpdated {
                        strongSelf.groupsArrowNode.image = generateTintedImage(image: UIImage(bundleImageName: "Contact List/SubtitleArrow"), color: primaryTextColor)
                    }
                                        
                    if item.groupsInCommonCount > 0 {
                        if strongSelf.groupsInCommonContext == nil {
                            let groupsInCommonContext = GroupsInCommonContext(account: item.context.account, peerId: item.peer.id)
                            strongSelf.groupsInCommonContext = groupsInCommonContext
                            strongSelf.groupsInCommonDisposable = (groupsInCommonContext.state
                            |> deliverOnMainQueue).start(next: { [weak self] state in
                                guard let self, let item = self.item else {
                                    return
                                }
                                self.groupsInCommon = Array(state.peers.compactMap { $0.peer }.prefix(3))
                                self.groupsAvatarsNode.update(context: item.context, peers: self.groupsInCommon, synchronousLoad: true, imageSize: avatarImageSize, imageSpacing: avatarSpacing, borderWidth: avatarBorder)
                            })
                        }
                    }
                    
                    if item.presentationData.theme.theme.overallDarkAppearance {
                        strongSelf.registrationDateTitleTextNode.layer.compositingFilter = nil
                        strongSelf.phoneCountryTitleTextNode.layer.compositingFilter = nil
                        strongSelf.groupsTitleTextNode.layer.compositingFilter = nil
                        strongSelf.subtitleNode.layer.compositingFilter = nil
                        strongSelf.disclaimerTextNode.textNode.layer.compositingFilter = nil
                    } else {
                        strongSelf.registrationDateTitleTextNode.layer.compositingFilter = "overlayBlendMode"
                        strongSelf.phoneCountryTitleTextNode.layer.compositingFilter = "overlayBlendMode"
                        strongSelf.groupsTitleTextNode.layer.compositingFilter = "overlayBlendMode"
                        strongSelf.subtitleNode.layer.compositingFilter = "overlayBlendMode"
                        strongSelf.disclaimerTextNode.textNode.layer.compositingFilter = "overlayBlendMode"
                    }
                    
                    strongSelf.registrationDateText = registrationDateText
                    strongSelf.phoneCountryText = phoneCountryText
                                        
                    strongSelf.controllerInteraction = item.controllerInteraction
                    
                    strongSelf.offsetContainer.frame = CGRect(origin: CGPoint(), size: itemLayout.contentSize)
                    
                    let _ = titleApply()
                    var contentOriginY = backgroundFrame.origin.y + verticalInset
                    let titleFrame = CGRect(origin: CGPoint(x: backgroundFrame.origin.x + floor((backgroundSize.width - titleLayout.size.width) / 2.0), y: contentOriginY), size: titleLayout.size)
                    strongSelf.titleNode.frame = titleFrame
                    contentOriginY += titleLayout.size.height
                    contentOriginY += verticalSpacing - paragraphSpacing
                    
                    let _ = subtitleApply()
                    let subtitleFrame = CGRect(origin: CGPoint(x: backgroundFrame.origin.x + floor((backgroundSize.width - subtitleLayout.size.width) / 2.0), y: contentOriginY), size: subtitleLayout.size)
                    strongSelf.subtitleNode.frame = subtitleFrame
                    contentOriginY += subtitleLayout.size.height
                    contentOriginY += verticalSpacing * 2.0 + paragraphSpacing
                    
                    var attributeMidpoints: [CGFloat] = []
                    
                    func appendAttributeMidpoint(titleLayout: TextNodeLayout?, valueLayout: TextNodeLayout?, valueOffset: CGFloat = 0.0) {
                        if let valueLayout {
                            let midpoint = backgroundSize.width - horizontalContentInset - valueLayout.size.width - valueOffset - attributeSpacing / 2.0
                            attributeMidpoints.append(midpoint)
                        }
                    }
                    appendAttributeMidpoint(titleLayout: phoneCountryTitleLayoutAndApply?.0, valueLayout: phoneCountryValueLayoutAndApply?.0)
                    appendAttributeMidpoint(titleLayout: registrationDateTitleLayoutAndApply?.0, valueLayout: registrationDateValueLayoutAndApply?.0)
                    appendAttributeMidpoint(titleLayout: groupsTitleLayoutAndApply?.0, valueLayout: groupsValueLayoutAndApply?.0, valueOffset: estimatedValueOffset)
                    
                    let middleX = floorToScreenPixels(attributeMidpoints.min() ?? backgroundSize.width / 2.0)
                                                      
                    let titleMaxX: CGFloat = backgroundFrame.minX + middleX - attributeSpacing / 2.0
                    let valueMinX: CGFloat = backgroundFrame.minX + middleX + attributeSpacing / 2.0
                  
                    func positionAttributeNodes(
                        titleTextNode: TextNode,
                        valueTextNode: TextNode,
                        valueOffset: CGFloat = 0.0,
                        titleLayoutAndApply: (TextNodeLayout, () -> TextNode)?,
                        valueLayoutAndApply: (TextNodeLayout, () -> TextNode)?
                    ) {
                        if let (titleLayout, titleApply) = titleLayoutAndApply {
                            if titleTextNode.supernode == nil {
                                strongSelf.offsetContainer.addSubnode(titleTextNode)
                            }
                            let _ = titleApply()
                            titleTextNode.frame = CGRect(
                                origin: CGPoint(x: titleMaxX - titleLayout.size.width, y: contentOriginY),
                                size: titleLayout.size
                            )
                        }
                        if let (valueLayout, valueApply) = valueLayoutAndApply {
                            if valueTextNode.supernode == nil {
                                strongSelf.offsetContainer.addSubnode(valueTextNode)
                            }
                            let _ = valueApply()
                            valueTextNode.frame = CGRect(
                                origin: CGPoint(x: valueMinX + valueOffset, y: contentOriginY),
                                size: valueLayout.size
                            )
                            contentOriginY += valueLayout.size.height + verticalSpacing
                        }
                    }
                    
                    positionAttributeNodes(
                        titleTextNode: strongSelf.phoneCountryTitleTextNode,
                        valueTextNode: strongSelf.phoneCountryValueTextNode,
                        titleLayoutAndApply: phoneCountryTitleLayoutAndApply,
                        valueLayoutAndApply: phoneCountryValueLayoutAndApply
                    )
                    positionAttributeNodes(
                        titleTextNode: strongSelf.registrationDateTitleTextNode,
                        valueTextNode: strongSelf.registrationDateValueTextNode,
                        titleLayoutAndApply: registrationDateTitleLayoutAndApply,
                        valueLayoutAndApply: registrationDateValueLayoutAndApply
                    )
                              
                    var valueOffset: CGFloat = 0.0
                    if let groupsValueLayoutAndApply {
                        let avatarsFrame = CGRect(origin: CGPoint(x: valueMinX + groupsValueLayoutAndApply.0.size.width + 4.0, y: contentOriginY + floor((groupsValueLayoutAndApply.0.size.height - avatarImageSize) / 2.0)), size: CGSize(width: avatarImageSize + avatarSpacing * 2.0, height: avatarImageSize))
                        strongSelf.groupsAvatarsNode.frame = avatarsFrame
                        strongSelf.groupsAvatarsNode.updateLayout(size: avatarsFrame.size)
                        strongSelf.groupsAvatarsNode.update(context: item.context, peers: strongSelf.groupsInCommon, synchronousLoad: true, imageSize: avatarImageSize, imageSpacing: avatarSpacing, borderWidth: avatarBorder)
                        
                        if groupsInCommonCount > 0 {
                            valueOffset = avatarImageSize + CGFloat(min(2, max(0, groupsInCommonCount - 1))) * avatarSpacing + 4.0
                            strongSelf.groupsButtonNode.frame = CGRect(origin: CGPoint(x: valueMinX, y: contentOriginY), size: CGSize(width: groupsValueLayoutAndApply.0.size.width + 20.0, height: 18.0))
                            
                            strongSelf.groupsButtonNode.isHidden = false
                            strongSelf.groupsAvatarsNode.isHidden = false
                            strongSelf.groupsArrowNode.isHidden = false
                            
                            if let icon = strongSelf.groupsArrowNode.image {
                                strongSelf.groupsArrowNode.frame = CGRect(origin: CGPoint(x: avatarsFrame.minX + valueOffset, y: contentOriginY + 4.0 - UIScreenPixel), size: icon.size)
                            }
                        } else {
                            strongSelf.groupsAvatarsNode.isHidden = true
                            strongSelf.groupsButtonNode.isHidden = true
                            strongSelf.groupsArrowNode.isHidden = true
                        }
                    }
                    
                    positionAttributeNodes(
                        titleTextNode: strongSelf.groupsTitleTextNode,
                        valueTextNode: strongSelf.groupsValueTextNode,
                        titleLayoutAndApply: groupsTitleLayoutAndApply,
                        valueLayoutAndApply: groupsValueLayoutAndApply
                    )
                    
                    contentOriginY += verticalSpacing + paragraphSpacing
                    let _ = disclaimerApply(TextNodeWithEntities.Arguments(context: item.context, cache: item.context.animationCache, renderer: item.context.animationRenderer, placeholderColor: primaryTextColor.withMultipliedAlpha(0.4), attemptSynchronous: true))
                    let disclaimerFrame = CGRect(origin: CGPoint(x: backgroundFrame.origin.x + floor((backgroundSize.width - disclaimerLayout.size.width) / 2.0), y: contentOriginY), size: disclaimerLayout.size)
                    strongSelf.disclaimerTextNode.textNode.frame = disclaimerFrame
                    
                    if strongSelf.backgroundContent == nil, let backgroundContent = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                        backgroundContent.clipsToBounds = true
                        strongSelf.backgroundContent = backgroundContent
                        strongSelf.offsetContainer.insertSubnode(backgroundContent, at: 0)
                    }
                    
                    if let backgroundContent = strongSelf.backgroundContent {
                        backgroundContent.cornerRadius = item.presentationData.chatBubbleCorners.mainRadius
                        backgroundContent.frame = backgroundFrame
                        if let (rect, containerSize) = strongSelf.absolutePosition {
                            var backgroundFrame = backgroundContent.frame
                            backgroundFrame.origin.x += rect.minX
                            backgroundFrame.origin.y += containerSize.height - rect.minY
                            backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
                        }
                    }
                }
            })
        }
    }
    
    override public func updateTrailingItemSpace(_ height: CGFloat, transition: ContainedViewLayoutTransition) {
        if height.isLessThanOrEqualTo(0.0) {
            transition.updateFrame(node: self.offsetContainer, frame: CGRect(origin: CGPoint(), size: self.offsetContainer.bounds.size))
        } else {
            transition.updateFrame(node: self.offsetContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: -floorToScreenPixels(height / 2.0)), size: self.offsetContainer.bounds.size))
        }
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.5, removeOnCompletion: false)
    }
    
    override public func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let result = super.point(inside: point, with: event)
        let extra = self.offsetContainer.frame.contains(point)
        return result || extra
    }
}
