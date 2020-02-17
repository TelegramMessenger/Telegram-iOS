import Foundation
import UIKit
import AppBundle
import AsyncDisplayKit
import Display
import SolidRoundedButtonNode
import SwiftSignalKit
import MergeLists
import AnimatedStickerNode
import WalletCore

private class WalletInfoTitleView: UIView, NavigationBarTitleView {
    private let buttonView: HighlightTrackingButton
    private let action: () -> Void
    
    init(action: @escaping () -> Void) {
        self.action = action
        
        self.buttonView = HighlightTrackingButton()
        
        super.init(frame: CGRect())
        
        self.addSubview(self.buttonView)
        
        self.buttonView.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func buttonPressed() {
        self.action()
    }
    
    func animateLayoutTransition() {

    }
    
    func updateLayout(size: CGSize, clearBounds: CGRect, transition: ContainedViewLayoutTransition) {
        self.buttonView.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height))
    }
}

public final class WalletInfoScreen: ViewController {
    private let context: WalletContext
    private let walletInfo: WalletInfo?
    private let address: String
    private let enableDebugActions: Bool
    
    private var presentationData: WalletPresentationData
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    public init(context: WalletContext, walletInfo: WalletInfo?, address: String, enableDebugActions: Bool) {
        self.context = context
        self.walletInfo = walletInfo
        self.address = address
        self.enableDebugActions = enableDebugActions
        
        self.presentationData = context.presentationData
        
        let navigationBarTheme = NavigationBarTheme(buttonColor: .white, disabledButtonColor: .white, primaryTextColor: .white, backgroundColor: .clear, separatorColor: .clear, badgeBackgroundColor: self.presentationData.theme.navigationBar.badgeBackgroundColor, badgeStrokeColor: self.presentationData.theme.navigationBar.badgeStrokeColor, badgeTextColor: self.presentationData.theme.navigationBar.badgeTextColor)
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: navigationBarTheme, strings: NavigationBarStrings(back: self.presentationData.strings.Wallet_Navigation_Back, close: self.presentationData.strings.Wallet_Navigation_Close)))
        
        self.statusBar.statusBarStyle = .White
        self.navigationPresentation = .modalInLargeLayout
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.navigationBar?.intrinsicCanTransitionInline = false
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Wallet_Navigation_Back, style: .plain, target: nil, action: nil)
        if let _ = walletInfo {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: generateTintedImage(image: UIImage(bundleImageName: "Wallet/NavigationSettingsIcon"), color: .white), style: .plain, target: self, action: #selector(self.settingsPressed))
        }
        
        self.navigationItem.titleView = WalletInfoTitleView(action: { [weak self] in self?.scrollToTop?() })
        
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
        if let walletInfo = self.walletInfo {
            self.push(walletSettingsController(context: self.context, walletInfo: walletInfo))
        }
    }
    
    override public func loadDisplayNode() {
        self.displayNode = WalletInfoScreenNode(context: self.context, presentationData: self.presentationData, walletInfo: self.walletInfo, address: self.address, sendAction: { [weak self] in
            guard let strongSelf = self, let walletInfo = strongSelf.walletInfo else {
                return
            }
            guard let combinedState = (strongSelf.displayNode as! WalletInfoScreenNode).combinedState else {
                return
            }
            if (strongSelf.displayNode as! WalletInfoScreenNode).reloadingState {
                strongSelf.present(standardTextAlertController(theme: strongSelf.presentationData.theme.alert, title: nil, text: strongSelf.presentationData.strings.Wallet_Send_SyncInProgress, actions: [
                    TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Wallet_Alert_OK, action: {
                    })
                ]), in: .window(.root))
            } else if !combinedState.pendingTransactions.isEmpty {
                strongSelf.present(standardTextAlertController(theme: strongSelf.presentationData.theme.alert, title: nil, text: strongSelf.presentationData.strings.Wallet_Send_TransactionInProgress, actions: [
                    TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Wallet_Alert_OK, action: {
                    })
                ]), in: .window(.root))
            } else {
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                strongSelf.push(walletSendScreen(context: strongSelf.context, randomId: randomId, walletInfo: walletInfo))
            }
        }, receiveAction: { [weak self] in
            guard let strongSelf = self, let walletInfo = strongSelf.walletInfo else {
                return
            }
            strongSelf.push(WalletReceiveScreen(context: strongSelf.context, mode: .receive(address: strongSelf.address)))
        }, openTransaction: { [weak self] transaction in
            guard let strongSelf = self else {
                return
            }
            strongSelf.push(WalletTransactionInfoScreen(context: strongSelf.context, walletInfo: strongSelf.walletInfo, walletTransaction: transaction, walletState: (strongSelf.displayNode as! WalletInfoScreenNode).statePromise.get(), enableDebugActions: strongSelf.enableDebugActions))
        }, present: { [weak self] c, a in
            guard let strongSelf = self else {
                return
            }
            strongSelf.present(c, in: .window(.root), with: a)
        })
        
        self.displayNodeDidLoad()
        
        self._ready.set((self.displayNode as! WalletInfoScreenNode).contentReady.get())
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! WalletInfoScreenNode).containerLayoutUpdated(layout: layout, navigationHeight: self.navigationHeight, transition: transition)
    }
}

final class WalletInfoBalanceNode: ASDisplayNode {
    let dateTimeFormat: WalletPresentationDateTimeFormat
    
    let balanceIntegralTextNode: ImmediateTextNode
    let balanceFractionalTextNode: ImmediateTextNode
    let balanceIconNode: AnimatedStickerNode
    private var balanceIconNodeIsStatic: Bool
    
    var balance: (String, UIColor) = (" ", .white) {
        didSet {
            let integralString = NSMutableAttributedString()
            let fractionalString = NSMutableAttributedString()
            if let range = self.balance.0.range(of: self.dateTimeFormat.decimalSeparator) {
                let integralPart = String(self.balance.0[..<range.lowerBound])
                let fractionalPart = String(self.balance.0[range.lowerBound...])
                integralString.append(NSAttributedString(string: integralPart, font: Font.medium(48.0), textColor: self.balance.1))
                fractionalString.append(NSAttributedString(string: fractionalPart, font: Font.medium(48.0), textColor: self.balance.1))
            } else {
                integralString.append(NSAttributedString(string: self.balance.0, font: Font.medium(48.0), textColor: self.balance.1))
            }
            self.balanceIntegralTextNode.attributedText = integralString
            self.balanceFractionalTextNode.attributedText = fractionalString
        }
    }
    
    var isLoading: Bool = true
    
    init(dateTimeFormat: WalletPresentationDateTimeFormat) {
        self.dateTimeFormat = dateTimeFormat
        
        self.balanceIntegralTextNode = ImmediateTextNode()
        self.balanceIntegralTextNode.displaysAsynchronously = false
        self.balanceIntegralTextNode.attributedText = NSAttributedString(string: " ", font: Font.bold(39.0), textColor: .white)
        self.balanceIntegralTextNode.layer.minificationFilter = .linear
        
        self.balanceFractionalTextNode = ImmediateTextNode()
        self.balanceFractionalTextNode.displaysAsynchronously = false
        self.balanceFractionalTextNode.attributedText = NSAttributedString(string: " ", font: Font.bold(39.0), textColor: .white)
        self.balanceFractionalTextNode.layer.minificationFilter = .linear
        
        self.balanceIconNode = AnimatedStickerNode()
        if let path = getAppBundle().path(forResource: "WalletIntroStatic", ofType: "tgs") {
            self.balanceIconNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 120, height: 120, mode: .direct)
            self.balanceIconNode.visibility = true
        }
        self.balanceIconNodeIsStatic = true
        
        super.init()
        
        self.addSubnode(self.balanceIntegralTextNode)
        self.addSubnode(self.balanceFractionalTextNode)
        self.addSubnode(self.balanceIconNode)
    }
    
    func update(width: CGFloat, scaleTransition: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let sideInset: CGFloat = 16.0
        let balanceIconSpacing: CGFloat = scaleTransition * 0.0 + (1.0 - scaleTransition) * (-12.0)
        let balanceVerticalIconOffset: CGFloat = scaleTransition * (-2.0) + (1.0 - scaleTransition) * (-2.0)
        
        let balanceIntegralTextSize = self.balanceIntegralTextNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: 200.0))
        let balanceFractionalTextSize = self.balanceFractionalTextNode.updateLayout(CGSize(width: width - sideInset * 2.0, height: 200.0))
        let balanceIconSize = CGSize(width: 50.0, height: 50.0)
        
        let integralScale: CGFloat = scaleTransition * 1.0 + (1.0 - scaleTransition) * 0.8
        let fractionalScale: CGFloat = scaleTransition * 0.5 + (1.0 - scaleTransition) * 0.8
        
        let balanceOrigin = CGPoint(x: floor((width - balanceIntegralTextSize.width * integralScale - balanceFractionalTextSize.width * fractionalScale - balanceIconSpacing + balanceIconSize.width / 2.0) / 2.0), y: 0.0)
        
        let balanceIntegralTextFrame = CGRect(origin: balanceOrigin, size: balanceIntegralTextSize)
        let apparentBalanceIntegralTextFrame = CGRect(origin: balanceIntegralTextFrame.origin, size: CGSize(width: balanceIntegralTextFrame.width * integralScale, height: balanceIntegralTextFrame.height * integralScale))
        var balanceFractionalTextFrame = CGRect(origin: CGPoint(x: balanceIntegralTextFrame.maxX, y: balanceIntegralTextFrame.maxY - balanceFractionalTextSize.height), size: balanceFractionalTextSize)
        let apparentBalanceFractionalTextFrame = CGRect(origin: balanceFractionalTextFrame.origin, size: CGSize(width: balanceFractionalTextFrame.width * fractionalScale, height: balanceFractionalTextFrame.height * fractionalScale))
        
        balanceFractionalTextFrame.origin.x -= (balanceFractionalTextFrame.width / 4.0) * scaleTransition + 0.25 * (balanceFractionalTextFrame.width / 2.0) * (1.0 - scaleTransition)
        balanceFractionalTextFrame.origin.y += balanceFractionalTextFrame.height * 0.5 * (0.8 - fractionalScale)
        
        let isBalanceEmpty = self.balance.0.isEmpty || self.balance.0 == " "
        
        let balanceIconFrame: CGRect
        if isBalanceEmpty {
            balanceIconFrame = CGRect(origin: CGPoint(x: floor((width - balanceIconSize.width) / 2.0), y: balanceIntegralTextFrame.midY - balanceIconSize.height / 2.0 + balanceVerticalIconOffset), size: balanceIconSize)
        } else {
            balanceIconFrame = CGRect(origin: CGPoint(x: apparentBalanceIntegralTextFrame.minX - balanceIconSize.width - balanceIconSpacing * integralScale, y: balanceIntegralTextFrame.midY - balanceIconSize.height / 2.0 + balanceVerticalIconOffset), size: balanceIconSize)
        }
        
        transition.updateFrameAsPositionAndBounds(node: self.balanceIntegralTextNode, frame: balanceIntegralTextFrame)
        transition.updateTransformScale(node: self.balanceIntegralTextNode, scale: integralScale)
        transition.updateFrameAsPositionAndBounds(node: self.balanceFractionalTextNode, frame: balanceFractionalTextFrame)
        transition.updateTransformScale(node: self.balanceFractionalTextNode, scale: fractionalScale)
        
        if !isBalanceEmpty != self.balanceIconNodeIsStatic {
            self.balanceIconNodeIsStatic = !isBalanceEmpty
            if isBalanceEmpty {
                if let path = getAppBundle().path(forResource: "WalletIntroLoading", ofType: "tgs") {
                self.balanceIconNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 120, height: 120, mode: .direct)
                }
            } else {
                if let path = getAppBundle().path(forResource: "WalletIntroStatic", ofType: "tgs") {
                self.balanceIconNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 120, height: 120, mode: .direct)
                }
            }
        }
        
        self.balanceIconNode.updateLayout(size: balanceIconFrame.size)
        transition.updateFrameAsPositionAndBounds(node: self.balanceIconNode, frame: balanceIconFrame)
        transition.updateTransformScale(node: self.balanceIconNode, scale: scaleTransition * 1.0 + (1.0 - scaleTransition) * 0.8)
        
        return balanceIntegralTextSize.height
    }
}

private final class WalletInfoHeaderNode: ASDisplayNode {
    var balance: Int64?
    var isRefreshing: Bool = false
    var timestamp: Int32?
    
    private let hasActions: Bool
    
    let balanceNode: WalletInfoBalanceNode
    let refreshNode: WalletRefreshNode
    private let balanceSubtitleNode: ImmediateTextNode
    private let receiveButtonNode: SolidRoundedButtonNode
    private let receiveGramsButtonNode: SolidRoundedButtonNode
    private let sendButtonNode: SolidRoundedButtonNode
    private let headerBackgroundNode: ASDisplayNode
    private let headerCornerNode: ASImageNode
    
    init(presentationData: WalletPresentationData, hasActions: Bool, sendAction: @escaping () -> Void, receiveAction: @escaping () -> Void) {
        self.hasActions = hasActions
        
        self.balanceNode = WalletInfoBalanceNode(dateTimeFormat: presentationData.dateTimeFormat)
        
        self.balanceSubtitleNode = ImmediateTextNode()
        self.balanceSubtitleNode.displaysAsynchronously = false
        self.balanceSubtitleNode.attributedText = NSAttributedString(string: hasActions ? presentationData.strings.Wallet_Info_YourBalance : "balance", font: Font.regular(13), textColor: UIColor(white: 1.0, alpha: 0.6))
        
        self.headerBackgroundNode = ASDisplayNode()
        self.headerBackgroundNode.backgroundColor = .black
        
        self.headerCornerNode = ASImageNode()
        self.headerCornerNode.displaysAsynchronously = false
        self.headerCornerNode.displayWithoutProcessing = true
        self.headerCornerNode.image = generateImage(CGSize(width: 20.0, height: 10.0), rotatedContext: { size, context in
            context.setFillColor(UIColor.black.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: size))
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 20.0, height: 20.0)))
        })?.stretchableImage(withLeftCapWidth: 10, topCapHeight: 1)
        
        self.receiveButtonNode = SolidRoundedButtonNode(title: presentationData.strings.Wallet_Info_Receive, icon: generateTintedImage(image: UIImage(bundleImageName: "Wallet/ReceiveButtonIcon"), color: presentationData.theme.info.buttonTextColor), theme: SolidRoundedButtonTheme(backgroundColor: presentationData.theme.info.buttonBackgroundColor, foregroundColor: presentationData.theme.info.buttonTextColor), height: 50.0, cornerRadius: 10.0, gloss: false)
        self.receiveGramsButtonNode = SolidRoundedButtonNode(title: presentationData.strings.Wallet_Info_ReceiveGrams, icon: generateTintedImage(image: UIImage(bundleImageName: "Wallet/ReceiveButtonIcon"), color: presentationData.theme.info.buttonTextColor), theme: SolidRoundedButtonTheme(backgroundColor: presentationData.theme.info.buttonBackgroundColor, foregroundColor: presentationData.theme.info.buttonTextColor), height: 50.0, cornerRadius: 10.0, gloss: false)
        self.sendButtonNode = SolidRoundedButtonNode(title: presentationData.strings.Wallet_Info_Send, icon: generateTintedImage(image: UIImage(bundleImageName: "Wallet/SendButtonIcon"), color: presentationData.theme.info.buttonTextColor), theme: SolidRoundedButtonTheme(backgroundColor: presentationData.theme.info.buttonBackgroundColor, foregroundColor: presentationData.theme.info.buttonTextColor), height: 50.0, cornerRadius: 10.0, gloss: false)
        
        self.refreshNode = WalletRefreshNode(strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat)
        
        super.init()
        
        self.addSubnode(self.headerBackgroundNode)
        self.addSubnode(self.headerCornerNode)
        if hasActions {
            self.addSubnode(self.receiveButtonNode)
            self.addSubnode(self.receiveGramsButtonNode)
            self.addSubnode(self.sendButtonNode)
        }
        self.addSubnode(self.balanceNode)
        self.addSubnode(self.balanceSubtitleNode)
        self.addSubnode(self.refreshNode)
        
        self.receiveButtonNode.pressed = {
            receiveAction()
        }
        self.receiveGramsButtonNode.pressed = {
            receiveAction()
        }
        self.sendButtonNode.pressed = {
            sendAction()
        }
    }
    
    func update(size: CGSize, navigationHeight: CGFloat, offset: CGFloat, transition: ContainedViewLayoutTransition, isScrolling: Bool) {
        let sideInset: CGFloat = 16.0
        let buttonSideInset: CGFloat = 48.0
        let titleSpacing: CGFloat = 10.0
        let termsSpacing: CGFloat = 10.0
        let buttonHeight: CGFloat = 50.0
        let balanceSubtitleSpacing: CGFloat = 0.0
        
        let alphaTransition: ContainedViewLayoutTransition
        if transition.isAnimated {
            alphaTransition = transition
        } else if isScrolling {
            alphaTransition = .animated(duration: 0.2, curve: .easeInOut)
        } else {
            alphaTransition = transition
        }
        
        let minOffset = navigationHeight
        let maxOffset = size.height
        
        let minHeaderOffset = minOffset
        let maxHeaderOffset = (minOffset + maxOffset) / 2.0
        
        let effectiveOffset = max(offset, navigationHeight)
        
        let minButtonsOffset = maxOffset - buttonHeight * 2.0 - sideInset
        let maxButtonsOffset = maxOffset
        let buttonTransition: CGFloat = max(0.0, min(1.0, (effectiveOffset - minButtonsOffset) / (maxButtonsOffset - minButtonsOffset)))
        let buttonAlpha: CGFloat = buttonTransition
        
        let balanceSubtitleSize = self.balanceSubtitleNode.updateLayout(CGSize(width: size.width - sideInset * 2.0, height: 200.0))
        
        let headerScaleTransition: CGFloat = max(0.0, min(1.0, (effectiveOffset - minHeaderOffset) / (maxHeaderOffset - minHeaderOffset)))
        
        let balanceHeight = self.balanceNode.update(width: size.width, scaleTransition: headerScaleTransition, transition: transition)
        let balanceSize = CGSize(width: size.width, height: balanceHeight)
        
        let maxHeaderScale: CGFloat = min(1.0, (size.width - 40.0) / balanceSize.width)
        let minHeaderScale: CGFloat = min(0.435, (size.width - 80.0 * 2.0) / balanceSize.width)
        
        let minHeaderHeight: CGFloat = balanceSize.height + balanceSubtitleSize.height + balanceSubtitleSpacing
        
        let minHeaderY = navigationHeight - 44.0 + floor((44.0 - minHeaderHeight) / 2.0)
        let maxHeaderY = floor((size.height - balanceSize.height) / 2.0 - balanceSubtitleSize.height)
        let headerPositionTransition: CGFloat = max(0.0, (effectiveOffset - minHeaderOffset) / (maxOffset - minHeaderOffset))
        let headerY = headerPositionTransition * maxHeaderY + (1.0 - headerPositionTransition) * minHeaderY
        let headerScale = headerScaleTransition * maxHeaderScale + (1.0 - headerScaleTransition) * minHeaderScale
        
        let refreshSize = CGSize(width: 0.0, height: 0.0)
        transition.updateFrame(node: self.refreshNode, frame: CGRect(origin: CGPoint(x: floor((size.width - refreshSize.width) / 2.0), y: navigationHeight - 44.0 + floor((44.0 - refreshSize.height) / 2.0)), size: refreshSize))
        transition.updateAlpha(node: self.refreshNode, alpha: headerScaleTransition, beginWithCurrentState: true)
        if self.isRefreshing {
            self.refreshNode.update(state: .refreshing)
        } else if self.balance == nil {
            self.refreshNode.update(state: .pullToRefresh(self.timestamp ?? 0, 0.0))
        } else {
            let refreshOffset: CGFloat = 20.0
            let refreshScaleTransition: CGFloat = max(0.0, (offset - maxOffset) / refreshOffset)
            self.refreshNode.update(state: .pullToRefresh(self.timestamp ?? 0, refreshScaleTransition * 0.1))
        }
        
        let balanceFrame = CGRect(origin: CGPoint(x: 0.0, y: headerY), size: balanceSize)
        transition.updateFrame(node: self.balanceNode, frame: balanceFrame)
        transition.updateSublayerTransformScale(node: self.balanceNode, scale: headerScale)
        
        let balanceSubtitleOffset = headerScaleTransition * 27.0 + (1.0 - headerScaleTransition) * 9.0
        let balanceSubtitleFrame = CGRect(origin: CGPoint(x: floor((size.width - balanceSubtitleSize.width) / 2.0), y: balanceFrame.midY + balanceSubtitleOffset), size: balanceSubtitleSize)
        transition.updateFrameAdditive(node: self.balanceSubtitleNode, frame: balanceSubtitleFrame)
        
        let headerHeight: CGFloat = 1000.0
        transition.updateFrame(node: self.headerBackgroundNode, frame: CGRect(origin: CGPoint(x: -1.0, y: effectiveOffset - headerHeight), size: CGSize(width: size.width + 2.0, height: headerHeight)))
        transition.updateFrame(node: self.headerCornerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: effectiveOffset), size: CGSize(width: size.width, height: 10.0)))
        
        let buttonOffset = effectiveOffset
        
        let leftButtonFrame = CGRect(origin: CGPoint(x: sideInset, y: buttonOffset - sideInset - buttonHeight), size: CGSize(width: floor((size.width - sideInset * 3.0) / 2.0), height: buttonHeight))
        let sendButtonFrame = CGRect(origin: CGPoint(x: leftButtonFrame.maxX + sideInset, y: leftButtonFrame.minY), size: CGSize(width: size.width - leftButtonFrame.maxX - sideInset * 2.0, height: buttonHeight))
        let fullButtonFrame = CGRect(origin: CGPoint(x: sideInset, y: buttonOffset - sideInset - buttonHeight), size: CGSize(width: size.width - sideInset * 2.0, height: buttonHeight))
        
        if let balance = self.balance, balance > 0 {
            self.receiveGramsButtonNode.isHidden = true
            self.receiveButtonNode.isHidden = false
            self.sendButtonNode.isHidden = false
        } else {
            if self.balance == nil {
                self.receiveGramsButtonNode.isHidden = false
                self.receiveButtonNode.isHidden = true
                self.sendButtonNode.isHidden = true
            } else {
                self.receiveGramsButtonNode.isHidden = false
                self.receiveButtonNode.isHidden = true
                self.sendButtonNode.isHidden = true
            }
        }
        if self.balance == nil {
            self.balanceNode.isHidden = false
            self.balanceSubtitleNode.isHidden = true
            self.refreshNode.isHidden = false
        } else {
            self.balanceNode.isHidden = false
            self.balanceSubtitleNode.isHidden = false
            self.refreshNode.isHidden = false
        }
        
        transition.updateFrame(node: self.receiveGramsButtonNode, frame: fullButtonFrame)
        transition.updateAlpha(node: self.receiveGramsButtonNode, alpha: buttonAlpha, beginWithCurrentState: true)
        transition.updateFrame(node: self.receiveButtonNode, frame: leftButtonFrame)
        transition.updateAlpha(node: self.receiveButtonNode, alpha: buttonAlpha, beginWithCurrentState: true)
        self.receiveGramsButtonNode.updateLayout(width: fullButtonFrame.width, transition: transition)
        self.receiveButtonNode.updateLayout(width: leftButtonFrame.width, transition: transition)
        transition.updateFrame(node: self.sendButtonNode, frame: sendButtonFrame)
        transition.updateAlpha(node: self.sendButtonNode, alpha: buttonAlpha, beginWithCurrentState: true)
        self.sendButtonNode.updateLayout(width: sendButtonFrame.width, transition: transition)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.sendButtonNode.hitTest(self.view.convert(point, to: self.sendButtonNode.view), with: event) {
            return result
        }
        if let result = self.receiveButtonNode.hitTest(self.view.convert(point, to: self.receiveButtonNode.view), with: event) {
            return result
        }
        if let result = self.receiveGramsButtonNode.hitTest(self.view.convert(point, to: self.receiveGramsButtonNode.view), with: event) {
            return result
        }
        return nil
    }
    
    func becameReady(animated: Bool) {
        if animated {
            self.sendButtonNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.receiveGramsButtonNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.receiveButtonNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.balanceNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.balanceSubtitleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.refreshNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }
        self.balanceNode.isLoading = false
    }
}

private struct WalletInfoListTransaction {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

enum WalletInfoTransaction: Equatable {
    case completed(WalletTransaction)
    case pending(PendingWalletTransaction)
}

private enum WalletInfoListEntryId: Hashable {
    case empty
    case transaction(WalletTransactionId)
    case pendingTransaction(Data)
}

private enum WalletInfoListEntry: Equatable, Comparable, Identifiable {
    case empty(String, Bool)
    case transaction(Int, WalletInfoTransaction)
    
    var stableId: WalletInfoListEntryId {
        switch self {
        case .empty:
            return .empty
        case let .transaction(_, transaction):
            switch transaction {
            case let .completed(completed):
                return .transaction(completed.transactionId)
            case let .pending(pending):
                return .pendingTransaction(pending.bodyHash)
            }
        }
    }
    
    static func <(lhs: WalletInfoListEntry, rhs: WalletInfoListEntry) -> Bool {
        switch lhs {
        case .empty:
            switch rhs {
            case .empty:
                return false
            case .transaction:
                return true
            }
        case let .transaction(lhsIndex, _):
            switch rhs {
            case .empty:
                return false
            case let .transaction(rhsIndex, _):
                return lhsIndex < rhsIndex
            }
        }
    }
    
    func item(theme: WalletTheme, strings: WalletStrings, dateTimeFormat: WalletPresentationDateTimeFormat, action: @escaping (WalletInfoTransaction) -> Void, displayAddressContextMenu: @escaping (ASDisplayNode, CGRect) -> Void) -> ListViewItem {
        switch self {
        case let .empty(address, loading):
            return WalletInfoEmptyItem(theme: theme, strings: strings, address: address, loading: loading, displayAddressContextMenu: { node, frame in
                displayAddressContextMenu(node, frame)
            })
        case let .transaction(_, transaction):
            return WalletInfoTransactionItem(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, walletTransaction: transaction, action: {
                action(transaction)
            })
        }
    }
}

private func preparedTransition(from fromEntries: [WalletInfoListEntry], to toEntries: [WalletInfoListEntry], presentationData: WalletPresentationData, action: @escaping (WalletInfoTransaction) -> Void, displayAddressContextMenu: @escaping (ASDisplayNode, CGRect) -> Void) -> WalletInfoListTransaction {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(theme: presentationData.theme, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, action: action, displayAddressContextMenu: displayAddressContextMenu), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(theme: presentationData.theme, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, action: action, displayAddressContextMenu: displayAddressContextMenu), directionHint: nil) }
    
    return WalletInfoListTransaction(deletions: deletions, insertions: insertions, updates: updates)
}

private final class WalletInfoScreenNode: ViewControllerTracingNode {
    private let context: WalletContext
    private var presentationData: WalletPresentationData
    private let walletInfo: WalletInfo?
    private let address: String
    
    private let openTransaction: (WalletInfoTransaction) -> Void
    private let present: (ViewController, Any?) -> Void
    
    private let hapticFeedback = HapticFeedback()
    
    private let headerNode: WalletInfoHeaderNode
    private let listNode: ListView
    
    private var enqueuedTransactions: [WalletInfoListTransaction] = []
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private let stateDisposable = MetaDisposable()
    private let transactionListDisposable = MetaDisposable()
    
    private var listOffset: CGFloat?
    private(set) var reloadingState: Bool = false
    private var loadingMoreTransactions: Bool = false
    private var canLoadMoreTransactions: Bool = true
    
    fileprivate var combinedState: CombinedWalletState?
    private var currentEntries: [WalletInfoListEntry]?
    
    fileprivate let statePromise = Promise<(CombinedWalletState, Bool)>()
    
    private var isReady: Bool = false
    
    let contentReady = Promise<Bool>()
    private var didSetContentReady = false
    
    private var updateTimestampTimer: SwiftSignalKit.Timer?
    
    private var pollCombinedStateDisposable: Disposable?
    private var watchCombinedStateDisposable: Disposable?
    private var refreshProgressDisposable: Disposable?
    
    init(context: WalletContext, presentationData: WalletPresentationData, walletInfo: WalletInfo?, address: String, sendAction: @escaping () -> Void, receiveAction: @escaping () -> Void, openTransaction: @escaping (WalletInfoTransaction) -> Void, present: @escaping (ViewController, Any?) -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.walletInfo = walletInfo
        self.address = address
        self.openTransaction = openTransaction
        self.present = present
        
        self.headerNode = WalletInfoHeaderNode(presentationData: presentationData, hasActions: walletInfo != nil, sendAction: sendAction, receiveAction: receiveAction)
        
        self.listNode = ListView()
        self.listNode.verticalScrollIndicatorColor = UIColor(white: 0.0, alpha: 0.3)
        self.listNode.verticalScrollIndicatorFollowsOverscroll = true
        self.listNode.isHidden = false
        self.listNode.view.disablesInteractiveModalDismiss = true
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.itemBlocksBackgroundColor
        
        self.addSubnode(self.listNode)
        self.addSubnode(self.headerNode)
        
        var canBeginRefresh = true
        var isScrolling = false
        self.listNode.beganInteractiveDragging = {
            isScrolling = true
        }
        self.listNode.endedInteractiveDragging = {
            isScrolling = false
        }
        
        self.listNode.updateFloatingHeaderOffset = { [weak self] offset, listTransition in
            guard let strongSelf = self, let (layout, navigationHeight) = strongSelf.validLayout else {
                return
            }
            
            let headerHeight: CGFloat = navigationHeight + 260.0
            strongSelf.listOffset = offset
            
            if strongSelf.isReady {
                if !strongSelf.reloadingState && canBeginRefresh && isScrolling {
                    if offset >= headerHeight + 100.0 {
                        canBeginRefresh = false
                        strongSelf.hapticFeedback.impact()
                        strongSelf.refreshTransactions()
                    }
                }
                strongSelf.headerNode.update(size: strongSelf.headerNode.bounds.size, navigationHeight: navigationHeight, offset: offset, transition: listTransition, isScrolling: true)
            }
        }
        
        self.listNode.visibleBottomContentOffsetChanged = { [weak self] offset in
            guard let strongSelf = self else {
                return
            }
            guard case let .known(value) = offset, value < 100.0 else {
                return
            }
            if !strongSelf.loadingMoreTransactions && !strongSelf.reloadingState && strongSelf.canLoadMoreTransactions {
                strongSelf.loadMoreTransactions()
            }
        }
        
        self.listNode.didEndScrolling = { [weak self] in
            canBeginRefresh = true
            
            guard let strongSelf = self, let (_, navigationHeight) = strongSelf.validLayout else {
                return
            }
            switch strongSelf.listNode.visibleContentOffset() {
            case let .known(offset):
                if offset < strongSelf.listNode.insets.top {
                    if offset > strongSelf.listNode.insets.top / 2.0 {
                        strongSelf.scrollToHideHeader()
                    } else {
                        strongSelf.scrollToTop()
                    }
                }
            default:
                break
            }
        }
        
        self.refreshTransactions()
        
        self.updateTimestampTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
            guard let strongSelf = self, let combinedState = strongSelf.combinedState, !strongSelf.reloadingState else {
                return
            }
            strongSelf.headerNode.timestamp = Int32(clamping: combinedState.timestamp)
        }, queue: .mainQueue())
        self.updateTimestampTimer?.start()
        
        let subject: CombinedWalletStateSubject
        if let walletInfo = walletInfo {
            subject = .wallet(walletInfo)
            
            self.watchCombinedStateDisposable = (context.storage.watchWalletRecords()
            |> deliverOnMainQueue).start(next: { [weak self] records in
                guard let strongSelf = self else {
                    return
                }
                for wallet in records {
                    if wallet.info.publicKey == walletInfo.publicKey {
                        if let state = wallet.state {
                            if state.pendingTransactions != strongSelf.combinedState?.pendingTransactions || state.timestamp != strongSelf.combinedState?.timestamp {
                                if !strongSelf.reloadingState {
                                    strongSelf.updateCombinedState(combinedState: state, isUpdated: true)
                                }
                            }
                        }
                        break
                    }
                }
            })
        } else {
            subject = .address(address)
        }
        let pollCombinedState: Signal<Never, NoError> = (
            getCombinedWalletState(storage: context.storage, subject: subject, tonInstance: context.tonInstance)
            |> ignoreValues
            |> `catch` { _ -> Signal<Never, NoError> in
                return .complete()
            }
            |> then(
                Signal<Never, NoError>.complete()
                |> delay(5.0, queue: .mainQueue())
            )
        )
        |> restart
        
        self.pollCombinedStateDisposable = (pollCombinedState
        |> deliverOnMainQueue).start()
        
        self.refreshProgressDisposable = (context.tonInstance.syncProgress
        |> deliverOnMainQueue).start(next: { [weak self] progress in
            guard let strongSelf = self else {
                return
            }
            strongSelf.headerNode.refreshNode.refreshProgress = progress
            if strongSelf.headerNode.isRefreshing, strongSelf.isReady, let (layout, navigationHeight) = strongSelf.validLayout {
                strongSelf.headerNode.refreshNode.update(state: .refreshing)
            }
        })
    }
    
    deinit {
        self.stateDisposable.dispose()
        self.transactionListDisposable.dispose()
        self.updateTimestampTimer?.invalidate()
        self.pollCombinedStateDisposable?.dispose()
        self.watchCombinedStateDisposable?.dispose()
        self.refreshProgressDisposable?.dispose()
    }
    
    func scrollToHideHeader() {
        guard let (_, navigationHeight) = self.validLayout else {
            return
        }
        let _ = self.listNode.scrollToOffsetFromTop(self.headerNode.frame.maxY - navigationHeight)
    }
    
    func scrollToTop() {
        if !self.listNode.scrollToOffsetFromTop(0.0) {
            self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Spring(duration: 0.4), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        }
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let isFirstLayout = self.validLayout == nil
        self.validLayout = (layout, navigationHeight)
        
        let headerHeight: CGFloat = navigationHeight + 260.0
        let topInset: CGFloat = headerHeight
        
        let visualHeaderHeight: CGFloat
        let visualHeaderOffset: CGFloat
        if !self.isReady {
            visualHeaderHeight = layout.size.height
            visualHeaderOffset = visualHeaderHeight
        } else {
            visualHeaderHeight = headerHeight
            visualHeaderOffset = self.listOffset ?? 0.0
        }
        let visualListOffset = visualHeaderHeight - headerHeight
        
        let headerFrame = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: visualHeaderHeight))
        transition.updateFrame(node: self.headerNode, frame: headerFrame)
        self.headerNode.update(size: headerFrame.size, navigationHeight: navigationHeight, offset: visualHeaderOffset, transition: transition, isScrolling: false)
        
        transition.updateFrame(node: self.listNode, frame: CGRect(origin: CGPoint(x: 0.0, y: visualListOffset), size: layout.size))
    
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)

        self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: layout.size, insets: UIEdgeInsets(top: topInset, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0), headerInsets: UIEdgeInsets(top: navigationHeight, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0), scrollIndicatorInsets: UIEdgeInsets(top: topInset + 3.0, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0), duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if isFirstLayout {
            while !self.enqueuedTransactions.isEmpty {
                self.dequeueTransaction()
            }
        }
    }
    
    private func refreshTransactions() {
        self.transactionListDisposable.set(nil)
        self.loadingMoreTransactions = true
        self.reloadingState = true
        self.updateStatePromise()
        
        self.headerNode.isRefreshing = true
        self.headerNode.refreshNode.refreshProgress = 0.0
        
        let subject: CombinedWalletStateSubject
        if let walletInfo = self.walletInfo {
            subject = .wallet(walletInfo)
        } else {
            subject = .address(self.address)
        }
        
        self.stateDisposable.set((getCombinedWalletState(storage: self.context.storage, subject: subject, tonInstance: self.context.tonInstance)
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            let combinedState: CombinedWalletState?
            var isUpdated = false
            switch value {
            case let .cached(state):
                if strongSelf.combinedState != nil {
                    return
                }
                combinedState = state
            case let .updated(state):
                isUpdated = true
                combinedState = state
            }
            
            strongSelf.updateCombinedState(combinedState: combinedState, isUpdated: isUpdated)
        }, error: { [weak self] error in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.reloadingState = false
            strongSelf.updateStatePromise()
            
            if let combinedState = strongSelf.combinedState {
                strongSelf.headerNode.timestamp = Int32(clamping: combinedState.timestamp)
            }
                
            if strongSelf.isReady, let (layout, navigationHeight) = strongSelf.validLayout {
                strongSelf.headerNode.update(size: strongSelf.headerNode.bounds.size, navigationHeight: navigationHeight, offset: strongSelf.listOffset ?? 0.0, transition: .immediate, isScrolling: false)
            }
                
            strongSelf.loadingMoreTransactions = false
            strongSelf.canLoadMoreTransactions = false
                
            strongSelf.headerNode.isRefreshing = false
                
            if strongSelf.isReady, let (layout, navigationHeight) = strongSelf.validLayout {
                strongSelf.headerNode.update(size: strongSelf.headerNode.bounds.size, navigationHeight: navigationHeight, offset: strongSelf.listOffset ?? 0.0, transition: .animated(duration: 0.2, curve: .easeInOut), isScrolling: false)
            }
            
            if !strongSelf.didSetContentReady {
                strongSelf.didSetContentReady = true
                strongSelf.contentReady.set(.single(true))
            }
            
            let text: String
            switch error {
            case .generic:
                text = strongSelf.presentationData.strings.Wallet_Info_RefreshErrorText
            case .network:
                text = strongSelf.presentationData.strings.Wallet_Info_RefreshErrorNetworkText
            }
            strongSelf.present(standardTextAlertController(theme: strongSelf.presentationData.theme.alert, title: strongSelf.presentationData.strings.Wallet_Info_RefreshErrorTitle, text: text, actions: [
                TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Wallet_Alert_OK, action: {
                })
            ], actionLayout: .vertical), nil)
        }))
    }
    
    private func updateCombinedState(combinedState: CombinedWalletState?, isUpdated: Bool) {
        self.combinedState = combinedState
        if let combinedState = combinedState {
            self.headerNode.balanceNode.balance = (formatBalanceText(max(0, combinedState.walletState.balance), decimalSeparator: self.presentationData.dateTimeFormat.decimalSeparator), .white)
            self.headerNode.balance = max(0, combinedState.walletState.balance)
            
            if self.isReady, let (layout, navigationHeight) = self.validLayout {
                self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate)
            }
            
            if isUpdated {
                self.reloadingState = false
            }
            
            self.headerNode.timestamp = Int32(clamping: combinedState.timestamp)
            
            if self.isReady, let (layout, navigationHeight) = self.validLayout {
                self.headerNode.update(size: self.headerNode.bounds.size, navigationHeight: navigationHeight, offset: self.listOffset ?? 0.0, transition: .immediate, isScrolling: false)
            }
            
            var updatedTransactions: [WalletTransaction] = combinedState.topTransactions
            if let currentEntries = self.currentEntries {
                var existingIds = Set<WalletInfoListEntryId>()
                for transaction in updatedTransactions {
                    existingIds.insert(.transaction(transaction.transactionId))
                }
                for entry in currentEntries {
                    switch entry {
                    case let .transaction(_, transaction):
                    switch transaction {
                    case let .completed(transaction):
                        if !existingIds.contains(.transaction(transaction.transactionId)) {
                            existingIds.insert(.transaction(transaction.transactionId))
                            updatedTransactions.append(transaction)
                        }
                    case .pending:
                        break
                    }
                    default:
                        break
                    }
                }
            }
            
            self.transactionsLoaded(isReload: true, isEmpty: false, transactions: updatedTransactions, pendingTransactions: combinedState.pendingTransactions)
            
            if isUpdated {
                self.headerNode.isRefreshing = false
            }
            
            if self.isReady, let (layout, navigationHeight) = self.validLayout {
                self.headerNode.update(size: self.headerNode.bounds.size, navigationHeight: navigationHeight, offset: self.listOffset ?? 0.0, transition: .animated(duration: 0.2, curve: .easeInOut), isScrolling: false)
            }
        } else {
            self.transactionsLoaded(isReload: true, isEmpty: true, transactions: [], pendingTransactions: [])
        }
        
        let wasReady = self.isReady
        self.isReady = true
        
        if self.isReady && !wasReady {
            if let (layout, navigationHeight) = self.validLayout {
                self.headerNode.update(size: self.headerNode.bounds.size, navigationHeight: navigationHeight, offset: layout.size.height, transition: .immediate, isScrolling: false)
            }
            
            self.becameReady(animated: self.didSetContentReady)
        }
        
        if !self.didSetContentReady {
            self.didSetContentReady = true
            self.contentReady.set(.single(true))
        }
    
        self.updateStatePromise()
    }
    
    private func updateStatePromise() {
        if let combinedState = self.combinedState {
            self.statePromise.set(.single((combinedState, self.reloadingState)))
        }
    }
    
    private func loadMoreTransactions() {
        if self.loadingMoreTransactions {
            return
        }
        self.loadingMoreTransactions = true
        var lastTransactionId: WalletTransactionId?
        if let last = self.currentEntries?.last {
            switch last {
            case let .transaction(_, transaction):
                switch transaction {
                case let .completed(completed):
                    lastTransactionId = completed.transactionId
                case .pending:
                    break
                }
            case .empty:
                break
            }
        }
        self.transactionListDisposable.set((getWalletTransactions(address: self.address, previousId: lastTransactionId, tonInstance: self.context.tonInstance)
        |> deliverOnMainQueue).start(next: { [weak self] transactions in
            guard let strongSelf = self else {
                return
            }
            strongSelf.transactionsLoaded(isReload: false, isEmpty: false, transactions: transactions, pendingTransactions: [])
        }, error: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
        }))
    }
    
    private func transactionsLoaded(isReload: Bool, isEmpty: Bool, transactions: [WalletTransaction], pendingTransactions: [PendingWalletTransaction]) {
        if !isEmpty {
            self.loadingMoreTransactions = false
            self.canLoadMoreTransactions = transactions.count > 2
        }
        
        var updatedEntries: [WalletInfoListEntry] = []
        if isReload {
            var existingIds = Set<WalletInfoListEntryId>()
            for transaction in pendingTransactions {
                if !existingIds.contains(.pendingTransaction(transaction.bodyHash)) {
                    existingIds.insert(.pendingTransaction(transaction.bodyHash))
                    updatedEntries.append(.transaction(updatedEntries.count, .pending(transaction)))
                }
            }
            for transaction in transactions {
                if !existingIds.contains(.transaction(transaction.transactionId)) {
                    existingIds.insert(.transaction(transaction.transactionId))
                    updatedEntries.append(.transaction(updatedEntries.count, .completed(transaction)))
                }
            }
            if updatedEntries.isEmpty {
                updatedEntries.append(.empty(self.address, isEmpty))
            }
        } else {
            updatedEntries = self.currentEntries ?? []
            updatedEntries = updatedEntries.filter { entry in
                if case .empty = entry {
                    return false
                } else {
                    return true
                }
            }
            var existingIds = Set<WalletInfoListEntryId>()
            for entry in updatedEntries {
                switch entry {
                case let .transaction(_, transaction):
                    existingIds.insert(entry.stableId)
                case .empty:
                    break
                }
            }
            for transaction in transactions {
                if !existingIds.contains(.transaction(transaction.transactionId)) {
                    existingIds.insert(.transaction(transaction.transactionId))
                    updatedEntries.append(.transaction(updatedEntries.count, .completed(transaction)))
                }
            }
            if updatedEntries.isEmpty {
                updatedEntries.append(.empty(self.address, false))
            }
        }
        
        let transaction = preparedTransition(from: self.currentEntries ?? [], to: updatedEntries, presentationData: self.presentationData, action: { [weak self] transaction in
            guard let strongSelf = self else {
                return
            }
            strongSelf.openTransaction(transaction)
        }, displayAddressContextMenu: { [weak self] node, frame in
            guard let strongSelf = self else {
                return
            }
            let address = strongSelf.address
            let contextMenuController = ContextMenuController(actions: [ContextMenuAction(content: .text(title: strongSelf.presentationData.strings.Wallet_ContextMenuCopy, accessibilityLabel: strongSelf.presentationData.strings.Wallet_ContextMenuCopy), action: {
                UIPasteboard.general.string = address
            })])
            strongSelf.present(contextMenuController, ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
                if let strongSelf = self {
                    return (node, frame.insetBy(dx: 0.0, dy: -2.0), strongSelf, strongSelf.view.bounds)
                } else {
                    return nil
                }
            }))
        })
        self.currentEntries = updatedEntries
        
        self.enqueuedTransactions.append(transaction)
        self.dequeueTransaction()
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
    
    private func becameReady(animated: Bool) {
        self.listNode.isHidden = false
        self.headerNode.becameReady(animated: animated)
        if let (layout, navigationHeight) = self.validLayout {
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: animated ? .animated(duration: 0.5, curve: .spring) : .immediate)
        }
    }
}

private final class WalletApplicationSplashScreenNode: ASDisplayNode {
    private let headerBackgroundNode: ASDisplayNode
    private let headerCornerNode: ASImageNode
    
    private var isDismissed = false
    
    private var validLayout: (layout: ContainerViewLayout, navigationHeight: CGFloat)?
    
    init(theme: WalletTheme) {
        self.headerBackgroundNode = ASDisplayNode()
        self.headerBackgroundNode.backgroundColor = .black
        
        self.headerCornerNode = ASImageNode()
        self.headerCornerNode.displaysAsynchronously = false
        self.headerCornerNode.displayWithoutProcessing = true
        self.headerCornerNode.image = generateImage(CGSize(width: 20.0, height: 10.0), rotatedContext: { size, context in
            context.setFillColor(UIColor.black.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: size))
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 20.0, height: 20.0)))
        })?.stretchableImage(withLeftCapWidth: 10, topCapHeight: 1)
        
        super.init()
        
        self.backgroundColor = theme.list.itemBlocksBackgroundColor
        
        self.addSubnode(self.headerBackgroundNode)
        self.addSubnode(self.headerCornerNode)
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        if self.isDismissed {
            return
        }
        self.validLayout = (layout, navigationHeight)
        
        let headerHeight = navigationHeight + 260.0
        
        transition.updateFrame(node: self.headerBackgroundNode, frame: CGRect(origin: CGPoint(x: -1.0, y: 0), size: CGSize(width: layout.size.width + 2.0, height: headerHeight)))
        transition.updateFrame(node: self.headerCornerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: headerHeight), size: CGSize(width: layout.size.width, height: 10.0)))
    }
    
    func animateOut(completion: @escaping () -> Void) {
        guard let (layout, navigationHeight) = self.validLayout else {
            completion()
            return
        }
        self.isDismissed = true
        let transition: ContainedViewLayoutTransition = .animated(duration: 0.4, curve: .spring)
        
        let headerHeight = navigationHeight + 260.0
        
        transition.updateFrame(node: self.headerBackgroundNode, frame: CGRect(origin: CGPoint(x: -1.0, y: -headerHeight - 10.0), size: CGSize(width: layout.size.width + 2.0, height: headerHeight)), completion: { _ in
            completion()
        })
        transition.updateFrame(node: self.headerCornerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -10.0), size: CGSize(width: layout.size.width, height: 10.0)))
    }
}

public final class WalletApplicationSplashScreen: ViewController {
    private let theme: WalletTheme
    
    public init(theme: WalletTheme) {
        self.theme = theme
        
        let navigationBarTheme = NavigationBarTheme(buttonColor: .white, disabledButtonColor: .white, primaryTextColor: .white, backgroundColor: .clear, separatorColor: .clear, badgeBackgroundColor: theme.navigationBar.badgeBackgroundColor, badgeStrokeColor: theme.navigationBar.badgeStrokeColor, badgeTextColor: theme.navigationBar.badgeTextColor)
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: navigationBarTheme, strings: NavigationBarStrings(back: "", close: "")))
        
        self.statusBar.statusBarStyle = .White
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = WalletApplicationSplashScreenNode(theme: self.theme)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! WalletApplicationSplashScreenNode).containerLayoutUpdated(layout: layout, navigationHeight: self.navigationHeight, transition: transition)
    }
    
    public func animateOut(completion: @escaping () -> Void) {
        self.statusBar.statusBarStyle = .Black
        (self.displayNode as! WalletApplicationSplashScreenNode).animateOut(completion: completion)
    }
}
