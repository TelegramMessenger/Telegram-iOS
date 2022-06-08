import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AppBundle
import QrCode
import AccountContext
import SolidRoundedButtonNode
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import PresentationDataUtils

private func shareQrCode(context: AccountContext, link: String, ecl: String, view: UIView) {
    let _ = (qrCode(string: link, color: .black, backgroundColor: .white, icon: .custom(UIImage(bundleImageName: "Chat/Links/QrLogo")), ecl: ecl)
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
        if let window = view.window {
            activityController.popoverPresentationController?.sourceView = window
            activityController.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.size.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
        }
        context.sharedContext.applicationBindings.presentNativeController(activityController)
    })
}

public final class QrCodeScreen: ViewController {
    public enum Subject {
        case peer(peer: EnginePeer)
        case invite(invite: ExportedInvitation, isGroup: Bool)
        
        var link: String {
            switch self {
                case let .peer(peer):
                    return "https://t.me/\(peer.addressName ?? "")"
                case let .invite(invite, _):
                    return invite.link ?? ""
            }
        }
        
        var ecl: String {
            switch self {
                case .peer:
                    return "Q"
                case .invite:
                    return "Q"
            }
        }
    }
    
    private var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    private var animatedIn = false
    
    private let context: AccountContext
    private let subject: QrCodeScreen.Subject
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var initialBrightness: CGFloat?
    private var brightnessArguments: (Double, Double, CGFloat, CGFloat)?
    
    private var animator: ConstantDisplayLinkAnimator?
    
    private let idleTimerExtensionDisposable = MetaDisposable()
    
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, subject: QrCodeScreen.Subject) {
        self.context = context
        self.subject = subject
        
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        
        self.blocksBackgroundWhenInOverlay = true
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationData = presentationData
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
        
        self.idleTimerExtensionDisposable.set(self.context.sharedContext.applicationBindings.pushIdleTimerExtension())
        
        self.statusBar.statusBarStyle = .Ignore
        
        self.animator = ConstantDisplayLinkAnimator(update: { [weak self] in
            self?.updateBrightness()
        })
        self.animator?.isPaused = true
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.idleTimerExtensionDisposable.dispose()
        self.animator?.invalidate()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(context: self.context, presentationData: self.presentationData, subject: self.subject)
        self.controllerNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        self.controllerNode.cancel = { [weak self] in
            self?.dismiss()
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedIn {
            self.animatedIn = true
            self.controllerNode.animateIn()
            
            self.initialBrightness = UIScreen.main.brightness
            self.brightnessArguments = (CACurrentMediaTime(), 0.3, UIScreen.main.brightness, 1.0)
            self.updateBrightness()
        }
    }
    
    private func updateBrightness() {
        if let (startTime, duration, initial, target) = self.brightnessArguments {
            self.animator?.isPaused = false
            
            let t = CGFloat(max(0.0, min(1.0, (CACurrentMediaTime() - startTime) / duration)))
            let value = initial + (target - initial) * t
            
            UIScreen.main.brightness = value
            
            if t >= 1.0 {
                self.brightnessArguments = nil
                self.animator?.isPaused = true
            }
        } else {
            self.animator?.isPaused = true
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if UIScreen.main.brightness > 0.99, let initialBrightness = self.initialBrightness {
            self.brightnessArguments = (CACurrentMediaTime(), 0.3, UIScreen.main.brightness, initialBrightness)
            self.updateBrightness()
        }
        
        self.controllerNode.animateOut(completion: completion)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }

    class Node: ViewControllerTracingNode, UIScrollViewDelegate {
        private let context: AccountContext
        private let subject: QrCodeScreen.Subject
        private var presentationData: PresentationData
    
        private let dimNode: ASDisplayNode
        private let wrappingScrollNode: ASScrollNode
        private let contentContainerNode: ASDisplayNode
        private let backgroundNode: ASDisplayNode
        private let contentBackgroundNode: ASDisplayNode
        private let titleNode: ASTextNode
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
        
        init(context: AccountContext, presentationData: PresentationData, subject: QrCodeScreen.Subject) {
            self.context = context
            self.subject = subject
            self.presentationData = presentationData

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
            
            let title: String
            let text: String
            switch subject {
                case let .invite(_, isGroup):
                    title = self.presentationData.strings.InviteLink_QRCode_Title
                    text = isGroup ? self.presentationData.strings.InviteLink_QRCode_Info : self.presentationData.strings.InviteLink_QRCode_InfoChannel
                default:
                    title = ""
                    text = ""
            }
            
            self.titleNode = ASTextNode()
            self.titleNode.attributedText = NSAttributedString(string: title, font: Font.bold(17.0), textColor: textColor)
            
            self.cancelButton = HighlightableButtonNode()
            self.cancelButton.setTitle(self.presentationData.strings.Common_Done, with: Font.bold(17.0), with: accentColor, for: .normal)
            
            self.buttonNode = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(theme: self.presentationData.theme), height: 52.0, cornerRadius: 11.0, gloss: false)
            
            self.textNode = ImmediateTextNode()
            self.textNode.maximumNumberOfLines = 3
            self.textNode.textAlignment = .center
            
            self.qrButtonNode = HighlightTrackingButtonNode()
            self.qrImageNode = TransformImageNode()
            self.qrImageNode.clipsToBounds = true
            self.qrImageNode.cornerRadius = 16.0
            
            self.qrIconNode = DefaultAnimatedStickerNodeImpl()   
            self.qrIconNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "PlaneLogo"), width: 240, height: 240, playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
            self.qrIconNode.visibility = true
            
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
                        
            self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(14.0), textColor: secondaryTextColor)
            self.buttonNode.title = self.presentationData.strings.InviteLink_QRCode_Share
            
            self.cancelButton.addTarget(self, action: #selector(self.cancelButtonPressed), forControlEvents: .touchUpInside)
            self.buttonNode.pressed = { [weak self] in
                if let strongSelf = self{
                    shareQrCode(context: strongSelf.context, link: subject.link, ecl: subject.ecl, view: strongSelf.view)
                }
            }
            
            self.qrImageNode.setSignal(qrCode(string: subject.link, color: .black, backgroundColor: .white, icon: .cutout, ecl: subject.ecl) |> beforeNext { [weak self] size, _ in
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
            self.buttonNode.pressed?()
        }
        
        func updatePresentationData(_ presentationData: PresentationData) {
            let previousTheme = self.presentationData.theme
            self.presentationData = presentationData
            
            self.contentBackgroundNode.backgroundColor = self.presentationData.theme.actionSheet.opaqueItemBackgroundColor
            self.titleNode.attributedText = NSAttributedString(string: self.titleNode.attributedText?.string ?? "", font: Font.bold(17.0), textColor: self.presentationData.theme.actionSheet.primaryTextColor)
            self.textNode.attributedText = NSAttributedString(string: self.textNode.attributedText?.string ?? "", font: Font.regular(13.0), textColor: self.presentationData.theme.actionSheet.secondaryTextColor)
            
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
            insets.top = 32.0
            
            let makeImageLayout = self.qrImageNode.asyncLayout()
            let imageSide: CGFloat = 240.0
            let imageSize = CGSize(width: imageSide, height: imageSide)
            let imageApply = makeImageLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: nil))
            let _ = imageApply()
            
            let width = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: 0.0)
            
            let imageFrame = CGRect(origin: CGPoint(x: floor((width - imageSize.width) / 2.0), y: insets.top + 16.0), size: imageSize)
            transition.updateFrame(node: self.qrImageNode, frame: imageFrame)
            transition.updateFrame(node: self.qrButtonNode, frame: imageFrame)
            
            if let qrCodeSize = self.qrCodeSize {
                let (_, cutoutFrame, _) = qrCodeCutout(size: qrCodeSize, dimensions: imageSize, scale: nil)
                self.qrIconNode.updateLayout(size: cutoutFrame.size)
                transition.updateBounds(node: self.qrIconNode, bounds: CGRect(origin: CGPoint(), size: cutoutFrame.size))
                transition.updatePosition(node: self.qrIconNode, position: imageFrame.center.offsetBy(dx: 0.0, dy: -1.0))
            }
            
            let inset: CGFloat = 32.0
            var textSize = self.textNode.updateLayout(CGSize(width: width - inset * 3.0, height: CGFloat.greatestFiniteMagnitude))
            let textFrame = CGRect(origin: CGPoint(x: floor((width - textSize.width) / 2.0), y: imageFrame.maxY + 20.0), size: textSize)
            transition.updateFrame(node: self.textNode, frame: textFrame)
            
            var textSpacing: CGFloat = 111.0
            if case .compact = layout.metrics.widthClass, layout.size.width > layout.size.height {
                textSize = CGSize()
                self.textNode.isHidden = true
                textSpacing = 52.0
            } else {
                self.textNode.isHidden = false
            }
            
            let buttonSideInset: CGFloat = 16.0
            let bottomInset = insets.bottom + 10.0
            let buttonWidth = layout.size.width - buttonSideInset * 2.0
            let buttonHeight: CGFloat = 50.0
            
            let buttonFrame = CGRect(origin: CGPoint(x: floor((width - buttonWidth) / 2.0), y: layout.size.height - bottomInset - buttonHeight), size: CGSize(width: buttonWidth, height: buttonHeight))
            transition.updateFrame(node: self.buttonNode, frame: buttonFrame)
            let _ = self.buttonNode.updateLayout(width: buttonFrame.width, transition: transition)
            
            let titleHeight: CGFloat = 54.0
            let contentHeight = titleHeight + textSize.height + imageSize.height + bottomInset + textSpacing
                        
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
            let cancelFrame = CGRect(origin: CGPoint(x: width - cancelSize.width - 16.0, y: 16.0), size: cancelSize)
            transition.updateFrame(node: self.cancelButton, frame: cancelFrame)
            
            let buttonInset: CGFloat = 16.0
            let doneButtonHeight = self.buttonNode.updateLayout(width: contentFrame.width - buttonInset * 2.0, transition: transition)
            transition.updateFrame(node: self.buttonNode, frame: CGRect(x: buttonInset, y: contentHeight - doneButtonHeight - insets.bottom - 16.0, width: contentFrame.width, height: doneButtonHeight))
            
            transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)
        }
    }
}
