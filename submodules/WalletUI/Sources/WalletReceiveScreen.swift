import Foundation
import UIKit
import SwiftSignalKit
import AppBundle
import AsyncDisplayKit
import Display
import QrCode
import AnimatedStickerNode
import SolidRoundedButtonNode

private func shareInvoiceQrCode(context: WalletContext, invoice: String) {
    let _ = (qrCode(string: invoice, color: .black, backgroundColor: .white, icon: .custom(UIImage(bundleImageName: "Wallet/QrGem")))
    |> map { _, generator -> UIImage? in
        let imageSize = CGSize(width: 768.0, height: 768.0)
        let context = generator(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), scale: 1.0))
        return context?.generateImage()
    }
    |> deliverOnMainQueue).start(next: { image in
        guard let image = image else {
            return
        }
        
        let activityController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        context.presentNativeController(activityController)
    })
}

public enum WalletReceiveScreenMode {
    case receive(address: String)
    case invoice(address: String, amount: String?, comment: String?)
    
    var address: String {
        switch self {
            case let .receive(address), let .invoice(address, _, _):
                return address
        }
    }
}

final class WalletReceiveScreen: ViewController {
    private let context: WalletContext
    private let mode: WalletReceiveScreenMode
    private var presentationData: WalletPresentationData
    
    private let idleTimerExtensionDisposable: Disposable
    
    public init(context: WalletContext, mode: WalletReceiveScreenMode) {
        self.context = context
        self.mode = mode
        
        self.presentationData = context.presentationData
        
        let defaultTheme = self.presentationData.theme.navigationBar
        let navigationBarTheme = NavigationBarTheme(buttonColor: defaultTheme.buttonColor, disabledButtonColor: defaultTheme.disabledButtonColor, primaryTextColor: defaultTheme.primaryTextColor, backgroundColor: .clear, separatorColor: .clear, badgeBackgroundColor: defaultTheme.badgeBackgroundColor, badgeStrokeColor: defaultTheme.badgeStrokeColor, badgeTextColor: defaultTheme.badgeTextColor)
        
        self.idleTimerExtensionDisposable = context.idleTimerExtension()
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: navigationBarTheme, strings: NavigationBarStrings(back: self.presentationData.strings.Wallet_Navigation_Back, close: self.presentationData.strings.Wallet_Navigation_Close)))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.navigationBar?.intrinsicCanTransitionInline = false
        
        if case .receive = mode {
            self.navigationPresentation = .flatModal
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
        }
    
        self.title = self.presentationData.strings.Wallet_Receive_Title
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Wallet_Navigation_Back, style: .plain, target: nil, action: nil)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Wallet_Navigation_Done, style: .done, target: self, action: #selector(self.donePressed))
    }
    
    deinit {
        self.idleTimerExtensionDisposable.dispose()
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = WalletReceiveScreenNode(context: self.context, presentationData: self.presentationData, mode: self.mode)
        (self.displayNode as! WalletReceiveScreenNode).openCreateInvoice = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            self?.push(walletCreateInvoiceScreen(context: strongSelf.context, address: strongSelf.mode.address))
        }
        (self.displayNode as! WalletReceiveScreenNode).displayCopyContextMenu = { [weak self] node, frame, text in
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
    
    override func preferredContentSizeForLayout(_ layout: ContainerViewLayout) -> CGSize? {
        return CGSize(width: layout.size.width, height: min(674.0, layout.size.height))
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! WalletReceiveScreenNode).containerLayoutUpdated(layout: layout, navigationHeight: self.navigationHeight, transition: transition)
    }
    
    @objc private func donePressed() {
        if let navigationController = self.navigationController as? NavigationController {
            var controllers = navigationController.viewControllers
            controllers = controllers.filter { controller in
                if controller is WalletReceiveScreen {
                    return false
                }
                if controller is WalletCreateInvoiceScreen {
                    return false
                }
                return true
            }
            navigationController.setViewControllers(controllers, animated: true)
        }
    }
}

private func urlForMode(_ mode: WalletReceiveScreenMode) -> String {
    switch mode {
        case let .receive(address):
            return walletInvoiceUrl(address: address)
        case let .invoice(address, amount, comment):
            return walletInvoiceUrl(address: address, amount: amount, comment: comment)
    }
}

private final class WalletReceiveScreenNode: ViewControllerTracingNode {
    private let context: WalletContext
    private var presentationData: WalletPresentationData
    private let mode: WalletReceiveScreenMode
    
    private let textNode: ImmediateTextNode
    
    private let qrButtonNode: HighlightTrackingButtonNode
    private let qrImageNode: TransformImageNode
    private let qrIconNode: AnimatedStickerNode
    private var qrCodeSize: Int?
    
    private let urlTextNode: ImmediateTextNode
    
    private let buttonNode: SolidRoundedButtonNode
    private let secondaryButtonNode: HighlightableButtonNode
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    var openCreateInvoice: (() -> Void)?
    var displayCopyContextMenu: ((ASDisplayNode, CGRect, String) -> Void)?
  
    init(context: WalletContext, presentationData: WalletPresentationData, mode: WalletReceiveScreenMode) {
        self.context = context
        self.presentationData = presentationData
        self.mode = mode
        
        self.textNode = ImmediateTextNode()
        self.textNode.textAlignment = .center
        self.textNode.maximumNumberOfLines = 3
        
        self.qrImageNode = TransformImageNode()
        self.qrImageNode.clipsToBounds = true
        self.qrImageNode.cornerRadius = 14.0
            
        self.qrIconNode = AnimatedStickerNode()
        if let path = getAppBundle().path(forResource: "WalletIntroStatic", ofType: "tgs") {
            self.qrIconNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 240, height: 240, mode: .direct)
            self.qrIconNode.visibility = true
        }
        
        self.qrButtonNode = HighlightTrackingButtonNode()
        
        self.urlTextNode = ImmediateTextNode()
        self.urlTextNode.maximumNumberOfLines = 4
        self.urlTextNode.textAlignment = .justified
        self.urlTextNode.lineSpacing = 0.35
        
        self.buttonNode = SolidRoundedButtonNode(title: "", icon: nil, theme: SolidRoundedButtonTheme(backgroundColor: self.presentationData.theme.setup.buttonFillColor, foregroundColor: self.presentationData.theme.setup.buttonForegroundColor), height: 50.0, cornerRadius: 10.0, gloss: false)
        
        self.secondaryButtonNode = HighlightableButtonNode()
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.textNode)
        self.addSubnode(self.qrImageNode)
        self.addSubnode(self.qrIconNode)
        self.addSubnode(self.qrButtonNode)
        self.addSubnode(self.urlTextNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.secondaryButtonNode)
        
        self.qrImageNode.setSignal(qrCode(string: urlForMode(mode), color: .black, backgroundColor: .white, icon: .cutout) |> beforeNext { [weak self] size, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.qrCodeSize = size
            if let (layout, navigationHeight) = strongSelf.validLayout {
                strongSelf.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .immediate)
            }
        } |> map { $0.1 }, attemptSynchronously: true)
        
        self.qrButtonNode.addTarget(self, action: #selector(self.qrPressed), forControlEvents: .touchUpInside)
        self.qrButtonNode.highligthedChanged = { [weak self] highlighted in
            guard let strongSelf = self else {
                return
            }
            if highlighted {
                strongSelf.qrImageNode.alpha = 0.4
                strongSelf.qrIconNode.alpha = 0.4
            } else {
                strongSelf.qrImageNode.layer.animateAlpha(from: strongSelf.qrImageNode.alpha, to: 1.0, duration: 0.2)
                strongSelf.qrIconNode.layer.animateAlpha(from: strongSelf.qrIconNode.alpha, to: 1.0, duration: 0.2)
                strongSelf.qrImageNode.alpha = 1.0
                strongSelf.qrIconNode.alpha = 1.0
            }
        }
        
        let textFont = Font.regular(16.0)
        let textColor = self.presentationData.theme.list.itemPrimaryTextColor
        let secondaryTextColor = self.presentationData.theme.list.itemSecondaryTextColor
        let url = urlForMode(self.mode)
        switch self.mode {
            case let .receive(address):
                self.textNode.attributedText = NSAttributedString(string: self.presentationData.strings.Wallet_Receive_ShareUrlInfo, font: textFont, textColor: secondaryTextColor)
                self.buttonNode.title = self.presentationData.strings.Wallet_Receive_ShareAddress
                self.secondaryButtonNode.setTitle(self.presentationData.strings.Wallet_Receive_CreateInvoice, with: Font.regular(17.0), with: self.presentationData.theme.list.itemAccentColor, for: .normal)
            case let .invoice(address, amount, comment):
                self.textNode.attributedText = NSAttributedString(string: self.presentationData.strings.Wallet_Receive_ShareUrlInfo, font: textFont, textColor: secondaryTextColor, paragraphAlignment: .center)
                self.buttonNode.title = self.presentationData.strings.Wallet_Receive_ShareInvoiceUrl
        }
        
        self.buttonNode.pressed = {
            context.shareUrl(url)
        }
        self.secondaryButtonNode.addTarget(self, action: #selector(createInvoicePressed), forControlEvents: .touchUpInside)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let addressGestureRecognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapAddressGesture(_:)))
        addressGestureRecognizer.tapActionAtPoint = { [weak self] point in
            return .waitForSingleTap
        }
        self.urlTextNode.view.addGestureRecognizer(addressGestureRecognizer)
    }
    
    @objc func tapLongTapOrDoubleTapAddressGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                switch gesture {
                case .longTap:
                    self.displayCopyContextMenu?(self, self.urlTextNode.frame, urlForMode(self.mode))
                default:
                    break
                }
            }
        default:
            break
        }
    }
    
    @objc private func qrPressed() {
        shareInvoiceQrCode(context: self.context, invoice: urlForMode(self.mode))
    }
    
    @objc private func createInvoicePressed() {
        self.openCreateInvoice?()
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationHeight)
        
        var insets = layout.insets(options: [])
        insets.top += navigationHeight
        let inset: CGFloat = 22.0
        
        let textSize = self.textNode.updateLayout(CGSize(width: layout.size.width - inset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        let textFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - textSize.width) / 2.0), y: insets.top + 24.0), size: textSize)
        transition.updateFrame(node: self.textNode, frame: textFrame)
        
        let makeImageLayout = self.qrImageNode.asyncLayout()
        
        let imageSide: CGFloat = 215.0
        var imageSize = CGSize(width: imageSide, height: imageSide)
        let imageApply = makeImageLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: nil))
        
        let _ = imageApply()
        
        let imageFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - imageSize.width) / 2.0), y: textFrame.maxY + 20.0), size: imageSize)
        transition.updateFrame(node: self.qrImageNode, frame: imageFrame)
        transition.updateFrame(node: self.qrButtonNode, frame: imageFrame)
        
        if let qrCodeSize = self.qrCodeSize {
            let (_, cutoutFrame, _) = qrCodeCutout(size: qrCodeSize, dimensions: imageSize, scale: nil)
            self.qrIconNode.updateLayout(size: cutoutFrame.size)
            transition.updateBounds(node: self.qrIconNode, bounds: CGRect(origin: CGPoint(), size: cutoutFrame.size))
            transition.updatePosition(node: self.qrIconNode, position: imageFrame.center.offsetBy(dx: 0.0, dy: -1.0))
        }
        
        if self.urlTextNode.attributedText?.string.isEmpty ?? true {
            var url = urlForMode(self.mode)
            if case .receive = self.mode {
                url = url + "?"
            }
            
            let addressFont: UIFont
            let countRatio: CGFloat
            if layout.size.width == 320.0 {
                addressFont = Font.monospace(16.0)
                countRatio = 0.0999
            } else {
                addressFont = Font.monospace(17.0)
                countRatio = 0.0853
            }
            let count = min(url.count / 2, Int(ceil(min(layout.size.width, layout.size.height) * countRatio)))
            let sliced = String(url.enumerated().map { $0 > 0 && $0 % count == 0 ? ["\n", $1] : [$1]}.joined())
            
            self.urlTextNode.attributedText = NSAttributedString(string: sliced, font: addressFont, textColor: self.presentationData.theme.list.itemPrimaryTextColor, paragraphAlignment: .justified)
        }
        
        let addressInset: CGFloat = 12.0
        let urlTextSize = self.urlTextNode.updateLayout(CGSize(width: layout.size.width - addressInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        transition.updateFrame(node: self.urlTextNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - urlTextSize.width) / 2.0), y: imageFrame.maxY + 23.0), size: urlTextSize))
        
        let buttonSideInset: CGFloat = 16.0
        let bottomInset = insets.bottom + 10.0
        let buttonWidth = layout.size.width - buttonSideInset * 2.0
        let buttonHeight: CGFloat = 50.0
        
        var buttonOffset: CGFloat = 0.0
        if let _ = self.secondaryButtonNode.attributedTitle(for: .normal) {
            buttonOffset = -60.0
            self.secondaryButtonNode.frame = CGRect(x: floor((layout.size.width - buttonWidth) / 2.0), y: layout.size.height - bottomInset - buttonHeight, width: buttonWidth, height: buttonHeight)
        }
        
        let buttonFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - buttonWidth) / 2.0), y: layout.size.height - bottomInset - buttonHeight + buttonOffset), size: CGSize(width: buttonWidth, height: buttonHeight))
        transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
        self.buttonNode.updateLayout(width: buttonFrame.width, transition: transition)
    }
}
