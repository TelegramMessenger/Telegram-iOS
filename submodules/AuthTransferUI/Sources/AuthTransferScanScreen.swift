import Foundation
import UIKit
import AccountContext
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Camera
import GlassButtonNode
import CoreImage
import AlertUI
import TelegramPresentationData
import TelegramCore
import UndoUI
import Markdown
import TextFormat

private func parseAuthTransferUrl(_ url: URL) -> Data? {
    var tokenString: String?
    if let query = url.query, let components = URLComponents(string: "/?" + query), let queryItems = components.queryItems {
        for queryItem in queryItems {
            if let value = queryItem.value {
                if queryItem.name == "token", !value.isEmpty {
                    tokenString = value
                }
            }
        }
    }
    if var tokenString = tokenString {
        tokenString = tokenString.replacingOccurrences(of: "-", with: "+")
        tokenString = tokenString.replacingOccurrences(of: "_", with: "/")
        while tokenString.count % 4 != 0 {
            tokenString.append("=")
        }
        if let data = Data(base64Encoded: tokenString) {
            return data
        }
    }
    return nil
}

private func generateFrameImage() -> UIImage? {
    return generateImage(CGSize(width: 64.0, height: 64.0), contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(4.0)
        context.setLineCap(.round)
        
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 2.0, y: 2.0 + 26.0))
        path.addArc(tangent1End: CGPoint(x: 2.0, y: 2.0), tangent2End: CGPoint(x: 2.0 + 26.0, y: 2.0), radius: 6.0)
        path.addLine(to: CGPoint(x: 2.0 + 26.0, y: 2.0))
        context.addPath(path)
        context.strokePath()
        
        path.move(to: CGPoint(x: size.width - 2.0, y: 2.0 + 26.0))
        path.addArc(tangent1End: CGPoint(x: size.width - 2.0, y: 2.0), tangent2End: CGPoint(x: 2.0 + 26.0, y: 2.0), radius: 6.0)
        path.addLine(to: CGPoint(x: size.width - 2.0 - 26.0, y: 2.0))
        context.addPath(path)
        context.strokePath()
        
        path.move(to: CGPoint(x: 2.0, y: size.height - 2.0 - 26.0))
        path.addArc(tangent1End: CGPoint(x: 2.0, y: size.height - 2.0), tangent2End: CGPoint(x: 2.0 + 26.0, y: size.height - 2.0), radius: 6.0)
        path.addLine(to: CGPoint(x: 2.0 + 26.0, y: size.height - 2.0))
        context.addPath(path)
        context.strokePath()
        
        path.move(to: CGPoint(x: size.width - 2.0, y: size.height - 2.0 - 26.0))
        path.addArc(tangent1End: CGPoint(x: size.width - 2.0, y: size.height - 2.0), tangent2End: CGPoint(x: 2.0 + 26.0, y: size.height - 2.0), radius: 6.0)
        path.addLine(to: CGPoint(x: size.width - 2.0 - 26.0, y: size.height - 2.0))
        context.addPath(path)
        context.strokePath()
    })?.stretchableImage(withLeftCapWidth: 32, topCapHeight: 32)
}

public final class AuthTransferScanScreen: ViewController {
    private let context: AccountContext
    private let activeSessionsContext: ActiveSessionsContext
    private var presentationData: PresentationData
    
    private var codeDisposable: Disposable?
    private var inForegroundDisposable: Disposable?
    private let approveDisposable = MetaDisposable()
    
    private var controllerNode: AuthTransferScanScreenNode {
        return self.displayNode as! AuthTransferScanScreenNode
    }
    
    public init(context: AccountContext, activeSessionsContext: ActiveSessionsContext) {
        self.context = context
        self.activeSessionsContext = activeSessionsContext
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let navigationBarTheme = NavigationBarTheme(buttonColor: .white, disabledButtonColor: .white, primaryTextColor: .white, backgroundColor: .clear, enableBackgroundBlur: false, separatorColor: .clear, badgeBackgroundColor: .clear, badgeStrokeColor: .clear, badgeTextColor: .clear)
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: navigationBarTheme, strings: NavigationBarStrings(back: self.presentationData.strings.Common_Back, close: self.presentationData.strings.Common_Close)))
        
        self.statusBar.statusBarStyle = .White
        
        self.navigationPresentation = .modalInLargeLayout
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.navigationBar?.intrinsicCanTransitionInline = false
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.inForegroundDisposable = (context.sharedContext.applicationBindings.applicationInForeground
        |> deliverOnMainQueue).start(next: { [weak self] inForeground in
            guard let strongSelf = self else {
                return
            }
            (strongSelf.displayNode as! AuthTransferScanScreenNode).updateInForeground(inForeground)
        })
        
        #if DEBUG
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Test", style: .plain, target: self, action: #selector(self.testPressed))
        #endif
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.codeDisposable?.dispose()
        self.inForegroundDisposable?.dispose()
        self.approveDisposable.dispose()
    }
    
    @objc private func testPressed() {
        self.dismissWithSuccess(session: nil)
    }
    
    private func dismissWithSuccess(session: RecentAccountSession?) {
        if let navigationController = navigationController as? NavigationController {
            let activeSessionsContext = self.activeSessionsContext
            
            self.present(UndoOverlayController(presentationData: self.presentationData, content: .actionSucceeded(title: self.presentationData.strings.AuthSessions_AddedDeviceTitle, text: session?.appName ?? "Telegram for macOS", cancel: self.presentationData.strings.AuthSessions_AddedDeviceTerminate), elevatedLayout: false, animateInAsReplacement: false, action: { value in
                if value == .undo, let session = session {
                    let _ = activeSessionsContext.remove(hash: session.hash).start()
                    return true
                } else {
                    return false
                }
            }), in: .window(.root))
            
            var viewControllers = navigationController.viewControllers
            viewControllers = viewControllers.filter { controller in
                if controller is RecentSessionsController {
                    return false
                }
                if controller === self {
                    return false
                }
                return true
            }
            viewControllers.append(self.context.sharedContext.makeRecentSessionsController(context: self.context, activeSessionsContext: activeSessionsContext))
            navigationController.setViewControllers(viewControllers, animated: true)
        } else {
            self.dismiss()
        }
    }
    
    override public func loadDisplayNode() {
        self.displayNode = AuthTransferScanScreenNode(context: self.context, presentationData: self.presentationData)
        
        self.displayNodeDidLoad()
        
        self.codeDisposable = ((self.displayNode as! AuthTransferScanScreenNode).focusedCode.get()
        |> map { code -> String? in
            return code?.message
        }
        |> distinctUntilChanged
        |> mapToSignal { code -> Signal<String?, NoError> in
            return .single(code)
            |> delay(0.5, queue: Queue.mainQueue())
        }).start(next: { [weak self] code in
            guard let strongSelf = self else {
                return
            }
            guard let code = code else {
                return
            }
            if let url = URL(string: code), let parsedToken = parseAuthTransferUrl(url) {
                strongSelf.approveDisposable.set((approveAuthTransferToken(account: strongSelf.context.account, token: parsedToken, activeSessionsContext: strongSelf.activeSessionsContext)
                |> deliverOnMainQueue).start(next: { session in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.controllerNode.codeWithError = nil
                    let activeSessionsContext = strongSelf.activeSessionsContext
                    Queue.mainQueue().after(1.5, {
                        activeSessionsContext.loadMore()
                    })
                    strongSelf.dismissWithSuccess(session: session)
                }, error: { _ in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.controllerNode.codeWithError = code
                    strongSelf.controllerNode.updateFocusedRect(nil)
                }))
            }
        })
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! AuthTransferScanScreenNode).containerLayoutUpdated(layout: layout, navigationHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}

private final class AuthTransferScanScreenNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData

    private let previewNode: CameraPreviewNode
    private let fadeNode: ASDisplayNode
    private let topDimNode: ASDisplayNode
    private let bottomDimNode: ASDisplayNode
    private let leftDimNode: ASDisplayNode
    private let rightDimNode: ASDisplayNode
    private let centerDimNode: ASDisplayNode
    private let frameNode: ASImageNode
    private let torchButtonNode: GlassButtonNode
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let errorTextNode: ImmediateTextNode
    
    private let camera: Camera
    private let codeDisposable = MetaDisposable()
    private var torchDisposable: Disposable?
    
    fileprivate let focusedCode = ValuePromise<CameraCode?>(ignoreRepeated: true)
    private var focusedRect: CGRect?
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    var codeWithError: String? {
        didSet {
            if self.codeWithError != oldValue {
                if self.codeWithError != nil {
                    self.errorTextNode.isHidden = false
                } else {
                    self.errorTextNode.isHidden = true
                }
            }
        }
    }
    
    private var highlightViews: [UIVisualEffectView] = []
    
    init(context: AccountContext, presentationData: PresentationData) {
        self.context = context
        self.presentationData = presentationData
        
        self.previewNode = CameraPreviewNode()
        self.previewNode.backgroundColor = .black
        
        self.fadeNode = ASDisplayNode()
        self.fadeNode.alpha = 0.0
        self.fadeNode.backgroundColor = .black
        
        self.topDimNode = ASDisplayNode()
        self.topDimNode.alpha = 0.625
        self.topDimNode.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.8)
        
        self.bottomDimNode = ASDisplayNode()
        self.bottomDimNode.alpha = 0.625
        self.bottomDimNode.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.8)
        
        self.leftDimNode = ASDisplayNode()
        self.leftDimNode.alpha = 0.625
        self.leftDimNode.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.8)
        
        self.rightDimNode = ASDisplayNode()
        self.rightDimNode.alpha = 0.625
        self.rightDimNode.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.8)
        
        self.centerDimNode = ASDisplayNode()
        self.centerDimNode.alpha = 0.0
        self.centerDimNode.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.8)
        
        self.frameNode = ASImageNode()
        self.frameNode.image = generateFrameImage()
        
        self.torchButtonNode = GlassButtonNode(icon: UIImage(bundleImageName: "Wallet/CameraFlashIcon")!, label: nil)
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: presentationData.strings.AuthSessions_AddDevice_ScanTitle, font: Font.bold(32.0), textColor: .white)
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        
        let textFont = Font.regular(17.0)
        let boldFont = Font.bold(17.0)
        
        var text = presentationData.strings.AuthSessions_AddDevice_ScanInstallInfo
        text = text.replacingOccurrences(of: " [", with: "   [").replacingOccurrences(of: ") ", with: ")   ")
        
        let attributedText = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: .white), bold: MarkdownAttributeSet(font: boldFont, textColor: .white), link: MarkdownAttributeSet(font: boldFont, textColor: .white), linkAttribute: { contents in
            return (TelegramTextAttributes.URL, contents)
        })))
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.attributedText = attributedText
        self.textNode.maximumNumberOfLines = 0
        self.textNode.textAlignment = .center
        self.textNode.lineSpacing = 0.5
        
        self.errorTextNode = ImmediateTextNode()
        self.errorTextNode.displaysAsynchronously = false
        self.errorTextNode.attributedText = NSAttributedString(string: presentationData.strings.AuthSessions_AddDevice_InvalidQRCode, font: Font.medium(16.0), textColor: .white)
        self.errorTextNode.maximumNumberOfLines = 0
        self.errorTextNode.textAlignment = .center
        self.errorTextNode.isHidden = true
        
        self.camera = Camera(configuration: .init(preset: .hd1920x1080, position: .back, audio: false))
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.torchDisposable = (self.camera.hasTorch
        |> deliverOnMainQueue).start(next: { [weak self] hasTorch in
            if let strongSelf = self {
                strongSelf.torchButtonNode.isHidden = !hasTorch
            }
        })
        
        self.addSubnode(self.previewNode)
        self.addSubnode(self.fadeNode)
        self.addSubnode(self.topDimNode)
        self.addSubnode(self.bottomDimNode)
        self.addSubnode(self.leftDimNode)
        self.addSubnode(self.rightDimNode)
        self.addSubnode(self.centerDimNode)
        self.addSubnode(self.frameNode)
        self.addSubnode(self.torchButtonNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.errorTextNode)
      
        self.torchButtonNode.addTarget(self, action: #selector(self.torchPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.codeDisposable.dispose()
        self.torchDisposable?.dispose()
        self.camera.stopCapture(invalidate: true)
    }
    
    fileprivate func updateInForeground(_ inForeground: Bool) {
        if !inForeground {
            self.camera.stopCapture(invalidate: false)
        } else {
            self.camera.startCapture()
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.camera.attachPreviewNode(self.previewNode)
        self.camera.startCapture()
        
        let throttledSignal = self.camera.detectedCodes
        |> mapToThrottled { next -> Signal<[CameraCode], NoError> in
            return .single(next) |> then(.complete() |> delay(0.3, queue: Queue.concurrentDefaultQueue()))
        }
        
        self.codeDisposable.set((throttledSignal
        |> deliverOnMainQueue).start(next: { [weak self] codes in
            guard let strongSelf = self else {
                return
            }
            let filteredCodes = codes.filter { $0.message.hasPrefix("tg://") }
            if let code = filteredCodes.first, CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4).contains(code.boundingBox.center) {
                if strongSelf.codeWithError != code.message {
                    strongSelf.codeWithError = nil
                }
                if strongSelf.codeWithError == code.message {
                    strongSelf.focusedCode.set(nil)
                    strongSelf.updateFocusedRect(nil)
                } else {
                    strongSelf.focusedCode.set(code)
                    strongSelf.updateFocusedRect(code.boundingBox)
                }
            } else {
                strongSelf.codeWithError = nil
                strongSelf.focusedCode.set(nil)
                strongSelf.updateFocusedRect(nil)
            }
        }))
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        self.textNode.view.addGestureRecognizer(recognizer)
    }
    
    @objc private func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
            case .ended:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                    switch gesture {
                        case .tap:
                            if let (_, attributes) = self.textNode.attributesAtPoint(location) {
                                if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                                    switch url {
                                    case "desktop":
                                        self.context.sharedContext.openExternalUrl(context: self.context, urlContext: .generic, url: "https://getdesktop.telegram.org", forceExternal: true, presentationData: self.context.sharedContext.currentPresentationData.with { $0 }, navigationController: nil, dismissInput: {})
                                    case "web":
                                        self.context.sharedContext.openExternalUrl(context: self.context, urlContext: .generic, url: "https://web.telegram.org", forceExternal: true, presentationData: self.context.sharedContext.currentPresentationData.with { $0 }, navigationController: nil, dismissInput: {})
                                    default:
                                        break
                                    }
                                }
                            }
                        default:
                            break
                    }
                }
            default:
                break
        }
    }
    
    func updateFocusedRect(_ rect: CGRect?) {
        self.focusedRect = rect
        if let (layout, navigationHeight) = self.validLayout {
            self.containerLayoutUpdated(layout: layout, navigationHeight: navigationHeight, transition: .animated(duration: 0.4, curve: .spring))
        }
    }
    
    func containerLayoutUpdated(layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationHeight)
        
        let sideInset: CGFloat = 66.0
        let titleSpacing: CGFloat = 48.0
        let bounds = CGRect(origin: CGPoint(), size: layout.size)

        if case .tablet = layout.deviceMetrics.type {
            if UIDevice.current.orientation == .landscapeLeft {
                self.previewNode.transform = CATransform3DMakeRotation(-CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
            } else if UIDevice.current.orientation == .landscapeRight {
                self.previewNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
            } else {
                self.previewNode.transform = CATransform3DIdentity
            }
        }
        transition.updateFrame(node: self.previewNode, frame: bounds)
        transition.updateFrame(node: self.fadeNode, frame: bounds)
        
        let frameSide = max(240.0, layout.size.width - sideInset * 2.0)
        let dimHeight = ceil((layout.size.height - frameSide) / 2.0)
        let dimInset = (layout.size.width - frameSide) / 2.0
        
        let dimAlpha: CGFloat
        let dimRect: CGRect
        let controlsAlpha: CGFloat
        let centerDimAlpha: CGFloat = 0.0
        let frameAlpha: CGFloat = 1.0
        if let focusedRect = self.focusedRect {
            controlsAlpha = 0.0
            dimAlpha = 1.0
            let side = max(bounds.width * focusedRect.width, bounds.height * focusedRect.height) * 0.6
            let center = CGPoint(x: (1.0 - focusedRect.center.y) * bounds.width, y: focusedRect.center.x * bounds.height)
            dimRect = CGRect(x: center.x - side / 2.0, y: center.y - side / 2.0, width: side, height: side)
        } else {
            controlsAlpha = 1.0
            dimAlpha = 0.625
            dimRect = CGRect(x: dimInset, y: dimHeight, width: layout.size.width - dimInset * 2.0, height: layout.size.height - dimHeight * 2.0)
        }
    
        transition.updateAlpha(node: self.topDimNode, alpha: dimAlpha)
        transition.updateAlpha(node: self.bottomDimNode, alpha: dimAlpha)
        transition.updateAlpha(node: self.leftDimNode, alpha: dimAlpha)
        transition.updateAlpha(node: self.rightDimNode, alpha: dimAlpha)
        transition.updateAlpha(node: self.centerDimNode, alpha: centerDimAlpha)
        transition.updateAlpha(node: self.frameNode, alpha: frameAlpha)
        
        transition.updateFrame(node: self.topDimNode, frame: CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: dimRect.minY))
        transition.updateFrame(node: self.bottomDimNode, frame: CGRect(x: 0.0, y: dimRect.maxY, width: layout.size.width, height: max(0.0, layout.size.height - dimRect.maxY)))
        transition.updateFrame(node: self.leftDimNode, frame: CGRect(x: 0.0, y: dimRect.minY, width: max(0.0, dimRect.minX), height: dimRect.height))
        transition.updateFrame(node: self.rightDimNode, frame: CGRect(x: dimRect.maxX, y: dimRect.minY, width: max(0.0, layout.size.width - dimRect.maxX), height: dimRect.height))
        transition.updateFrame(node: self.frameNode, frame: dimRect.insetBy(dx: -2.0, dy: -2.0))
        transition.updateFrame(node: self.centerDimNode, frame: dimRect)
        
        let buttonSize = CGSize(width: 72.0, height: 72.0)
        var torchFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - buttonSize.width) / 2.0), y: dimHeight + frameSide + 98.0), size: buttonSize)
        let updatedTorchY = min(torchFrame.minY, layout.size.height - torchFrame.height - 10.0)
        let additionalTorchOffset: CGFloat = updatedTorchY - torchFrame.minY
        torchFrame.origin.y = updatedTorchY
        transition.updateFrame(node: self.torchButtonNode, frame: torchFrame)
        
        transition.updateAlpha(node: self.textNode, alpha: controlsAlpha)
        transition.updateAlpha(node: self.errorTextNode, alpha: controlsAlpha)
        transition.updateAlpha(node: self.torchButtonNode, alpha: controlsAlpha)
        for view in self.highlightViews {
            transition.updateAlpha(layer: view.layer, alpha: controlsAlpha)
        }
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: layout.size.width - 16.0, height: layout.size.height))
        let textSize = self.textNode.updateLayout(CGSize(width: layout.size.width - 16.0, height: layout.size.height))
        let errorTextSize = self.errorTextNode.updateLayout(CGSize(width: layout.size.width - 16.0, height: layout.size.height))
        var textFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - textSize.width) / 2.0), y: max(dimHeight - textSize.height - titleSpacing, navigationHeight + floorToScreenPixels((dimHeight - navigationHeight - textSize.height) / 2.0) + 5.0)), size: textSize)
        let titleFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width) / 2.0), y: textFrame.minY - 18.0 - titleSize.height), size: titleSize)
        if titleFrame.minY < navigationHeight {
            transition.updateAlpha(node: self.titleNode, alpha: 0.0)
            textFrame = textFrame.offsetBy(dx: 0.0, dy: -5.0)
        } else {
            transition.updateAlpha(node: self.titleNode, alpha: controlsAlpha)
        }
        var errorTextFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - errorTextSize.width) / 2.0), y: dimHeight + frameSide + 48.0), size: errorTextSize)
        errorTextFrame.origin.y += floor(additionalTorchOffset / 2.0)

        transition.updateFrameAdditive(node: self.titleNode, frame: titleFrame)
        transition.updateFrameAdditive(node: self.textNode, frame: textFrame)
        transition.updateFrameAdditive(node: self.errorTextNode, frame: errorTextFrame)
        
        if self.highlightViews.isEmpty {
            let urlAttributesAndRects = self.textNode.cachedLayout?.allAttributeRects(name: "UrlAttributeT") ?? []
            
            for (_, rect) in urlAttributesAndRects {
                let view = UIVisualEffectView(effect: UIBlurEffect(style: .light))
                view.clipsToBounds = true
                view.layer.cornerRadius = 5.0
                view.frame = rect.offsetBy(dx: self.textNode.frame.minX, dy: self.textNode.frame.minY).insetBy(dx: -4.0, dy: -2.0)
                self.view.insertSubview(view, belowSubview: self.textNode.view)
                self.highlightViews.append(view)
            }
        }
    }
    
    @objc private func torchPressed() {
        self.torchButtonNode.isSelected = !self.torchButtonNode.isSelected
        self.camera.setTorchActive(self.torchButtonNode.isSelected)
    }
}

