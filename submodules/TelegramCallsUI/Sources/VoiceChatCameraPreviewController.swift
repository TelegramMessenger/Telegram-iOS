import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import SolidRoundedButtonNode
import PresentationDataUtils
import UIKitRuntimeUtils
import ReplayKit

final class VoiceChatCameraPreviewController: ViewController {
    private var controllerNode: VoiceChatCameraPreviewControllerNode {
        return self.displayNode as! VoiceChatCameraPreviewControllerNode
    }
    
    private let context: AccountContext
    
    private var animatedIn = false

    private let cameraNode: GroupVideoNode
    private let shareCamera: (ASDisplayNode) -> Void
    private let switchCamera: () -> Void
    
    private var presentationDataDisposable: Disposable?
    
    init(context: AccountContext, cameraNode: GroupVideoNode, shareCamera: @escaping (ASDisplayNode) -> Void, switchCamera: @escaping () -> Void) {
        self.context = context
        self.cameraNode = cameraNode
        self.shareCamera = shareCamera
        self.switchCamera = switchCamera
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        
        self.blocksBackgroundWhenInOverlay = true
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = VoiceChatCameraPreviewControllerNode(controller: self, context: self.context, cameraNode: self.cameraNode)
        self.controllerNode.shareCamera = { [weak self] in
            if let strongSelf = self {
                strongSelf.shareCamera(strongSelf.cameraNode)
                strongSelf.dismiss()
            }
        }
        self.controllerNode.switchCamera = { [weak self] in
            self?.switchCamera()
            self?.cameraNode.flip(withBackground: true)
        }
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
}

private class VoiceChatCameraPreviewControllerNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private weak var controller: VoiceChatCameraPreviewController?
    private let context: AccountContext
    private var presentationData: PresentationData
    
    private let cameraNode: GroupVideoNode
    private let dimNode: ASDisplayNode
    private let wrappingScrollNode: ASScrollNode
    private let contentContainerNode: ASDisplayNode
    private let effectNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let contentBackgroundNode: ASDisplayNode
    private let titleNode: ASTextNode
    private let previewContainerNode: ASDisplayNode
    private let cameraButton: SolidRoundedButtonNode
    private let screenButton: SolidRoundedButtonNode
    private var broadcastPickerView: UIView?
    private let cancelButton: SolidRoundedButtonNode
    
    private let switchCameraButton: HighlightTrackingButtonNode
    private let switchCameraEffectView: UIVisualEffectView
    private let switchCameraIconNode: ASImageNode
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?

    private var applicationStateDisposable: Disposable?
    
    var shareCamera: (() -> Void)?
    var switchCamera: (() -> Void)?
    var dismiss: (() -> Void)?
    var cancel: (() -> Void)?
    
    init(controller: VoiceChatCameraPreviewController, context: AccountContext, cameraNode: GroupVideoNode) {
        self.controller = controller
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.cameraNode = cameraNode
        
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
        
        let backgroundColor = UIColor(rgb: 0x1c1c1e)
        let textColor: UIColor = .white
        let buttonColor: UIColor = UIColor(rgb: 0x2b2b2f)
        let buttonTextColor: UIColor = .white
        let blurStyle: UIBlurEffect.Style = .dark
        
        self.effectNode = ASDisplayNode(viewBlock: {
            return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
        })
        
        self.contentBackgroundNode = ASDisplayNode()
        self.contentBackgroundNode.backgroundColor = backgroundColor
        
        let title =  self.presentationData.strings.VoiceChat_VideoPreviewTitle
        
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.bold(17.0), textColor: textColor)
                
        self.cameraButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(theme: self.presentationData.theme), font: .bold, height: 52.0, cornerRadius: 11.0, gloss: false)
        self.cameraButton.title = self.presentationData.strings.VoiceChat_VideoPreviewShareCamera
        
        self.screenButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(backgroundColor: buttonColor, foregroundColor: buttonTextColor), font: .bold, height: 52.0, cornerRadius: 11.0, gloss: false)
        self.screenButton.title = self.presentationData.strings.VoiceChat_VideoPreviewShareScreen

        if #available(iOS 12.0, *) {
            let broadcastPickerView = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 50, height: 52.0))
            broadcastPickerView.alpha = 0.1
            broadcastPickerView.preferredExtension = "\(self.context.sharedContext.applicationBindings.appBundleId).BroadcastUpload"
            broadcastPickerView.showsMicrophoneButton = false
            self.broadcastPickerView = broadcastPickerView
        }
        
        self.cancelButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(backgroundColor: buttonColor, foregroundColor: buttonTextColor), font: .regular, height: 52.0, cornerRadius: 11.0, gloss: false)
        self.cancelButton.title = self.presentationData.strings.Common_Cancel
        
        self.previewContainerNode = ASDisplayNode()
        self.previewContainerNode.cornerRadius = 11.0
        self.previewContainerNode.backgroundColor = .black
        
        self.switchCameraButton = HighlightTrackingButtonNode()
        self.switchCameraEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        self.switchCameraEffectView.clipsToBounds = true
        self.switchCameraEffectView.layer.cornerRadius = 24.0
        self.switchCameraEffectView.isUserInteractionEnabled = false
        
        self.switchCameraIconNode = ASImageNode()
        self.switchCameraIconNode.displaysAsynchronously = false
        self.switchCameraIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallSwitchCameraButton"), color: .white)
        self.switchCameraIconNode.contentMode = .center
        
        super.init()
        
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        self.addSubnode(self.dimNode)
        
        self.wrappingScrollNode.view.delegate = self
        self.addSubnode(self.wrappingScrollNode)
                
        self.wrappingScrollNode.addSubnode(self.backgroundNode)
        self.wrappingScrollNode.addSubnode(self.contentContainerNode)
        
        self.backgroundNode.addSubnode(self.effectNode)
        self.backgroundNode.addSubnode(self.contentBackgroundNode)
        self.contentContainerNode.addSubnode(self.titleNode)
        self.contentContainerNode.addSubnode(self.cameraButton)
        self.contentContainerNode.addSubnode(self.screenButton)
        if let broadcastPickerView = self.broadcastPickerView {
            self.contentContainerNode.view.addSubview(broadcastPickerView)
        }
        self.contentContainerNode.addSubnode(self.cancelButton)
        
        self.contentContainerNode.addSubnode(self.previewContainerNode)
        
        self.previewContainerNode.addSubnode(self.cameraNode)
        self.previewContainerNode.addSubnode(self.switchCameraButton)
        self.switchCameraButton.view.addSubview(self.switchCameraEffectView)
        self.switchCameraButton.addSubnode(self.switchCameraIconNode)
        
        self.cameraButton.pressed = { [weak self] in
            if let strongSelf = self {
                strongSelf.shareCamera?()
            }
        }
        self.cancelButton.pressed = { [weak self] in
            if let strongSelf = self {
                strongSelf.cancel?()
            }
        }
        
        self.switchCameraButton.addTarget(self, action: #selector(self.switchCameraPressed), forControlEvents: .touchUpInside)
        self.switchCameraButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .spring)
                    transition.updateSublayerTransformScale(node: strongSelf.switchCameraButton, scale: 0.9)
                } else {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.5, curve: .spring)
                    transition.updateSublayerTransformScale(node: strongSelf.switchCameraButton, scale: 1.0)
                }
            }
        }
    }
    
    @objc private func switchCameraPressed() {
        self.switchCamera?()
    }
        
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
    }
    
    override func didLoad() {
        super.didLoad()
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.wrappingScrollNode.view.contentInsetAdjustmentBehavior = .never
        }
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
    
    func animateIn() {
        self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
        
        let offset = self.bounds.size.height - self.contentBackgroundNode.frame.minY
        let dimPosition = self.dimNode.layer.position
        
        let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
        let targetBounds = self.bounds
        self.bounds = self.bounds.offsetBy(dx: 0.0, dy: -offset)
        self.dimNode.position = CGPoint(x: dimPosition.x, y: dimPosition.y - offset)
        transition.animateView({
            self.bounds = targetBounds
            self.dimNode.position = dimPosition
        })

        self.applicationStateDisposable = (self.context.sharedContext.applicationBindings.applicationIsActive
        |> filter { !$0 }
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controller?.dismiss()
        })
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
            self.cancel?()
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.statusBar, .input])
        let cleanInsets = layout.insets(options: [.statusBar])
        insets.top = max(10.0, insets.top)
        
        let buttonOffset: CGFloat = 120.0

        let bottomInset: CGFloat = 10.0 + cleanInsets.bottom
        let titleHeight: CGFloat = 54.0
        var contentHeight = titleHeight + bottomInset + 52.0 + 17.0
        let innerContentHeight: CGFloat = layout.size.height - contentHeight - 160.0
        contentHeight = titleHeight + bottomInset + 52.0 + 17.0 + innerContentHeight + buttonOffset
        
        let width = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: layout.safeInsets.left)
        
        let previewInset: CGFloat = 16.0
        let sideInset = floor((layout.size.width - width) / 2.0)
        let contentContainerFrame = CGRect(origin: CGPoint(x: sideInset, y: layout.size.height - contentHeight), size: CGSize(width: width, height: contentHeight))
        let contentFrame = contentContainerFrame
        
        var backgroundFrame = CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY), size: CGSize(width: contentFrame.width, height: contentFrame.height + 2000.0))
        if backgroundFrame.minY < contentFrame.minY {
            backgroundFrame.origin.y = contentFrame.minY
        }
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        transition.updateFrame(node: self.effectNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        transition.updateFrame(node: self.contentBackgroundNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        transition.updateFrame(node: self.wrappingScrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let titleSize = self.titleNode.measure(CGSize(width: width, height: titleHeight))
        let titleFrame = CGRect(origin: CGPoint(x: floor((contentFrame.width - titleSize.width) / 2.0), y: 18.0), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        
        let previewSize = CGSize(width: contentFrame.width - previewInset * 2.0, height: contentHeight - 243.0 - bottomInset)
        transition.updateFrame(node: self.previewContainerNode, frame: CGRect(origin: CGPoint(x: previewInset, y: 56.0), size: previewSize))
        
        self.cameraNode.frame =  CGRect(origin: CGPoint(), size: previewSize)
        self.cameraNode.updateLayout(size: previewSize, isLandscape: false, transition: .immediate)
        
        let switchCameraFrame = CGRect(x: previewSize.width - 48.0 - 16.0, y: previewSize.height - 48.0 - 16.0, width: 48.0, height: 48.0)
        transition.updateFrame(node: self.switchCameraButton, frame: switchCameraFrame)
        transition.updateFrame(view: self.switchCameraEffectView, frame: CGRect(origin: CGPoint(), size: switchCameraFrame.size))
        transition.updateFrame(node: self.switchCameraIconNode, frame: CGRect(origin: CGPoint(), size: switchCameraFrame.size))
        
        let buttonInset: CGFloat = 16.0
        let cameraButtonHeight = self.cameraButton.updateLayout(width: contentFrame.width - buttonInset * 2.0, transition: transition)
        transition.updateFrame(node: self.cameraButton, frame: CGRect(x: buttonInset, y: contentHeight - cameraButtonHeight - insets.bottom - 16.0 - buttonOffset, width: contentFrame.width, height: cameraButtonHeight))
        
        let screenButtonHeight = self.screenButton.updateLayout(width: contentFrame.width - buttonInset * 2.0, transition: transition)
        transition.updateFrame(node: self.screenButton, frame: CGRect(x: buttonInset, y: contentHeight - cameraButtonHeight - 8.0 - screenButtonHeight - insets.bottom - 16.0, width: contentFrame.width, height: screenButtonHeight))
        if let broadcastPickerView = self.broadcastPickerView {
            broadcastPickerView.frame = CGRect(x: buttonInset, y: contentHeight - cameraButtonHeight - 8.0 - screenButtonHeight - insets.bottom - 16.0, width: contentFrame.width + 1000.0, height: screenButtonHeight)
        }
       
        let cancelButtonHeight = self.cancelButton.updateLayout(width: contentFrame.width - buttonInset * 2.0, transition: transition)
        transition.updateFrame(node: self.cancelButton, frame: CGRect(x: buttonInset, y: contentHeight - cancelButtonHeight - insets.bottom - 16.0, width: contentFrame.width, height: cancelButtonHeight))
        
        transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)
    }
}
