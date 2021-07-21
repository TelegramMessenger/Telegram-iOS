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
import UIKitRuntimeUtils
import ReplayKit

private let accentColor: UIColor = UIColor(rgb: 0x007aff)

protocol PreviewVideoNode: ASDisplayNode {
    var ready: Signal<Bool, NoError> { get }
    
    func flip(withBackground: Bool)
    func updateIsBlurred(isBlurred: Bool, light: Bool, animated: Bool)
    
    func updateLayout(size: CGSize, layoutMode: VideoNodeLayoutMode, transition: ContainedViewLayoutTransition)
}

final class VoiceChatCameraPreviewController: ViewController {
    private var controllerNode: VoiceChatCameraPreviewControllerNode {
        return self.displayNode as! VoiceChatCameraPreviewControllerNode
    }
    
    private let sharedContext: SharedAccountContext
    
    private var animatedIn = false

    private let cameraNode: PreviewVideoNode
    private let shareCamera: (ASDisplayNode, Bool) -> Void
    private let switchCamera: () -> Void
    
    private var presentationDataDisposable: Disposable?
    
    init(sharedContext: SharedAccountContext, cameraNode: PreviewVideoNode, shareCamera: @escaping (ASDisplayNode, Bool) -> Void, switchCamera: @escaping () -> Void) {
        self.sharedContext = sharedContext
        self.cameraNode = cameraNode
        self.shareCamera = shareCamera
        self.switchCamera = switchCamera
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        
        self.blocksBackgroundWhenInOverlay = true
        
        self.presentationDataDisposable = (sharedContext.presentationData
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
        self.displayNode = VoiceChatCameraPreviewControllerNode(controller: self, sharedContext: self.sharedContext, cameraNode: self.cameraNode)
        self.controllerNode.shareCamera = { [weak self] unmuted in
            if let strongSelf = self {
                strongSelf.shareCamera(strongSelf.cameraNode, unmuted)
                strongSelf.dismiss()
            }
        }
        self.controllerNode.switchCamera = { [weak self] in
            self?.switchCamera()
            self?.cameraNode.flip(withBackground: false)
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

private class VoiceChatCameraPreviewControllerNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private weak var controller: VoiceChatCameraPreviewController?
    private let sharedContext: SharedAccountContext
    private var presentationData: PresentationData
    
    private let cameraNode: PreviewVideoNode
    private let dimNode: ASDisplayNode
    private let wrappingScrollNode: ASScrollNode
    private let contentContainerNode: ASDisplayNode
    private let effectNode: ASDisplayNode
    private let backgroundNode: ASDisplayNode
    private let contentBackgroundNode: ASDisplayNode
    private let titleNode: ASTextNode
    private let previewContainerNode: ASDisplayNode
    private let shimmerNode: ShimmerEffectForegroundNode
    private let doneButton: SolidRoundedButtonNode
    private var broadcastPickerView: UIView?
    private let cancelButton: SolidRoundedButtonNode
    
    private let microphoneButton: HighlightTrackingButtonNode
    private let microphoneEffectView: UIVisualEffectView
    private let microphoneIconNode: VoiceChatMicrophoneNode
        
    private let placeholderTextNode: ImmediateTextNode
    private let placeholderIconNode: ASImageNode
    
    private let tabsNode: TabsSegmentedControlNode
    private var selectedTabIndex: Int = 0
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?

    private var applicationStateDisposable: Disposable?
    
    private let hapticFeedback = HapticFeedback()
    
    private let readyDisposable = MetaDisposable()
    
    var shareCamera: ((Bool) -> Void)?
    var switchCamera: (() -> Void)?
    var dismiss: (() -> Void)?
    var cancel: (() -> Void)?
    
    init(controller: VoiceChatCameraPreviewController, sharedContext: SharedAccountContext, cameraNode: PreviewVideoNode) {
        self.controller = controller
        self.sharedContext = sharedContext
        self.presentationData = sharedContext.currentPresentationData.with { $0 }
        
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
                
        self.doneButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(backgroundColor: accentColor, foregroundColor: .white), font: .bold, height: 52.0, cornerRadius: 11.0, gloss: false)
        self.doneButton.title = self.presentationData.strings.VoiceChat_VideoPreviewContinue
        
        if #available(iOS 12.0, *) {
            let broadcastPickerView = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 50, height: 52.0))
            broadcastPickerView.alpha = 0.02
            broadcastPickerView.isHidden = true
            broadcastPickerView.preferredExtension = "\(self.sharedContext.applicationBindings.appBundleId).BroadcastUpload"
            broadcastPickerView.showsMicrophoneButton = false
            self.broadcastPickerView = broadcastPickerView
        }
        
        self.cancelButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(backgroundColor: buttonColor, foregroundColor: buttonTextColor), font: .regular, height: 52.0, cornerRadius: 11.0, gloss: false)
        self.cancelButton.title = self.presentationData.strings.Common_Cancel
        
        self.previewContainerNode = ASDisplayNode()
        self.previewContainerNode.clipsToBounds = true
        self.previewContainerNode.cornerRadius = 11.0
        self.previewContainerNode.backgroundColor = UIColor(rgb: 0x2b2b2f)
        
        self.shimmerNode = ShimmerEffectForegroundNode(size: 200.0)
        self.previewContainerNode.addSubnode(self.shimmerNode)
                
        self.microphoneButton = HighlightTrackingButtonNode()
        self.microphoneButton.isSelected = true
        self.microphoneEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        self.microphoneEffectView.clipsToBounds = true
        self.microphoneEffectView.layer.cornerRadius = 24.0
        self.microphoneEffectView.isUserInteractionEnabled = false
        
        self.microphoneIconNode = VoiceChatMicrophoneNode()
//        self.microphoneIconNode.alpha = 0.75
        self.microphoneIconNode.update(state: .init(muted: false, filled: true, color: .white), animated: false)
        
        self.tabsNode = TabsSegmentedControlNode(items: [TabsSegmentedControlNode.Item(title: "Front Camera"), TabsSegmentedControlNode.Item(title: "Back Camera"), TabsSegmentedControlNode.Item(title: "Share Screen")], selectedIndex: 0)
        
        self.placeholderTextNode = ImmediateTextNode()
        self.placeholderTextNode.alpha = 0.0
        self.placeholderTextNode.maximumNumberOfLines = 3
        self.placeholderTextNode.textAlignment = .center
        
        self.placeholderIconNode = ASImageNode()
        self.placeholderIconNode.alpha = 0.0
        self.placeholderIconNode.contentMode = .scaleAspectFit
        self.placeholderIconNode.displaysAsynchronously = false
        
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
        if let broadcastPickerView = self.broadcastPickerView {
            self.contentContainerNode.view.addSubview(broadcastPickerView)
        }
        self.contentContainerNode.addSubnode(self.cancelButton)
        
        self.contentContainerNode.addSubnode(self.previewContainerNode)
        
        self.previewContainerNode.addSubnode(self.cameraNode)
        
        self.previewContainerNode.addSubnode(self.placeholderIconNode)
        self.previewContainerNode.addSubnode(self.placeholderTextNode)
        
        if self.cameraNode is GroupVideoNode {
            self.previewContainerNode.addSubnode(self.microphoneButton)
            self.microphoneButton.view.addSubview(self.microphoneEffectView)
            self.microphoneButton.addSubnode(self.microphoneIconNode)
        }
        self.previewContainerNode.addSubnode(self.tabsNode)
        
        self.tabsNode.selectedIndexChanged = { [weak self] index in
            if let strongSelf = self {
                if (index == 0 && strongSelf.selectedTabIndex == 1) || (index == 1 && strongSelf.selectedTabIndex == 0) {
                    strongSelf.switchCamera?()
                }
                if index == 2 && [0, 1].contains(strongSelf.selectedTabIndex) {
                    strongSelf.broadcastPickerView?.isHidden = false
                    strongSelf.cameraNode.updateIsBlurred(isBlurred: true, light: false, animated: true)
                    let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .easeInOut)
                    transition.updateAlpha(node: strongSelf.placeholderTextNode, alpha: 1.0)
                    transition.updateAlpha(node: strongSelf.placeholderIconNode, alpha: 1.0)
                } else if [0, 1].contains(index) && strongSelf.selectedTabIndex == 2 {
                    strongSelf.broadcastPickerView?.isHidden = true
                    strongSelf.cameraNode.updateIsBlurred(isBlurred: false, light: false, animated: true)
                    let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .easeInOut)
                    transition.updateAlpha(node: strongSelf.placeholderTextNode, alpha: 0.0)
                    transition.updateAlpha(node: strongSelf.placeholderIconNode, alpha: 0.0)
                }
                strongSelf.selectedTabIndex = index
            }
        }
        
        self.doneButton.pressed = { [weak self] in
            if let strongSelf = self {
                strongSelf.shareCamera?(strongSelf.microphoneButton.isSelected)
            }
        }
        self.cancelButton.pressed = { [weak self] in
            if let strongSelf = self {
                strongSelf.cancel?()
            }
        }
        
        self.microphoneButton.addTarget(self, action: #selector(self.microphonePressed), forControlEvents: .touchUpInside)
        self.microphoneButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .spring)
                    transition.updateSublayerTransformScale(node: strongSelf.microphoneButton, scale: 0.9)
                } else {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.5, curve: .spring)
                    transition.updateSublayerTransformScale(node: strongSelf.microphoneButton, scale: 1.0)
                }
            }
        }
        
        self.readyDisposable.set(self.cameraNode.ready.start(next: { [weak self] ready in
            if let strongSelf = self, ready {
                Queue.mainQueue().after(0.07) {
                    strongSelf.shimmerNode.alpha = 0.0
                    strongSelf.shimmerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                }
            }
        }))
    }
    
    deinit {
        self.readyDisposable.dispose()
        self.applicationStateDisposable?.dispose()
    }
    
    @objc private func microphonePressed() {
        self.hapticFeedback.impact(.light)
        self.microphoneButton.isSelected = !self.microphoneButton.isSelected
        self.microphoneIconNode.update(state: .init(muted: !self.microphoneButton.isSelected, filled: true, color: .white), animated: true)
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

        self.applicationStateDisposable = (self.sharedContext.applicationBindings.applicationIsActive
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
        
        let isLandscape: Bool
        if layout.size.width > layout.size.height {
            isLandscape = true
        } else {
            isLandscape = false
        }
        let isTablet: Bool
        if case .regular = layout.metrics.widthClass {
            isTablet = true
        } else {
            isTablet = false
        }
        
        var insets = layout.insets(options: [.statusBar, .input])
        let cleanInsets = layout.insets(options: [.statusBar])
        insets.top = max(10.0, insets.top)
        
        var buttonOffset: CGFloat = 60.0
        let bottomInset: CGFloat = isTablet ? 31.0 : 10.0 + cleanInsets.bottom
        let titleHeight: CGFloat = 54.0
        var contentHeight = titleHeight + bottomInset + 52.0 + 17.0
        let innerContentHeight: CGFloat = layout.size.height - contentHeight - 160.0
        var width = horizontalContainerFillingSizeForLayout(layout: layout, sideInset: layout.safeInsets.left)
        if isLandscape {
            if isTablet {
                width = 870.0
                contentHeight = 690.0
            } else {
                contentHeight = layout.size.height
                width = layout.size.width
            }
        } else {
            if isTablet {
                width = 600.0
                contentHeight = 960.0
            } else {
                contentHeight = titleHeight + bottomInset + 52.0 + 17.0 + innerContentHeight + buttonOffset
            }
        }
        
        let previewInset: CGFloat = 16.0
        let sideInset = floor((layout.size.width - width) / 2.0)
        let contentFrame: CGRect
        if isTablet {
            contentFrame = CGRect(origin: CGPoint(x: sideInset, y: floor((layout.size.height - contentHeight) / 2.0)), size: CGSize(width: width, height: contentHeight))
        } else {
            contentFrame = CGRect(origin: CGPoint(x: sideInset, y: layout.size.height - contentHeight), size: CGSize(width: width, height: contentHeight))
        }
        var backgroundFrame = CGRect(origin: CGPoint(x: contentFrame.minX, y: contentFrame.minY), size: CGSize(width: contentFrame.width, height: contentFrame.height))
        if !isTablet {
            backgroundFrame.size.height += 2000.0
        }
        if backgroundFrame.minY < contentFrame.minY {
            backgroundFrame.origin.y = contentFrame.minY
        }
        transition.updateAlpha(node: self.titleNode, alpha: isLandscape && !isTablet ? 0.0 : 1.0)
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        transition.updateFrame(node: self.effectNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        transition.updateFrame(node: self.contentBackgroundNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        transition.updateFrame(node: self.wrappingScrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let titleSize = self.titleNode.measure(CGSize(width: width, height: titleHeight))
        let titleFrame = CGRect(origin: CGPoint(x: floor((contentFrame.width - titleSize.width) / 2.0), y: 18.0), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        
        var previewSize: CGSize
        var previewFrame: CGRect
        if isLandscape {
            let previewHeight = contentHeight - 21.0 - 52.0 - 10.0
            previewSize = CGSize(width: min(contentFrame.width - layout.safeInsets.left - layout.safeInsets.right, previewHeight * 1.7778), height: previewHeight)
            if isTablet {
                previewSize.width -= previewInset * 2.0
                previewSize.height -= 46.0
            }
            previewFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((contentFrame.width - previewSize.width) / 2.0), y: 0.0), size: previewSize)
            if isTablet {
                previewFrame.origin.y += 56.0
            }
        } else {
            previewSize = CGSize(width: contentFrame.width - previewInset * 2.0, height: contentHeight - 243.0 - bottomInset + (120.0 - buttonOffset))
            if isTablet {
                previewSize.height += 17.0
            }
            previewFrame = CGRect(origin: CGPoint(x: previewInset, y: 56.0), size: previewSize)
        }
        transition.updateFrame(node: self.previewContainerNode, frame: previewFrame)
        transition.updateFrame(node: self.shimmerNode, frame: CGRect(origin: CGPoint(), size: previewFrame.size))
        self.shimmerNode.update(foregroundColor: UIColor(rgb: 0xffffff, alpha: 0.07))
        self.shimmerNode.updateAbsoluteRect(previewFrame, within: layout.size)
        
        self.cameraNode.frame =  CGRect(origin: CGPoint(), size: previewSize)
        self.cameraNode.updateLayout(size: previewSize, layoutMode: isLandscape ? .fillHorizontal : .fillVertical, transition: .immediate)
        
        let microphoneFrame = CGRect(x: 8.0, y: previewSize.height - 48.0 - 8.0 - 48.0, width: 48.0, height: 48.0)
        transition.updateFrame(node: self.microphoneButton, frame: microphoneFrame)
        transition.updateFrame(view: self.microphoneEffectView, frame: CGRect(origin: CGPoint(), size: microphoneFrame.size))
        transition.updateFrameAsPositionAndBounds(node: self.microphoneIconNode, frame: CGRect(origin: CGPoint(x: 1.0, y: 0.0), size: microphoneFrame.size).insetBy(dx: 6.0, dy: 6.0))
        self.microphoneIconNode.transform = CATransform3DMakeScale(1.2, 1.2, 1.0)
        
        let tabsFrame = CGRect(x: 8.0, y: previewSize.height - 40.0 - 8.0, width: previewSize.width - 16.0, height: 40.0)
        self.tabsNode.updateLayout(size: tabsFrame.size, transition: transition)
        transition.updateFrame(node: self.tabsNode, frame: tabsFrame)
        
        self.placeholderTextNode.attributedText = NSAttributedString(string: presentationData.strings.VoiceChat_VideoPreviewShareScreenInfo, font: Font.semibold(14.0), textColor: .white)
        self.placeholderIconNode.image = generateTintedImage(image: UIImage(bundleImageName: isTablet ? "Call/ScreenShareTablet" : "Call/ScreenSharePhone"), color: .white)
        
        let placeholderTextSize = self.placeholderTextNode.updateLayout(CGSize(width: previewSize.width - 80.0, height: 100.0))
        transition.updateFrame(node: self.placeholderTextNode, frame: CGRect(origin: CGPoint(x: floor((previewSize.width - placeholderTextSize.width) / 2.0), y: floorToScreenPixels(previewSize.height / 2.0) + 10.0), size: placeholderTextSize))
        if let imageSize = self.placeholderIconNode.image?.size {
            transition.updateFrame(node: self.placeholderIconNode, frame: CGRect(origin: CGPoint(x: floor((previewSize.width - imageSize.width) / 2.0), y: floorToScreenPixels(previewSize.height / 2.0) - imageSize.height - 8.0), size: imageSize))
        }
        
        if isLandscape {
            var buttonsCount: Int = 2
            
            let buttonInset: CGFloat = 6.0
            var leftButtonInset = buttonInset
            let availableWidth: CGFloat
            if isTablet {
                availableWidth = contentFrame.width - layout.safeInsets.left - layout.safeInsets.right - previewInset * 2.0
                leftButtonInset += previewInset
            } else {
                availableWidth = contentFrame.width - layout.safeInsets.left - layout.safeInsets.right
            }
            let buttonWidth = floorToScreenPixels((availableWidth - CGFloat(buttonsCount + 1) * buttonInset) / CGFloat(buttonsCount))
            
            let cameraButtonHeight = self.doneButton.updateLayout(width: buttonWidth, transition: transition)
            let cancelButtonHeight = self.cancelButton.updateLayout(width: buttonWidth, transition: transition)
            
            transition.updateFrame(node: self.cancelButton, frame: CGRect(x: layout.safeInsets.left + leftButtonInset, y: previewFrame.maxY + 10.0, width: buttonWidth, height: cancelButtonHeight))
            transition.updateFrame(node: self.doneButton, frame: CGRect(x: layout.safeInsets.left + leftButtonInset + buttonWidth + buttonInset, y: previewFrame.maxY + 10.0, width: buttonWidth, height: cameraButtonHeight))
            self.broadcastPickerView?.frame = self.doneButton.frame
        } else {
            let bottomInset = isTablet ? 21.0 : insets.bottom + 16.0
            let buttonInset: CGFloat = 16.0
            let cameraButtonHeight = self.doneButton.updateLayout(width: contentFrame.width - buttonInset * 2.0, transition: transition)
            transition.updateFrame(node: self.doneButton, frame: CGRect(x: buttonInset, y: contentHeight - cameraButtonHeight - bottomInset - buttonOffset, width: contentFrame.width, height: cameraButtonHeight))
            self.broadcastPickerView?.frame = self.doneButton.frame

            let cancelButtonHeight = self.cancelButton.updateLayout(width: contentFrame.width - buttonInset * 2.0, transition: transition)
            transition.updateFrame(node: self.cancelButton, frame: CGRect(x: buttonInset, y: contentHeight - cancelButtonHeight - bottomInset, width: contentFrame.width, height: cancelButtonHeight))
        }
        
        transition.updateFrame(node: self.contentContainerNode, frame: contentFrame)
    }
}

private let textFont = Font.medium(14.0)

class TabsSegmentedControlNode: ASDisplayNode, UIGestureRecognizerDelegate {
    struct Item: Equatable {
        public let title: String
        
        public init(title: String) {
            self.title = title
        }
    }
    
    private var blurEffectView: UIVisualEffectView?
    private var vibrancyEffectView: UIVisualEffectView?
    
    private let selectionNode: ASDisplayNode
    private var itemNodes: [HighlightTrackingButtonNode]
    private var highlightedItemNodes: [HighlightTrackingButtonNode]
    
    private var validLayout: CGSize?

    private var _items: [Item]
    private var _selectedIndex: Int = 0
    
    public var selectedIndex: Int {
        get {
            return self._selectedIndex
        }
        set {
            guard newValue != self._selectedIndex else {
                return
            }
            self._selectedIndex = newValue
            if let size = self.validLayout {
                self.updateLayout(size: size, transition: .immediate)
            }
        }
    }
    
    public func setSelectedIndex(_ index: Int, animated: Bool) {
        guard index != self._selectedIndex else {
            return
        }
        self._selectedIndex = index
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .animated(duration: 0.2, curve: .easeInOut))
        }
    }
    
    public var selectedIndexChanged: (Int) -> Void = { _ in }
    
    private var gestureRecognizer: UIPanGestureRecognizer?
    private var gestureSelectedIndex: Int?
    
    public init(items: [Item], selectedIndex: Int) {
        self._items = items
        self._selectedIndex = selectedIndex
        
        self.selectionNode = ASDisplayNode()
        self.selectionNode.clipsToBounds = true
        self.selectionNode.backgroundColor = .black
        self.selectionNode.alpha = 0.75
        
        self.itemNodes = items.map { item in
            let itemNode = HighlightTrackingButtonNode()
            itemNode.contentEdgeInsets = UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 8.0)
            itemNode.imageNode.isHidden = true
            itemNode.titleNode.maximumNumberOfLines = 1
            itemNode.titleNode.truncationMode = .byTruncatingTail
            itemNode.titleNode.alpha = 0.75
            itemNode.accessibilityLabel = item.title
            itemNode.accessibilityTraits = [.button]
            itemNode.setTitle(item.title, with: textFont, with: .black, for: .normal)
            return itemNode
        }
        
        self.highlightedItemNodes = items.map { item in
            let itemNode = HighlightTrackingButtonNode()
            itemNode.isUserInteractionEnabled = false
            itemNode.isHidden = true
            itemNode.contentEdgeInsets = UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 8.0)
            itemNode.imageNode.isHidden = true
            itemNode.titleNode.maximumNumberOfLines = 1
            itemNode.titleNode.truncationMode = .byTruncatingTail
            itemNode.setTitle(item.title, with: textFont, with: .white, for: .normal)
            return itemNode
        }
        
        super.init()
        
        self.clipsToBounds = true
        if #available(iOS 13.0, *) {
            self.layer.cornerCurve = .continuous
            self.selectionNode.layer.cornerCurve = .continuous
        }
        
        self.setupButtons()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
       
        let gestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        gestureRecognizer.delegate = self
        self.view.addGestureRecognizer(gestureRecognizer)
        self.gestureRecognizer = gestureRecognizer
        
        let blurEffect = UIBlurEffect(style: .light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        self.blurEffectView = blurEffectView
        self.view.addSubview(blurEffectView)
        
        let vibrancyEffect: UIVibrancyEffect
        if #available(iOS 13.0, *) {
            vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect, style: .label)
        } else {
            vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
        }
        let vibrancyEffectView = UIVisualEffectView(effect: vibrancyEffect)
        self.vibrancyEffectView = vibrancyEffectView
        
        blurEffectView.contentView.addSubview(vibrancyEffectView)
        
        self.itemNodes.forEach(vibrancyEffectView.contentView.addSubnode(_:))
        vibrancyEffectView.contentView.addSubnode(self.selectionNode)
        
        self.highlightedItemNodes.forEach(self.addSubnode(_:))
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        let bounds = CGRect(origin: CGPoint(), size: size)
        
        self.cornerRadius = size.height / 2.0
        
        if let blurEffectView = self.blurEffectView {
            transition.updateFrame(view: blurEffectView, frame: bounds)
        }
        
        if let vibrancyEffectView = self.vibrancyEffectView {
            transition.updateFrame(view: vibrancyEffectView, frame: bounds)
        }
        
        let selectedIndex: Int
        if let gestureSelectedIndex = self.gestureSelectedIndex {
            selectedIndex = gestureSelectedIndex
        } else {
            selectedIndex = self.selectedIndex
        }
        
        if !self.itemNodes.isEmpty {
            let itemSize = CGSize(width: floorToScreenPixels(size.width / CGFloat(self.itemNodes.count)), height: size.height)
            
            let selectionFrame = CGRect(origin: CGPoint(x: itemSize.width * CGFloat(selectedIndex), y: 0.0), size: itemSize).insetBy(dx: 4.0, dy: 4.0)
            transition.updateFrameAsPositionAndBounds(node: self.selectionNode, frame: selectionFrame)
            self.selectionNode.cornerRadius = selectionFrame.height / 2.0
            
            for i in 0 ..< self.itemNodes.count {
                let itemNode = self.itemNodes[i]
                let highlightedItemNode = self.highlightedItemNodes[i]
                let _ = itemNode.measure(itemSize)
                transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: itemSize.width * CGFloat(i), y: (size.height - itemSize.height) / 2.0), size: itemSize))
                transition.updateFrame(node: highlightedItemNode, frame: CGRect(origin: CGPoint(x: itemSize.width * CGFloat(i), y: (size.height - itemSize.height) / 2.0), size: itemSize))
                
                let isSelected = selectedIndex == i
                if itemNode.isSelected != isSelected {
                    if case .animated = transition {
                        UIView.transition(with: itemNode.view, duration: 0.2, options: .transitionCrossDissolve, animations: {
                            itemNode.isSelected = isSelected
                            highlightedItemNode.isHidden = !isSelected
                        }, completion: nil)
                    } else {
                        itemNode.isSelected = isSelected
                        highlightedItemNode.isHidden = !isSelected
                    }
                    if isSelected {
                        itemNode.accessibilityTraits.insert(.selected)
                    } else {
                        itemNode.accessibilityTraits.remove(.selected)
                    }
                }
            }
        }
    }
    
    private func setupButtons() {
        for i in 0 ..< self.itemNodes.count {
            let itemNode = self.itemNodes[i]
            itemNode.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: .touchUpInside)
            itemNode.highligthedChanged = { [weak self, weak itemNode] highlighted in
                if let strongSelf = self, let itemNode = itemNode {
                    let transition = ContainedViewLayoutTransition.animated(duration: 0.25, curve: .easeInOut)
                    if strongSelf.selectedIndex == i {
                        if let gestureRecognizer = strongSelf.gestureRecognizer, case .began = gestureRecognizer.state {
                        } else {
                            strongSelf.updateButtonsHighlights(highlightedIndex: highlighted ? i : nil, gestureSelectedIndex: strongSelf.gestureSelectedIndex)
                        }
                    } else if highlighted {
                        transition.updateAlpha(node: itemNode, alpha: 0.4)
                    }
                    if !highlighted {
                        transition.updateAlpha(node: itemNode, alpha: 1.0)
                    }
                }
            }
        }
    }
    
    private func updateButtonsHighlights(highlightedIndex: Int?, gestureSelectedIndex: Int?) {
        let transition = ContainedViewLayoutTransition.animated(duration: 0.25, curve: .easeInOut)
        if highlightedIndex == nil && gestureSelectedIndex == nil {
            transition.updateTransformScale(node: self.selectionNode, scale: 1.0)
        } else {
            transition.updateTransformScale(node: self.selectionNode, scale: 0.96)
        }
        for i in 0 ..< self.itemNodes.count {
            let itemNode = self.itemNodes[i]
            let highlightedItemNode = self.highlightedItemNodes[i]
            if i == highlightedIndex || i == gestureSelectedIndex {
                transition.updateTransformScale(node: itemNode, scale: 0.96)
                transition.updateTransformScale(node: highlightedItemNode, scale: 0.96)
            } else {
                transition.updateTransformScale(node: itemNode, scale: 1.0)
                transition.updateTransformScale(node: highlightedItemNode, scale: 1.0)
            }
        }
    }
    
    private func updateButtonsHighlights() {
        let transition = ContainedViewLayoutTransition.animated(duration: 0.25, curve: .easeInOut)
        if let gestureSelectedIndex = self.gestureSelectedIndex {
            for i in 0 ..< self.itemNodes.count {
                let itemNode = self.itemNodes[i]
                let highlightedItemNode = self.highlightedItemNodes[i]
                transition.updateTransformScale(node: itemNode, scale: i == gestureSelectedIndex ? 0.96 : 1.0)
                transition.updateTransformScale(node: highlightedItemNode, scale: i == gestureSelectedIndex ? 0.96 : 1.0)
            }
        } else {
            for itemNode in self.itemNodes {
                transition.updateTransformScale(node: itemNode, scale: 1.0)
            }
            for itemNode in self.highlightedItemNodes {
                transition.updateTransformScale(node: itemNode, scale: 1.0)
            }
        }
    }
    
    @objc private func buttonPressed(_ button: HighlightTrackingButtonNode) {
        guard let index = self.itemNodes.firstIndex(of: button) else {
            return
        }
        
        self._selectedIndex = index
        self.selectedIndexChanged(index)
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .animated(duration: 0.2, curve: .slide))
        }
    }
    
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return self.selectionNode.frame.contains(gestureRecognizer.location(in: self.view))
    }
    
    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        let location = recognizer.location(in: self.view)
        switch recognizer.state {
            case .changed:
                if !self.selectionNode.frame.contains(location) {
                    let point = CGPoint(x: max(0.0, min(self.bounds.width, location.x)), y: 1.0)
                    for i in 0 ..< self.itemNodes.count {
                        let itemNode = self.itemNodes[i]
                        if itemNode.frame.contains(point) {
                            if i != self.gestureSelectedIndex {
                                self.gestureSelectedIndex = i
                                self.updateButtonsHighlights(highlightedIndex: nil, gestureSelectedIndex: i)
                                if let size = self.validLayout {
                                    self.updateLayout(size: size, transition: .animated(duration: 0.35, curve: .slide))
                                }
                            }
                            break
                        }
                    }
                }
            case .ended:
                if let gestureSelectedIndex = self.gestureSelectedIndex {
                    if gestureSelectedIndex != self.selectedIndex  {
                        self._selectedIndex = gestureSelectedIndex
                        self.selectedIndexChanged(gestureSelectedIndex)
                    }
                    self.gestureSelectedIndex = nil
                }
                self.updateButtonsHighlights(highlightedIndex: nil, gestureSelectedIndex: nil)
            default:
                break
        }
    }
}
