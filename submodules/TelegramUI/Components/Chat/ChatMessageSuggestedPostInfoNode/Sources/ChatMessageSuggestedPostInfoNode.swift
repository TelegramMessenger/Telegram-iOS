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
            
            //TODO:localize
            let amountString: String
            if let amount, amount.amount != .zero {
                switch amount.currency {
                case .stars:
                    if amount.amount.value == 1 {
                        amountString = "1 Star"
                    } else {
                        amountString = "\(amount.amount) Stars"
                    }
                case .ton:
                    if amount.amount.value == 1 {
                        amountString = "1 TON"
                    } else {
                        amountString = "\(formatTonAmountText(amount.amount.value, dateTimeFormat: item.presentationData.dateTimeFormat)) TON"
                    }
                }
            } else {
                amountString = "Free"
            }
            
            var timestampString: String
            if let timestamp {
                timestampString = humanReadableStringForTimestamp(strings: item.presentationData.strings, dateTimeFormat: item.presentationData.dateTimeFormat, timestamp: timestamp, alwaysShowTime: true).string
                if timestampString.count > 1 {
                    timestampString = String(timestampString[timestampString.startIndex]).capitalized + timestampString[timestampString.index(after: timestampString.startIndex)...]
                }
            } else {
                timestampString = "Anytime"
            }
            
            let serviceColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper)
            
            //TODO:localize
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
                        titleText = "You suggest a new price,\ntime and contents for this message."
                    } else if changedText && changedPrice && changedTime {
                        titleText = "You suggest a new price,\ntime and text for this message."
                    } else if changedMedia && changedPrice && changedTime {
                        titleText = "You suggest a new price,\ntime and attachments for this message."
                    } else if changedPrice && changedTime {
                        titleText = "You suggest a new price and time\nfor this message."
                    } else if changedPrice {
                        titleText = "You suggest a new price\nfor this message."
                    } else if changedTime {
                        titleText = "You suggest a new time\nfor this message."
                    } else {
                        titleText = "You suggest changes\nfor this message."
                    }
                } else {
                    var channelName = ""
                    if item.message.author is TelegramChannel {
                        channelName = item.message.author.flatMap(EnginePeer.init)?.compactDisplayTitle ?? " "
                    }
                    if changedText && changedMedia && changedPrice && changedTime {
                        titleText = "**\(channelName)** suggests a new price,\ntime and contents for this message."
                    } else if changedText && changedPrice && changedTime {
                        titleText = "**\(channelName)** suggests a new price,\ntime and text for this message."
                    } else if changedMedia && changedPrice && changedTime {
                        titleText = "**\(channelName)** suggests a new price,\ntime and attachments for this message."
                    } else if changedPrice && changedTime {
                        titleText = "**\(channelName)** suggests a new price and time\nfor this message."
                    } else if changedPrice {
                        titleText = "**\(channelName)** suggests a new price\nfor this message."
                    } else if changedTime {
                        titleText = "**\(channelName)** suggests a new time\nfor this message."
                    } else {
                        titleText = "**\(channelName)** suggests changes\nfor this message."
                    }
                }
            } else {
                if !item.message.effectivelyIncoming(item.context.account.peerId) {
                    titleText = "You suggest to post\nthis message."
                } else {
                    titleText = "**\(item.message.author.flatMap(EnginePeer.init)?.compactDisplayTitle ?? " ")** suggests to post\nthis message."
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
            
            let priceLabelLayout = makePriceLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "Price", font: Font.regular(13.0), textColor: serviceColor.primaryText.withMultipliedAlpha(0.5)), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: maxWidth - insets.left - insets.right, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let timeLabelLayout = makeTimeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "Time", font: Font.regular(13.0), textColor: serviceColor.primaryText.withMultipliedAlpha(0.5)), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: maxWidth - insets.left - insets.right, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
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
