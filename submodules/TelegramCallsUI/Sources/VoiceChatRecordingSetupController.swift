import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import SolidRoundedButtonNode
import PresentationDataUtils

private let accentColor: UIColor = UIColor(rgb: 0x007aff)

final class VoiceChatRecordingSetupController: ViewController {
    private var controllerNode: VoiceChatRecordingSetupControllerNode {
        return self.displayNode as! VoiceChatRecordingSetupControllerNode
    }
    
    private let context: AccountContext
    private let peer: Peer
    private let completion: (Bool?) -> Void
    
    private var animatedIn = false
    
    private var presentationDataDisposable: Disposable?
    
    init(context: AccountContext, peer: Peer, completion: @escaping (Bool?) -> Void) {
        self.context = context
        self.peer = peer
        self.completion = completion
        
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
        self.displayNode = VoiceChatRecordingSetupControllerNode(controller: self, context: self.context, peer: self.peer)
        self.controllerNode.completion = { [weak self] videoOrientation in
            self?.completion(videoOrientation)
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
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}

private class VoiceChatRecordingSetupControllerNode: ViewControllerTracingNode, UIScrollViewDelegate {
    enum MediaMode {
        case videoAndAudio
        case audioOnly
    }
    
    enum VideoMode {
        case portrait
        case landscape
    }
    
    private weak var controller: VoiceChatRecordingSetupController?
    private let context: AccountContext
    private var presentationData: PresentationData
    
    private let dimNode: ASDisplayNode
    private let wrappingScrollNode: ASScrollNode
    private let contentContainerNode: ASDisplayNode
    private let effectNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let contentBackgroundNode: ASDisplayNode
    private let titleNode: ASTextNode
    private let doneButton: VoiceChatActionButton
    private let cancelButton: SolidRoundedButtonNode
    private let modeContainerNode: ASDisplayNode
    
    private let modeSeparatorNode: ASDisplayNode
    private let videoAudioButton: HighlightTrackingButtonNode
    private let videoAudioTitleNode: ImmediateTextNode
    private let videoAudioCheckNode: ASImageNode

    private let audioButton: HighlightTrackingButtonNode
    private let audioTitleNode: ImmediateTextNode
    private let audioCheckNode: ASImageNode
    
    private let portraitButton: HighlightTrackingButtonNode
    private let portraitIconNode: PreviewIconNode
    private let portraitTitleNode: ImmediateTextNode
    
    private let landscapeButton: HighlightTrackingButtonNode
    private let landscapeIconNode: PreviewIconNode
    private let landscapeTitleNode: ImmediateTextNode
    
    private let selectionNode: ASImageNode
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private let hapticFeedback = HapticFeedback()
    
    private let readyDisposable = MetaDisposable()
    
    private var mediaMode: MediaMode = .videoAndAudio
    private var videoMode: VideoMode = .portrait
    
    var completion: ((Bool?) -> Void)?
    var dismiss: (() -> Void)?
    var cancel: (() -> Void)?
    
    init(controller: VoiceChatRecordingSetupController, context: AccountContext, peer: Peer) {
        self.controller = controller
        self.context = context
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
        
        let isLivestream: Bool
        if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
            isLivestream = true
        } else {
            isLivestream = false
        }
        
        let title = isLivestream ? self.presentationData.strings.LiveStream_RecordTitle : self.presentationData.strings.VoiceChat_RecordTitle
        
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.bold(17.0), textColor: textColor)
                
        self.doneButton = VoiceChatActionButton()
        
        self.cancelButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(backgroundColor: buttonColor, foregroundColor: buttonTextColor), font: .regular, height: 52.0, cornerRadius: 11.0, gloss: false)
        self.cancelButton.title = self.presentationData.strings.Common_Cancel
        
        self.modeContainerNode = ASDisplayNode()
        self.modeContainerNode.clipsToBounds = true
        self.modeContainerNode.cornerRadius = 11.0
        self.modeContainerNode.backgroundColor = UIColor(rgb: 0x303032)
        
        self.modeSeparatorNode = ASDisplayNode()
        self.modeSeparatorNode.backgroundColor = UIColor(rgb: 0x404041)
        
        self.videoAudioButton = HighlightTrackingButtonNode()
        self.videoAudioTitleNode = ImmediateTextNode()
        self.videoAudioTitleNode.attributedText = NSAttributedString(string: self.presentationData.strings.VoiceChat_RecordVideoAndAudio, font: Font.regular(17.0), textColor: .white, paragraphAlignment: .left)
        self.videoAudioCheckNode = ASImageNode()
        self.videoAudioCheckNode.displaysAsynchronously = false
        self.videoAudioCheckNode.image = UIImage(bundleImageName: "Call/Check")
        
        self.audioButton = HighlightTrackingButtonNode()
        self.audioTitleNode = ImmediateTextNode()
        self.audioTitleNode.attributedText = NSAttributedString(string: self.presentationData.strings.VoiceChat_RecordOnlyAudio, font: Font.regular(17.0), textColor: .white, paragraphAlignment: .left)
        self.audioCheckNode = ASImageNode()
        self.audioCheckNode.displaysAsynchronously = false
        self.audioCheckNode.image = UIImage(bundleImageName: "Call/Check")
        
        self.portraitButton = HighlightTrackingButtonNode()
        self.portraitButton.backgroundColor = UIColor(rgb: 0x303032)
        self.portraitButton.cornerRadius = 11.0
        self.portraitIconNode = PreviewIconNode()
        self.portraitTitleNode = ImmediateTextNode()
        self.portraitTitleNode.attributedText = NSAttributedString(string: self.presentationData.strings.VoiceChat_RecordPortrait, font: Font.semibold(15.0), textColor: UIColor(rgb: 0x8e8e93), paragraphAlignment: .left)
        
        self.landscapeButton = HighlightTrackingButtonNode()
        self.landscapeButton.backgroundColor = UIColor(rgb: 0x303032)
        self.landscapeButton.cornerRadius = 11.0
        self.landscapeIconNode = PreviewIconNode()
        self.landscapeTitleNode = ImmediateTextNode()
        self.landscapeTitleNode.attributedText = NSAttributedString(string: self.presentationData.strings.VoiceChat_RecordLandscape, font: Font.semibold(15.0), textColor: UIColor(rgb: 0x8e8e93), paragraphAlignment: .left)
        
        self.selectionNode = ASImageNode()
        self.selectionNode.displaysAsynchronously = false
        self.selectionNode.image = generateImage(CGSize(width: 174.0, height: 140.0), rotatedContext: { size, context in
            let bounds = CGRect(origin: CGPoint(), size: size)
            context.clear(bounds)   
            
            let lineWidth: CGFloat = 2.0
            
            let path = UIBezierPath(roundedRect: bounds.insetBy(dx: lineWidth / 2.0, dy: lineWidth / 2.0), cornerRadius: 11.0)
            let cgPath = path.cgPath.copy(strokingWithWidth: lineWidth, lineCap: .round, lineJoin: .round, miterLimit: 10.0)
            context.addPath(cgPath)
            context.clip()
            
            let colors: [CGColor] = [UIColor(rgb: 0x5064fd).cgColor, UIColor(rgb: 0xe76598).cgColor]
            var locations: [CGFloat] = [0.0, 1.0]
            let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colors as CFArray, locations: &locations)!
            
            context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: size.width, y: 0.0), options: CGGradientDrawingOptions())
        })
        self.selectionNode.isUserInteractionEnabled = false
        
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
        self.contentContainerNode.addSubnode(self.doneButton)
        self.contentContainerNode.addSubnode(self.cancelButton)
        self.contentContainerNode.addSubnode(self.modeContainerNode)
        
        self.contentContainerNode.addSubnode(self.videoAudioTitleNode)
        self.contentContainerNode.addSubnode(self.videoAudioCheckNode)
        self.contentContainerNode.addSubnode(self.videoAudioButton)
        
        self.contentContainerNode.addSubnode(self.modeSeparatorNode)
        
        self.contentContainerNode.addSubnode(self.audioTitleNode)
        self.contentContainerNode.addSubnode(self.audioCheckNode)
        self.contentContainerNode.addSubnode(self.audioButton)
        
        self.contentContainerNode.addSubnode(self.portraitButton)
        self.contentContainerNode.addSubnode(self.portraitIconNode)
        self.contentContainerNode.addSubnode(self.portraitTitleNode)
        
        self.contentContainerNode.addSubnode(self.landscapeButton)
        self.contentContainerNode.addSubnode(self.landscapeIconNode)
        self.contentContainerNode.addSubnode(self.landscapeTitleNode)
        
        self.contentContainerNode.addSubnode(self.selectionNode)
        
        self.videoAudioButton.addTarget(self, action: #selector(self.videoAudioPressed), forControlEvents: .touchUpInside)
        self.audioButton.addTarget(self, action: #selector(self.audioPressed), forControlEvents: .touchUpInside)
        
        self.portraitButton.addTarget(self, action: #selector(self.portraitPressed), forControlEvents: .touchUpInside)
        self.landscapeButton.addTarget(self, action: #selector(self.landscapePressed), forControlEvents: .touchUpInside)
        
        self.doneButton.addTarget(self, action: #selector(self.donePressed), forControlEvents: .touchUpInside)
        
        self.cancelButton.pressed = { [weak self] in
            if let strongSelf = self {
                strongSelf.cancel?()
            }
        }
    }
    
    @objc private func donePressed() {
        let videoOrientation: Bool?
        switch self.mediaMode {
        case .audioOnly:
            videoOrientation = nil
        case .videoAndAudio:
            switch self.videoMode {
            case .portrait:
                videoOrientation = true
            case .landscape:
                videoOrientation = false
            }
        }
        self.completion?(videoOrientation)
        self.dismiss?()
    }
    
    @objc private func videoAudioPressed() {
        self.mediaMode = .videoAndAudio
        
        if let (layout, navigationHeight) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .animated(duration: 0.2, curve: .easeInOut))
        }
    }
    
    @objc private func audioPressed() {
        self.mediaMode = .audioOnly
        
        if let (layout, navigationHeight) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .animated(duration: 0.2, curve: .easeInOut))
        }
    }
    
    @objc private func portraitPressed() {
        self.mediaMode = .videoAndAudio
        self.videoMode = .portrait
        
        if let (layout, navigationHeight) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .animated(duration: 0.2, curve: .easeInOut))
        }
    }
    
    @objc private func landscapePressed() {
        self.mediaMode = .videoAndAudio
        self.videoMode = .landscape
        
        if let (layout, navigationHeight) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .animated(duration: 0.2, curve: .easeInOut))
        }
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
        
        let isLandscape: Bool
        if layout.size.width > layout.size.height, case .compact = layout.metrics.widthClass {
            isLandscape = true
        } else {
            isLandscape = false
        }
        
     
        var insets = layout.insets(options: [.statusBar, .input])
        let cleanInsets = layout.insets(options: [.statusBar])
        insets.top = max(10.0, insets.top)
        
        let buttonOffset: CGFloat = 60.0

        let bottomInset: CGFloat = 10.0 + cleanInsets.bottom
        let titleHeight: CGFloat = 54.0
        var contentHeight = titleHeight + bottomInset + 52.0 + 17.0
        let innerContentHeight: CGFloat = 287.0
        var width = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: 0.0)
        if isLandscape {
            contentHeight = layout.size.height
            width = layout.size.width
        } else {
            contentHeight = titleHeight + bottomInset + 52.0 + 17.0 + innerContentHeight + buttonOffset
        }
        
        let inset: CGFloat = 16.0
        let sideInset = floor((layout.size.width - width) / 2.0)
        let contentContainerFrame = CGRect(origin: CGPoint(x: sideInset, y: layout.size.height - contentHeight), size: CGSize(width: width, height: contentHeight))
        let contentFrame = contentContainerFrame
                
        var backgroundFrame = CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY), size: CGSize(width: contentFrame.width, height: contentFrame.height + 2000.0))
        if backgroundFrame.minY < contentFrame.minY {
            backgroundFrame.origin.y = contentFrame.minY
        }
        transition.updateAlpha(node: self.titleNode, alpha: isLandscape ? 0.0 : 1.0)
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        transition.updateFrame(node: self.effectNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        transition.updateFrame(node: self.contentBackgroundNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        transition.updateFrame(node: self.wrappingScrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let titleSize = self.titleNode.measure(CGSize(width: width, height: titleHeight))
        let titleFrame = CGRect(origin: CGPoint(x: floor((contentFrame.width - titleSize.width) / 2.0), y: 18.0), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        
        let itemHeight: CGFloat = 44.0
        
        transition.updateFrame(node: self.modeContainerNode, frame: CGRect(x: inset, y: 56.0, width: contentFrame.width - inset * 2.0, height: itemHeight * 2.0))
        
        transition.updateFrame(node: self.videoAudioButton, frame: CGRect(x: inset, y: 56.0, width: contentFrame.width - inset * 2.0, height: itemHeight))
        transition.updateFrame(node: self.videoAudioCheckNode, frame: CGRect(x: contentFrame.width - inset - 16.0 - 20.0, y: 56.0 + floorToScreenPixels((itemHeight - 16.0) / 2.0), width: 16.0, height: 16.0))
        self.videoAudioCheckNode.isHidden = self.mediaMode != .videoAndAudio
        
        let videoAudioSize = self.videoAudioTitleNode.updateLayout(CGSize(width: contentFrame.width - inset * 2.0, height: itemHeight))
        transition.updateFrame(node: self.videoAudioTitleNode, frame: CGRect(x: inset + 16.0, y: 56.0 + floorToScreenPixels((itemHeight - videoAudioSize.height) / 2.0), width: videoAudioSize.width, height: videoAudioSize.height))
        
        transition.updateFrame(node: self.audioButton, frame: CGRect(x: inset, y: 56.0 + itemHeight, width: contentFrame.width - inset * 2.0, height: itemHeight))
        transition.updateFrame(node: self.audioCheckNode, frame: CGRect(x: contentFrame.width - inset - 16.0 - 20.0, y: 56.0 + itemHeight + floorToScreenPixels((itemHeight - 16.0) / 2.0), width: 16.0, height: 16.0))
        self.audioCheckNode.isHidden = self.mediaMode != .audioOnly
        
        let audioSize = self.audioTitleNode.updateLayout(CGSize(width: contentFrame.width - inset * 2.0, height: itemHeight))
        transition.updateFrame(node: self.audioTitleNode, frame: CGRect(x: inset + 16.0, y: 56.0 + itemHeight + floorToScreenPixels((itemHeight - audioSize.height) / 2.0), width: audioSize.width, height: audioSize.height))
        
        transition.updateFrame(node: self.modeSeparatorNode, frame: CGRect(x: inset + 16.0, y: 56.0 + itemHeight, width: contentFrame.width - inset * 2.0 - 16.0, height: UIScreenPixel))
        
        var buttonsAlpha: CGFloat = 1.0
        if case .audioOnly = self.mediaMode {
            buttonsAlpha = 0.3
        }
        
        transition.updateAlpha(node: self.portraitButton, alpha: buttonsAlpha)
        transition.updateAlpha(node: self.portraitIconNode, alpha: buttonsAlpha)
        transition.updateAlpha(node: self.portraitTitleNode, alpha: buttonsAlpha)
        
        transition.updateAlpha(node: self.landscapeButton, alpha: buttonsAlpha)
        transition.updateAlpha(node: self.landscapeIconNode, alpha: buttonsAlpha)
        transition.updateAlpha(node: self.landscapeTitleNode, alpha: buttonsAlpha)
        
        transition.updateAlpha(node: self.selectionNode, alpha: buttonsAlpha)
        
        self.portraitTitleNode.attributedText = NSAttributedString(string: self.presentationData.strings.VoiceChat_RecordPortrait, font: Font.semibold(15.0), textColor: self.videoMode == .portrait ? UIColor(rgb: 0xb56df4) : UIColor(rgb: 0x8e8e93), paragraphAlignment: .left)
        self.landscapeTitleNode.attributedText = NSAttributedString(string: self.presentationData.strings.VoiceChat_RecordLandscape, font: Font.semibold(15.0), textColor: self.videoMode == .landscape ? UIColor(rgb: 0xb56df4) : UIColor(rgb: 0x8e8e93), paragraphAlignment: .left)
        
        let buttonWidth = floorToScreenPixels((contentFrame.width - inset * 2.0 - 11.0) / 2.0)
        let portraitButtonFrame = CGRect(x: inset, y: 56.0 + itemHeight * 2.0 + 25.0, width: buttonWidth, height: 140.0)
        transition.updateFrame(node: self.portraitButton, frame: portraitButtonFrame)
        transition.updateFrame(node: self.portraitIconNode, frame: CGRect(x: portraitButtonFrame.minX + floorToScreenPixels((portraitButtonFrame.width - 72.0) / 2.0), y: portraitButtonFrame.minY + floorToScreenPixels((portraitButtonFrame.height - 122.0) / 2.0), width: 76.0, height: 122.0))
        self.portraitIconNode.updateLayout(landscape: false)
        let portraitSize = self.portraitTitleNode.updateLayout(CGSize(width: buttonWidth, height: 30.0))
        transition.updateFrame(node: self.portraitTitleNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels(portraitButtonFrame.center.x - portraitSize.width / 2.0), y: portraitButtonFrame.maxY + 7.0), size: portraitSize))
                
        let landscapeButtonFrame = CGRect(x: portraitButtonFrame.maxX + 11.0, y: portraitButtonFrame.minY, width: portraitButtonFrame.width, height: portraitButtonFrame.height)
        transition.updateFrame(node: self.landscapeButton, frame: landscapeButtonFrame)
        transition.updateFrame(node: self.landscapeIconNode, frame: CGRect(x: landscapeButtonFrame.minX + floorToScreenPixels((landscapeButtonFrame.width - 122.0) / 2.0), y: landscapeButtonFrame.minY + floorToScreenPixels((landscapeButtonFrame.height - 76.0) / 2.0), width: 122.0, height: 76.0))
        self.landscapeIconNode.updateLayout(landscape: true)
        let landscapeSize = self.landscapeTitleNode.updateLayout(CGSize(width: buttonWidth, height: 30.0))
        transition.updateFrame(node: self.landscapeTitleNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels(landscapeButtonFrame.center.x - landscapeSize.width / 2.0), y: landscapeButtonFrame.maxY + 7.0), size: landscapeSize))
        
        let centralButtonSide = min(contentFrame.width, layout.size.height) - 32.0
        let centralButtonSize = CGSize(width: centralButtonSide, height: centralButtonSide)
        
        let buttonInset: CGFloat = 16.0
        let doneButtonPreFrame = CGRect(x: buttonInset, y: contentHeight - 50.0 - insets.bottom - 16.0 - buttonOffset, width: contentFrame.width - buttonInset * 2.0, height: 50.0)
        let doneButtonFrame = CGRect(origin: CGPoint(x: floor(doneButtonPreFrame.midX - centralButtonSize.width / 2.0), y: floor(doneButtonPreFrame.midY - centralButtonSize.height / 2.0)), size: centralButtonSize)
        transition.updateFrame(node: self.doneButton, frame: doneButtonFrame)
        
        if self.videoMode == .portrait {
            self.selectionNode.frame = portraitButtonFrame.insetBy(dx: -1.0, dy: -1.0)
        } else {
            self.selectionNode.frame = landscapeButtonFrame.insetBy(dx: -1.0, dy: -1.0)
        }
                   
        self.doneButton.update(size: centralButtonSize, buttonSize: CGSize(width: 112.0, height: 112.0), state: .button(text: self.presentationData.strings.VoiceChat_RecordStartRecording), title: "", subtitle: "", dark: false, small: false)
        
        let cancelButtonHeight = self.cancelButton.updateLayout(width: contentFrame.width - buttonInset * 2.0, transition: transition)
        transition.updateFrame(node: self.cancelButton, frame: CGRect(x: buttonInset, y: contentHeight - cancelButtonHeight - insets.bottom - 16.0, width: contentFrame.width, height: cancelButtonHeight))
        
        transition.updateFrame(node: self.contentContainerNode, frame: contentContainerFrame)
    }
}

private class PreviewIconNode: ASDisplayNode {
    private let avatar1Node: ASImageNode
    private let avatar2Node: ASImageNode
    private let avatar3Node: ASImageNode
    private let avatar4Node: ASImageNode
    
    override init() {
        self.avatar1Node = ASImageNode()
        self.avatar1Node.cornerRadius = 4.0
        self.avatar1Node.clipsToBounds = true
        self.avatar1Node.displaysAsynchronously = false
        self.avatar1Node.backgroundColor = UIColor(rgb: 0x834fff)
        self.avatar1Node.image = UIImage(bundleImageName: "Call/Avatar1")
        self.avatar1Node.contentMode = .bottom
        
        self.avatar2Node = ASImageNode()
        self.avatar2Node.cornerRadius = 4.0
        self.avatar2Node.clipsToBounds = true
        self.avatar2Node.displaysAsynchronously = false
        self.avatar2Node.backgroundColor = UIColor(rgb: 0x63d5c9)
        self.avatar2Node.image = UIImage(bundleImageName: "Call/Avatar2")
        self.avatar2Node.contentMode = .scaleAspectFit
        
        self.avatar3Node = ASImageNode()
        self.avatar3Node.cornerRadius = 4.0
        self.avatar3Node.clipsToBounds = true
        self.avatar3Node.displaysAsynchronously = false
        self.avatar3Node.backgroundColor = UIColor(rgb: 0xccff60)
        self.avatar3Node.image = UIImage(bundleImageName: "Call/Avatar3")
        self.avatar3Node.contentMode = .scaleAspectFit
        
        self.avatar4Node = ASImageNode()
        self.avatar4Node.cornerRadius = 4.0
        self.avatar4Node.clipsToBounds = true
        self.avatar4Node.displaysAsynchronously = false
        self.avatar4Node.backgroundColor = UIColor(rgb: 0xf5512a)
        self.avatar4Node.image = UIImage(bundleImageName: "Call/Avatar4")
        self.avatar4Node.contentMode = .scaleAspectFit
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.avatar1Node)
        self.addSubnode(self.avatar2Node)
        self.addSubnode(self.avatar3Node)
        self.addSubnode(self.avatar4Node)
    }
    
    func updateLayout(landscape: Bool) {
        if landscape {
            self.avatar1Node.frame = CGRect(x: 0.0, y: 0.0, width: 96.0, height: 76.0)
            self.avatar2Node.frame = CGRect(x: 98.0, y: 0.0, width: 24.0, height: 24.0)
            self.avatar3Node.frame = CGRect(x: 98.0, y: 26.0, width: 24.0, height: 24.0)
            self.avatar4Node.frame = CGRect(x: 98.0, y: 52.0, width: 24.0, height: 24.0)
        } else {
            self.avatar1Node.frame = CGRect(x: 0.0, y: 0.0, width: 76.0, height: 96.0)
            self.avatar2Node.frame = CGRect(x: 0.0, y: 98.0, width: 24.0, height: 24.0)
            self.avatar3Node.frame = CGRect(x: 26.0, y: 98.0, width: 24.0, height: 24.0)
            self.avatar4Node.frame = CGRect(x: 52.0, y: 98.0, width: 24.0, height: 24.0)
        }
    }
}
