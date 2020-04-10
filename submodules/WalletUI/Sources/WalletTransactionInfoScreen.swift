import Foundation
import UIKit
import AppBundle
import AsyncDisplayKit
import Display
import SolidRoundedButtonNode
import SwiftSignalKit
import OverlayStatusController
import WalletCore
import AnimatedStickerNode
import Markdown

private func stringForFullDate(timestamp: Int32, strings: WalletStrings, dateTimeFormat: WalletPresentationDateTimeFormat) -> String {
    var t: time_t = Int(timestamp)
    var timeinfo = tm()
    localtime_r(&t, &timeinfo);
    
    let dayString = "\(timeinfo.tm_mday)"
    let yearString = "\(2000 + timeinfo.tm_year - 100)"
    let timeString = stringForShortTimestamp(hours: Int32(timeinfo.tm_hour), minutes: Int32(timeinfo.tm_min), dateTimeFormat: dateTimeFormat)
    
    let monthFormat: (String, String, String) -> (String, [(Int, NSRange)])
    switch timeinfo.tm_mon + 1 {
    case 1:
        monthFormat = strings.Wallet_Time_PreciseDate_m1
    case 2:
        monthFormat = strings.Wallet_Time_PreciseDate_m2
    case 3:
        monthFormat = strings.Wallet_Time_PreciseDate_m3
    case 4:
        monthFormat = strings.Wallet_Time_PreciseDate_m4
    case 5:
        monthFormat = strings.Wallet_Time_PreciseDate_m5
    case 6:
        monthFormat = strings.Wallet_Time_PreciseDate_m6
    case 7:
        monthFormat = strings.Wallet_Time_PreciseDate_m7
    case 8:
        monthFormat = strings.Wallet_Time_PreciseDate_m8
    case 9:
        monthFormat = strings.Wallet_Time_PreciseDate_m9
    case 10:
        monthFormat = strings.Wallet_Time_PreciseDate_m10
    case 11:
        monthFormat = strings.Wallet_Time_PreciseDate_m11
    case 12:
        monthFormat = strings.Wallet_Time_PreciseDate_m12
    default:
        return ""
    }

    return monthFormat(dayString, yearString, timeString).0
}

private enum WalletTransactionAddress {
    case list([String])
    case none
    case unknown
}

private func stringForAddress(strings: WalletStrings, address: WalletTransactionAddress) -> String {
    switch address {
        case let .list(addresses):
            return addresses.map { formatAddress($0) }.joined(separator: "\n\n")
        case .none:
            return strings.Wallet_TransactionInfo_NoAddress
        case .unknown:
            return "<unknown>"
    }
}

private extension WalletInfoTransaction {
    var isEncrypted: Bool {
        switch self {
        case .pending:
            return false
        case let .completed(transaction):
            if let inMessage = transaction.inMessage {
                switch inMessage.contents {
                case .encryptedText:
                    return true
                default:
                    break
                }
            }
            for message in transaction.outMessages {
                switch message.contents {
                    case .encryptedText:
                        return true
                    default:
                        break
                }
            }
            return false
        }
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
    case let .pending(pending):
        return .list([pending.address])
    }
}

private func extractDescription(_ walletTransaction: WalletInfoTransaction) -> (string: String, isEncrypted: Bool) {
    switch walletTransaction {
    case let .completed(walletTransaction):
        let transferredValue = walletTransaction.transferredValueWithoutFees
        var text = ""
        var isEncrypted = false
        if transferredValue <= 0 {
            for message in walletTransaction.outMessages {
                if !text.isEmpty {
                    text.append("\n\n")
                }
                switch message.contents {
                case .raw:
                    break
                case .encryptedText:
                    text.append("Encrypted Comment")
                    isEncrypted = true
                case let .plainText(plainText):
                    text.append(plainText)
                }
            }
        } else {
            if let inMessage = walletTransaction.inMessage {
                switch inMessage.contents {
                case .raw:
                    text = ""
                case .encryptedText:
                    text = "Encrypted Comment"
                    isEncrypted = true
                case let .plainText(plainText):
                    text = plainText
                }
            }
        }
        return (text, isEncrypted)
    case let .pending(pending):
        return (String(data: pending.comment, encoding: .utf8) ?? "", false)
    }
}

private func messageBubbleImage(incoming: Bool, fillColor: UIColor, strokeColor: UIColor) -> UIImage {
    let diameter: CGFloat = 36.0
    let corner: CGFloat = 7.0
    
    return generateImage(CGSize(width: 42.0, height: diameter), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.scaleBy(x: incoming ? 1.0 : -1.0, y: -1.0)
        context.translateBy(x: -size.width / 2.0 + 0.5, y: -size.height / 2.0 + 0.5)
        
        let lineWidth: CGFloat = 1.0
        context.setFillColor(fillColor.cgColor)
        context.setLineWidth(lineWidth)
        context.setStrokeColor(strokeColor.cgColor)
        
        let _ = try? drawSvgPath(context, path: "M6,17.5 C6,7.83289181 13.8350169,0 23.5,0 C33.1671082,0 41,7.83501688 41,17.5 C41,27.1671082 33.1649831,35 23.5,35 C19.2941198,35 15.4354328,33.5169337 12.4179496,31.0453367 C9.05531719,34.9894816 -2.41102995e-08,35 0,35 C5.972003,31.5499861 6,26.8616169 6,26.8616169 L6,17.5 L6,17.5 ")
        context.strokePath()
        
        let _ = try? drawSvgPath(context, path: "M6,17.5 C6,7.83289181 13.8350169,0 23.5,0 C33.1671082,0 41,7.83501688 41,17.5 C41,27.1671082 33.1649831,35 23.5,35 C19.2941198,35 15.4354328,33.5169337 12.4179496,31.0453367 C9.05531719,34.9894816 -2.41102995e-08,35 0,35 C5.972003,31.5499861 6,26.8616169 6,26.8616169 L6,17.5 L6,17.5 ")
        context.fillPath()
    })!.stretchableImage(withLeftCapWidth: incoming ? Int(corner + diameter / 2.0) : Int(diameter / 2.0), topCapHeight: Int(diameter / 2.0))
}

final class WalletTransactionInfoScreen: ViewController {
    private let context: WalletContext
    private let walletInfo: WalletInfo?
    private var walletTransaction: WalletInfoTransaction
    private let walletState: Signal<(CombinedWalletState, Bool), NoError>
    private let decryptionKeyUpdated: (WalletTransactionDecryptionKey) -> Void
    private var presentationData: WalletPresentationData

    private var walletStateDisposable: Disposable?
    private var combinedState: CombinedWalletState?
    private var reloadingState = false
        
    public init(context: WalletContext, walletInfo: WalletInfo?, walletTransaction: WalletInfoTransaction, walletState: Signal<(CombinedWalletState, Bool), NoError>, enableDebugActions: Bool, decryptionKeyUpdated: @escaping (WalletTransactionDecryptionKey) -> Void) {
        self.context = context
        self.walletInfo = walletInfo
        self.walletTransaction = walletTransaction
        self.walletState = walletState
        self.decryptionKeyUpdated = decryptionKeyUpdated
        
        self.presentationData = context.presentationData
        
        let defaultTheme = self.presentationData.theme.navigationBar
        let navigationBarTheme = NavigationBarTheme(buttonColor: defaultTheme.buttonColor, disabledButtonColor: defaultTheme.disabledButtonColor, primaryTextColor: defaultTheme.primaryTextColor, backgroundColor: .clear, separatorColor: .clear, badgeBackgroundColor: defaultTheme.badgeBackgroundColor, badgeStrokeColor: defaultTheme.badgeStrokeColor, badgeTextColor: defaultTheme.badgeTextColor)
                
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: navigationBarTheme, strings: NavigationBarStrings(back: self.presentationData.strings.Wallet_Navigation_Back, close: self.presentationData.strings.Wallet_Navigation_Close)))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.navigationBar?.intrinsicCanTransitionInline = false
        
        self.navigationPresentation = .flatModal
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Wallet_Navigation_Back, style: .plain, target: nil, action: nil)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Wallet_Navigation_Done, style: .done, target: self, action: #selector(self.donePressed))
        
        self.walletStateDisposable = (walletState
        |> deliverOnMainQueue).start(next: { [weak self] combinedState, reloadingState in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.combinedState = combinedState
            strongSelf.reloadingState = reloadingState
        })
    }
    
    deinit {
        self.walletStateDisposable?.dispose()
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = WalletTransactionInfoScreenNode(context: self.context, presentationData: self.presentationData, walletTransaction: self.walletTransaction, decryptionKeyUpdated: self.decryptionKeyUpdated)
        (self.displayNode as! WalletTransactionInfoScreenNode).send = { [weak self] address in
            guard let strongSelf = self else {
                return
            }
            
            if strongSelf.reloadingState {
                strongSelf.present(standardTextAlertController(theme: strongSelf.presentationData.theme.alert, title: nil, text: strongSelf.presentationData.strings.Wallet_Send_SyncInProgress, actions: [
                    TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Wallet_Alert_OK, action: {
                    })
                ]), in: .window(.root))
            } else if let combinedState = strongSelf.combinedState, !combinedState.pendingTransactions.isEmpty {
                strongSelf.present(standardTextAlertController(theme: strongSelf.presentationData.theme.alert, title: nil, text: strongSelf.presentationData.strings.Wallet_Send_TransactionInProgress, actions: [
                    TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Wallet_Alert_OK, action: {
                    })
                ]), in: .window(.root))
            } else {
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                if let walletInfo = strongSelf.walletInfo {
                    strongSelf.push(walletSendScreen(context: strongSelf.context, randomId: randomId, walletInfo: walletInfo, address: address))
                    strongSelf.dismiss()
                }
            }
        }
        (self.displayNode as! WalletTransactionInfoScreenNode).requestDecryption = { [weak self] in
            guard let strongSelf = self, let walletInfo = strongSelf.walletInfo, case let .completed(walletTransaction) = strongSelf.walletTransaction else {
                return
            }
            let keychain = strongSelf.context.keychain
            let _ = (strongSelf.context.getServerSalt()
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Data?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { serverSalt -> Signal<WalletTransactionDecryptionKey?, NoError> in
                guard let serverSalt = serverSalt else {
                    return .single(nil)
                }
                return walletTransactionDecryptionKey(keychain: keychain, walletInfo: walletInfo, localPassword: serverSalt)
            }
            |> deliverOnMainQueue).start(next: { decryptionKey in
                guard let strongSelf = self else {
                    return
                }
                if let decryptionKey = decryptionKey {
                    strongSelf.decryptionKeyUpdated(decryptionKey)
                    let _ = (decryptWalletTransactions(decryptionKey: decryptionKey, transactions: [walletTransaction], tonInstance: strongSelf.context.tonInstance)
                    |> deliverOnMainQueue).start(next: { result in
                        guard let strongSelf = self, let updatedTransaction = result.first else {
                            return
                        }
                        strongSelf.walletTransaction = .completed(updatedTransaction)
                        (strongSelf.displayNode as! WalletTransactionInfoScreenNode).updateTransaction(strongSelf.walletTransaction)
                        (strongSelf.navigationController as? NavigationController)?.requestLayout(transition: .immediate)
                    })
                }
            })
        }
        (self.displayNode as! WalletTransactionInfoScreenNode).displayFeesTooltip = { [weak self] node, rect in
            guard let strongSelf = self else {
                return
            }
            let text: NSAttributedString
            if let _ = strongSelf.context.feeInfoUrl {
                let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white, additionalAttributes: [:])
                let link = MarkdownAttributeSet(font: Font.regular(14.0), textColor: strongSelf.context.presentationData.theme.alert.accentColor, additionalAttributes: [:])
                text = parseMarkdownIntoAttributedString(strongSelf.context.presentationData.strings.Wallet_TransactionInfo_StorageFeeInfoUrl, attributes: MarkdownAttributes(body: body, bold: body, link: link, linkAttribute: { _ in nil }), textAlignment: .center)
            } else {
                text = NSAttributedString(string: strongSelf.context.presentationData.strings.Wallet_TransactionInfo_StorageFeeInfo, font: Font.regular(14.0), textColor: .white, paragraphAlignment: .center)
            }
            let controller = TooltipController(content: .attributedText(text), baseFontSize: 17.0, timeout: 3.0, dismissByTapOutside: true, dismissByTapOutsideSource: false, dismissImmediatelyOnLayoutUpdate: false, arrowOnBottom: false)
            controller.dismissed = { [weak self] tappedInside in
                if let strongSelf = self, tappedInside {
                    if let feeInfoUrl = strongSelf.context.feeInfoUrl {
                        strongSelf.context.openUrl(feeInfoUrl)
                    }
                }
            }
            strongSelf.present(controller, in: .window(.root), with: TooltipControllerPresentationArguments(sourceViewAndRect: {
                if let _ = self {
                    return (node.view, rect.insetBy(dx: 0.0, dy: -4.0))
                }
                return nil
            }))
        }
        (self.displayNode as! WalletTransactionInfoScreenNode).displayCopyContextMenu = { [weak self] node, frame, text in
            guard let strongSelf = self else {
                return
            }
            let contextMenuController = ContextMenuController(actions: [ContextMenuAction(content: .text(title: strongSelf.presentationData.strings.Wallet_ContextMenuCopy, accessibilityLabel: strongSelf.presentationData.strings.Wallet_ContextMenuCopy), action: {
                UIPasteboard.general.string = text
            })])
            strongSelf.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
                if let strongSelf = self {
                    return (node, frame.insetBy(dx: 0.0, dy: -2.0), strongSelf.displayNode, strongSelf.displayNode.view.bounds)
                } else {
                    return nil
                }
            }))
        }
        self.displayNodeDidLoad()
    }
    
    private let measureTextNode = TextNode()
    override func preferredContentSizeForLayout(_ layout: ContainerViewLayout) -> CGSize? {
        let insets = layout.insets(options: [])
        
        let minHeight: CGFloat = 424.0
        let maxHeight: CGFloat = min(596.0, layout.size.height)
        
        let (plainText, textIsEncrypted) = extractDescription(self.walletTransaction)
        let text = NSAttributedString(string: plainText, font: textIsEncrypted ? Font.monospace(17.0) : Font.regular(17.0), textColor: .black)
        let makeTextLayout = TextNode.asyncLayout(self.measureTextNode)
        let (textLayout, _) = makeTextLayout(TextNodeLayoutArguments(attributedString: text, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: layout.size.width - 36.0 * 2.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
        
        var resultHeight = minHeight
        if textLayout.size.height > 0.0 {
            let textHeight = textLayout.size.height + 24.0
            let minOverscroll: CGFloat = 42.0
            let maxOverscroll: CGFloat = 148.0
            
            var contentHeight = minHeight + textHeight
            
            if textIsEncrypted {
                let (decryptTextLayout, _) = TextNode.asyncLayout(nil)(TextNodeLayoutArguments(attributedString: NSAttributedString(string: "Decrypt", font: Font.regular(17.0), textColor: presentationData.theme.list.itemAccentColor), maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: layout.size.width - 40.0, height: .greatestFiniteMagnitude), alignment: .center, insets: UIEdgeInsets()))
                contentHeight += 10.0 + decryptTextLayout.size.height + 10.0
            }
            
            let difference = contentHeight - maxHeight
            if difference < 0.0 {
                resultHeight = contentHeight
            } else if difference > maxOverscroll {
                resultHeight = maxHeight
            } else if difference > minOverscroll {
                resultHeight = maxHeight - (maxOverscroll - difference)
            } else {
                resultHeight = maxHeight - (minOverscroll - difference)
            }
        }
        
        return CGSize(width: layout.size.width, height: resultHeight + insets.bottom)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! WalletTransactionInfoScreenNode).containerLayoutUpdated(layout: layout, navigationHeight: self.navigationHeight, transition: transition)
    }
    
    @objc private func donePressed() {
        self.dismiss()
    }
}

private let amountFont = Font.medium(48.0)
private let fractionalFont = Font.medium(24.0)

private final class WalletTransactionInfoScreenNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private let context: WalletContext
    private var presentationData: WalletPresentationData
    private var walletTransaction: WalletInfoTransaction
    private let incoming: Bool
    private let decryptionKeyUpdated: (WalletTransactionDecryptionKey) -> Void

    private let titleNode: ImmediateTextNode
    private let timeNode: ImmediateTextNode
    private let navigationBackgroundNode: ASDisplayNode
    private let navigationSeparatorNode: ASDisplayNode
    private let scrollNode: ASScrollNode
    private let amountNode: WalletInfoBalanceNode
    private let activateArea: AccessibilityAreaNode
    private let feesNode: ImmediateTextNode
    private let feesInfoIconNode: ASImageNode
    private let feesButtonNode: ASButtonNode
    private let commentBackgroundNode: ASImageNode
    private let commentTextNode: ImmediateTextNode
    private let commentSeparatorNode: ASDisplayNode
    private let commentDecryptButtonTitle: ImmediateTextNode
    private let commentDecryptButton: HighlightableButtonNode
    private let addressTextNode: ImmediateTextNode
    private let buttonNode: SolidRoundedButtonNode
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    var send: ((String) -> Void)?
    var requestDecryption: (() -> Void)?
    var displayFeesTooltip: ((ASDisplayNode, CGRect) -> Void)?
    var displayCopyContextMenu: ((ASDisplayNode, CGRect, String) -> Void)?
  
    init(context: WalletContext, presentationData: WalletPresentationData, walletTransaction: WalletInfoTransaction, decryptionKeyUpdated: @escaping (WalletTransactionDecryptionKey) -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.walletTransaction = walletTransaction
        self.decryptionKeyUpdated = decryptionKeyUpdated
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.textAlignment = .center
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.displaysAsynchronously = false
        
        self.timeNode = ImmediateTextNode()
        self.timeNode.textAlignment = .center
        self.timeNode.maximumNumberOfLines = 1
        self.timeNode.displaysAsynchronously = false
        
        self.navigationBackgroundNode = ASDisplayNode()
        self.navigationBackgroundNode.backgroundColor = self.presentationData.theme.navigationBar.backgroundColor
        self.navigationBackgroundNode.alpha = 0.0
        self.navigationSeparatorNode = ASDisplayNode()
        self.navigationSeparatorNode.backgroundColor = self.presentationData.theme.navigationBar.separatorColor
        
        self.scrollNode = ASScrollNode()
        
        self.amountNode = WalletInfoBalanceNode(dateTimeFormat: presentationData.dateTimeFormat)
        
        self.feesNode = ImmediateTextNode()
        self.feesNode.textAlignment = .center
        self.feesNode.maximumNumberOfLines = 2
        self.feesNode.lineSpacing = 0.35
        self.feesNode.displaysAsynchronously = false
        
        self.feesInfoIconNode = ASImageNode()
        self.feesInfoIconNode.displaysAsynchronously = false
        self.feesInfoIconNode.displayWithoutProcessing = true
        self.feesInfoIconNode.image = UIImage(bundleImageName: "Wallet/InfoIcon")
        
        self.feesButtonNode = ASButtonNode()
        
        self.commentBackgroundNode = ASImageNode()
        self.commentBackgroundNode.contentMode = .scaleToFill
        self.commentBackgroundNode.isUserInteractionEnabled = true
        
        self.commentTextNode = ImmediateTextNode()
        self.commentTextNode.textAlignment = .natural
        self.commentTextNode.maximumNumberOfLines = 0
        self.commentTextNode.isUserInteractionEnabled = false
        self.commentTextNode.displaysAsynchronously = false
        
        self.commentSeparatorNode = ASDisplayNode()
        self.commentSeparatorNode.backgroundColor = self.presentationData.theme.list.itemPlainSeparatorColor
        
        self.commentDecryptButtonTitle = ImmediateTextNode()
        self.commentDecryptButtonTitle.attributedText = NSAttributedString(string: "Decrypt", font: Font.regular(17.0), textColor: presentationData.theme.list.itemAccentColor)
        self.commentDecryptButtonTitle.textAlignment = .natural
        self.commentDecryptButtonTitle.maximumNumberOfLines = 0
        self.commentDecryptButtonTitle.isUserInteractionEnabled = false
        self.commentDecryptButtonTitle.displaysAsynchronously = false
        
        self.commentDecryptButton = HighlightableButtonNode()
        
        self.addressTextNode = ImmediateTextNode()
        self.addressTextNode.maximumNumberOfLines = 4
        self.addressTextNode.textAlignment = .justified
        self.addressTextNode.lineSpacing = 0.35
        self.addressTextNode.displaysAsynchronously = false
        
        self.buttonNode = SolidRoundedButtonNode(title: "", icon: nil, theme: SolidRoundedButtonTheme(backgroundColor: self.presentationData.theme.setup.buttonFillColor, foregroundColor: self.presentationData.theme.setup.buttonForegroundColor), height: 50.0, cornerRadius: 10.0, gloss: false)
               
        self.activateArea = AccessibilityAreaNode()
        
        let timestamp: Int64
        let transferredValue: Int64
        switch walletTransaction {
        case let .completed(transaction):
            timestamp = transaction.timestamp
            transferredValue = transaction.transferredValueWithoutFees
        case let .pending(transaction):
            timestamp = transaction.timestamp
            transferredValue = -transaction.value
        }
        self.incoming = transferredValue > 0
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.scrollNode)
        self.addSubnode(self.feesNode)
        self.addSubnode(self.feesInfoIconNode)
        self.addSubnode(self.feesButtonNode)
        self.scrollNode.addSubnode(self.commentBackgroundNode)
        self.scrollNode.addSubnode(self.commentTextNode)
        self.addSubnode(self.navigationBackgroundNode)
        self.navigationBackgroundNode.addSubnode(self.navigationSeparatorNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.timeNode)
        self.addSubnode(self.amountNode)
        self.addSubnode(self.commentSeparatorNode)
        self.commentDecryptButton.addSubnode(self.commentDecryptButtonTitle)
        self.scrollNode.addSubnode(self.commentDecryptButton)
        self.addSubnode(self.addressTextNode)
        self.addSubnode(self.buttonNode)
        
        self.commentDecryptButton.isHidden = !walletTransaction.isEncrypted
    
        let titleFont = Font.semibold(17.0)
        let subtitleFont = Font.regular(13.0)
        let addressFont = Font.monospace(17.0)
        let textColor = self.presentationData.theme.list.itemPrimaryTextColor
        let seccondaryTextColor = self.presentationData.theme.list.itemSecondaryTextColor
        
        self.titleNode.attributedText = NSAttributedString(string: self.presentationData.strings.Wallet_TransactionInfo_Title, font: titleFont, textColor: textColor)
        
        self.timeNode.attributedText = NSAttributedString(string: stringForFullDate(timestamp: Int32(clamping: timestamp), strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat), font: subtitleFont, textColor: seccondaryTextColor)

        let amountString: String
        let amountColor: UIColor
        if transferredValue <= 0 {
            amountString = "\(formatBalanceText(-transferredValue, decimalSeparator: self.presentationData.dateTimeFormat.decimalSeparator))"
            amountColor = self.presentationData.theme.info.outgoingFundsTitleColor
        } else {
            amountString = "\(formatBalanceText(transferredValue, decimalSeparator: self.presentationData.dateTimeFormat.decimalSeparator))"
            amountColor = self.presentationData.theme.info.incomingFundsTitleColor
        }
        self.amountNode.balance = (amountString, amountColor)
                
        var feesString: String = ""
        if case let .completed(transaction) = walletTransaction {
            if transaction.otherFee != 0 {
                feesString.append(formatBalanceText(transaction.otherFee, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator) + " transaction fee")
            }
            if transaction.storageFee != 0 {
                if !feesString.isEmpty {
                    feesString.append("\n")
                }
                feesString.append(formatBalanceText(transaction.storageFee, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator) + " storage fee")
            }
            
            self.feesInfoIconNode.isHidden = feesString.isEmpty
        }
        self.feesNode.attributedText = NSAttributedString(string: feesString, font: subtitleFont, textColor: seccondaryTextColor)
        
        self.feesButtonNode.addTarget(self, action: #selector(self.feesPressed), forControlEvents: .touchUpInside)
        
        var commentBackgroundColor = presentationData.theme.transaction.descriptionBackgroundColor
        if commentBackgroundColor.distance(to: presentationData.theme.list.plainBackgroundColor) < 100 {
            commentBackgroundColor = UIColor(rgb: 0xf1f1f4)
        }
        self.commentBackgroundNode.image = messageBubbleImage(incoming: transferredValue > 0, fillColor: commentBackgroundColor, strokeColor: presentationData.theme.transaction.descriptionBackgroundColor)
        let (plainText, textIsEncrypted) = extractDescription(walletTransaction)
        self.commentTextNode.attributedText = NSAttributedString(string: plainText, font:  textIsEncrypted ? Font.monospace(17.0) : Font.regular(17.0), textColor: presentationData.theme.transaction.descriptionTextColor)
        
        let address = extractAddress(walletTransaction)
        var singleAddress: String?
        if case let .list(list) = address, list.count == 1 {
            singleAddress = list.first
        }
        
        if let address = singleAddress {
            self.addressTextNode.attributedText = NSAttributedString(string: formatAddress(address), font: addressFont, textColor: textColor, paragraphAlignment: .justified)
            self.buttonNode.title = presentationData.strings.Wallet_TransactionInfo_SendGrams

            self.buttonNode.pressed = { [weak self] in
                self?.send?(address)
            }
        }
        
        self.commentDecryptButton.addTarget(self, action: #selector(self.decryptCommentPressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func decryptCommentPressed() {
        self.requestDecryption?()
    }
    
    func updateTransaction(_ walletTransaction: WalletInfoTransaction) {
        self.walletTransaction = walletTransaction
        
        let (plainText, textIsEncrypted) = extractDescription(walletTransaction)
        self.commentTextNode.attributedText = NSAttributedString(string: plainText, font:  textIsEncrypted ? Font.monospace(17.0) : Font.regular(17.0), textColor: presentationData.theme.transaction.descriptionTextColor)
        
        self.commentDecryptButton.isHidden = !walletTransaction.isEncrypted
    }

    override func didLoad() {
        super.didLoad()
        
        self.scrollNode.view.delegate = self
        self.scrollNode.view.alwaysBounceVertical = true
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.view.canCancelContentTouches = true
        
        let commentGestureRecognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapCommentGesture(_:)))
        commentGestureRecognizer.tapActionAtPoint = { point in
            return .waitForSingleTap
        }
        self.commentBackgroundNode.view.addGestureRecognizer(commentGestureRecognizer)
        
        let addressGestureRecognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapAddressGesture(_:)))
        addressGestureRecognizer.tapActionAtPoint = { point in
            return .waitForSingleTap
        }
        self.addressTextNode.view.addGestureRecognizer(addressGestureRecognizer)
    }
    
    @objc func tapLongTapOrDoubleTapCommentGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, _) = recognizer.lastRecognizedGestureAndLocation {
                switch gesture {
                case .longTap:
                    let (description, _) = extractDescription(self.walletTransaction)
                    if !description.isEmpty {
                        self.displayCopyContextMenu?(self, self.commentBackgroundNode.convert(self.commentBackgroundNode.bounds, to: self), description)
                    }
                default:
                    break
                }
            }
        default:
            break
        }
    }
    
    @objc func tapLongTapOrDoubleTapAddressGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, _) = recognizer.lastRecognizedGestureAndLocation {
                switch gesture {
                case .longTap:
                    let address = extractAddress(self.walletTransaction)
                    var singleAddress: String?
                    if case let .list(list) = address, list.count == 1 {
                        singleAddress = list.first
                    }
                           
                    if let address = singleAddress {
                        self.displayCopyContextMenu?(self, self.addressTextNode.convert(self.addressTextNode.bounds, to: self), address)
                    }
                default:
                    break
                }
            }
        default:
            break
        }
    }
    
    @objc private func feesPressed() {
        self.displayFeesTooltip?(self.feesNode, self.feesNode.bounds)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateTitle(transition: .immediate)
    }
    
    private func updateTitle(transition: ContainedViewLayoutTransition) {
        guard let (layout, navigationHeight) = self.validLayout else {
            return
        }
        
        let width = layout.size.width
        let sideInset: CGFloat = 16.0
                        
        let minOffset = navigationHeight
        let maxOffset: CGFloat = 200.0
        
        let nominalFeesHeight: CGFloat = 42.0
        let minHeaderOffset = minOffset
        let maxHeaderOffset = (minOffset + maxOffset) / 2.0
        let maxHeaderPositionOffset = maxOffset - nominalFeesHeight
        
        let offset: CGFloat = max(0.0, maxOffset - self.scrollNode.view.contentOffset.y)
        let effectiveOffset = max(offset, navigationHeight)
               
        let minFeesOffset = maxOffset - nominalFeesHeight
        let maxFeesOffset = maxOffset
        let feesTransition: CGFloat = max(0.0, min(1.0, (effectiveOffset - minFeesOffset) / (maxFeesOffset - minFeesOffset)))
        let feesAlpha: CGFloat = feesTransition
        transition.updateAlpha(node: self.feesNode, alpha: feesAlpha)
        
        let headerScaleTransition: CGFloat = max(0.0, min(1.0, (effectiveOffset - minHeaderOffset) / (maxHeaderOffset - minHeaderOffset)))
        let balanceHeight = self.amountNode.update(width: width, scaleTransition: headerScaleTransition, transition: transition)
        let balanceSize = CGSize(width: width, height: balanceHeight)
        
        let maxHeaderScale: CGFloat = min(1.0, (width - 40.0) / balanceSize.width)
        let minHeaderScale: CGFloat = min(0.435, (width - 80.0 * 2.0) / balanceSize.width)
        
        let minHeaderHeight: CGFloat = balanceSize.height

        let minHeaderY = floor((navigationHeight - minHeaderHeight) / 2.0)
        let maxHeaderY: CGFloat = 90.0
        let headerPositionTransition: CGFloat = min(1.0, max(0.0, (effectiveOffset - minHeaderOffset) / (maxHeaderPositionOffset - minHeaderOffset)))
        let headerY = headerPositionTransition * maxHeaderY + (1.0 - headerPositionTransition) * minHeaderY
        let headerScale = headerScaleTransition * maxHeaderScale + (1.0 - headerScaleTransition) * minHeaderScale
        
        let balanceFrame = CGRect(origin: CGPoint(x: 0.0, y: headerY), size: balanceSize)
        transition.updateFrame(node: self.amountNode, frame: balanceFrame)
        transition.updateSublayerTransformScale(node: self.amountNode, scale: headerScale)
        
        let feesSize = self.feesNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        let feesFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - feesSize.width) / 2.0), y: headerY + 64.0), size: feesSize)
        transition.updateFrame(node: self.feesNode, frame: feesFrame)
        transition.updateFrame(node: self.feesButtonNode, frame: feesFrame)
        self.feesButtonNode.isUserInteractionEnabled = feesAlpha > 1.0 - CGFloat.ulpOfOne
        
        let minTitleOffset = minOffset
        let maxTitleOffset = (minOffset + maxOffset) / 2.0
        let titleTransition: CGFloat = max(0.0, min(1.0, (effectiveOffset - minTitleOffset) / (maxTitleOffset - minTitleOffset)))
        let titleAlpha: CGFloat = titleTransition * titleTransition
        transition.updateAlpha(node: self.titleNode, alpha: titleAlpha)
        transition.updateAlpha(node: self.timeNode, alpha: titleAlpha)
        
        let minTitleY: CGFloat = -44.0
        let maxTitleY: CGFloat = 10.0
        let titleY: CGFloat = titleTransition * maxTitleY + (1.0 - titleTransition) * minTitleY
        let titleSize = self.titleNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        let titleFrame = CGRect(origin: CGPoint(x: floor((width - titleSize.width) / 2.0), y: titleY), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        let subtitleSize = self.timeNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        let subtitleFrame = CGRect(origin: CGPoint(x: floor((width - subtitleSize.width) / 2.0), y: titleFrame.maxY + 1.0), size: subtitleSize)
        transition.updateFrame(node: self.timeNode, frame: subtitleFrame)
        
        let alphaTransition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
        let navigationAlpha: CGFloat = (headerScaleTransition <= 0.0 + CGFloat.ulpOfOne) ? 1.0 : 0.0
        if self.navigationBackgroundNode.alpha != navigationAlpha {
            alphaTransition.updateAlpha(node: self.navigationBackgroundNode, alpha: navigationAlpha, beginWithCurrentState: true)
        }
        
        let separatorAlpha: CGFloat = self.scrollNode.view.contentOffset.y + self.scrollNode.frame.height >= self.scrollNode.view.contentSize.height ? 0.0 : 1.0
        if self.commentSeparatorNode.alpha != separatorAlpha {
            alphaTransition.updateAlpha(node: self.commentSeparatorNode, alpha: separatorAlpha, beginWithCurrentState: true)
        }
    }

    func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationHeight)
        
        var insets = layout.insets(options: [])
        insets.top += navigationHeight
        let sideInset: CGFloat = 22.0
    
        self.updateTitle(transition: transition)
                
        let buttonSideInset: CGFloat = 16.0
        let bottomInset = insets.bottom + 10.0
        let buttonWidth = layout.size.width - buttonSideInset * 2.0
        let buttonHeight: CGFloat = 50.0
        let buttonFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - buttonWidth) / 2.0), y: layout.size.height - bottomInset - buttonHeight), size: CGSize(width: buttonWidth, height: buttonHeight))
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
        let _ = self.buttonNode.updateLayout(width: buttonFrame.width, transition: transition)
        
        let addressSize = self.addressTextNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        let addressFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - addressSize.width) / 2.0), y: buttonFrame.minY - addressSize.height - 34.0), size: addressSize)
        transition.updateFrame(node: self.addressTextNode, frame: addressFrame)
        
        transition.updateFrame(node: self.navigationBackgroundNode, frame: CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: navigationHeight))
        transition.updateFrame(node: self.navigationSeparatorNode, frame: CGRect(x: 0.0, y: navigationHeight, width: layout.size.width, height: UIScreenPixel))
        
        let commentSeparatorFrame = CGRect(x: 0.0, y: addressFrame.minY - 36.0, width: layout.size.width, height: UIScreenPixel)
        transition.updateFrame(node: self.commentSeparatorNode, frame: commentSeparatorFrame)
        
        let scrollFrame = CGRect(x: 0.0, y: navigationHeight, width: layout.size.width, height: commentSeparatorFrame.minY - navigationHeight)
        transition.updateFrame(node: self.scrollNode, frame: scrollFrame)
        
        let commentSize = self.commentTextNode.updateLayout(CGSize(width: layout.size.width - 36.0 * 2.0, height: CGFloat.greatestFiniteMagnitude))
        let commentOrigin = CGPoint(x: floor((layout.size.width - commentSize.width) / 2.0), y: 175.0)
        let commentFrame = CGRect(origin: commentOrigin, size: commentSize)
        transition.updateFrame(node: self.commentTextNode, frame: commentFrame)

        var commentBackgroundFrame = commentSize.width > 0.0 ? commentFrame.insetBy(dx: -11.0, dy: -7.0) : CGRect()
        commentBackgroundFrame.size.width += 7.0
        if self.incoming {
            commentBackgroundFrame.origin.x -= 7.0
        }
        transition.updateFrame(node: self.commentBackgroundNode, frame: commentBackgroundFrame)
        
        var commentMaxY = commentOrigin.y + commentBackgroundFrame.height
        
        let decryptSize = self.commentDecryptButtonTitle.updateLayout(CGSize(width: layout.size.width - 40.0, height: .greatestFiniteMagnitude))
        let decryptButtonFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - decryptSize.width) / 2.0), y: commentMaxY + 10.0), size: decryptSize)
        transition.updateFrame(node: self.commentDecryptButton, frame: decryptButtonFrame.insetBy(dx: -10.0, dy: -10.0))
        transition.updateFrame(node: self.commentDecryptButtonTitle, frame: CGRect(origin: CGPoint(x: 10.0, y: 10.0), size: decryptSize))
        
        if self.walletTransaction.isEncrypted {
            commentMaxY = decryptButtonFrame.maxY + 10.0
        }
        
        let contentHeight = commentMaxY
        self.scrollNode.view.contentSize = CGSize(width: layout.size.width, height: contentHeight)
        
        let isScrollEnabled = contentHeight - scrollFrame.height > 20.0
        self.scrollNode.view.isScrollEnabled = isScrollEnabled
        self.scrollNode.clipsToBounds = isScrollEnabled
        self.commentSeparatorNode.isHidden = !isScrollEnabled
    }
}
