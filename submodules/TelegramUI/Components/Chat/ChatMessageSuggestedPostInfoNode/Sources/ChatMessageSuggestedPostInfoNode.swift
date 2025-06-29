import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TextFormat
import AccountContext
import WallpaperBackgroundNode
import ChatMessageItem
import TelegramStringFormatting
import Markdown

public final class ChatMessageSuggestedPostInfoNode: ASDisplayNode {
    private var titleNode: TextNode?
    private var priceLabelNode: TextNode?
    private var priceValueNode: TextNode?
    private var timeLabelNode: TextNode?
    private var timeValueNode: TextNode?
    
    private var backgroundNode: WallpaperBubbleBackgroundNode?
    
    override public init() {
        super.init()
    }

    public typealias AsyncLayout = (ChatMessageItem, CGFloat) -> (CGSize, () -> ChatMessageSuggestedPostInfoNode)

    public static func asyncLayout(_ node: ChatMessageSuggestedPostInfoNode?) -> (ChatMessageItem, CGFloat) -> (CGSize, () -> ChatMessageSuggestedPostInfoNode) {
        let makeTitleLayout = TextNode.asyncLayout(node?.titleNode)
        let makePriceLabelLayout = TextNode.asyncLayout(node?.priceLabelNode)
        let makePriceValueLayout = TextNode.asyncLayout(node?.priceValueNode)
        let makeTimeLabelLayout = TextNode.asyncLayout(node?.timeLabelNode)
        let makeTimeValueLayout = TextNode.asyncLayout(node?.timeValueNode)
        
        return { item, maxWidth in
            let insets = UIEdgeInsets(
                top: 12.0,
                left: 12.0,
                bottom: 12.0,
                right: 12.0
            )
            
            let titleSpacing: CGFloat = 8.0
            let labelSpacing: CGFloat = 8.0
            let valuesVerticalSpacing: CGFloat = 2.0
            
            var amount: CurrencyAmount?
            var timestamp: Int32?
            
            for attribute in item.message.attributes {
                if let attribute = attribute as? SuggestedPostMessageAttribute {
                    amount = attribute.amount
                    timestamp = attribute.timestamp
                }
            }
            
            let amountString: String
            if let amount, amount.amount != .zero {
                switch amount.currency {
                case .stars:
                    amountString = item.presentationData.strings.Chat_PostApproval_DetailStatus_StarsAmount(Int32((amount.amount.value == 1 && amount.amount.nanos == 0) ? 1 : 100)).replacingOccurrences(of: "#", with: "\(amount.amount)")
                case .ton:
                    amountString = item.presentationData.strings.Chat_PostApproval_DetailStatus_TonAmount(Int32((amount.amount.value == 1 * 1_000_000_000) ? 1 : 100)).replacingOccurrences(of: "#", with: "\(formatTonAmountText(amount.amount.value, dateTimeFormat: item.presentationData.dateTimeFormat, maxDecimalPositions: 3))")
                }
            } else {
                amountString = item.presentationData.strings.Chat_PostSuggestion_PriceFree
            }
            
            var timestampString: String
            if let timestamp {
                timestampString = humanReadableStringForTimestamp(strings: item.presentationData.strings, dateTimeFormat: item.presentationData.dateTimeFormat, timestamp: timestamp, alwaysShowTime: true).string
                if timestampString.count > 1 {
                    timestampString = String(timestampString[timestampString.startIndex]).capitalized + timestampString[timestampString.index(after: timestampString.startIndex)...]
                }
            } else {
                timestampString = item.presentationData.strings.Chat_PostSuggestion_TimeAny
            }
            
            let serviceColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper)
            
            let titleText: String
            if let attribute = item.message.attributes.first(where: { $0 is ReplyMessageAttribute }) as? ReplyMessageAttribute {
                var changedText = false
                var changedMedia = false
                var changedTime = false
                var changedPrice = false
                if let previousMessage = item.message.associatedMessages[attribute.messageId] {
                    if previousMessage.text != item.message.text {
                        changedText = true
                    }
                    let filteredMediaIds = item.message.media.compactMap { media -> EngineMedia.Id? in
                        if media is TelegramMediaImage || media is TelegramMediaFile {
                            return media.id
                        } else {
                            return nil
                        }
                    }
                    let filteredPreviousMediaIds = previousMessage.media.compactMap { media -> EngineMedia.Id? in
                        if media is TelegramMediaImage || media is TelegramMediaFile {
                            return media.id
                        } else {
                            return nil
                        }
                    }
                    if Set(filteredPreviousMediaIds) != Set(filteredMediaIds) {
                        changedMedia = true
                    }
                    if let previousAttribute = previousMessage.attributes.first(where: { $0 is SuggestedPostMessageAttribute }) as? SuggestedPostMessageAttribute {
                        if previousAttribute.amount != amount {
                            changedPrice = true
                        }
                        if previousAttribute.timestamp != timestamp {
                            changedTime = true
                        }
                    }
                }
                
                if !item.message.effectivelyIncoming(item.context.account.peerId) {
                    if changedText && changedMedia && changedPrice && changedTime {
                        titleText = item.presentationData.strings.Chat_PostSuggestion_UserChangePTC
                    } else if changedText && changedPrice && changedTime {
                        titleText = item.presentationData.strings.Chat_PostSuggestion_UserChangePTT
                    } else if changedMedia && changedPrice && changedTime {
                        titleText = item.presentationData.strings.Chat_PostSuggestion_UserChangePTA
                    } else if changedPrice && changedTime {
                        titleText = item.presentationData.strings.Chat_PostSuggestion_UserChangePT
                    } else if changedPrice {
                        titleText = item.presentationData.strings.Chat_PostSuggestion_UserChangeP
                    } else if changedTime {
                        titleText = item.presentationData.strings.Chat_PostSuggestion_UserChangeT
                    } else {
                        titleText = item.presentationData.strings.Chat_PostSuggestion_UserChange
                    }
                } else {
                    var channelName = ""
                    if item.message.author is TelegramChannel {
                        channelName = item.message.author.flatMap(EnginePeer.init)?.compactDisplayTitle ?? " "
                    }
                    if changedText && changedMedia && changedPrice && changedTime {
                        titleText = item.presentationData.strings.Chat_PostSuggestion_ChannelChangePTC(channelName).string
                    } else if changedText && changedPrice && changedTime {
                        titleText = item.presentationData.strings.Chat_PostSuggestion_ChannelChangePTT(channelName).string
                    } else if changedMedia && changedPrice && changedTime {
                        titleText = item.presentationData.strings.Chat_PostSuggestion_ChannelChangePTA(channelName).string
                    } else if changedPrice && changedTime {
                        titleText = item.presentationData.strings.Chat_PostSuggestion_ChannelChangePT(channelName).string
                    } else if changedPrice {
                        titleText = item.presentationData.strings.Chat_PostSuggestion_ChannelChangeP(channelName).string
                    } else if changedTime {
                        titleText = item.presentationData.strings.Chat_PostSuggestion_ChannelChangeT(channelName).string
                    } else {
                        titleText = item.presentationData.strings.Chat_PostSuggestion_ChannelChange(channelName).string
                    }
                }
            } else {
                if !item.message.effectivelyIncoming(item.context.account.peerId) {
                    titleText = item.presentationData.strings.Chat_PostSuggestion_UserPost
                } else {
                    titleText = item.presentationData.strings.Chat_PostSuggestion_ChannelPost(item.message.author.flatMap(EnginePeer.init)?.compactDisplayTitle ?? " ").string
                }
            }
            
            let titleAttributedText = parseMarkdownIntoAttributedString(titleText, attributes: MarkdownAttributes(
                body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: serviceColor.primaryText),
                bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: serviceColor.primaryText),
                link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: serviceColor.primaryText),
                linkAttribute: { url in
                    return ("URL", url)
                }
            ))
            
            let titleLayout = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: maxWidth - insets.left - insets.right, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            let priceLabelLayout = makePriceLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Chat_PostSuggestion_TablePrice, font: Font.regular(13.0), textColor: serviceColor.primaryText.withMultipliedAlpha(0.5)), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: maxWidth - insets.left - insets.right, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let timeLabelLayout = makeTimeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Chat_PostSuggestion_TableTime, font: Font.regular(13.0), textColor: serviceColor.primaryText.withMultipliedAlpha(0.5)), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: maxWidth - insets.left - insets.right, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let priceValueLayout = makePriceValueLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: amountString, font: Font.semibold(13.0), textColor: serviceColor.primaryText), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: maxWidth - insets.left - insets.right, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let timeValueLayout = makeTimeValueLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: timestampString, font: Font.semibold(13.0), textColor: serviceColor.primaryText), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: maxWidth - insets.left - insets.right, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var maxContentWidth: CGFloat = 0.0
            var contentHeight: CGFloat = 0.0
            
            maxContentWidth = max(maxContentWidth, titleLayout.0.size.width)
            
            contentHeight += titleLayout.0.size.height
            contentHeight += titleSpacing
            
            var tableContentWidth: CGFloat = 0.0
            tableContentWidth = max(tableContentWidth, priceLabelLayout.0.size.width + labelSpacing + priceValueLayout.0.size.width)
            tableContentWidth = max(tableContentWidth, timeLabelLayout.0.size.width + labelSpacing + timeValueLayout.0.size.width)
            
            let labelValueOffset = labelSpacing + max(priceLabelLayout.0.size.width, timeLabelLayout.0.size.width)
            
            maxContentWidth = max(maxContentWidth, tableContentWidth)
            contentHeight += priceLabelLayout.0.size.height + valuesVerticalSpacing
            contentHeight += timeLabelLayout.0.size.height
            
            let size = CGSize(width: insets.left + insets.right + maxContentWidth, height: insets.top + insets.bottom + contentHeight)

            return (size, {
                let node = node ?? ChatMessageSuggestedPostInfoNode()
                
                if node.backgroundNode == nil {
                    if let backgroundNode = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                        node.backgroundNode = backgroundNode
                        backgroundNode.layer.masksToBounds = true
                        backgroundNode.layer.cornerRadius = 15.0
                        node.insertSubnode(backgroundNode, at: 0)
                    }
                }
                
                if let backgroundNode = node.backgroundNode {
                    backgroundNode.frame = CGRect(origin: CGPoint(), size: size)
                }
                
                let titleNode = titleLayout.1()
                if node.titleNode !== titleNode {
                    node.titleNode = titleNode
                    node.addSubnode(titleNode)
                }
                let priceLabelNode = priceLabelLayout.1()
                if node.priceLabelNode !== priceLabelNode {
                    node.priceLabelNode = priceLabelNode
                    node.addSubnode(priceLabelNode)
                }
                let priceValueNode = priceValueLayout.1()
                if node.priceValueNode !== priceValueNode {
                    node.priceValueNode = priceValueNode
                    node.addSubnode(priceValueNode)
                }
                let timeLabelNode = timeLabelLayout.1()
                if node.timeLabelNode !== timeLabelNode {
                    node.timeLabelNode = timeLabelNode
                    node.addSubnode(timeLabelNode)
                }
                let timeValueNode = timeValueLayout.1()
                if node.timeValueNode !== timeValueNode {
                    node.timeValueNode = timeValueNode
                    node.addSubnode(timeValueNode)
                }
                
                let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleLayout.0.size.width) * 0.5), y: insets.top), size: titleLayout.0.size)
                titleNode.frame = titleFrame
                
                let tableX: CGFloat = floor((size.width - tableContentWidth) * 0.5)
                
                let priceLabelFrame = CGRect(origin: CGPoint(x: tableX, y: titleFrame.maxY + titleSpacing), size: priceLabelLayout.0.size)
                priceLabelNode.frame = priceLabelFrame
                priceValueNode.frame = CGRect(origin: CGPoint(x: tableX + labelValueOffset, y: priceLabelFrame.minY), size: priceValueLayout.0.size)

                let timeLabelFrame = CGRect(origin: CGPoint(x: tableX, y: priceLabelFrame.maxY + valuesVerticalSpacing), size: timeLabelLayout.0.size)
                timeLabelNode.frame = timeLabelFrame
                timeValueNode.frame = CGRect(origin: CGPoint(x: tableX + labelValueOffset, y: timeLabelFrame.minY), size: timeValueLayout.0.size)

                return node
            })
        }
    }
}
