import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import TelegramCore
import TelegramStringFormatting

private let transactionIcon = UIImage(bundleImageName: "Wallet/TransactionGem")?.precomposed()

class WalletInfoTransactionItem: ListViewItem {
    let theme: PresentationTheme
    let dateTimeFormat: PresentationDateTimeFormat
    let walletTransaction: WalletTransaction
    let action: () -> Void
    
    fileprivate let header: WalletInfoTransactionDateHeader?
    
    init(theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, walletTransaction: WalletTransaction, action: @escaping () -> Void) {
        self.theme = theme
        self.dateTimeFormat = dateTimeFormat
        self.walletTransaction = walletTransaction
        self.action = action
        self.header = WalletInfoTransactionDateHeader(timestamp: Int32(clamping: walletTransaction.timestamp), theme: theme, strings: strings)
    }
    
    func getDateAtBottom(top: ListViewItem?, bottom: ListViewItem?) -> Bool {
        var dateAtBottom = false
        if let top = top as? WalletInfoTransactionItem, top.header != nil {
            if top.header?.id != self.header?.id {
                dateAtBottom = true
            }
        } else {
            dateAtBottom = true
        }
        
        return dateAtBottom
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = WalletInfoTransactionItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, previousItem != nil, nextItem != nil, self.getDateAtBottom(top: previousItem, bottom: nextItem))
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply() })
                })
            }
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? WalletInfoTransactionItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                async {
                    let (layout, apply) = makeLayout(self, params, previousItem != nil, nextItem != nil, self.getDateAtBottom(top: previousItem, bottom: nextItem))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply()
                        })
                    }
                }
            }
        }
    }
    
    var selectable: Bool = true
    
    func selected(listView: ListView){
        listView.clearHighlightAnimated(true)
        self.action()
    }
}

private let titleFont = Font.medium(17.0)
private let textFont = Font.monospace(15.0)
private let descriptionFont = Font.regular(15.0)
private let dateFont = Font.regular(14.0)
private let directionFont = Font.regular(15.0)

private func formatAddress(_ address: String) -> String {
    var address = address
    address.insert("\n", at: address.index(address.startIndex, offsetBy: address.count / 2))
    return address
}

class WalletInfoTransactionItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let titleNode: TextNode
    private let directionNode: TextNode
    private let iconNode: ASImageNode
    private let textNode: TextNode
    private let descriptionNode: TextNode
    private let dateNode: TextNode
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: WalletInfoTransactionItem?
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = .white
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.directionNode = TextNode()
        self.directionNode.isUserInteractionEnabled = false
        self.directionNode.contentMode = .left
        self.directionNode.contentsScale = UIScreen.main.scale
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.contentMode = .left
        self.textNode.contentsScale = UIScreen.main.scale
        
        self.descriptionNode = TextNode()
        self.descriptionNode.isUserInteractionEnabled = false
        self.descriptionNode.contentMode = .left
        self.descriptionNode.contentsScale = UIScreen.main.scale
        
        self.dateNode = TextNode()
        self.dateNode.isUserInteractionEnabled = false
        self.dateNode.contentMode = .left
        self.dateNode.contentsScale = UIScreen.main.scale
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.directionNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.descriptionNode)
        self.addSubnode(self.dateNode)
        
        self.addSubnode(self.activateArea)
    }
    
    func asyncLayout() -> (_ item: WalletInfoTransactionItem, _ params: ListViewItemLayoutParams, _ hasPrevious: Bool, _ hasNext: Bool, _ dateAtBottom: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeDirectionLayout = TextNode.asyncLayout(self.directionNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let makeDescriptionLayout = TextNode.asyncLayout(self.descriptionNode)
        let makeDateLayout = TextNode.asyncLayout(self.dateNode)
        
        let currentItem = self.item
        
        return { item, params, hasPrevious, hasNext, dateHeaderAtBottom in
            var updatedTheme: PresentationTheme?
            
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
            }
            let iconImage: UIImage? = transactionIcon
            let iconSize = iconImage?.size ?? CGSize(width: 10.0, height: 10.0)
            
            let leftInset = 16.0 + params.leftInset
            
            let title: String
            let directionText: String
            let titleColor: UIColor
            let transferredValue = item.walletTransaction.transferredValue
            var text: String = ""
            var description: String = ""
            if transferredValue <= 0 {
                title = "\(formatBalanceText(transferredValue, decimalSeparator: item.dateTimeFormat.decimalSeparator))"
                titleColor = item.theme.list.itemPrimaryTextColor
                if item.walletTransaction.outMessages.isEmpty {
                    directionText = ""
                    text = "Empty Transaction"
                } else {
                    directionText = "to"
                    for message in item.walletTransaction.outMessages {
                        if !text.isEmpty {
                            text.append("\n")
                        }
                        text.append(formatAddress(message.destination))
                        
                        if !description.isEmpty {
                            description.append("\n")
                        }
                        description.append(message.textMessage)
                    }
                }
            } else {
                title = "+\(formatBalanceText(transferredValue, decimalSeparator: item.dateTimeFormat.decimalSeparator))"
                titleColor = item.theme.chatList.secretTitleColor
                directionText = "from"
                if let inMessage = item.walletTransaction.inMessage {
                    text = formatAddress(inMessage.source)
                    description = inMessage.textMessage
                } else {
                    text = "<unknown>"
                }
            }
            
            let dateText = stringForMessageTimestamp(timestamp: Int32(clamping: item.walletTransaction.timestamp), dateTimeFormat: item.dateTimeFormat)
            
            let (dateLayout, dateApply) = makeDateLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: dateText, font: dateFont, textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - leftInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (directionLayout, directionApply) = makeDirectionLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: directionText, font: directionFont, textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - leftInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: title, font: titleFont, textColor: titleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - leftInset - 20.0 - dateLayout.size.width - directionLayout.size.width - iconSize.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: text, font: textFont, textColor: item.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - leftInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (descriptionLayout, descriptionApply) = makeDescriptionLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: description, font: descriptionFont, textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - leftInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var contentSize: CGSize
            var insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            itemBackgroundColor = item.theme.list.plainBackgroundColor
            itemSeparatorColor = item.theme.list.itemPlainSeparatorColor
            
            let topInset: CGFloat = 11.0
            let bottomInset: CGFloat = 11.0
            let titleSpacing: CGFloat = 2.0
            let textSpacing: CGFloat = 2.0
            
            contentSize = CGSize(width: params.width, height: topInset + titleLayout.size.height + titleSpacing + textLayout.size.height + bottomInset)
            if !descriptionLayout.size.width.isZero {
                contentSize.height += descriptionLayout.size.height + textSpacing
            }
            insets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
            var topHighlightInset: CGFloat = 0.0
            if dateHeaderAtBottom, let header = item.header {
                insets.top += header.height - 4.0
                topHighlightInset = 4.0
            }
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    //strongSelf.activateArea.accessibilityLabel = item.title
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.theme.list.itemHighlightedBackgroundColor
                        strongSelf.iconNode.image = iconImage
                    }
                    
                    let _ = titleApply()
                    let _ = textApply()
                    let _ = descriptionApply()
                    let _ = dateApply()
                    let _ = directionApply()
                    
                    if strongSelf.backgroundNode.supernode != nil {
                        strongSelf.backgroundNode.removeFromSupernode()
                    }
                    if strongSelf.topStripeNode.supernode != nil {
                        strongSelf.topStripeNode.removeFromSupernode()
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 0)
                    }
                    strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - leftInset, height: separatorHeight))
                    
                    let titleFrame = CGRect(origin: CGPoint(x: leftInset, y: topInset), size: titleLayout.size)
                    strongSelf.titleNode.frame = titleFrame
                    
                    let iconFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + 3.0, y: titleFrame.minY + floor((titleFrame.height - iconSize.height) / 2.0) - 1.0), size: iconSize)
                    strongSelf.iconNode.frame = iconFrame
                    
                    let directionFrame = CGRect(origin: CGPoint(x: iconFrame.maxX + 3.0, y: titleFrame.maxY - directionLayout.size.height - 1.0), size: directionLayout.size)
                    strongSelf.directionNode.frame = directionFrame
                    
                    let textFrame = CGRect(origin: CGPoint(x: leftInset, y: titleFrame.maxY + titleSpacing), size: textLayout.size)
                    strongSelf.textNode.frame = textFrame
                    
                    strongSelf.descriptionNode.frame = CGRect(origin: CGPoint(x: leftInset, y: textFrame.maxY + textSpacing), size: descriptionLayout.size)
                    
                    strongSelf.dateNode.frame = CGRect(origin: CGPoint(x: params.width - leftInset - dateLayout.size.width, y: topInset), size: dateLayout.size)
                    
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: topHighlightInset + -UIScreenPixel), size: CGSize(width: params.width, height: layout.contentSize.height + UIScreenPixel * 2.0 - topHighlightInset))
                }
            })
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
        
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
    
    override func header() -> ListViewItemHeader? {
        return self.item?.header
    }
}

private let timezoneOffset: Int32 = {
    let nowTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
    var now: time_t = time_t(nowTimestamp)
    var timeinfoNow: tm = tm()
    localtime_r(&now, &timeinfoNow)
    return Int32(timeinfoNow.tm_gmtoff)
}()

private let granularity: Int32 = 60 * 60 * 24

private final class WalletInfoTransactionDateHeader: ListViewItemHeader {
    private let timestamp: Int32
    private let roundedTimestamp: Int32
    private let month: Int32
    private let year: Int32
    private let localTimestamp: Int32
    
    let id: Int64
    let theme: PresentationTheme
    let strings: PresentationStrings
    
    init(timestamp: Int32, theme: PresentationTheme, strings: PresentationStrings) {
        self.timestamp = timestamp
        self.theme = theme
        self.strings = strings
        
        var time: time_t = time_t(timestamp + timezoneOffset)
        var timeinfo: tm = tm()
        localtime_r(&time, &timeinfo)
        
        self.roundedTimestamp = timeinfo.tm_year * 100 + timeinfo.tm_mon
        self.month = timeinfo.tm_mon
        self.year = timeinfo.tm_year
        
        self.id = Int64(self.roundedTimestamp)
        
        if timestamp == Int32.max {
            self.localTimestamp = timestamp / (granularity) * (granularity)
        } else {
            self.localTimestamp = ((timestamp + timezoneOffset) / (granularity)) * (granularity)
        }
    }
    
    let stickDirection: ListViewItemHeaderStickDirection = .top
    
    let height: CGFloat = 40.0
    
    func node() -> ListViewItemHeaderNode {
        return WalletInfoTransactionDateHeaderNode(theme: self.theme, strings: self.strings, roundedTimestamp: self.localTimestamp, month: self.month, year: self.year)
    }
}

private let sectionTitleFont = Font.semibold(17.0)

private func monthAtIndex(_ index: Int, strings: PresentationStrings) -> String {
    switch index {
    case 0:
        return strings.Month_GenJanuary
    case 1:
        return strings.Month_GenFebruary
    case 2:
        return strings.Month_GenMarch
    case 3:
        return strings.Month_GenApril
    case 4:
        return strings.Month_GenMay
    case 5:
        return strings.Month_GenJune
    case 6:
        return strings.Month_GenJuly
    case 7:
        return strings.Month_GenAugust
    case 8:
        return strings.Month_GenSeptember
    case 9:
        return strings.Month_GenOctober
    case 10:
        return strings.Month_GenNovember
    case 11:
        return strings.Month_GenDecember
    default:
        return ""
    }
}

final class WalletInfoTransactionDateHeaderNode: ListViewItemHeaderNode {
    var theme: PresentationTheme
    var strings: PresentationStrings
    let titleNode: ASTextNode
    let backgroundNode: ASDisplayNode
    
    init(theme: PresentationTheme, strings: PresentationStrings, roundedTimestamp: Int32, month: Int32, year: Int32) {
        self.theme = theme
        self.strings = strings
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = theme.list.plainBackgroundColor.withAlphaComponent(0.9)
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        
        super.init()
        
        let nowTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        
        var t: time_t = time_t(roundedTimestamp)
        var timeinfo: tm = tm()
        gmtime_r(&t, &timeinfo)
        
        var now: time_t = time_t(nowTimestamp)
        var timeinfoNow: tm = tm()
        localtime_r(&now, &timeinfoNow)
        
        var text: String
        if timeinfo.tm_year == timeinfoNow.tm_year {
            if timeinfo.tm_yday == timeinfoNow.tm_yday {
                text = strings.Weekday_Today
            } else {
                text = strings.Date_ChatDateHeader(monthAtIndex(Int(timeinfo.tm_mon), strings: strings), "\(timeinfo.tm_mday)").0
            }
        } else {
            text = strings.Date_ChatDateHeaderYear(monthAtIndex(Int(timeinfo.tm_mon), strings: strings), "\(timeinfo.tm_mday)", "\(1900 + timeinfo.tm_year)").0
        }
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.titleNode)
        self.titleNode.attributedText = NSAttributedString(string: text, font: sectionTitleFont, textColor: theme.list.itemPrimaryTextColor)
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        if let attributedString = self.titleNode.attributedText?.mutableCopy() as? NSMutableAttributedString {
            attributedString.addAttribute(NSAttributedString.Key.foregroundColor, value: theme.list.itemPrimaryTextColor, range: NSMakeRange(0, attributedString.length))
            self.titleNode.attributedText = attributedString
        }
        
        self.strings = strings
        
        self.backgroundNode.backgroundColor = theme.list.plainBackgroundColor.withAlphaComponent(0.9)
        self.setNeedsLayout()
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat) {
        let titleSize = self.titleNode.measure(CGSize(width: size.width - leftInset - rightInset - 24.0, height: CGFloat.greatestFiniteMagnitude))
        self.titleNode.frame = CGRect(origin: CGPoint(x: leftInset + 16.0, y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)
    }
}
