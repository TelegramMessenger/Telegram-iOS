import Foundation
import UIKit
import SwiftSignalKit
import TelegramPresentationData
import AppBundle
import AsyncDisplayKit
import SyncCore
import Display
import QrCode
import AccountContext
import SolidRoundedButtonNode
import AnimatedStickerNode

private func shareQrCode(context: AccountContext, link: String) {
    let _ = (qrCode(string: link, color: .black, backgroundColor: .white, icon: .custom(UIImage(bundleImageName: "Chat/Links/QrLogo")))
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
        context.sharedContext.applicationBindings.presentNativeController(activityController)
    })
}

public final class InviteLinkQRCodeController: ViewController {
    private var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    private var animatedIn = false
    
    private let context: AccountContext
    private let invite: ExportedInvitation

    private var presentationDataDisposable: Disposable?
    
    private let idleTimerExtensionDisposable = MetaDisposable()
    
    public init(context: AccountContext, invite: ExportedInvitation) {
        self.context = context
        self.invite = invite
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        
        self.blocksBackgroundWhenInOverlay = true
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
        
        self.idleTimerExtensionDisposable.set(self.context.sharedContext.applicationBindings.pushIdleTimerExtension())
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.idleTimerExtensionDisposable.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(context: self.context, invite: self.invite)
        self.controllerNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        self.controllerNode.cancel = { [weak self] in
            self?.dismiss()
        }
    }
    
    override public func loadView() {
        super.loadView()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedIn {
            self.animatedIn = true
            self.controllerNode.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: completion)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }

    class Node: ViewControllerTracingNode, UIScrollViewDelegate {
        private let context: AccountContext
        private let invite: ExportedInvitation
        private var presentationData: PresentationData
    
        private let dimNode: ASDisplayNode
        private let wrappingScrollNode: ASScrollNode
        private let contentContainerNode: ASDisplayNode
        private let backgroundNode: ASDisplayNode
        private let contentBackgroundNode: ASDisplayNode
        private let titleNode: ASTextNode
        private let subtitleNode: ASTextNode
        private let cancelButton: HighlightableButtonNode
        
        private let textNode: ImmediateTextNode
        private let qrButtonNode: HighlightTrackingButtonNode
        private let qrImageNode: TransformImageNode
        private let qrIconNode: AnimatedStickerNode
        private var qrCodeSize: Int?
        private let buttonNode: SolidRoundedButtonNode
                
        private var containerLayout: (ContainerViewLayout, CGFloat)?
        
        var completion: ((Int32) -> Void)?
        var dismiss: (() -> Void)?
        var cancel: (() -> Void)?
        
        init(context: AccountContext, invite: ExportedInvitation) {
            self.context = context
            self.invite = invite
            self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

            self.wrappingScrollNode = ASScrollNode()
            self.wrappingScrollNode.view.alwaysBounceVertical = true
            self.wrappingScrollNode.view.delaysContentTouches = false
            self.wrappingScrollNode.view.canCancelContentTouches = true
            
            self.dimNode = ASDisplayNode()
            self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
            
            self.contentContainerNode = ASDisplayNode()
            self.contentContainerNode.isOpaque = false

            self.backgroundNode = ASDisplayNode()
            self.backgroundNode.clipsToBounds = true
            self.backgroundNode.cornerRadius = 16.0
            
            let backgroundColor = self.presentationData.theme.actionSheet.opaqueItemBackgroundColor
            let textColor = self.presentationData.theme.actionSheet.primaryTextColor
            let secondaryTextColor = self.presentationData.theme.actionSheet.secondaryTextColor
            let accentColor = self.presentationData.theme.actionSheet.controlAccentColor
            
            self.contentBackgroundNode = ASDisplayNode()
            self.contentBackgroundNode.backgroundColor = backgroundColor
            
            self.titleNode = ASTextNode()
            self.titleNode.attributedText = NSAttributedString(string: self.presentationData.strings.InviteLink_QRCode_Title, font: Font.bold(17.0), textColor: textColor)
            
            self.subtitleNode = ASTextNode()
            self.subtitleNode.attributedText = NSAttributedString(string: self.presentationData.strings.InviteLink_QRCode_Title, font: Font.regular(13.0), textColor: secondaryTextColor)
            
            self.cancelButton = HighlightableButtonNode()
            self.cancelButton.setTitle(self.presentationData.strings.Common_Done, with: Font.bold(17.0), with: accentColor, for: .normal)
            
            self.buttonNode = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(theme: self.presentationData.theme), height: 52.0, cornerRadius: 11.0, gloss: false)
            
            self.textNode = ImmediateTextNode()
            self.textNode.maximumNumberOfLines = 3
            self.textNode.textAlignment = .center
            
            self.qrButtonNode = HighlightTrackingButtonNode()
            self.qrImageNode = TransformImageNode()
            
            self.qrIconNode = AnimatedStickerNode()
            if let path = getAppBundle().path(forResource: "PlaneLogo", ofType: "tgs") {
                self.qrIconNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: 240, height: 240, mode: .direct(cachePathPrefix: nil))
                self.qrIconNode.visibility = true
            }
            
            super.init()
            
            self.backgroundColor = nil
            self.isOpaque = false
            
            self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
            self.addSubnode(self.dimNode)
            
            self.wrappingScrollNode.view.delegate = self
            self.addSubnode(self.wrappingScrollNode)
            
            self.wrappingScrollNode.addSubnode(self.backgroundNode)
            self.wrappingScrollNode.addSubnode(self.contentContainerNode)
            
            self.backgroundNode.addSubnode(self.contentBackgroundNode)
            self.contentContainerNode.addSubnode(self.titleNode)
            self.contentContainerNode.addSubnode(self.cancelButton)
            self.contentContainerNode.addSubnode(self.buttonNode)

            self.contentContainerNode.addSubnode(self.textNode)
            self.contentContainerNode.addSubnode(self.qrImageNode)
            self.contentContainerNode.addSubnode(self.qrIconNode)
            self.contentContainerNode.addSubnode(self.qrButtonNode)
            
            let textFont = Font.regular(13.0)
            
            self.textNode.attributedText = NSAttributedString(string: self.presentationData.strings.InviteLink_QRCode_Info, font: textFont, textColor: secondaryTextColor)
            self.buttonNode.title = self.presentationData.strings.InviteLink_QRCode_Share
            
            self.cancelButton.addTarget(self, action: #selector(self.cancelButtonPressed), forControlEvents: .touchUpInside)
            self.buttonNode.pressed = { [weak self] in
                if let strongSelf = self{
                    shareQrCode(context: strongSelf.context, link: strongSelf.invite.link)
                }
            }
            
            self.qrImageNode.setSignal(qrCode(string: self.invite.link, color: .black, backgroundColor: .white, icon: .cutout) |> beforeNext { [weak self] size, _ in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.qrCodeSize = size
                if let (layout, navigationHeight) = strongSelf.containerLayout {
                    strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
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
                    strongSelf.qrImageNode.alpha = 1.0
                    strongSelf.qrIconNode.layer.animateAlpha(from: strongSelf.qrIconNode.alpha, to: 1.0, duration: 0.2)
                    strongSelf.qrIconNode.alpha = 1.0
                }
            }
        }
        
        @objc private func qrPressed() {
            shareQrCode(context: self.context, link: self.invite.link)
        }
        
        func updatePresentationData(_ presentationData: PresentationData) {
            let previousTheme = self.presentationData.theme
            self.presentationData = presentationData
            
            self.contentBackgroundNode.backgroundColor = self.presentationData.theme.actionSheet.opaqueItemBackgroundColor
            self.titleNode.attributedText = NSAttributedString(string: self.titleNode.attributedText?.string ?? "", font: Font.bold(17.0), textColor: self.presentationData.theme.actionSheet.primaryTextColor)
            
            if previousTheme !== presentationData.theme, let (layout, navigationBarHeight) = self.containerLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            }
            
            self.cancelButton.setTitle(self.presentationData.strings.Common_Done, with: Font.bold(17.0), with: self.presentationData.theme.actionSheet.controlAccentColor, for: .normal)
            self.buttonNode.updateTheme(SolidRoundedButtonTheme(theme: self.presentationData.theme))
        }
        
        override func didLoad() {
            super.didLoad()
            
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.wrappingScrollNode.view.contentInsetAdjustmentBehavior = .never
            }
        }
        
        @objc func cancelButtonPressed() {
            self.cancel?()
        }
        
        @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.cancelButtonPressed()
            }
        }
        
        func animateIn() {
            self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
            
            let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
            
            let dimPosition = self.dimNode.layer.position
            self.dimNode.layer.animatePosition(from: CGPoint(x: dimPosition.x, y: dimPosition.y - offset), to: dimPosition, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
            self.layer.animateBoundsOriginYAdditive(from: -offset, to: 0.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        }
        
        func animateOut(completion: (() -> Void)? = nil) {
            var dimCompleted = false
            var offsetCompleted = false
            
            let internalCompletion: () -> Void = { [weak self] in
                if let strongSelf = self, dimCompleted && offsetCompleted {
                    strongSelf.dismiss?()
                }
                completion?()
            }
            
            self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
                dimCompleted = true
                internalCompletion()
            })
            
            let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
            let dimPosition = self.dimNode.layer.position
            self.dimNode.layer.animatePosition(from: dimPosition, to: CGPoint(x: dimPosition.x, y: dimPosition.y - offset), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
            self.layer.animateBoundsOriginYAdditive(from: 0.0, to: -offset, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
                offsetCompleted = true
                internalCompletion()
            })
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if self.bounds.contains(point) {
                if !self.contentBackgroundNode.bounds.contains(self.convert(point, to: self.contentBackgroundNode)) {
                    return self.dimNode.view
                }
            }
            return super.hitTest(point, with: event)
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            let contentOffset = scrollView.contentOffset
            let additionalTopHeight = max(0.0, -contentOffset.y)
            
            if additionalTopHeight >= 30.0 {
                self.cancelButtonPressed()
            }
        }
        
        func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
            self.containerLayout = (layout, navigationBarHeight)
            
            var insets = layout.insets(options: [.statusBar, .input])
            insets.top = max(10.0, insets.top)
            
            let makeImageLayout = self.qrImageNode.asyncLayout()
            let imageSide: CGFloat = 240.0
            let imageSize = CGSize(width: imageSide, height: imageSide)
            let imageApply = makeImageLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: nil))
            
            let _ = imageApply()
            
            let imageFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - imageSize.width) / 2.0), y: insets.top + 16.0), size: imageSize)
            transition.updateFrame(node: self.qrImageNode, frame: imageFrame)
            transition.updateFrame(node: self.qrButtonNode, frame: imageFrame)
            
            if let qrCodeSize = self.qrCodeSize {
                let (_, cutoutFrame, _) = qrCodeCutout(size: qrCodeSize, dimensions: imageSize, scale: nil)
                self.qrIconNode.updateLayout(size: cutoutFrame.size)
                transition.updateBounds(node: self.qrIconNode, bounds: CGRect(origin: CGPoint(), size: cutoutFrame.size))
                transition.updatePosition(node: self.qrIconNode, position: imageFrame.center.offsetBy(dx: 0.0, dy: -1.0))
            }
            
            let inset: CGFloat = 22.0
            let textSize = self.textNode.updateLayout(CGSize(width: layout.size.width - inset * 2.0, height: CGFloat.greatestFiniteMagnitude))
            let textFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - textSize.width) / 2.0), y: imageFrame.maxY + 20.0), size: textSize)
            transition.updateFrame(node: self.textNode, frame: textFrame)
            
            let buttonSideInset: CGFloat = 16.0
            let bottomInset = insets.bottom + 10.0
            let buttonWidth = layout.size.width - buttonSideInset * 2.0
            let buttonHeight: CGFloat = 50.0
            
            let buttonFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - buttonWidth) / 2.0), y: layout.size.height - bottomInset - buttonHeight), size: CGSize(width: buttonWidth, height: buttonHeight))
            transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
            let _ = self.buttonNode.updateLayout(width: buttonFrame.width, transition: transition)
            
            
            let titleHeight: CGFloat = 54.0
            let contentHeight = titleHeight + textSize.height + imageSize.height + bottomInset + 121.0
            
            let width = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: layout.safeInsets.left)
            
            let sideInset = floor((layout.size.width - width) / 2.0)
            let contentContainerFrame = CGRect(origin: CGPoint(x: sideInset, y: layout.size.height - contentHeight), size: CGSize(width: width, height: contentHeight))
            let contentFrame = contentContainerFrame
            
            var backgroundFrame = CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY), size: CGSize(width: contentFrame.width, height: contentFrame.height + 2000.0))
            if backgroundFrame.minY < contentFrame.minY {
                backgroundFrame.origin.y = contentFrame.minY
            }
            transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
            transition.updateFrame(node: self.contentBackgroundNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
            transition.updateFrame(node: self.wrappingScrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
            transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
            
            let titleSize = self.titleNode.measure(CGSize(width: width, height: titleHeight))
            let titleFrame = CGRect(origin: CGPoint(x: floor((contentFrame.width - titleSize.width) / 2.0), y: 16.0), size: titleSize)
            transition.updateFrame(node: self.titleNode, frame: titleFrame)
            
            let cancelSize = self.cancelButton.measure(CGSize(width: width, height: titleHeight))
            let cancelFrame = CGRect(origin: CGPoint(x: width - cancelSize.width - 16.0, y: 18.0), size: cancelSize)
            transition.updateFrame(node: self.cancelButton, frame: cancelFrame)
            
            let buttonInset: CGFloat = 16.0
            let doneButtonHeight = self.buttonNode.updateLayout(width: contentFrame.width - buttonInset * 2.0, transition: transition)
            transition.updateFrame(node: self.buttonNode, frame: CGRect(x: buttonInset, y: contentHeight - doneButtonHeight - insets.bottom - 16.0, width: contentFrame.width, height: doneButtonHeight))
            
            transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)
        }
    }
}
