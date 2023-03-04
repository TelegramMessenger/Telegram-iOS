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
    private var startRect: CGRect?
    init(sharedContext: SharedAccountContext, cameraNode: PreviewVideoNode, shareCamera: @escaping (ASDisplayNode, Bool) -> Void, switchCamera: @escaping () -> Void, startRect: CGRect? = nil) {
        self.sharedContext = sharedContext
        self.cameraNode = cameraNode
        self.shareCamera = shareCamera
        self.switchCamera = switchCamera
        
        super.init(navigationBarPresentationData: nil)
        self.startRect = startRect
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
        self.displayNode = VoiceChatCameraPreviewControllerNode(controller: self, sharedContext: self.sharedContext, cameraNode: self.cameraNode, startRect: startRect ?? CGRect())
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
    private let contentContainerNode: ASDisplayNode
    private let titleNode: ASTextNode
    private let previewContainerNode: ASDisplayNode
    private let doneButton: SolidRoundedButtonNode
    private var broadcastPickerView: UIView?
    private let cancelButton: HighlightableButtonNode
    
    private let placeholderTextNode: ImmediateTextNode
    private let placeholderIconNode: ASImageNode
    private let gradientLayer = CAGradientLayer()
    private var wheelNode: WheelControlNode
    private var selectedTabIndex: Int = 1
    private var containerLayout: (ContainerViewLayout, CGFloat)?

    private var applicationStateDisposable: Disposable?
    
    private let hapticFeedback = HapticFeedback()
    
    private let readyDisposable = MetaDisposable()
    private var startRect: CGRect?
    var shareCamera: ((Bool) -> Void)?
    var switchCamera: (() -> Void)?
    var dismiss: (() -> Void)?
    var cancel: (() -> Void)?
    
    init(controller: VoiceChatCameraPreviewController, sharedContext: SharedAccountContext, cameraNode: PreviewVideoNode, startRect: CGRect? = nil) {
        self.controller = controller
        self.sharedContext = sharedContext
        self.presentationData = sharedContext.currentPresentationData.with { $0 }
        
        self.cameraNode = cameraNode
        
        self.contentContainerNode = ASDisplayNode()
        self.contentContainerNode.isOpaque = false

        self.startRect = startRect
        
        let title =  self.presentationData.strings.VoiceChat_VideoPreviewTitle
        
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.bold(17.0), textColor: UIColor(rgb: 0xffffff))
                
        self.doneButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(backgroundColor: UIColor(rgb: 0xffffff), foregroundColor: UIColor(rgb: 0x4f5352)), font: .bold, height: 48.0, cornerRadius: 10.0, gloss: false)
        self.doneButton.title = self.presentationData.strings.VoiceChat_VideoPreviewContinue
        
        if #available(iOS 12.0, *) {
            let broadcastPickerView = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 50, height: 52.0))
            broadcastPickerView.alpha = 0.02
            broadcastPickerView.isHidden = true
            broadcastPickerView.preferredExtension = "\(self.sharedContext.applicationBindings.appBundleId).BroadcastUpload"
            broadcastPickerView.showsMicrophoneButton = false
            self.broadcastPickerView = broadcastPickerView
        }
        
        self.cancelButton = HighlightableButtonNode()
        self.cancelButton.setAttributedTitle(NSAttributedString(string: self.presentationData.strings.Common_Cancel, font: Font.regular(17.0), textColor: UIColor(rgb: 0xffffff)), for: [])
        
        self.previewContainerNode = ASDisplayNode()
        self.previewContainerNode.clipsToBounds = true
        self.previewContainerNode.backgroundColor = UIColor(rgb: 0x2b2b2f)
        
        self.placeholderTextNode = ImmediateTextNode()
        self.placeholderTextNode.alpha = 0.0
        self.placeholderTextNode.maximumNumberOfLines = 3
        self.placeholderTextNode.textAlignment = .center
        
        self.placeholderIconNode = ASImageNode()
        self.placeholderIconNode.alpha = 0.0
        self.placeholderIconNode.contentMode = .scaleAspectFit
        self.placeholderIconNode.displaysAsynchronously = false
        
        self.wheelNode = WheelControlNode(items: [WheelControlNode.Item(title: UIDevice.current.model == "iPad" ? self.presentationData.strings.VoiceChat_VideoPreviewTabletScreen : self.presentationData.strings.VoiceChat_VideoPreviewPhoneScreen), WheelControlNode.Item(title: self.presentationData.strings.VoiceChat_VideoPreviewFrontCamera), WheelControlNode.Item(title: self.presentationData.strings.VoiceChat_VideoPreviewBackCamera)], selectedIndex: self.selectedTabIndex)
        
        super.init()
        
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.addSubnode(self.contentContainerNode)
        
        self.contentContainerNode.addSubnode(self.previewContainerNode)
        self.contentContainerNode.addSubnode(self.titleNode)
        self.contentContainerNode.addSubnode(self.doneButton)
        if let broadcastPickerView = self.broadcastPickerView {
            self.contentContainerNode.view.addSubview(broadcastPickerView)
        }
        self.contentContainerNode.addSubnode(self.cancelButton)
                
        self.previewContainerNode.addSubnode(self.cameraNode)
        
        self.previewContainerNode.addSubnode(self.placeholderIconNode)
        self.previewContainerNode.addSubnode(self.placeholderTextNode)
        
        self.previewContainerNode.addSubnode(self.wheelNode)

        self.wheelNode.selectedIndexChanged = { [weak self] index in
            if let strongSelf = self {
                if (index == 1 && strongSelf.selectedTabIndex == 2) || (index == 2 && strongSelf.selectedTabIndex == 1) {
                    strongSelf.switchCamera?()
                }
                if index == 0 && [1, 2].contains(strongSelf.selectedTabIndex) {
                    strongSelf.broadcastPickerView?.isHidden = false
                    strongSelf.cameraNode.updateIsBlurred(isBlurred: true, light: false, animated: true)
                    let transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .easeInOut)
                    transition.updateAlpha(node: strongSelf.placeholderTextNode, alpha: 1.0)
                    transition.updateAlpha(node: strongSelf.placeholderIconNode, alpha: 1.0)
                } else if [1, 2].contains(index) && strongSelf.selectedTabIndex == 0 {
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
                strongSelf.shareCamera?(true)
            }
        }
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
        
        self.previewContainerNode.layer.addSublayer(gradientLayer)
    }
    
    deinit {
        self.readyDisposable.dispose()
        self.applicationStateDisposable?.dispose()
    }
       
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
    }
    
    override func didLoad() {
        super.didLoad()
        
        let leftSwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.leftSwipeGesture))
        leftSwipeGestureRecognizer.direction = .left
        let rightSwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.rightSwipeGesture))
        rightSwipeGestureRecognizer.direction = .right
        
        self.view.addGestureRecognizer(leftSwipeGestureRecognizer)
        self.view.addGestureRecognizer(rightSwipeGestureRecognizer)
        
    }
    
    @objc func leftSwipeGesture() {
        if self.selectedTabIndex < 2 {
            self.wheelNode.setSelectedIndex(self.selectedTabIndex + 1, animated: true)
            self.wheelNode.selectedIndexChanged(self.wheelNode.selectedIndex)
        }
    }
    
    @objc func rightSwipeGesture() {
        if self.selectedTabIndex > 0 {
            self.wheelNode.setSelectedIndex(self.selectedTabIndex - 1, animated: true)
            self.wheelNode.selectedIndexChanged(self.wheelNode.selectedIndex)
        }
    }
    
    @objc func cancelPressed() {
        self.cancel?()
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
    
    func animateIn() {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        
        let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
        let targetBounds = self.bounds
        transition.animateView({
            self.bounds = targetBounds
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
        if let fromRect = startRect {
            self.animateRadialMaskIn(from: fromRect, to: fromRect)
        }
    }
    
    func animateRadialMaskIn(from fromRect: CGRect, to toRect: CGRect) {
        let maskLayer = CAShapeLayer()
        maskLayer.frame = fromRect
        
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(origin: CGPoint(), size: fromRect.size))
        maskLayer.path = path
        
        self.layer.mask = maskLayer
        
        let topLeft = CGPoint(x: 0.0, y: 0.0)
        let topRight = CGPoint(x: self.bounds.width, y: 0.0)
        let bottomLeft = CGPoint(x: 0.0, y: self.bounds.height)
        let bottomRight = CGPoint(x: self.bounds.width, y: self.bounds.height)
        
        func distance(_ v1: CGPoint, _ v2: CGPoint) -> CGFloat {
            let dx = v1.x - v2.x
            let dy = v1.y - v2.y
            return sqrt(dx * dx + dy * dy)
        }
        
        var maxRadius = distance(toRect.center, topLeft)
        maxRadius = max(maxRadius, distance(toRect.center, topRight))
        maxRadius = max(maxRadius, distance(toRect.center, bottomLeft))
        maxRadius = max(maxRadius, distance(toRect.center, bottomRight))
        maxRadius = ceil(maxRadius)
        
        let targetFrame = CGRect(origin: CGPoint(x: toRect.center.x - maxRadius, y: toRect.center.y - maxRadius), size: CGSize(width: maxRadius * 2.0, height: maxRadius * 2.0))
        
        let transition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .easeInOut)
        transition.updatePosition(layer: maskLayer, position: targetFrame.center)
        transition.updateTransformScale(layer: maskLayer, scale: maxRadius * 2.0 / fromRect.width, completion: { [weak self] _ in
            self?.layer.mask = nil
        })
    }
    
    
    func animateOut(completion: (() -> Void)? = nil) {
        if let toRect = self.startRect {
            self.zoomOutAnimation(from: self.frame, to: toRect) {
                self.dismiss?()
            }
        }
        
    }
    func zoomOutAnimation(from fromRect: CGRect, to toRect: CGRect, completion: @escaping ()->()) {
        let duration = 0.3
        let maskLayer = CAShapeLayer()
        let finalPath = UIBezierPath(roundedRect: CGRect(origin: toRect.origin, size: toRect.size), cornerRadius: fromRect.width / 2).cgPath
        let initialPath = UIBezierPath(roundedRect: CGRect(origin: fromRect.origin, size: fromRect.size), cornerRadius: 20).cgPath
        
        maskLayer.path = initialPath
        self.layer.mask = maskLayer
        maskLayer.animate(from: initialPath, to: finalPath, keyPath: "path", timingFunction: CAMediaTimingFunctionName.easeIn.rawValue, duration: duration)
        maskLayer.animateAlpha(from: 1, to: 0, duration: duration)  { _ in
            completion()
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.path = finalPath
        CATransaction.commit()
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
        
        var insets = layout.insets(options: [.statusBar])
        insets.top = max(10.0, insets.top)
    
        let contentSize: CGSize
        if isLandscape {
            if isTablet {
                contentSize = CGSize(width: 870.0, height: 690.0)
            } else {
                contentSize = CGSize(width: layout.size.width, height: layout.size.height)
            }
        } else {
            if isTablet {
                contentSize = CGSize(width: 600.0, height: 960.0)
            } else {
                contentSize = CGSize(width: layout.size.width, height: layout.size.height)
            }
        }
        
        let sideInset = floor((layout.size.width - contentSize.width) / 2.0)
        let contentFrame: CGRect
        if isTablet {
            contentFrame = CGRect(origin: CGPoint(x: sideInset, y: floor((layout.size.height - contentSize.height) / 2.0)), size: contentSize)
        } else {
            contentFrame = CGRect(origin: CGPoint(x: sideInset, y: layout.size.height - contentSize.height), size: contentSize)
        }
//        var backgroundFrame = contentFrame
//        if !isTablet {
//            backgroundFrame.size.height += 2000.0
//        }
//        if backgroundFrame.minY < contentFrame.minY {
//            backgroundFrame.origin.y = contentFrame.minY
//        }
//        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
//        transition.updateFrame(node: self.contentBackgroundNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
//        transition.updateFrame(node: self.wrappingScrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
//        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let titleSize = self.titleNode.measure(CGSize(width: contentFrame.width, height: .greatestFiniteMagnitude))
        let titleFrame = CGRect(origin: CGPoint(x: floor((contentFrame.width - titleSize.width) / 2.0), y: insets.top + 20), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
                
        var previewSize: CGSize
        var previewFrame: CGRect
        let previewAspectRatio: CGFloat = 1.85
        if isLandscape {
            let previewHeight = contentFrame.height
            previewSize = CGSize(width: min(contentFrame.width - layout.safeInsets.left - layout.safeInsets.right, ceil(previewHeight * previewAspectRatio)), height: previewHeight)
            previewFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((contentFrame.width - previewSize.width) / 2.0), y: 0.0), size: previewSize)
        } else {
            previewSize = CGSize(width: contentFrame.width, height: contentFrame.height)
            previewFrame = CGRect(origin: CGPoint(), size: layout.size)
        }
        transition.updateFrame(node: self.previewContainerNode, frame: previewFrame)
        let cancelButtonSize = self.cancelButton.measure(CGSize(width: (previewFrame.width - titleSize.width) / 2.0, height: .greatestFiniteMagnitude))
        let cancelButtonFrame = CGRect(origin: CGPoint(x: previewFrame.minX + 17.0, y: insets.top + 20), size: cancelButtonSize)
        transition.updateFrame(node: self.cancelButton, frame: cancelButtonFrame)
        
        self.cameraNode.frame =  CGRect(origin: CGPoint(), size: previewSize)
        self.cameraNode.updateLayout(size: previewSize, layoutMode: isLandscape ? .fillHorizontal : .fillVertical, transition: .immediate)
      
        self.placeholderTextNode.attributedText = NSAttributedString(string: presentationData.strings.VoiceChat_VideoPreviewShareScreenInfo, font: Font.semibold(16.0), textColor: .white)
        self.placeholderIconNode.image = generateTintedImage(image: UIImage(bundleImageName: isTablet ? "Call/ScreenShareTablet" : "Call/ScreenSharePhone"), color: .white)
        
        let placeholderTextSize = self.placeholderTextNode.updateLayout(CGSize(width: previewSize.width - 80.0, height: 100.0))
        transition.updateFrame(node: self.placeholderTextNode, frame: CGRect(origin: CGPoint(x: floor((previewSize.width - placeholderTextSize.width) / 2.0), y: floorToScreenPixels(previewSize.height / 2.0) + 10.0), size: placeholderTextSize))
        if let imageSize = self.placeholderIconNode.image?.size {
            transition.updateFrame(node: self.placeholderIconNode, frame: CGRect(origin: CGPoint(x: floor((previewSize.width - imageSize.width) / 2.0), y: floorToScreenPixels(previewSize.height / 2.0) - imageSize.height - 8.0), size: imageSize))
        }

        let buttonInset: CGFloat = 16.0
        let buttonMaxWidth: CGFloat = 360.0
        
        let buttonWidth = min(buttonMaxWidth, contentFrame.width - buttonInset * 2.0)
        let doneButtonHeight = self.doneButton.updateLayout(width: buttonWidth, transition: transition)
        transition.updateFrame(node: self.doneButton, frame: CGRect(x: floorToScreenPixels((contentFrame.width - buttonWidth) / 2.0), y: previewFrame.maxY - doneButtonHeight - buttonInset - previewFrame.height * 0.05, width: buttonWidth, height: doneButtonHeight))
        self.broadcastPickerView?.frame = self.doneButton.frame
        
        
        
        let wheelFrame = CGRect(origin: CGPoint(x: 16.0 + previewFrame.minX, y: previewFrame.maxY - doneButtonHeight - buttonInset - 36.0 - 20.0 - 36 - 36), size: CGSize(width: previewFrame.width - 32.0, height: 36.0))
        self.wheelNode.updateLayout(size: wheelFrame.size, transition: transition)
        transition.updateFrame(node: self.wheelNode, frame: wheelFrame)
        
        transition.updateFrame(node: self.contentContainerNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        self.gradientLayer.frame = CGRect(x: 0, y: 0, width: layout.size.width, height: layout.size.height)

        self.gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.2).cgColor,
            UIColor.black.withAlphaComponent(0).cgColor,
            UIColor.black.withAlphaComponent(0).cgColor,
            UIColor.black.withAlphaComponent(0.2).cgColor,
            UIColor.black.withAlphaComponent(0.5).cgColor
        ]
        
        self.gradientLayer.locations = [0, 0.15, 0.75, 0.9, 1]
        self.gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        self.gradientLayer.endPoint = CGPoint(x: 0, y: 1)
    }
}

private let textFont = Font.with(size: 14.0, design: .camera, weight: .regular)
private let selectedTextFont = Font.with(size: 14.0, design: .camera, weight: .semibold)

private class WheelControlNode: ASDisplayNode, UIGestureRecognizerDelegate {
    struct Item: Equatable {
        public let title: String
        
        public init(title: String) {
            self.title = title
        }
    }

    private let maskNode: ASDisplayNode
    private let containerNode: ASDisplayNode
    private var itemNodes: [HighlightTrackingButtonNode]
    
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
        
    public init(items: [Item], selectedIndex: Int) {
        self._items = items
        self._selectedIndex = selectedIndex
        
        self.maskNode = ASDisplayNode()
        self.maskNode.setLayerBlock({
            let maskLayer = CAGradientLayer()
            maskLayer.colors = [UIColor.clear.cgColor, UIColor.white.cgColor, UIColor.white.cgColor, UIColor.clear.cgColor]
            maskLayer.locations = [0.0, 0.15, 0.85, 1.0]
            maskLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
            maskLayer.endPoint = CGPoint(x: 1.0, y: 0.0)
            return maskLayer
        })
        self.containerNode = ASDisplayNode()
        
        self.itemNodes = items.map { item in
            let itemNode = HighlightTrackingButtonNode()
            itemNode.contentEdgeInsets = UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 8.0)
            itemNode.titleNode.maximumNumberOfLines = 1
            itemNode.titleNode.truncationMode = .byTruncatingTail
            itemNode.accessibilityLabel = item.title
            itemNode.accessibilityTraits = [.button]
            itemNode.hitTestSlop = UIEdgeInsets(top: -10.0, left: -5.0, bottom: -10.0, right: -5.0)
            itemNode.setTitle(item.title.uppercased(), with: textFont, with: .white, for: .normal)
            itemNode.titleNode.shadowColor = UIColor.black.cgColor
            itemNode.titleNode.shadowOffset = CGSize()
            itemNode.titleNode.layer.shadowRadius = 2.0
            itemNode.titleNode.layer.shadowOpacity = 0.3
            itemNode.titleNode.layer.masksToBounds = false
            itemNode.titleNode.layer.shouldRasterize = true
            itemNode.titleNode.layer.rasterizationScale = UIScreen.main.scale
            return itemNode
        }
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.containerNode)
        
        self.itemNodes.forEach(self.containerNode.addSubnode(_:))
        self.setupButtons()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.layer.mask = self.maskNode.layer
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        let bounds = CGRect(origin: CGPoint(), size: size)
        
        transition.updateFrame(node: self.maskNode, frame: bounds)
        
        let spacing: CGFloat = 15.0
        if !self.itemNodes.isEmpty {
            var leftOffset: CGFloat = 0.0
            var selectedItemNode: ASDisplayNode?
            for i in 0 ..< self.itemNodes.count {
                let itemNode = self.itemNodes[i]
                let itemSize = itemNode.measure(size)
                transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: leftOffset, y: (size.height - itemSize.height) / 2.0), size: itemSize))
                
                leftOffset += itemSize.width + spacing
                
                let isSelected = self.selectedIndex == i
                if isSelected {
                    selectedItemNode = itemNode
                }
                if itemNode.isSelected != isSelected {
                    itemNode.isSelected = isSelected
                    let title = itemNode.attributedTitle(for: .normal)?.string ?? ""
                    itemNode.setTitle(title, with: isSelected ? selectedTextFont : textFont, with: isSelected ? .white : .white.withAlphaComponent(0.5), for: .normal)
                    if isSelected {
                        itemNode.accessibilityTraits.insert(.selected)
                    } else {
                        itemNode.accessibilityTraits.remove(.selected)
                    }
                }
            }
            
            let totalWidth = leftOffset - spacing
            if let selectedItemNode = selectedItemNode {
                let itemCenter = selectedItemNode.frame.center
                transition.updateFrame(node: self.containerNode, frame: CGRect(x: bounds.width / 2.0 - itemCenter.x, y: 0.0, width: totalWidth, height: bounds.height))
                
                for i in 0 ..< self.itemNodes.count {
                    let itemNode = self.itemNodes[i]
                    let convertedBounds = itemNode.view.convert(itemNode.bounds, to: self.view)
                    let position = convertedBounds.center
                    let offset = position.x - bounds.width / 2.0
                    let angle = abs(offset / bounds.width * 0.99)
                    let sign: CGFloat = offset > 0 ? 1.0 : -1.0
                    
                    var transform = CATransform3DMakeTranslation(-22.0 * angle * angle * sign, 0.0, 0.0)
                    transform = CATransform3DRotate(transform, angle, 0.0, sign, 0.0)
                    transition.animateView {
                        itemNode.transform = transform
                    }
                }
            }
        }
    }
    
    private func setupButtons() {
        for i in 0 ..< self.itemNodes.count {
            let itemNode = self.itemNodes[i]
            itemNode.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: .touchUpInside)
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
}
