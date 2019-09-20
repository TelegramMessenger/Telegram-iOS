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
import MergeLists

public final class WalletInfoScreen: ViewController {
    private let context: AccountContext
    private let tonContext: TonContext
    private let walletInfo: WalletInfo
    private let address: String
    
    private var presentationData: PresentationData
    
    public init(context: AccountContext, tonContext: TonContext, walletInfo: WalletInfo, address: String) {
        self.context = context
        self.tonContext = tonContext
        self.walletInfo = walletInfo
        self.address = address
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let defaultNavigationPresentationData = NavigationBarPresentationData(presentationTheme: self.presentationData.theme, presentationStrings: self.presentationData.strings)
        let navigationBarTheme = NavigationBarTheme(buttonColor: .white, disabledButtonColor: .white, primaryTextColor: .white, backgroundColor: .clear, separatorColor: .clear, badgeBackgroundColor: defaultNavigationPresentationData.theme.badgeBackgroundColor, badgeStrokeColor: defaultNavigationPresentationData.theme.badgeStrokeColor, badgeTextColor: defaultNavigationPresentationData.theme.badgeTextColor)
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: navigationBarTheme, strings: defaultNavigationPresentationData.strings))
        
        self.statusBar.statusBarStyle = .White
        self.navigationPresentation = .modalInLargeLayout
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.navigationBar?.intrinsicCanTransitionInline = false
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: generateTintedImage(image: UIImage(bundleImageName: "Wallet/NavigationSettingsIcon"), color: .white), style: .plain, target: self, action: #selector(self.settingsPressed))
        
        self.scrollToTop = { [weak self] in
            (self?.displayNode as? WalletInfoScreenNode)?.scrollToTop()
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func backPressed() {
        self.dismiss()
    }
    
    @objc private func settingsPressed() {
        self.push(walletSettingsController(context: self.context, tonContext: self.tonContext, walletInfo: self.walletInfo))
    }
    
    override public func loadDisplayNode() {
        self.displayNode = WalletInfoScreenNode(account: self.context.account, tonContext: self.tonContext, presentationData: self.presentationData, walletInfo: self.walletInfo, address: self.address, sendAction: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.push(walletSendScreen(context: strongSelf.context, tonContext: strongSelf.tonContext, walletInfo: strongSelf.walletInfo))
        }, receiveAction: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.push(walletReceiveScreen(context: strongSelf.context, tonContext: strongSelf.tonContext, walletInfo: strongSelf.walletInfo, address: strongSelf.address))
        }, openTransaction: { [weak self] transaction in
            guard let strongSelf = self else {
                return
            }
            strongSelf.push(walletTransactionInfoController(context: strongSelf.context, walletTransaction: transaction))
        })
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! WalletInfoScreenNode).containerLayoutUpdated(layout: layout, navigationHeight: self.navigationHeight, transition: transition)
    }
}

private final class WalletInfoBalanceNode: ASDisplayNode {
    private let balanceTextNode: ImmediateTextNode
    private let balanceIconNode: ASImageNode
    
    var balance: String = " " {
        didSet {
            self.balanceTextNode.attributedText = NSAttributedString(string: self.balance, font: Font.bold(39.0), textColor: .white)
        }
    }
    
    init(theme: PresentationTheme) {
        self.balanceTextNode = ImmediateTextNode()
        self.balanceTextNode.displaysAsynchronously = false
        self.balanceTextNode.attributedText = NSAttributedString(string: " ", font: Font.bold(39.0), textColor: .white)
        self.balanceTextNode.layer.minificationFilter = .linear
        
        self.balanceIconNode = ASImageNode()
        self.balanceIconNode.displaysAsynchronously = false
        self.balanceIconNode.displayWithoutProcessing = true
        self.balanceIconNode.image = UIImage(bundleImageName: "Wallet/BalanceGem")?.precomposed()
        
        super.init()
        
        self.addSubnode(self.balanceTextNode)
        self.addSubnode(self.balanceIconNode)
    }
    
    func update(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let sideInset: CGFloat = 16.0
        let balanceIconSpacing: CGFloat = 8.0
        
        let balanceTextSize = self.balanceTextNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: 200.0))
        let balanceIconSize = self.balanceIconNode.image?.size ?? CGSize(width: 38.0, height: 34.0)
        
        let balanceOrigin = CGPoint(x: floor((width - balanceTextSize.width - balanceIconSpacing - balanceIconSize.width / 2.0) / 2.0), y: 0.0)
        
        let balanceTextFrame = CGRect(origin: balanceOrigin, size: balanceTextSize)
        let balanceIconFrame = CGRect(origin: CGPoint(x: balanceTextFrame.maxX + balanceIconSpacing, y: balanceTextFrame.minY + floor((balanceTextFrame.height - balanceIconSize.height) / 2.0)), size: balanceIconSize)
        transition.updateFrameAdditive(node: self.balanceTextNode, frame: balanceTextFrame)
        transition.updateFrameAdditive(node: self.balanceIconNode, frame: balanceIconFrame)
        
        return balanceTextSize.height
    }
}

private final class WalletInfoHeaderNode: ASDisplayNode {
    var balance: Int64?
    
    let balanceNode: WalletInfoBalanceNode
    private let balanceSubtitleNode: ImmediateTextNode
    private let receiveButtonNode: SolidRoundedButtonNode
    private let sendButtonNode: SolidRoundedButtonNode
    private let headerBackgroundNode: ASImageNode
    
    init(theme: PresentationTheme, sendAction: @escaping () -> Void, receiveAction: @escaping () -> Void) {
        self.balanceNode = WalletInfoBalanceNode(theme: theme)
        
        self.balanceSubtitleNode = ImmediateTextNode()
        self.balanceSubtitleNode.displaysAsynchronously = false
        self.balanceSubtitleNode.attributedText = NSAttributedString(string: "your balance", font: Font.regular(13), textColor: UIColor(white: 1.0, alpha: 0.6))
        
        self.headerBackgroundNode = ASImageNode()
        self.headerBackgroundNode.displaysAsynchronously = false
        self.headerBackgroundNode.displayWithoutProcessing = true
        self.headerBackgroundNode.image = generateImage(CGSize(width: 20.0, height: 20.0), rotatedContext: { size, context in
            context.setFillColor(UIColor.black.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: size))
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: size.height / 2.0), size: size))
        })?.stretchableImage(withLeftCapWidth: 10, topCapHeight: 1)
        
        self.receiveButtonNode = SolidRoundedButtonNode(title: "Receive", icon: UIImage(bundleImageName: "Wallet/ReceiveButtonIcon"), theme: SolidRoundedButtonTheme(backgroundColor: .white, foregroundColor: .black), height: 50.0, cornerRadius: 10.0, gloss: false)
        self.sendButtonNode = SolidRoundedButtonNode(title: "Send", icon: UIImage(bundleImageName: "Wallet/SendButtonIcon"), theme: SolidRoundedButtonTheme(backgroundColor: .white, foregroundColor: .black), height: 50.0, cornerRadius: 10.0, gloss: false)
        
        super.init()
        
        self.addSubnode(self.headerBackgroundNode)
        self.addSubnode(self.receiveButtonNode)
        self.addSubnode(self.sendButtonNode)
        self.addSubnode(self.balanceNode)
        self.addSubnode(self.balanceSubtitleNode)
        
        self.receiveButtonNode.pressed = {
            receiveAction()
        }
        self.sendButtonNode.pressed = {
            sendAction()
        }
    }
    
    func update(size: CGSize, navigationHeight: CGFloat, offset: CGFloat, transition: ContainedViewLayoutTransition) {
        let sideInset: CGFloat = 16.0
        let buttonSideInset: CGFloat = 48.0
        let titleSpacing: CGFloat = 10.0
        let termsSpacing: CGFloat = 10.0
        let buttonHeight: CGFloat = 50.0
        let balanceSubtitleSpacing: CGFloat = 0.0
        
        let minOffset = navigationHeight
        let maxOffset = size.height
        
        let minHeaderOffset = minOffset
        let maxHeaderOffset = (minOffset + maxOffset) / 2.0
        
        let effectiveOffset = max(offset, navigationHeight)
        
        let minButtonsOffset = maxOffset - buttonHeight - sideInset
        let maxButtonsOffset = maxOffset
        let buttonTransition: CGFloat = max(0.0, min(1.0, (effectiveOffset - minButtonsOffset) / (maxButtonsOffset - minButtonsOffset)))
        let buttonAlpha = buttonTransition * 1.0
        
        let balanceSubtitleSize = self.balanceSubtitleNode.updateLayout(CGSize(width: size.width - sideInset * 2.0, height: 200.0))
        
        let balanceHeight = self.balanceNode.update(width: size.width, transition: transition)
        let balanceSize = CGSize(width: size.width, height: balanceHeight)
        
        let minHeaderScale: CGFloat = 0.435
        
        let minHeaderHeight: CGFloat = balanceSize.height + balanceSubtitleSize.height + balanceSubtitleSpacing
        
        let minHeaderY = navigationHeight - 44.0 + floor((44.0 - minHeaderHeight) / 2.0)
        let maxHeaderY = floor((size.height - balanceSize.height) / 2.0)
        let headerScaleTransition: CGFloat = max(0.0, min(1.0, (effectiveOffset - minHeaderOffset) / (maxHeaderOffset - minHeaderOffset)))
        let headerPositionTransition: CGFloat = max(0.0, (effectiveOffset - minHeaderOffset) / (maxOffset - minHeaderOffset))
        let headerY = headerPositionTransition * maxHeaderY + (1.0 - headerPositionTransition) * minHeaderY
        let headerScale = headerScaleTransition * 1.0 + (1.0 - headerScaleTransition) * minHeaderScale
        
        let balanceFrame = CGRect(origin: CGPoint(x: 0.0, y: headerY), size: balanceSize)
        transition.updateFrame(node: self.balanceNode, frame: balanceFrame)
        transition.updateSublayerTransformScale(node: self.balanceNode, scale: headerScale)
        
        transition.updateFrameAdditive(node: self.balanceSubtitleNode, frame: CGRect(origin: CGPoint(x: floor((size.width - balanceSubtitleSize.width) / 2.0), y: balanceFrame.midY + (balanceFrame.height / 2.0 * headerScale) + balanceSubtitleSpacing), size: balanceSubtitleSize))
        
        let headerHeight: CGFloat = 1000.0
        transition.updateFrame(node: self.headerBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: effectiveOffset + 10.0 - headerHeight), size: CGSize(width: size.width, height: headerHeight)))
        
        let leftButtonFrame = CGRect(origin: CGPoint(x: sideInset, y: effectiveOffset - sideInset - buttonHeight), size: CGSize(width: floor((size.width - sideInset * 3.0) / 2.0), height: buttonHeight))
        let sendButtonFrame = CGRect(origin: CGPoint(x: leftButtonFrame.maxX + sideInset, y: leftButtonFrame.minY), size: CGSize(width: size.width - leftButtonFrame.maxX - sideInset * 2.0, height: buttonHeight))
        let fullButtonFrame = CGRect(origin: CGPoint(x: sideInset, y: effectiveOffset - sideInset - buttonHeight), size: CGSize(width: size.width - sideInset * 2.0, height: buttonHeight))
        
        var receiveButtonFrame: CGRect
        if let balance = self.balance, balance > 0 {
            receiveButtonFrame = leftButtonFrame
            self.receiveButtonNode.isHidden = false
            self.sendButtonNode.isHidden = false
        } else {
            receiveButtonFrame = fullButtonFrame
            if self.balance == nil {
                self.receiveButtonNode.isHidden = true
                self.sendButtonNode.isHidden = true
            } else {
                self.receiveButtonNode.isHidden = false
                self.sendButtonNode.isHidden = true
            }
        }
        if self.balance == nil {
            self.balanceNode.isHidden = true
            self.balanceSubtitleNode.isHidden = true
        } else {
            self.balanceNode.isHidden = false
            self.balanceSubtitleNode.isHidden = false
        }
        transition.updateFrame(node: self.receiveButtonNode, frame: receiveButtonFrame)
        transition.updateAlpha(node: self.receiveButtonNode, alpha: buttonAlpha)
        self.receiveButtonNode.updateLayout(width: receiveButtonFrame.width, transition: transition)
        transition.updateFrame(node: self.sendButtonNode, frame: sendButtonFrame)
        transition.updateAlpha(node: self.sendButtonNode, alpha: buttonAlpha)
        self.sendButtonNode.updateLayout(width: sendButtonFrame.width, transition: transition)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.sendButtonNode.hitTest(self.view.convert(point, to: self.sendButtonNode.view), with: event) {
            return result
        }
        if let result = self.receiveButtonNode.hitTest(self.view.convert(point, to: self.receiveButtonNode.view), with: event) {
            return result
        }
        return nil
    }
    
    func animateIn() {
        self.sendButtonNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.receiveButtonNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.balanceNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.balanceSubtitleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
}

private struct WalletInfoListTransaction {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private struct WalletInfoListEntry: Equatable, Comparable, Identifiable {
    let index: Int
    let item: WalletTransaction
    
    var stableId: WalletTransactionId {
        return self.item.transactionId
    }
    
    static func <(lhs: WalletInfoListEntry, rhs: WalletInfoListEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(theme: PresentationTheme, strings: PresentationStrings, action: @escaping (WalletTransaction) -> Void) -> ListViewItem {
        let item = self.item
        return WalletInfoTransactionItem(theme: theme, strings: strings, walletTransaction: self.item, action: {
            action(item)
        })
    }
}

private func preparedTransition(from fromEntries: [WalletInfoListEntry], to toEntries: [WalletInfoListEntry], presentationData: PresentationData, action: @escaping (WalletTransaction) -> Void) -> WalletInfoListTransaction {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(theme: presentationData.theme, strings: presentationData.strings, action: action), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(theme: presentationData.theme, strings: presentationData.strings, action: action), directionHint: nil) }
    
    return WalletInfoListTransaction(deletions: deletions, insertions: insertions, updates: updates)
}

private final class WalletInfoScreenNode: ViewControllerTracingNode {
    private let account: Account
    private let tonContext: TonContext
    private var presentationData: PresentationData
    private let walletInfo: WalletInfo
    private let address: String
    private let openTransaction: (WalletTransaction) -> Void
    
    private let headerNode: WalletInfoHeaderNode
    private let listNode: ListView
    private let emptyNode: WalletInfoEmptyNode
    
    private var enqueuedTransactions: [WalletInfoListTransaction] = []
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private let balanceDisposable = MetaDisposable()
    private let transactionListDisposable = MetaDisposable()
    
    private var listOffset: CGFloat?
    private var loadingMoreTransactions: Bool = false
    private var canLoadMoreTransactions: Bool = true
    
    private var currentEntries: [WalletInfoListEntry]?
    
    init(account: Account, tonContext: TonContext, presentationData: PresentationData, walletInfo: WalletInfo, address: String, sendAction: @escaping () -> Void, receiveAction: @escaping () -> Void, openTransaction: @escaping (WalletTransaction) -> Void) {
        self.account = account
        self.tonContext = tonContext
        self.presentationData = presentationData
        self.walletInfo = walletInfo
        self.address = address
        self.openTransaction = openTransaction
        
        self.headerNode = WalletInfoHeaderNode(theme: presentationData.theme, sendAction: sendAction, receiveAction: receiveAction)
        
        self.listNode = ListView()
        self.listNode.verticalScrollIndicatorColor = self.presentationData.theme.list.scrollIndicatorColor
        self.listNode.verticalScrollIndicatorFollowsOverscroll = true
        
        self.emptyNode = WalletInfoEmptyNode(presentationData: self.presentationData, address: self.address)
        self.emptyNode.isHidden = true
        
        super.init()
        
        self.backgroundColor = .white
        
        self.balanceDisposable.set((currentWalletBalance(publicKey: walletInfo.publicKey, tonInstance: tonContext.instance)
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            let firstTime = strongSelf.headerNode.balance == nil
            strongSelf.headerNode.balanceNode.balance = formatBalanceText(max(0, value.rawValue))
            strongSelf.headerNode.balance = max(0, value.rawValue)
            if let (layout, navigationHeight) = strongSelf.validLayout {
                strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate)
            }
            if firstTime {
                strongSelf.headerNode.animateIn()
            }
        }))
        
        self.addSubnode(self.listNode)
        self.addSubnode(self.emptyNode)
        self.addSubnode(self.headerNode)
        
        self.listNode.updateFloatingHeaderOffset = { [weak self] offset, listTransition in
            guard let strongSelf = self, let (layout, navigationHeight) = strongSelf.validLayout else {
                return
            }
            
            strongSelf.listOffset = offset
            
            strongSelf.headerNode.update(size: strongSelf.headerNode.bounds.size, navigationHeight: navigationHeight, offset: offset, transition: listTransition)
        }
        
        self.listNode.visibleBottomContentOffsetChanged = { [weak self] offset in
            guard let strongSelf = self else {
                return
            }
            guard case let .known(value) = offset, value < 100.0 else {
                return
            }
            if !strongSelf.loadingMoreTransactions && strongSelf.canLoadMoreTransactions {
                strongSelf.loadMoreTransactions()
            }
        }
        
        self.listNode.didEndScrolling = { [weak self] in
            guard let strongSelf = self, let (_, navigationHeight) = strongSelf.validLayout else {
                return
            }
            switch strongSelf.listNode.visibleContentOffset() {
            case let .known(offset):
                if offset < strongSelf.listNode.insets.top {
                    /*if offset > strongSelf.listNode.insets.top / 2.0 {
                        strongSelf.scrollToHideHeader()
                    } else {
                        strongSelf.scrollToTop()
                    }*/
                }
            default:
                break
            }
        }
        
        self.refreshTransactions()
    }
    
    func scrollToHideHeader() {
        guard let (_, navigationHeight) = self.validLayout else {
            return
        }
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(navigationHeight), animated: true, curve: .Spring(duration: 0.4), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
    }
    
    func scrollToTop() {
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Spring(duration: 0.4), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let isFirstLayout = self.validLayout == nil
        self.validLayout = (layout, navigationHeight)
        
        let headerHeight: CGFloat = navigationHeight + 260.0
        let topInset: CGFloat = headerHeight
        
        let headerFrame = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: headerHeight))
        transition.updateFrame(node: self.headerNode, frame: headerFrame)
        self.headerNode.update(size: headerFrame.size, navigationHeight: navigationHeight, offset: self.listOffset ?? 0.0, transition: transition)
        
        transition.updateFrame(node: self.listNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        var duration: Double = 0.0
        var curve: UInt = 0
        switch transition {
        case .immediate:
            break
        case let .animated(animationDuration, animationCurve):
            duration = animationDuration
            switch animationCurve {
            case .easeInOut, .custom:
                break
            case .spring:
                curve = 7
            }
        }
        
        let listViewCurve: ListViewAnimationCurve
        if curve == 7 {
            listViewCurve = .Spring(duration: duration)
        } else {
            listViewCurve = .Default(duration: duration)
        }
        
        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: topInset, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0), headerInsets: UIEdgeInsets(top: navigationHeight, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0), scrollIndicatorInsets: UIEdgeInsets(top: topInset + 3.0, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0), duration: duration, curve: listViewCurve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        let emptyNodeHeight = self.emptyNode.updateLayout(width: layout.size.width, transition: transition)
        let maxEmptyNodeHeight: CGFloat = max(100.0, layout.size.height - headerHeight)
        let emptyNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: headerHeight + floor((maxEmptyNodeHeight - emptyNodeHeight) / 2.0)), size: CGSize(width: layout.size.width, height: emptyNodeHeight))
        transition.updateFrame(node: self.emptyNode, frame: emptyNodeFrame)
        
        if isFirstLayout {
            while !self.enqueuedTransactions.isEmpty {
                self.dequeueTransaction()
            }
        }
    }
    
    private func refreshTransactions() {
        self.transactionListDisposable.set(nil)
        self.loadingMoreTransactions = true
        
        self.transactionListDisposable.set((getWalletTransactions(address: self.address, previousId: nil, tonInstance: self.tonContext.instance)
        |> deliverOnMainQueue).start(next: { [weak self] transactions in
            guard let strongSelf = self else {
                return
            }
            strongSelf.transactionsLoaded(isReload: true, transactions: transactions)
        }, error: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
        }))
    }
    
    private func loadMoreTransactions() {
        if self.loadingMoreTransactions {
            return
        }
        self.loadingMoreTransactions = true
        self.transactionListDisposable.set((getWalletTransactions(address: self.address, previousId: self.currentEntries?.last?.item.transactionId, tonInstance: self.tonContext.instance)
        |> deliverOnMainQueue).start(next: { [weak self] transactions in
            guard let strongSelf = self else {
                return
            }
            strongSelf.transactionsLoaded(isReload: false, transactions: transactions)
        }, error: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
        }))
    }
    
    private func transactionsLoaded(isReload: Bool, transactions: [WalletTransaction]) {
        self.loadingMoreTransactions = false
        self.canLoadMoreTransactions = transactions.count > 2
        
        let isFirst = self.currentEntries == nil
        
        var updatedEntries: [WalletInfoListEntry] = []
        if isReload {
            for transaction in transactions {
                updatedEntries.append(WalletInfoListEntry(index: updatedEntries.count, item: transaction))
            }
        } else {
            updatedEntries = self.currentEntries ?? []
            var existingIds = Set(updatedEntries.map { $0.item.transactionId })
            for transaction in transactions {
                if !existingIds.contains(transaction.transactionId) {
                    existingIds.insert(transaction.transactionId)
                    updatedEntries.append(WalletInfoListEntry(index: updatedEntries.count, item: transaction))
                }
            }
        }
        
        let transaction = preparedTransition(from: self.currentEntries ?? [], to: updatedEntries, presentationData: self.presentationData, action: { [weak self] transaction in
            guard let strongSelf = self else {
                return
            }
            strongSelf.openTransaction(transaction)
        })
        self.currentEntries = updatedEntries
        
        self.enqueuedTransactions.append(transaction)
        self.dequeueTransaction()
        
        if updatedEntries.isEmpty {
            self.emptyNode.isHidden = false
        } else {
            self.emptyNode.isHidden = true
        }
        
        if isFirst {
            if !updatedEntries.isEmpty {
                self.emptyNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            } else {
                self.listNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
        }
    }
    
    private func dequeueTransaction() {
        guard let layout = self.validLayout, let transaction = self.enqueuedTransactions.first else {
            return
        }
        
        self.enqueuedTransactions.remove(at: 0)
        
        var options = ListViewDeleteAndInsertOptions()
        options.insert(.Synchronous)
        options.insert(.PreferSynchronousResourceLoading)
        options.insert(.PreferSynchronousDrawing)
        
        self.listNode.transaction(deleteIndices: transaction.deletions, insertIndicesAndItems: transaction.insertions, updateIndicesAndItems: transaction.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in
        })
    }
}

func formatBalanceText(_ value: Int64) -> String {
    var balanceText = "\(abs(value))"
    while balanceText.count < 10 {
        balanceText.insert("0", at: balanceText.startIndex)
    }
    balanceText.insert(".", at: balanceText.index(balanceText.endIndex, offsetBy: -9))
    while true {
        if balanceText.hasSuffix("0") {
            if balanceText.hasSuffix(".0") {
                break
            } else {
                balanceText.removeLast()
            }
        } else {
            break
        }
    }
    if value < 0 {
        balanceText.insert("-", at: balanceText.startIndex)
    }
    return balanceText
}
