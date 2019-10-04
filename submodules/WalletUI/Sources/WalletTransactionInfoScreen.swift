import Foundation
import UIKit
import AppBundle
import AccountContext
import TelegramPresentationData
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SolidRoundedButtonNode
import AnimationUI
import SwiftSignalKit
import OverlayStatusController
import ItemListUI
import TelegramStringFormatting

private final class WalletTransactionInfoControllerArguments {
    let copyWalletAddress: () -> Void
    let sendGrams: () -> Void
    let displayContextMenu: (WalletTransactionInfoEntryTag, String) -> Void
    let openFeeInfo: () -> Void
    
    init(copyWalletAddress: @escaping () -> Void, sendGrams: @escaping () -> Void, displayContextMenu: @escaping (WalletTransactionInfoEntryTag, String) -> Void, openFeeInfo: @escaping () -> Void) {
        self.copyWalletAddress = copyWalletAddress
        self.sendGrams = sendGrams
        self.displayContextMenu = displayContextMenu
        self.openFeeInfo = openFeeInfo
    }
}

private enum WalletTransactionInfoSection: Int32 {
    case amount
    case info
    case storageFee
    case otherFee
    case comment
}

private enum WalletTransactionInfoEntryTag: ItemListItemTag {
    case address
    case comment
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? WalletTransactionInfoEntryTag {
            return self == other
        } else {
            return false
        }
    }
}

private enum WalletTransactionInfoEntry: ItemListNodeEntry {
    case amount(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, WalletInfoTransaction)
    case infoHeader(PresentationTheme, String)
    case infoAddress(PresentationTheme, String, String?)
    case infoCopyAddress(PresentationTheme, String)
    case infoSendGrams(PresentationTheme, String)
    case storageFeeHeader(PresentationTheme, String)
    case storageFee(PresentationTheme, String)
    case storageFeeInfo(PresentationTheme, String)
    case otherFeeHeader(PresentationTheme, String)
    case otherFee(PresentationTheme, String)
    case otherFeeInfo(PresentationTheme, String)
    case commentHeader(PresentationTheme, String)
    case comment(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .amount:
            return WalletTransactionInfoSection.amount.rawValue
        case .infoHeader, .infoAddress, .infoCopyAddress, .infoSendGrams:
            return WalletTransactionInfoSection.info.rawValue
        case .storageFeeHeader, .storageFee, .storageFeeInfo:
            return WalletTransactionInfoSection.storageFee.rawValue
        case .otherFeeHeader, .otherFee, .otherFeeInfo:
            return WalletTransactionInfoSection.otherFee.rawValue
        case .commentHeader, .comment:
            return WalletTransactionInfoSection.comment.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .amount:
            return 0
        case .infoHeader:
            return 1
        case .infoAddress:
            return 2
        case .infoCopyAddress:
            return 3
        case .infoSendGrams:
            return 4
        case .storageFeeHeader:
            return 5
        case .storageFee:
            return 6
        case .storageFeeInfo:
            return 7
        case .otherFeeHeader:
            return 8
        case .otherFee:
            return 9
        case .otherFeeInfo:
            return 10
        case .commentHeader:
            return 11
        case .comment:
            return 12
        }
    }
    
    static func <(lhs: WalletTransactionInfoEntry, rhs: WalletTransactionInfoEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: WalletTransactionInfoControllerArguments) -> ListViewItem {
        switch self {
        case let .amount(theme, strings, dateTimeFormat, walletTransaction):
            return WalletTransactionHeaderItem(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, walletTransaction: walletTransaction, sectionId: self.section)
        case let .infoHeader(theme, text):
            return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
        case let .infoAddress(theme, text, address):
            return ItemListMultilineTextItem(theme: theme, text: text, enabledEntityTypes: [], font: .monospace, sectionId: self.section, style: .blocks, longTapAction: address == nil ? nil : {
                if let address = address {
                arguments.displayContextMenu(WalletTransactionInfoEntryTag.address, address)
                }
            }, tag: WalletTransactionInfoEntryTag.address)
        case let .infoCopyAddress(theme, text):
            return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.copyWalletAddress()
            })
        case let .infoSendGrams(theme, text):
            return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.sendGrams()
            })
        case let .storageFeeHeader(theme, text):
            return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
        case let .storageFee(theme, text):
            return ItemListMultilineTextItem(theme: theme, text: text, enabledEntityTypes: [], sectionId: self.section, style: .blocks, longTapAction: nil, tag: nil)
        case let .storageFeeInfo(theme, text):
            return ItemListTextItem(theme: theme, text: .markdown(text), sectionId: self.section, linkAction: { action in
                switch action {
                case .tap:
                    arguments.openFeeInfo()
                }
            }, style: .blocks)
        case let .otherFeeHeader(theme, text):
            return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
        case let .otherFee(theme, text):
            return ItemListMultilineTextItem(theme: theme, text: text, enabledEntityTypes: [], sectionId: self.section, style: .blocks, longTapAction: nil, tag: nil)
        case let .otherFeeInfo(theme, text):
            return ItemListTextItem(theme: theme, text: .markdown(text), sectionId: self.section, linkAction: { action in
                switch action {
                case .tap:
                    arguments.openFeeInfo()
                }
            }, style: .blocks)
        case let .commentHeader(theme, text):
            return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
        case let .comment(theme, text):
            return ItemListMultilineTextItem(theme: theme, text: text, enabledEntityTypes: [], sectionId: self.section, style: .blocks, longTapAction: {
                arguments.displayContextMenu(WalletTransactionInfoEntryTag.comment, text)
            }, tag: WalletTransactionInfoEntryTag.comment)
        }
    }
}

private struct WalletTransactionInfoControllerState: Equatable {
}

private enum WalletTransactionAddress {
    case list([String])
    case none
    case unknown
}

private func stringForAddress(strings: PresentationStrings, address: WalletTransactionAddress) -> String {
    switch address {
        case let .list(addresses):
            return addresses.map { formatAddress($0) }.joined(separator: "\n\n")
        case .none:
            return strings.Wallet_TransactionInfo_NoAddress
        case .unknown:
            return "<unknown>"
    }
}

private func extractAddress(_ walletTransaction: WalletInfoTransaction) -> WalletTransactionAddress {
    switch walletTransaction {
    case let .completed(walletTransaction):
        let transferredValue = walletTransaction.transferredValueWithoutFees
        if transferredValue <= 0 {
            if walletTransaction.outMessages.isEmpty {
                return .none
            } else {
                var addresses: [String] = []
                for message in walletTransaction.outMessages {
                    addresses.append(message.destination)
                }
                return .list(addresses)
            }
        } else {
            if let inMessage = walletTransaction.inMessage {
                return .list([inMessage.source])
            } else {
                return .unknown
            }
        }
        return .none
    case let .pending(pending):
        return .list([pending.address])
    }
}

private func extractDescription(_ walletTransaction: WalletInfoTransaction) -> String {
    switch walletTransaction {
    case let .completed(walletTransaction):
        let transferredValue = walletTransaction.transferredValueWithoutFees
        var text = ""
        if transferredValue <= 0 {
            for message in walletTransaction.outMessages {
                if !text.isEmpty {
                    text.append("\n\n")
                }
                text.append(message.textMessage)
            }
        } else {
            if let inMessage = walletTransaction.inMessage {
                text = inMessage.textMessage
            }
        }
        return text
    case let .pending(pending):
        return String(data: pending.comment, encoding: .utf8) ?? ""
    }
}

private func walletTransactionInfoControllerEntries(presentationData: PresentationData, walletTransaction: WalletInfoTransaction, state: WalletTransactionInfoControllerState, walletInfo: WalletInfo?) -> [WalletTransactionInfoEntry] {
    var entries: [WalletTransactionInfoEntry] = []
    
    entries.append(.amount(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, walletTransaction))
    
    let transferredValue: Int64
    switch walletTransaction {
    case let .completed(transaction):
        transferredValue = transaction.transferredValueWithoutFees
    case let .pending(transaction):
        transferredValue = -transaction.value
    }
    let address = extractAddress(walletTransaction)
    var singleAddress: String?
    let text = stringForAddress(strings: presentationData.strings, address: address)
    let description = extractDescription(walletTransaction)
    
    if transferredValue <= 0 {
        entries.append(.infoHeader(presentationData.theme, presentationData.strings.Wallet_TransactionInfo_RecipientHeader))
    } else {
        entries.append(.infoHeader(presentationData.theme, presentationData.strings.Wallet_TransactionInfo_SenderHeader))
    }
    var singleAddres: String?
    if case let .list(list) = address, list.count == 1 {
        singleAddres = list.first
    }
    entries.append(.infoAddress(presentationData.theme, text, singleAddres))
    if case .list = address, walletInfo != nil {
        entries.append(.infoCopyAddress(presentationData.theme, presentationData.strings.Wallet_TransactionInfo_CopyAddress))
        entries.append(.infoSendGrams(presentationData.theme, presentationData.strings.Wallet_TransactionInfo_SendGrams))
    }
    
    if case let .completed(transaction) = walletTransaction {
        if transaction.storageFee != 0 {
            entries.append(.storageFeeHeader(presentationData.theme, presentationData.strings.Wallet_TransactionInfo_StorageFeeHeader))
            entries.append(.storageFee(presentationData.theme, formatBalanceText(-transaction.storageFee, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            entries.append(.storageFeeInfo(presentationData.theme, presentationData.strings.Wallet_TransactionInfo_StorageFeeInfo))
        }
        if transaction.otherFee != 0 {
            entries.append(.otherFeeHeader(presentationData.theme, presentationData.strings.Wallet_TransactionInfo_OtherFeeHeader))
            entries.append(.otherFee(presentationData.theme, formatBalanceText(-transaction.otherFee, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator)))
            entries.append(.otherFeeInfo(presentationData.theme, presentationData.strings.Wallet_TransactionInfo_OtherFeeInfo))
        }
    }
    
    if !description.isEmpty {
        entries.append(.commentHeader(presentationData.theme, presentationData.strings.Wallet_TransactionInfo_CommentHeader))
        entries.append(.comment(presentationData.theme, description))
    }
    
    return entries
}

func walletTransactionInfoController(context: AccountContext, tonContext: TonContext, walletInfo: WalletInfo?, walletTransaction: WalletInfoTransaction, enableDebugActions: Bool) -> ViewController {
    let statePromise = ValuePromise(WalletTransactionInfoControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: WalletTransactionInfoControllerState())
    let updateState: ((WalletTransactionInfoControllerState) -> WalletTransactionInfoControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var pushImpl: ((ViewController) -> Void)?
    var displayContextMenuImpl: ((WalletTransactionInfoEntryTag, String) -> Void)?
    
    let arguments = WalletTransactionInfoControllerArguments(copyWalletAddress: {
        let address = extractAddress(walletTransaction)
        if case let .list(addresses) = address, let address = addresses.first {
            UIPasteboard.general.string = address
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentControllerImpl?(OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .genericSuccess(presentationData.strings.Wallet_TransactionInfo_AddressCopied, false)), nil)
        }
    }, sendGrams: {
        guard let walletInfo = walletInfo else {
            return
        }
        let address = extractAddress(walletTransaction)
        if case let .list(addresses) = address, let address = addresses.first {
            dismissImpl?()
            pushImpl?(walletSendScreen(context: context, tonContext: tonContext, randomId: arc4random64(), walletInfo: walletInfo, address: address))
        }
    }, displayContextMenu: { tag, text in
        displayContextMenuImpl?(tag, text)
    }, openFeeInfo: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: presentationData.strings.Wallet_TransactionInfo_FeeInfoURL, forceExternal: true, presentationData: presentationData, navigationController: nil, dismissInput: {})
    })
    
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState<WalletTransactionInfoEntry>, WalletTransactionInfoEntry.ItemGenerationArguments)) in
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Wallet_TransactionInfo_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(entries: walletTransactionInfoControllerEntries(presentationData: presentationData, walletTransaction: walletTransaction, state: state, walletInfo: walletInfo), style: .blocks, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    controller.enableInteractiveDismiss = true
    dismissImpl = { [weak controller] in
        controller?.view.endEditing(true)
        controller?.dismiss()
    }
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    displayContextMenuImpl = { [weak controller] tag, value in
        if let strongController = controller {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            var resultItemNode: ListViewItemNode?
            let _ = strongController.frameForItemNode({ itemNode in
                if let itemNode = itemNode as? ItemListMultilineTextItemNode {
                    if let itemTag = itemNode.tag as? WalletTransactionInfoEntryTag {
                        if itemTag == tag {
                            resultItemNode = itemNode
                            return true
                        }
                    }
                }
                return false
            })
            if let resultItemNode = resultItemNode {
                var actions: [ContextMenuAction] = []
                actions.append(ContextMenuAction(content: .text(title: presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: presentationData.strings.Conversation_ContextMenuCopy), action: {
                    UIPasteboard.general.string = value
                }))
                if enableDebugActions {
                    if case .address = tag {
                        actions.append(ContextMenuAction(content: .text(title: "View Transactions", accessibilityLabel: "View Transactions"), action: {
                            pushImpl?(WalletInfoScreen(context: context, tonContext: tonContext, walletInfo: nil, address: value, enableDebugActions: enableDebugActions))
                            //dismissImpl?()
                        }))
                    }
                }
                let contextMenuController =  ContextMenuController(actions: actions)
                strongController.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak resultItemNode] in
                    if let strongController = controller, let resultItemNode = resultItemNode {
                        return (resultItemNode, resultItemNode.contentBounds.insetBy(dx: 0.0, dy: -2.0), strongController.displayNode, strongController.view.bounds)
                    } else {
                        return nil
                    }
                }))
            }
        }
    }
    
    return controller
}

class WalletTransactionHeaderItem: ListViewItem, ItemListItem {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let dateTimeFormat: PresentationDateTimeFormat
    let walletTransaction: WalletInfoTransaction
    let sectionId: ItemListSectionId
    let isAlwaysPlain: Bool = true
    
    init(theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, walletTransaction: WalletInfoTransaction, sectionId: ItemListSectionId) {
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.walletTransaction = walletTransaction
        self.sectionId = sectionId
    }
    
    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = WalletTransactionHeaderItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
            
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
            guard let nodeValue = node() as? WalletTransactionHeaderItemNode else {
                assertionFailure()
                return
            }
            
            let makeLayout = nodeValue.asyncLayout()
            
            async {
                let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topItem: previousItem as? ItemListItem, bottomItem: nextItem as? ItemListItem))
                Queue.mainQueue().async {
                    completion(layout, { _ in
                        apply()
                    })
                }
            }
        }
    }
}

private let titleFont = Font.regular(14.0)
private let titleBoldFont = Font.semibold(14.0)

private class WalletTransactionHeaderItemNode: ListViewItemNode {
    private let titleSignNode: TextNode
    private let titleNode: TextNode
    private let subtitleNode: TextNode
    private let iconNode: ASImageNode
    private let activateArea: AccessibilityAreaNode
    
    private var item: WalletTransactionHeaderItem?
    
    init() {
        self.titleSignNode = TextNode()
        self.titleSignNode.isUserInteractionEnabled = false
        self.titleSignNode.contentMode = .left
        self.titleSignNode.contentsScale = UIScreen.main.scale
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.subtitleNode = TextNode()
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.contentMode = .left
        self.subtitleNode.contentsScale = UIScreen.main.scale
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.image = UIImage(bundleImageName: "Wallet/BalanceGem")?.precomposed()
        
        self.activateArea = AccessibilityAreaNode()
        self.activateArea.accessibilityTraits = .staticText
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.titleSignNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.activateArea)
    }
    
    func asyncLayout() -> (_ item: WalletTransactionHeaderItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleSignLayout = TextNode.asyncLayout(self.titleSignNode)
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        let iconSize = self.iconNode.image?.size ?? CGSize(width: 10.0, height: 10.0)
        
        return { item, params, neighbors in
            let leftInset: CGFloat = 15.0 + params.leftInset
            let verticalInset: CGFloat = 24.0
            
            let signString: String
            let balanceString: String
            let titleColor: UIColor
            let transferredValue: Int64
            switch item.walletTransaction {
            case let .completed(transaction):
                transferredValue = transaction.transferredValueWithoutFees
            case let .pending(transaction):
                transferredValue = -transaction.value
            }
            if transferredValue <= 0 {
                signString = ""
                balanceString = "\(formatBalanceText(-transferredValue, decimalSeparator: item.dateTimeFormat.decimalSeparator))"
                titleColor = item.theme.list.itemDestructiveColor
            } else {
                signString = ""
                balanceString = "\(formatBalanceText(transferredValue, decimalSeparator: item.dateTimeFormat.decimalSeparator))"
                titleColor = item.theme.chatList.secretTitleColor
            }
            
            let title = NSMutableAttributedString()
            if let range = balanceString.range(of: item.dateTimeFormat.decimalSeparator) {
                let integralPart = String(balanceString[..<range.lowerBound])
                let fractionalPart = String(balanceString[range.lowerBound...])
                title.append(NSAttributedString(string: integralPart, font: Font.bold(48.0), textColor: titleColor))
                title.append(NSAttributedString(string: fractionalPart, font: Font.bold(24.0), textColor: titleColor))
            } else {
                title.append(NSAttributedString(string: balanceString, font: Font.bold(48.0), textColor: titleColor))
            }
            let titleSign = NSAttributedString(string: signString, font: Font.bold(48.0), textColor: titleColor)
            
            let timestamp: Int64
            switch item.walletTransaction {
            case let .completed(transaction):
                timestamp = transaction.timestamp
            case let .pending(transaction):
                timestamp = transaction.timestamp
            }
            let subtitle: String = stringForFullDate(timestamp: Int32(clamping: timestamp), strings: item.strings, dateTimeFormat: item.dateTimeFormat)
            
            let (titleSignLayout, titleSignApply) = makeTitleSignLayout(TextNodeLayoutArguments(attributedString: titleSign, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - leftInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: title, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - leftInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: subtitle, font: Font.regular(13.0), textColor: item.theme.list.freeTextColor), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - params.rightInset - leftInset * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let contentSize: CGSize
            
            contentSize = CGSize(width: params.width, height: titleLayout.size.height + verticalInset + verticalInset)
            let insets = itemListNeighborsGroupedInsets(neighbors)
            
            let titleScale: CGFloat = min(1.0, (params.width - 40.0 - iconSize.width) / titleLayout.size.width)
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            
            return (layout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    //strongSelf.activateArea.accessibilityLabel = attributedText.string
                    
                    let _ = titleSignApply()
                    let _ = titleApply()
                    let _ = subtitleApply()
                    
                    let iconSpacing: CGFloat = 4.0
                    let contentWidth = titleSignLayout.size.width + iconSpacing + titleLayout.size.width + iconSpacing + iconSize.width * 3.0 / 2.0
                    let contentOrigin = floor((params.width - contentWidth) / 2.0)
                    let titleSignFrame = CGRect(origin: CGPoint(x: contentOrigin, y: verticalInset), size: titleSignLayout.size)
                    let iconFrame = CGRect(origin: CGPoint(x: contentOrigin + titleSignFrame.width * titleScale + iconSpacing, y: titleSignFrame.minY + floor((titleLayout.size.height - iconSize.height) / 2.0) - 2.0), size: iconSize)
                    let titleFrame = CGRect(origin: CGPoint(x: iconFrame.maxX + iconSpacing, y: verticalInset), size: titleLayout.size)
                    let subtitleFrame = CGRect(origin: CGPoint(x: floor((params.width - subtitleLayout.size.width) / 2.0), y: titleFrame.maxY - 5.0), size: subtitleLayout.size)
                    strongSelf.titleSignNode.position = titleSignFrame.center
                    strongSelf.titleSignNode.bounds = CGRect(origin: CGPoint(), size: titleSignFrame.size)
                    strongSelf.titleSignNode.transform = CATransform3DMakeScale(titleScale, titleScale, 1.0)
                    strongSelf.titleNode.position = titleFrame.center
                    strongSelf.titleNode.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
                    strongSelf.titleNode.transform = CATransform3DMakeScale(titleScale, titleScale, 1.0)
                    strongSelf.subtitleNode.frame = subtitleFrame
                    strongSelf.iconNode.frame = iconFrame
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
