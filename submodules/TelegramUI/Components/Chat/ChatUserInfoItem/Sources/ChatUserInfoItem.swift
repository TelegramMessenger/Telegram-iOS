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
import UniversalMediaPlayer
import TelegramUniversalVideoContent
import WallpaperBackgroundNode
import ChatControllerInteraction
import ChatMessageBubbleContentNode
import CountrySelectionUI
import TelegramStringFormatting

public final class ChatUserInfoItem: ListViewItem {
    fileprivate let title: String
    fileprivate let registrationDate: String?
    fileprivate let phoneCountry: String?
    fileprivate let locationCountry: String?
    fileprivate let groupsInCommon: [EnginePeer]
    fileprivate let controllerInteraction: ChatControllerInteraction
    fileprivate let presentationData: ChatPresentationData
    fileprivate let context: AccountContext
    
    public init(
        title: String,
        registrationDate: String?,
        phoneCountry: String?,
        locationCountry: String?,
        groupsInCommon: [EnginePeer],
        controllerInteraction: ChatControllerInteraction,
        presentationData: ChatPresentationData,
        context: AccountContext
    ) {
        self.title = title
        self.registrationDate = registrationDate
        self.phoneCountry = phoneCountry
        self.locationCountry = locationCountry
        self.groupsInCommon = groupsInCommon
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

public final class ChatUserInfoItemNode: ListViewItemNode {
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
    
    private let locationCountryTitleTextNode: TextNode
    private let locationCountryValueTextNode: TextNode
    private var locationCountryText: String?
    
    private let groupsTextNode: TextNode
    
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
        
        self.locationCountryTitleTextNode = TextNode()
        self.locationCountryTitleTextNode.isUserInteractionEnabled = false
        self.locationCountryTitleTextNode.displaysAsynchronously = false
        self.locationCountryValueTextNode = TextNode()
        self.locationCountryValueTextNode.isUserInteractionEnabled = false
        self.locationCountryValueTextNode.displaysAsynchronously = false
        
        self.groupsTextNode = TextNode()
        self.groupsTextNode.isUserInteractionEnabled = false
        self.groupsTextNode.displaysAsynchronously = false
        
        super.init(layerBacked: false, dynamicBounce: true, rotated: true)
        
        self.transform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
        
        self.addSubnode(self.offsetContainer)
        self.offsetContainer.addSubnode(self.titleNode)
        self.offsetContainer.addSubnode(self.subtitleNode)
        self.offsetContainer.addSubnode(self.groupsTextNode)
        self.wantsTrailingItemSpaceUpdates = true
    }
            
    override public func didLoad() {
        super.didLoad()
        
//        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
//        recognizer.tapActionAtPoint = { [weak self] point in
//            if let strongSelf = self {
//                let tapAction = strongSelf.tapActionAtPoint(point, gesture: .tap, isEstimating: true)
//                switch tapAction.content {
//                case .none:
//                    break
//                case .ignore:
//                    return .fail
//                case .url, .phone, .peerMention, .textMention, .botCommand, .hashtag, .instantPage, .wallpaper, .theme, .call, .openMessage, .timecode, .bankCard, .tooltip, .openPollResults, .copy, .largeEmoji, .customEmoji, .custom:
//                    return .waitForSingleTap
//                }
//            }
//            
//            return .waitForDoubleTap
//        }
//        recognizer.highlight = { [weak self] point in
//            if let strongSelf = self {
//                strongSelf.updateTouchesAtPoint(point)
//            }
//        }
//        self.view.addGestureRecognizer(recognizer)
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
    
    public func asyncLayout() -> (_ item: ChatUserInfoItem, _ width: ListViewItemLayoutParams) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        let makeRegistrationDateTitleLayout = TextNode.asyncLayout(self.registrationDateTitleTextNode)
        let makeRegistrationDateValueLayout = TextNode.asyncLayout(self.registrationDateValueTextNode)
        let makePhoneCountryTitleLayout = TextNode.asyncLayout(self.phoneCountryTitleTextNode)
        let makePhoneCountryValueLayout = TextNode.asyncLayout(self.phoneCountryValueTextNode)
        let makeLocationCountryTitleLayout = TextNode.asyncLayout(self.locationCountryTitleTextNode)
        let makeLocationCountryValueLayout = TextNode.asyncLayout(self.locationCountryValueTextNode)
        let makeGroupsLayout = TextNode.asyncLayout(self.groupsTextNode)
        
        let currentRegistrationDateText = self.registrationDateText
        let currentPhoneCountryText = self.phoneCountryText
        let currentLocationCountryText = self.locationCountryText
        
        return { [weak self] item, params in
            self?.item = item
                  
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
            //TODO:localize
            let constrainedWidth = params.width - (horizontalInset + horizontalContentInset) * 2.0
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: Font.semibold(15.0), textColor: primaryTextColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: constrainedWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            backgroundSize.height += titleLayout.size.height
            backgroundSize.height += verticalSpacing
            
            let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "Not a contact", font: Font.regular(13.0), textColor: subtitleColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: constrainedWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            backgroundSize.height += subtitleLayout.size.height
            backgroundSize.height += verticalSpacing + paragraphSpacing
            
            let infoConstrainedSize = CGSize(width: constrainedWidth * 0.7, height: CGFloat.greatestFiniteMagnitude)
            
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
                registrationDateTitleLayoutAndApply = makeRegistrationDateTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "Registration", font: Font.regular(13.0), textColor: subtitleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: infoConstrainedSize, alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                registrationDateValueLayoutAndApply = makeRegistrationDateValueLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: registrationDateText ?? "", font: Font.semibold(13.0), textColor: primaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: infoConstrainedSize, alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                backgroundSize.height += verticalSpacing
                backgroundSize.height += registrationDateValueLayoutAndApply?.0.size.height ?? 0
                
                backgroundSize.width = max(backgroundSize.width, horizontalContentInset * 2.0 + (registrationDateTitleLayoutAndApply?.0.size.width ?? 0) + attributeSpacing + (registrationDateValueLayoutAndApply?.0.size.width ?? 0))
            } else {
                registrationDateTitleLayoutAndApply = nil
                registrationDateValueLayoutAndApply = nil
            }
            
            var phoneCountryText: String?
            let phoneCountryTitleLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            let phoneCountryValueLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            if let phoneCountry = item.phoneCountry {
                if let currentPhoneCountryText {
                    phoneCountryText = currentPhoneCountryText
                } else {
                    var countryName = ""
                    let countriesConfiguration = item.context.currentCountriesConfiguration.with { $0 }
                    if let country = countriesConfiguration.countries.first(where: { $0.id == phoneCountry }) {
                        countryName = country.localizedName ?? country.name
                    }
                    phoneCountryText = emojiFlagForISOCountryCode(phoneCountry) + " " + countryName
                }
                phoneCountryTitleLayoutAndApply = makePhoneCountryTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "Phone Number", font: Font.regular(13.0), textColor: subtitleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: infoConstrainedSize, alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                phoneCountryValueLayoutAndApply = makePhoneCountryValueLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: phoneCountryText ?? "", font: Font.semibold(13.0), textColor: primaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: infoConstrainedSize, alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                backgroundSize.height += verticalSpacing
                backgroundSize.height += phoneCountryValueLayoutAndApply?.0.size.height ?? 0
                
                backgroundSize.width = max(backgroundSize.width, horizontalContentInset * 2.0 + (phoneCountryTitleLayoutAndApply?.0.size.width ?? 0) + attributeSpacing + (phoneCountryValueLayoutAndApply?.0.size.width ?? 0))
            } else {
                phoneCountryTitleLayoutAndApply = nil
                phoneCountryValueLayoutAndApply = nil
            }
            
            var locationCountryText: String?
            let locationCountryTitleLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            let locationCountryValueLayoutAndApply: (TextNodeLayout, () -> TextNode)?
            if let locationCountry = item.locationCountry {
                if let currentLocationCountryText {
                    locationCountryText = currentLocationCountryText
                } else {
                    var countryName = ""
                    let countriesConfiguration = item.context.currentCountriesConfiguration.with { $0 }
                    if let country = countriesConfiguration.countries.first(where: { $0.id == locationCountry }) {
                        countryName = country.localizedName ?? country.name
                    }
                    locationCountryText = emojiFlagForISOCountryCode(locationCountry) + " " + countryName
                }
                locationCountryTitleLayoutAndApply = makeLocationCountryTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "Location", font: Font.regular(13.0), textColor: subtitleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: infoConstrainedSize, alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                locationCountryValueLayoutAndApply = makeLocationCountryValueLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: locationCountryText ?? "", font: Font.semibold(13.0), textColor: primaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: infoConstrainedSize, alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                backgroundSize.height += verticalSpacing
                backgroundSize.height += locationCountryValueLayoutAndApply?.0.size.height ?? 0
                
                backgroundSize.width = max(backgroundSize.width, horizontalContentInset * 2.0 + (locationCountryTitleLayoutAndApply?.0.size.width ?? 0) + attributeSpacing + (locationCountryValueLayoutAndApply?.0.size.width ?? 0))
            } else {
                locationCountryTitleLayoutAndApply = nil
                locationCountryValueLayoutAndApply = nil
            }
            
            let (groupsLayout, groupsApply) = makeGroupsLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "No groups in common", font: Font.regular(13.0), textColor: subtitleColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: constrainedWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            backgroundSize.height += verticalSpacing * 2.0 + paragraphSpacing
            backgroundSize.height += groupsLayout.size.height
            
            backgroundSize.height += verticalInset
         
            let backgroundFrame = CGRect(origin: CGPoint(x: floor((params.width - backgroundSize.width) / 2.0), y: verticalItemInset + 4.0), size: backgroundSize)

            let itemLayout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: backgroundSize.height + verticalItemInset * 2.0), insets: UIEdgeInsets())
            return (itemLayout, { _ in
                if let strongSelf = self {
                    strongSelf.theme = item.presentationData.theme
                    
                    if item.presentationData.theme.theme.overallDarkAppearance {
                        strongSelf.registrationDateTitleTextNode.layer.compositingFilter = nil
                        strongSelf.phoneCountryTitleTextNode.layer.compositingFilter = nil
                        strongSelf.locationCountryTitleTextNode.layer.compositingFilter = nil
                        strongSelf.subtitleNode.layer.compositingFilter = nil
                        strongSelf.groupsTextNode.layer.compositingFilter = nil
                    } else {
                        strongSelf.registrationDateTitleTextNode.layer.compositingFilter = "overlayBlendMode"
                        strongSelf.phoneCountryTitleTextNode.layer.compositingFilter = "overlayBlendMode"
                        strongSelf.locationCountryTitleTextNode.layer.compositingFilter = "overlayBlendMode"
                        strongSelf.subtitleNode.layer.compositingFilter = "overlayBlendMode"
                        strongSelf.groupsTextNode.layer.compositingFilter = "overlayBlendMode"
                    }
                    
                    strongSelf.registrationDateText = registrationDateText
                    strongSelf.phoneCountryText = phoneCountryText
                    strongSelf.locationCountryText = locationCountryText
                                        
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
                    
                    func appendAttributeMidpoint(titleLayout: TextNodeLayout?, valueLayout: TextNodeLayout?) {
                        if let titleLayout, let valueLayout {
                            let totalWidth = titleLayout.size.width + attributeSpacing + valueLayout.size.width
                            let titleOffset = titleLayout.size.width + attributeSpacing / 2.0
                            let midpoint = (backgroundSize.width - totalWidth) / 2.0 + titleOffset
                            attributeMidpoints.append(midpoint)
                        }
                    }
                    appendAttributeMidpoint(titleLayout: registrationDateTitleLayoutAndApply?.0, valueLayout: registrationDateValueLayoutAndApply?.0)
                    appendAttributeMidpoint(titleLayout: phoneCountryTitleLayoutAndApply?.0, valueLayout: phoneCountryValueLayoutAndApply?.0)
                    appendAttributeMidpoint(titleLayout: locationCountryTitleLayoutAndApply?.0, valueLayout: locationCountryValueLayoutAndApply?.0)
                    
                    let middleX = floorToScreenPixels(attributeMidpoints.isEmpty ? backgroundSize.width / 2.0 : attributeMidpoints.reduce(0, +) / CGFloat(attributeMidpoints.count))
                    
                    let titleMaxX: CGFloat = backgroundFrame.minX + middleX - attributeSpacing / 2.0
                    let valueMinX: CGFloat = backgroundFrame.minX + middleX + attributeSpacing / 2.0
                  
                    func positionAttributeNodes(
                        titleTextNode: TextNode,
                        valueTextNode: TextNode,
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
                                origin: CGPoint(x: valueMinX, y: contentOriginY),
                                size: valueLayout.size
                            )
                            contentOriginY += valueLayout.size.height + verticalSpacing
                        }
                    }
                    
                    positionAttributeNodes(
                        titleTextNode: strongSelf.registrationDateTitleTextNode,
                        valueTextNode: strongSelf.registrationDateValueTextNode,
                        titleLayoutAndApply: registrationDateTitleLayoutAndApply,
                        valueLayoutAndApply: registrationDateValueLayoutAndApply
                    )
                    positionAttributeNodes(
                        titleTextNode: strongSelf.phoneCountryTitleTextNode,
                        valueTextNode: strongSelf.phoneCountryValueTextNode,
                        titleLayoutAndApply: phoneCountryTitleLayoutAndApply,
                        valueLayoutAndApply: phoneCountryValueLayoutAndApply
                    )
                    positionAttributeNodes(
                        titleTextNode: strongSelf.locationCountryTitleTextNode,
                        valueTextNode: strongSelf.locationCountryValueTextNode,
                        titleLayoutAndApply: locationCountryTitleLayoutAndApply,
                        valueLayoutAndApply: locationCountryValueLayoutAndApply
                    )
                    
                    contentOriginY += verticalSpacing + paragraphSpacing
                    let _ = groupsApply()
                    let groupsFrame = CGRect(origin: CGPoint(x: backgroundFrame.origin.x + floor((backgroundSize.width - groupsLayout.size.width) / 2.0), y: contentOriginY), size: groupsLayout.size)
                    strongSelf.groupsTextNode.frame = groupsFrame
                    
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
        
//    public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
//        let textNodeFrame = self.textNode.frame
//        if let (index, attributes) = self.textNode.attributesAtPoint(CGPoint(x: point.x - self.offsetContainer.frame.minX - textNodeFrame.minX, y: point.y - self.offsetContainer.frame.minY - textNodeFrame.minY)) {
//            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
//                var concealed = true
//                if let (attributeText, fullText) = self.textNode.attributeSubstring(name: TelegramTextAttributes.URL, index: index) {
//                    concealed = !doesUrlMatchText(url: url, text: attributeText, fullText: fullText)
//                }
//                return ChatMessageBubbleContentTapAction(content: .url(ChatMessageBubbleContentTapAction.Url(url: url, concealed: concealed)))
//            } else if let peerMention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
//                return ChatMessageBubbleContentTapAction(content: .peerMention(peerId: peerMention.peerId, mention: peerMention.mention, openProfile: false))
//            } else if let peerName = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
//                return ChatMessageBubbleContentTapAction(content: .textMention(peerName))
//            } else if let botCommand = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BotCommand)] as? String {
//                return ChatMessageBubbleContentTapAction(content: .botCommand(botCommand))
//            } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
//                return ChatMessageBubbleContentTapAction(content: .hashtag(hashtag.peerName, hashtag.hashtag))
//            } else {
//                return ChatMessageBubbleContentTapAction(content: .none)
//            }
//        } else {
//            return ChatMessageBubbleContentTapAction(content: .none)
//        }
//    }
    
//    @objc private func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
//        switch recognizer.state {
//            case .ended:
//                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
//                    switch gesture {
//                    case .tap:
//                        let tapAction = self.tapActionAtPoint(location, gesture: gesture, isEstimating: false)
//                        switch tapAction.content {
//                        case .none, .ignore:
//                            break
//                        case let .url(url):
//                            self.item?.controllerInteraction.openUrl(ChatControllerInteraction.OpenUrl(url: url.url, concealed: url.concealed, progress: tapAction.activate?()))
//                        case let .peerMention(peerId, _, _):
//                            if let item = self.item {
//                                let _ = (item.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
//                                |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
//                                    if let peer = peer {
//                                        self?.item?.controllerInteraction.openPeer(peer, .chat(textInputState: nil, subject: nil, peekData: nil), nil, .default)
//                                    }
//                                })
//                            }
//                        case let .textMention(name):
//                            self.item?.controllerInteraction.openPeerMention(name, tapAction.activate?())
//                        case let .botCommand(command):
//                            self.item?.controllerInteraction.sendBotCommand(nil, command)
//                        case let .hashtag(peerName, hashtag):
//                            self.item?.controllerInteraction.openHashtag(peerName, hashtag)
//                        default:
//                            break
//                            }
//                        case .longTap, .doubleTap:
//                            if let item = self.item, self.backgroundNode.frame.contains(location) {
//                                let tapAction = self.tapActionAtPoint(location, gesture: gesture, isEstimating: false)
//                                switch tapAction.content {
//                                case .none, .ignore:
//                                    break
//                                case let .url(url):
//                                    item.controllerInteraction.longTap(.url(url.url), ChatControllerInteraction.LongTapParams())
//                                case let .peerMention(peerId, mention, _):
//                                    item.controllerInteraction.longTap(.peerMention(peerId, mention), ChatControllerInteraction.LongTapParams())
//                                case let .textMention(name):
//                                    item.controllerInteraction.longTap(.mention(name), ChatControllerInteraction.LongTapParams())
//                                case let .botCommand(command):
//                                    item.controllerInteraction.longTap(.command(command), ChatControllerInteraction.LongTapParams())
//                                case let .hashtag(_, hashtag):
//                                    item.controllerInteraction.longTap(.hashtag(hashtag), ChatControllerInteraction.LongTapParams())
//                                default:
//                                    break
//                                }
//                            }
//                        default:
//                            break
//                    }
//                }
//            default:
//                break
//        }
//    }
}
