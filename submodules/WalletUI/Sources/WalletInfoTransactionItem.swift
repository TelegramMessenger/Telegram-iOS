import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit

private let transactionIcon = UIImage(bundleImageName: "Wallet/TransactionGem")?.precomposed()

private func stringForMessageTimestamp(timestamp: Int32, dateTimeFormat: WalletPresentationDateTimeFormat, local: Bool = true) -> String {
    var t = Int(timestamp)
    var timeinfo = tm()
    if local {
        localtime_r(&t, &timeinfo)
    } else {
        gmtime_r(&t, &timeinfo)
    }
    
    return stringForShortTimestamp(hours: timeinfo.tm_hour, minutes: timeinfo.tm_min, dateTimeFormat: dateTimeFormat)
}

class WalletInfoTransactionItem: ListViewItem {
    let theme: WalletTheme
    let strings: WalletStrings
    let dateTimeFormat: WalletPresentationDateTimeFormat
    let walletTransaction: WalletInfoTransaction
    let action: () -> Void
    
    fileprivate let header: WalletInfoTransactionDateHeader?
    
    init(theme: WalletTheme, strings: WalletStrings, dateTimeFormat: WalletPresentationDateTimeFormat, walletTransaction: WalletInfoTransaction, action: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.walletTransaction = walletTransaction
        self.action = action
        switch walletTransaction {
        case let .completed(transaction):
            self.header = WalletInfoTransactionDateHeader(timestamp: Int32(clamping: transaction.timestamp), theme: theme, strings: strings)
        case .pending:
            self.header = WalletInfoTransactionDateHeader(timestamp: Int32.max, theme: theme, strings: strings)
        }
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
private let descriptionMonospaceFont = Font.monospace(15.0)
private let dateFont = Font.regular(14.0)
private let directionFont = Font.regular(15.0)

class WalletInfoTransactionItemNode: ListViewItemNode {
    private let backgroundNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let titleSignNode: TextNode
    private let titleNode: TextNode
    private let directionNode: TextNode
    private let iconNode: ASImageNode
    private let textNode: TextNode
    private let descriptionNode: TextNode
    private let feesNode: TextNode
    private let dateNode: TextNode
    private var statusNode: StatusClockNode?
    private let lockIconNode: ASImageNode
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: WalletInfoTransactionItem?
    
    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.titleSignNode = TextNode()
        self.titleSignNode.isUserInteractionEnabled = false
        self.titleSignNode.contentMode = .left
        self.titleSignNode.contentsScale = UIScreen.main.scale
        
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
        
        self.lockIconNode = ASImageNode()
        self.lockIconNode.displaysAsynchronously = false
        self.lockIconNode.displayWithoutProcessing = true
        
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.contentMode = .left
        self.textNode.contentsScale = UIScreen.main.scale
        
        self.descriptionNode = TextNode()
        self.descriptionNode.isUserInteractionEnabled = false
        self.descriptionNode.contentMode = .left
        self.descriptionNode.contentsScale = UIScreen.main.scale
        
        self.feesNode = TextNode()
        self.feesNode.isUserInteractionEnabled = false
        self.feesNode.contentMode = .left
        self.feesNode.contentsScale = UIScreen.main.scale
        
        self.dateNode = TextNode()
        self.dateNode.isUserInteractionEnabled = false
        self.dateNode.contentMode = .left
        self.dateNode.contentsScale = UIScreen.main.scale
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleSignNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.lockIconNode)
        self.addSubnode(self.directionNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.descriptionNode)
        self.addSubnode(self.feesNode)
        self.addSubnode(self.dateNode)
        
        self.addSubnode(self.activateArea)
    }
    
    func asyncLayout() -> (_ item: WalletInfoTransactionItem, _ params: ListViewItemLayoutParams, _ hasPrevious: Bool, _ hasNext: Bool, _ dateAtBottom: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleSignLayout = TextNode.asyncLayout(self.titleSignNode)
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeDirectionLayout = TextNode.asyncLayout(self.directionNode)
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let makeDescriptionLayout = TextNode.asyncLayout(self.descriptionNode)
        let makeFeesLayout = TextNode.asyncLayout(self.feesNode)
        let makeDateLayout = TextNode.asyncLayout(self.dateNode)
        
        let currentItem = self.item
        
        return { item, params, hasPrevious, hasNext, dateHeaderAtBottom in
            var updatedTheme: WalletTheme?
            
            var lockIconImage: UIImage?
            if currentItem?.theme !== item.theme {
                updatedTheme = item.theme
                lockIconImage = walletTransactionLockIcon(item.theme)
            }
            let iconImage: UIImage? = transactionIcon
            let iconSize = CGSize(width: 14.0, height: 12.0)
            
            let leftInset = 16.0 + params.leftInset
            
            let sign: String
            let title: String
            let directionText: String
            let titleColor: UIColor
            let transferredValue: Int64
            switch item.walletTransaction {
            case let .completed(transaction):
                transferredValue = transaction.transferredValueWithoutFees
            case let .pending(transaction):
                transferredValue = -transaction.value
            }
            var text: String = ""
            var description: String = ""
            var descriptionIsMonospace = false
            if transferredValue <= 0 {
                sign = ""
                title = "\(formatBalanceText(-transferredValue, decimalSeparator: item.dateTimeFormat.decimalSeparator))"
                titleColor = item.theme.info.outgoingFundsTitleColor
                switch item.walletTransaction {
                case let .completed(transaction):
                    if transaction.outMessages.isEmpty {
                        directionText = ""
                        text = item.strings.Wallet_Info_UnknownTransaction
                    } else {
                        directionText = item.strings.Wallet_Info_TransactionTo
                        for message in transaction.outMessages {
                            if !text.isEmpty {
                                text.append("\n")
                            }
                            text.append(formatAddress(message.destination))
                            
                            if !description.isEmpty {
                                description.append("\n")
                            }
                            switch message.contents {
                            case .raw:
                                break
                            case .encryptedText:
                                descriptionIsMonospace = true
                            case let .plainText(text):
                                description.append(text)
                            }
                        }
                    }
                case let .pending(transaction):
                    directionText = item.strings.Wallet_Info_TransactionTo
                    if !text.isEmpty {
                        text.append("\n")
                    }
                    text.append(formatAddress(transaction.address))
                    
                    if let textMessage = String(data: transaction.comment, encoding: .utf8), !textMessage.isEmpty {
                        if !description.isEmpty {
                            description.append("\n")
                        }
                        description.append(textMessage)
                    }
                }
            } else {
                sign = ""
                title = "\(formatBalanceText(transferredValue, decimalSeparator: item.dateTimeFormat.decimalSeparator))"
                titleColor = item.theme.info.incomingFundsTitleColor
                directionText = item.strings.Wallet_Info_TransactionFrom
                switch item.walletTransaction {
                case let .completed(transaction):
                    if let inMessage = transaction.inMessage {
                        text = formatAddress(inMessage.source)
                        switch inMessage.contents {
                        case .raw:
                            description = ""
                        case .encryptedText:
                            description = ""
                            descriptionIsMonospace = true
                        case let .plainText(text):
                            description = text
                        }
                    } else {
                        text = "<unknown>"
                    }
                case .pending:
                    text = "<unknown>"
                }
            }
            
            var feeText: String = ""
            let dateText: String
            switch item.walletTransaction {
            case let .completed(transaction):
                let fee = transaction.storageFee + transaction.otherFee
                if fee != 0 {
                    feeText = item.strings.Wallet_Info_TransactionBlockchainFee(formatBalanceText(-fee, decimalSeparator: item.dateTimeFormat.decimalSeparator)).0
                }
                dateText = stringForMessageTimestamp(timestamp: Int32(clamping: transaction.timestamp), dateTimeFormat: item.dateTimeFormat)
            case let .pending(transaction):
                dateText = stringForMessageTimestamp(timestamp: Int32(clamping: transaction.timestamp), dateTimeFormat: item.dateTimeFormat)
            }
            
            let (dateLayout, dateApply) = makeDateLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: dateText, font: dateFont, textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - leftInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (directionLayout, directionApply) = makeDirectionLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: directionText, font: directionFont, textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - leftInset - 20.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let titleString = NSMutableAttributedString()
            if let range = title.range(of: item.dateTimeFormat.decimalSeparator) {
                let integralPart = String(title[..<range.lowerBound])
                let fractionalPart = String(title[range.lowerBound...])
                titleString.append(NSAttributedString(string: integralPart, font: Font.bold(17.0), textColor: titleColor))
                titleString.append(NSAttributedString(string: fractionalPart, font: Font.regular(14.0), textColor: titleColor))
            } else {
                titleString.append(NSAttributedString(string: title, font: Font.bold(17.0), textColor: titleColor))
            }
            
            let signString = NSAttributedString(string: sign, font: Font.bold(17.0), textColor: titleColor)
            
            let (titleSignLayout, titleSignApply) = makeTitleSignLayout(TextNodeLayoutArguments(attributedString: signString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - leftInset - 20.0 - dateLayout.size.width - directionLayout.size.width - iconSize.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - leftInset - 20.0 - dateLayout.size.width - directionLayout.size.width - iconSize.width, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: text, font: textFont, textColor: item.theme.list.itemPrimaryTextColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - leftInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (descriptionLayout, descriptionApply) = makeDescriptionLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: description, font: descriptionIsMonospace ? descriptionMonospaceFont : descriptionFont, textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - leftInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (feesLayout, feesApply) = makeFeesLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: feeText, font: descriptionFont, textColor: item.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - leftInset, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            var contentSize: CGSize
            var insets: UIEdgeInsets
            let separatorHeight = UIScreenPixel
            
            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            
            itemBackgroundColor = item.theme.list.itemBlocksBackgroundColor
            itemSeparatorColor = item.theme.list.itemBlocksSeparatorColor
            
            let topInset: CGFloat = 11.0
            let bottomInset: CGFloat = 11.0
            let titleSpacing: CGFloat = 2.0
            let textSpacing: CGFloat = 2.0
            
            contentSize = CGSize(width: params.width, height: topInset + titleLayout.size.height + titleSpacing + textLayout.size.height + bottomInset)
            if !descriptionLayout.size.width.isZero {
                contentSize.height += descriptionLayout.size.height + textSpacing
            }
            if !feesLayout.size.width.isZero {
                contentSize.height += feesLayout.size.height + textSpacing
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
                        strongSelf.lockIconNode.image = lockIconImage
                    }
                    
                    let _ = titleSignApply()
                    let _ = titleApply()
                    let _ = textApply()
                    let _ = descriptionApply()
                    let _ = feesApply()
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
                    
                    let titleSignFrame = CGRect(origin: CGPoint(x: leftInset, y: topInset), size: titleSignLayout.size)
                    strongSelf.titleSignNode.frame = titleSignFrame
                    
                    let iconFrame = CGRect(origin: CGPoint(x: titleSignFrame.maxX + (titleSignFrame.width.isZero ? 0.0 : 1.0), y: titleSignFrame.minY + floor((titleLayout.size.height - iconSize.height) / 2.0) - 1.0), size: iconSize)
                    strongSelf.iconNode.frame = iconFrame
                    
                    let titleFrame = CGRect(origin: CGPoint(x: iconFrame.maxX + 3.0, y: topInset), size: titleLayout.size)
                    strongSelf.titleNode.frame = titleFrame
                    
                    let directionFrame = CGRect(origin: CGPoint(x: titleFrame.maxX + 3.0, y: titleFrame.maxY - directionLayout.size.height - 1.0), size: directionLayout.size)
                    strongSelf.directionNode.frame = directionFrame
                    
                    let textFrame = CGRect(origin: CGPoint(x: leftInset, y: titleFrame.maxY + titleSpacing), size: textLayout.size)
                    strongSelf.textNode.frame = textFrame
                    
                    let descriptionFrame = CGRect(origin: CGPoint(x: leftInset, y: textFrame.maxY + textSpacing), size: descriptionLayout.size)
                    strongSelf.descriptionNode.frame = descriptionFrame
                    strongSelf.feesNode.frame = CGRect(origin: CGPoint(x: leftInset, y: descriptionFrame.maxY + textSpacing), size: feesLayout.size)
                    
                    let dateFrame = CGRect(origin: CGPoint(x: params.width - leftInset - dateLayout.size.width, y: topInset), size: dateLayout.size)
                    strongSelf.dateNode.frame = dateFrame
                    
                    if let image = strongSelf.lockIconNode.image {
                        strongSelf.lockIconNode.frame = CGRect(origin: CGPoint(x: params.width - leftInset - image.size.width + 4.0, y: dateFrame.maxY + 17.0), size: image.size)
                    }
                    
                    var hasEncryptedComment = false
                    switch item.walletTransaction {
                    case .pending:
                        let statusNode: StatusClockNode
                        if let current = strongSelf.statusNode {
                            statusNode = current
                        } else {
                            statusNode = StatusClockNode(theme: item.theme)
                            strongSelf.statusNode = statusNode
                            strongSelf.addSubnode(statusNode)
                        }
                        let statusSize = CGSize(width: 11.0, height: 11.0)
                        statusNode.frame = CGRect(origin: CGPoint(x: dateFrame.minX - statusSize.width - 4.0, y: dateFrame.minY + floor((dateFrame.height - statusSize.height) / 2.0) - UIScreenPixel), size: statusSize)
                    case let .completed(transaction):
                        if let statusNode = strongSelf.statusNode {
                            strongSelf.statusNode = nil
                            statusNode.removeFromSupernode()
                        }
                        
                        if let inMessage = transaction.inMessage {
                            switch inMessage.contents {
                            case .encryptedText:
                                hasEncryptedComment = true
                            default:
                                break
                            }
                        }
                        for message in transaction.outMessages {
                            switch message.contents {
                            case .encryptedText:
                                hasEncryptedComment = true
                            default:
                                break
                            }
                        }
                    }
                    strongSelf.lockIconNode.isHidden = !hasEncryptedComment
                    
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
    private let localTimestamp: Int32
    
    let id: Int64
    let theme: WalletTheme
    let strings: WalletStrings
    
    init(timestamp: Int32, theme: WalletTheme, strings: WalletStrings) {
        self.timestamp = timestamp
        self.theme = theme
        self.strings = strings
        
        if timestamp == Int32.max {
            self.localTimestamp = timestamp
        } else {
            self.localTimestamp = ((timestamp + timezoneOffset) / (granularity)) * (granularity)
        }
        
        self.roundedTimestamp = self.localTimestamp
        self.id = Int64(self.roundedTimestamp)
    }
    
    let stickDirection: ListViewItemHeaderStickDirection = .top
    
    let height: CGFloat = 40.0
    
    func node() -> ListViewItemHeaderNode {
        return WalletInfoTransactionDateHeaderNode(theme: self.theme, strings: self.strings, roundedTimestamp: self.localTimestamp)
    }
    
    func updateNode(_ node: ListViewItemHeaderNode, previous: ListViewItemHeader?, next: ListViewItemHeader?) {
        
    }
}

private let sectionTitleFont = Font.semibold(17.0)

private func monthAtIndex(_ index: Int, strings: WalletStrings) -> String {
    switch index {
    case 0:
        return strings.Wallet_Month_GenJanuary
    case 1:
        return strings.Wallet_Month_GenFebruary
    case 2:
        return strings.Wallet_Month_GenMarch
    case 3:
        return strings.Wallet_Month_GenApril
    case 4:
        return strings.Wallet_Month_GenMay
    case 5:
        return strings.Wallet_Month_GenJune
    case 6:
        return strings.Wallet_Month_GenJuly
    case 7:
        return strings.Wallet_Month_GenAugust
    case 8:
        return strings.Wallet_Month_GenSeptember
    case 9:
        return strings.Wallet_Month_GenOctober
    case 10:
        return strings.Wallet_Month_GenNovember
    case 11:
        return strings.Wallet_Month_GenDecember
    default:
        return ""
    }
}

final class WalletInfoTransactionDateHeaderNode: ListViewItemHeaderNode {
    var theme: WalletTheme
    var strings: WalletStrings
    let titleNode: ImmediateTextNode
    let backgroundNode: ASDisplayNode
    let separatorNode: ASDisplayNode
    
    init(theme: WalletTheme, strings: WalletStrings, roundedTimestamp: Int32) {
        self.theme = theme
        self.strings = strings
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = theme.list.itemBlocksBackgroundColor
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        self.separatorNode.backgroundColor = theme.list.itemBlocksSeparatorColor
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.isUserInteractionEnabled = false
        
        super.init()
        
        var text: String
        if roundedTimestamp == Int32.max {
            text = strings.Wallet_Info_TransactionPendingHeader
        } else {
            let nowTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
            
            var t: time_t = time_t(roundedTimestamp)
            var timeinfo: tm = tm()
            gmtime_r(&t, &timeinfo)
            
            var now: time_t = time_t(nowTimestamp)
            var timeinfoNow: tm = tm()
            localtime_r(&now, &timeinfoNow)
            
            if timeinfo.tm_year == timeinfoNow.tm_year {
                if timeinfo.tm_yday == timeinfoNow.tm_yday {
                    text = strings.Wallet_Weekday_Today
                } else {
                    text = strings.Wallet_Info_TransactionDateHeader(monthAtIndex(Int(timeinfo.tm_mon), strings: strings), "\(timeinfo.tm_mday)").0
                }
            } else {
                text = strings.Wallet_Info_TransactionDateHeaderYear(monthAtIndex(Int(timeinfo.tm_mon), strings: strings), "\(timeinfo.tm_mday)", "\(1900 + timeinfo.tm_year)").0
            }
        }
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.titleNode)
        self.titleNode.attributedText = NSAttributedString(string: text, font: sectionTitleFont, textColor: theme.list.itemPrimaryTextColor)
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationType = .end
    }
    
    func updateThemeAndStrings(theme: WalletTheme, strings: WalletStrings) {
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
        let titleSize = self.titleNode.updateLayout(CGSize(width: size.width - leftInset - rightInset - 24.0, height: CGFloat.greatestFiniteMagnitude))
        self.titleNode.frame = CGRect(origin: CGPoint(x: leftInset + 16.0, y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)
        self.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: size.height - UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel))
    }
    
    override func updateStickDistanceFactor(_ factor: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateAlpha(node: self.separatorNode, alpha: (1.0 - factor) * 0.0 + factor * 1.0)
    }
}

private func maybeAddRotationAnimation(_ layer: CALayer, duration: Double) {
    if let _ = layer.animation(forKey: "clockFrameAnimation") {
        return
    }
    
    let basicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
    basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
    basicAnimation.duration = duration
    basicAnimation.fromValue = NSNumber(value: Float(0.0))
    basicAnimation.toValue = NSNumber(value: Float(Double.pi * 2.0))
    basicAnimation.repeatCount = Float.infinity
    basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
    basicAnimation.beginTime = 1.0
    layer.add(basicAnimation, forKey: "clockFrameAnimation")
}


private final class StatusClockNode: ASDisplayNode {
    private var clockFrameNode: ASImageNode
    private var clockMinNode: ASImageNode
    
    init(theme: WalletTheme) {
        self.clockFrameNode = ASImageNode()
        self.clockMinNode = ASImageNode()
        
        super.init()
        
        self.clockFrameNode.image = clockFrameImage(theme)
        self.clockMinNode.image = clockMinImage(theme)
        
        self.addSubnode(self.clockFrameNode)
        self.addSubnode(self.clockMinNode)
    }
    
    override func didEnterHierarchy() {
        super.didEnterHierarchy()
        
        maybeAddRotationAnimation(self.clockFrameNode.layer, duration: 6.0)
        maybeAddRotationAnimation(self.clockMinNode.layer, duration: 1.0)
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        self.clockFrameNode.layer.removeAllAnimations()
        self.clockMinNode.layer.removeAllAnimations()
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        if let frameImage = self.clockFrameNode.image {
            self.clockFrameNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((bounds.width - frameImage.size.width) / 2.0), y: floorToScreenPixels((bounds.height - frameImage.size.height) / 2.0)), size: frameImage.size)
        }
        if let minImage = self.clockMinNode.image {
            self.clockMinNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((bounds.width - minImage.size.width) / 2.0), y: floorToScreenPixels((bounds.height - minImage.size.height) / 2.0)), size: minImage.size)
        }
    }
}
