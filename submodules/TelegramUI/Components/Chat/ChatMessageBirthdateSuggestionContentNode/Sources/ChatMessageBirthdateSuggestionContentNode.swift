import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import TextFormat
import TelegramStringFormatting
import WallpaperBackgroundNode
import Markdown
import ChatMessageBubbleContentNode
import ChatMessageItemCommon
import ChatControllerInteraction
import AnimatedStickerNode
import TelegramAnimatedStickerNode

public class ChatMessageBirthdateSuggestionContentNode: ChatMessageBubbleContentNode {
    private var mediaBackgroundContent: WallpaperBubbleBackgroundNode?
    private let mediaBackgroundNode: NavigationBackgroundNode
    
    private let animationNode: AnimatedStickerNode
    
    private let subtitleNode: TextNode
    
    private let dayTitleNode: TextNode
    private let dayValueNode: TextNode
    
    private let monthTitleNode: TextNode
    private let monthValueNode: TextNode
    
    private let yearTitleNode: TextNode
    private let yearValueNode: TextNode
    
    private let buttonNode: HighlightTrackingButtonNode
    private let buttonTitleNode: TextNode
    
    private var absoluteRect: (CGRect, CGSize)?
    
    required public init() {
        self.mediaBackgroundNode = NavigationBackgroundNode(color: .clear)
        self.mediaBackgroundNode.clipsToBounds = true
        self.mediaBackgroundNode.cornerRadius = 27.0
        
        self.animationNode = DefaultAnimatedStickerNodeImpl()
        
        self.subtitleNode = TextNode()
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.displaysAsynchronously = false
        
        self.dayTitleNode = TextNode()
        self.dayTitleNode.isUserInteractionEnabled = false
        self.dayTitleNode.displaysAsynchronously = false
        
        self.dayValueNode = TextNode()
        self.dayValueNode.isUserInteractionEnabled = false
        self.dayValueNode.displaysAsynchronously = false
        
        self.monthTitleNode = TextNode()
        self.monthTitleNode.isUserInteractionEnabled = false
        self.monthTitleNode.displaysAsynchronously = false
        
        self.monthValueNode = TextNode()
        self.monthValueNode.isUserInteractionEnabled = false
        self.monthValueNode.displaysAsynchronously = false
        
        self.yearTitleNode = TextNode()
        self.yearTitleNode.isUserInteractionEnabled = false
        self.yearTitleNode.displaysAsynchronously = false
        
        self.yearValueNode = TextNode()
        self.yearValueNode.isUserInteractionEnabled = false
        self.yearValueNode.displaysAsynchronously = false
        
        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonNode.clipsToBounds = true
        self.buttonNode.cornerRadius = 17.0
                        
        self.buttonTitleNode = TextNode()
        self.buttonTitleNode.isUserInteractionEnabled = false
        self.buttonTitleNode.displaysAsynchronously = false
        
        super.init()

        self.addSubnode(self.mediaBackgroundNode)
        
        self.addSubnode(self.animationNode)
        
        self.addSubnode(self.subtitleNode)
        
        self.addSubnode(self.dayTitleNode)
        self.addSubnode(self.dayValueNode)
        
        self.addSubnode(self.monthTitleNode)
        self.addSubnode(self.monthValueNode)
        
        self.addSubnode(self.yearTitleNode)
        self.addSubnode(self.yearValueNode)
    
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.buttonTitleNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.buttonNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.buttonNode.alpha = 0.4
                    strongSelf.buttonTitleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.buttonTitleNode.alpha = 0.4
                } else {
                    strongSelf.buttonNode.alpha = 1.0
                    strongSelf.buttonNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.buttonTitleNode.alpha = 1.0
                    strongSelf.buttonTitleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    @objc private func buttonPressed() {
        guard let item = self.item else {
            return
        }
        let _ = item.controllerInteraction.openMessage(item.message, OpenMessageParams(mode: .default))
    }
                
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, unboundSize: CGSize?, maxWidth: CGFloat, layout: (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        
        let makeDayTitleLayout = TextNode.asyncLayout(self.dayTitleNode)
        let makeDayValueLayout = TextNode.asyncLayout(self.dayValueNode)
        let makeMonthTitleLayout = TextNode.asyncLayout(self.monthTitleNode)
        let makeMonthValueLayout = TextNode.asyncLayout(self.monthValueNode)
        let makeYearTitleLayout = TextNode.asyncLayout(self.yearTitleNode)
        let makeYearValueLayout = TextNode.asyncLayout(self.yearValueNode)
        
        let makeButtonTitleLayout = TextNode.asyncLayout(self.buttonTitleNode)
        
        return { item, layoutConstants, _, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: true, headerSpacing: 0.0, hidesBackground: .always, forceFullCorners: false, forceAlignment: .center)
                        
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let width: CGFloat = 186.0
                
                var day: Int32 = 1
                var month: Int32 = 1
                var year: Int32?
                
                if let action = item.message.media.first(where: { $0 is TelegramMediaAction }) as? TelegramMediaAction, case let .suggestedBirthday(birthday) = action.action {
                    day = birthday.day
                    month = birthday.month
                    year = birthday.year
                }
                            
                let primaryTextColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper).primaryText
                let subtitleColor = primaryTextColor.withAlphaComponent(item.presentationData.theme.theme.overallDarkAppearance ? 0.7 : 0.8)
                
                let peerName = item.message.peers[item.message.id.peerId].flatMap { EnginePeer($0).compactDisplayTitle } ?? ""
                let text: String
                
                let fromYou = item.message.author?.id == item.context.account.peerId
                if fromYou {
                    text = item.presentationData.strings.Conversation_SuggestedBirthdateTextYou(peerName).string
                } else {
                    text =  item.presentationData.strings.Conversation_SuggestedBirthdateText(peerName).string
                }
                
                let body = MarkdownAttributeSet(font: Font.regular(13.0), textColor: primaryTextColor)
                let bold = MarkdownAttributeSet(font: Font.semibold(13.0), textColor: primaryTextColor)
                let subtitle = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in
                    return nil
                }), textAlignment: .center)
                
                let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: subtitle, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let titleFont = Font.regular(13.0)
                let valueFont = Font.semibold(13.0)

                let (dayTitleLayout, dayTitleApply) = makeDayTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Conversation_SuggestedBirthdate_Day, font: titleFont, textColor: subtitleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let (dayValueLayout, dayValueApply) = makeDayValueLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "\(day)", font: valueFont, textColor: primaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let (monthTitleLayout, monthTitleApply) = makeMonthTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Conversation_SuggestedBirthdate_Month, font: titleFont, textColor: subtitleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let (monthValueLayout, monthValueApply) = makeMonthValueLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: stringForMonth(strings: item.presentationData.strings, month: month - 1), font: valueFont, textColor: primaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let (yearTitleLayout, yearTitleApply) = makeYearTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Conversation_SuggestedBirthdate_Year, font: titleFont, textColor: subtitleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let (yearValueLayout, yearValueApply) = makeYearValueLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: year.flatMap { "\($0)" } ?? "", font: valueFont, textColor: primaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let (buttonTitleLayout, buttonTitleApply) = makeButtonTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Conversation_SuggestedBirthdate_View, font: Font.semibold(15.0), textColor: primaryTextColor, paragraphAlignment: .center), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
                var backgroundSize = CGSize(width: width, height: subtitleLayout.size.height + 160.0)
                if !fromYou {
                    backgroundSize.height += 44.0
                }
                
                return (backgroundSize.width, { boundingWidth in
                    return (backgroundSize, { [weak self] animation, synchronousLoads, _ in
                        if let strongSelf = self {
                            let isFirstTime = strongSelf.item == nil
                            strongSelf.item = item
                                                                                    
                            let mediaBackgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((backgroundSize.width - width) / 2.0), y: 0.0), size: backgroundSize)
                            strongSelf.mediaBackgroundNode.frame = mediaBackgroundFrame
                                                        
                            strongSelf.mediaBackgroundNode.updateColor(color: selectDateFillStaticColor(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper), enableBlur: item.controllerInteraction.enableFullTranslucency && dateFillNeedsBlur(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper), transition: .immediate)
                            strongSelf.mediaBackgroundNode.update(size: mediaBackgroundFrame.size, transition: .immediate)
                            strongSelf.buttonNode.backgroundColor = item.presentationData.theme.theme.overallDarkAppearance ? UIColor(rgb: 0xffffff, alpha: 0.12) : UIColor(rgb: 0x000000, alpha: 0.12)
                            
                            if item.presentationData.theme.theme.overallDarkAppearance {
                                strongSelf.dayTitleNode.layer.compositingFilter = nil
                                strongSelf.monthTitleNode.layer.compositingFilter = nil
                                strongSelf.yearTitleNode.layer.compositingFilter = nil
                            } else {
                                strongSelf.dayTitleNode.layer.compositingFilter = "overlayBlendMode"
                                strongSelf.monthTitleNode.layer.compositingFilter = "overlayBlendMode"
                                strongSelf.yearTitleNode.layer.compositingFilter = "overlayBlendMode"
                            }
                            
                            let _ = subtitleApply()
                            
                            let _ = dayTitleApply()
                            let _ = monthTitleApply()
                            let _ = yearTitleApply()
                            
                            let _ = dayValueApply()
                            let _ = monthValueApply()
                            let _ = yearValueApply()
                            
                            let _ = buttonTitleApply()
                            
                            let iconSize = CGSize(width: 80.0, height: 80.0)
                    
                            let animationFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - iconSize.width) / 2.0), y: mediaBackgroundFrame.minY + 8.0), size: iconSize)
                            strongSelf.animationNode.frame = animationFrame
                            if isFirstTime {
                                strongSelf.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "Cake"), width: 384, height: 384, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
                                strongSelf.animationNode.visibility = true
                            }
                            strongSelf.animationNode.updateLayout(size: iconSize)
                            
                            let subtitleFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - subtitleLayout.size.width) / 2.0) , y: mediaBackgroundFrame.minY + 96.0), size: subtitleLayout.size)
                            strongSelf.subtitleNode.frame = subtitleFrame
                            
                            let titleOriginY = subtitleFrame.maxY + 11.0
                            let valueOriginY = titleOriginY + 19.0
                            
                            let minX = mediaBackgroundFrame.minX
                            let maxX = mediaBackgroundFrame.maxX
                            let width = mediaBackgroundFrame.width

                            let dayColWidth = max(dayTitleLayout.size.width, dayValueLayout.size.width)
                            let monthColWidth = max(monthTitleLayout.size.width, monthValueLayout.size.width)
                            let yearColW = max(yearTitleLayout.size.width, yearValueLayout.size.width)
                            
                            func centerX(inLeft left: CGFloat, right: CGFloat, contentWidth: CGFloat) -> CGFloat {
                                return left + floorToScreenPixels((right - left - contentWidth) * 0.5)
                            }
                            
                            if yearValueLayout.size.width > 0.0 {
                                strongSelf.yearTitleNode.isHidden = false
                                strongSelf.yearValueNode.isHidden = false
                                
                                let monthLeft = centerX(inLeft: minX, right: maxX, contentWidth: monthColWidth)
                                let monthRight = monthLeft + monthColWidth
                                
                                let dayLeft = centerX(inLeft: minX, right: monthLeft, contentWidth: dayColWidth)
                                let yearLeft = centerX(inLeft: monthRight, right: maxX, contentWidth: yearColW)
                                
                                strongSelf.dayTitleNode.frame = CGRect(
                                    origin: CGPoint(x: dayLeft + floorToScreenPixels((dayColWidth - dayTitleLayout.size.width) * 0.5), y: titleOriginY),
                                    size: dayTitleLayout.size
                                )
                                strongSelf.dayValueNode.frame = CGRect(
                                    origin: CGPoint(x: dayLeft + floorToScreenPixels((dayColWidth - dayValueLayout.size.width) * 0.5), y: valueOriginY),
                                    size: dayValueLayout.size
                                )
                                
                                strongSelf.monthTitleNode.frame = CGRect(
                                    origin: CGPoint(x: monthLeft + floorToScreenPixels((monthColWidth - monthTitleLayout.size.width) * 0.5), y: titleOriginY),
                                    size: monthTitleLayout.size
                                )
                                strongSelf.monthValueNode.frame = CGRect(
                                    origin: CGPoint(x: monthLeft + floorToScreenPixels((monthColWidth - monthValueLayout.size.width) * 0.5), y: valueOriginY),
                                    size: monthValueLayout.size
                                )
                                
                                strongSelf.yearTitleNode.frame = CGRect(
                                    origin: CGPoint(x: yearLeft + floorToScreenPixels((yearColW - yearTitleLayout.size.width) * 0.5), y: titleOriginY),
                                    size: yearTitleLayout.size
                                )
                                strongSelf.yearValueNode.frame = CGRect(
                                    origin: CGPoint(x: yearLeft + floorToScreenPixels((yearColW - yearValueLayout.size.width) * 0.5), y: valueOriginY),
                                    size: yearValueLayout.size
                                )
                            } else {
                                strongSelf.yearTitleNode.isHidden = true
                                strongSelf.yearValueNode.isHidden = true
                                
                                let spacing: CGFloat = 16.0
                                let totalWidth = dayColWidth + monthColWidth + spacing
                                let dayLeft = minX + floorToScreenPixels((width - totalWidth) / 2.0)
                                let monthLeft = dayLeft + dayColWidth + spacing
                                    
                                strongSelf.dayTitleNode.frame = CGRect(
                                    origin: CGPoint(x: dayLeft + floorToScreenPixels((dayColWidth - dayTitleLayout.size.width) * 0.5), y: titleOriginY),
                                    size: dayTitleLayout.size
                                )
                                strongSelf.dayValueNode.frame = CGRect(
                                    origin: CGPoint(x: dayLeft + floorToScreenPixels((dayColWidth - dayValueLayout.size.width) * 0.5), y: valueOriginY),
                                    size: dayValueLayout.size
                                )
                                
                                strongSelf.monthTitleNode.frame = CGRect(
                                    origin: CGPoint(x: monthLeft + floorToScreenPixels((monthColWidth - monthTitleLayout.size.width) * 0.5), y: titleOriginY),
                                    size: monthTitleLayout.size
                                )
                                strongSelf.monthValueNode.frame = CGRect(
                                    origin: CGPoint(x: monthLeft + floorToScreenPixels((monthColWidth - monthValueLayout.size.width) * 0.5), y: valueOriginY),
                                    size: monthValueLayout.size
                                )
                            }
                            
                            strongSelf.buttonNode.isHidden = fromYou
                            strongSelf.buttonTitleNode.isHidden = fromYou
                                                        
                            let buttonSize = CGSize(width: buttonTitleLayout.size.width + 38.0, height: 34.0)
                            let buttonFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - buttonSize.width) / 2.0), y: mediaBackgroundFrame.maxY - buttonSize.height - 16.0), size: buttonSize)
                            strongSelf.buttonNode.frame = buttonFrame

                            let buttonTitleFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - buttonTitleLayout.size.width) / 2.0), y: floorToScreenPixels(buttonFrame.midY - buttonTitleLayout.size.height / 2.0)), size: buttonTitleLayout.size)
                            strongSelf.buttonTitleNode.frame = buttonTitleFrame
                            
                            if item.controllerInteraction.presentationContext.backgroundNode?.hasExtraBubbleBackground() == true {
                                if strongSelf.mediaBackgroundContent == nil, let backgroundContent = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                                    strongSelf.mediaBackgroundNode.isHidden = true
                                    backgroundContent.clipsToBounds = true
                                    backgroundContent.allowsGroupOpacity = true
                                    backgroundContent.cornerRadius = 27.0

                                    strongSelf.mediaBackgroundContent = backgroundContent
                                    strongSelf.insertSubnode(backgroundContent, at: 0)
                                }
                                
                                strongSelf.mediaBackgroundContent?.frame = mediaBackgroundFrame
                            } else {
                                strongSelf.mediaBackgroundNode.isHidden = false
                                strongSelf.mediaBackgroundContent?.removeFromSupernode()
                                strongSelf.mediaBackgroundContent = nil
                            }
                            
                            if let (rect, size) = strongSelf.absoluteRect {
                                strongSelf.updateAbsoluteRect(rect, within: size)
                            }
                        }
                    })
                })
            })
        }
    }

    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteRect = (rect, containerSize)
        
        if let mediaBackgroundContent = self.mediaBackgroundContent {
            var backgroundFrame = mediaBackgroundContent.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += rect.minY
            mediaBackgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
        }
    }
    
    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if self.mediaBackgroundNode.frame.contains(point) {
            return ChatMessageBubbleContentTapAction(content: .openMessage)
        } else {
            return ChatMessageBubbleContentTapAction(content: .none)
        }
    }
}
