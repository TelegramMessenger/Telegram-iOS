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
import LegacyUI
import LegacyComponents
import LegacyMediaPickerUI
import ImageContentAnalysis
import PresentationDataUtils

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

public final class QrCodeScanScreen: ViewController {
    public enum Subject {
        case authTransfer(activeSessionsContext: ActiveSessionsContext)
        case peer
    }
    
    private let context: AccountContext
    private let subject: QrCodeScanScreen.Subject
    private var presentationData: PresentationData
    
    private var codeDisposable: Disposable?
    private var inForegroundDisposable: Disposable?
    private let approveDisposable = MetaDisposable()
    
    private var controllerNode: QrCodeScanScreenNode {
        return self.displayNode as! QrCodeScanScreenNode
    }
    
    public var showMyCode: () -> Void = {}
    
    private var codeResolved = false
    
    public init(context: AccountContext, subject: QrCodeScanScreen.Subject) {
        self.context = context
        self.subject = subject
        
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
            (strongSelf.displayNode as! QrCodeScanScreenNode).updateInForeground(inForeground)
        })
        
        if case .peer = subject {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Contacts_QrCode_MyCode, style: .plain, target: self, action: #selector(self.myCodePressed))
        } else {
            #if DEBUG
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Test", style: .plain, target: self, action: #selector(self.testPressed))
            #endif
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.codeDisposable?.dispose()
        self.inForegroundDisposable?.dispose()
        self.approveDisposable.dispose()
    }
    
    @objc private func myCodePressed() {
        self.showMyCode()
    }
    
    @objc private func testPressed() {
        self.dismissWithSession(session: nil)
    }
    
    private func dismissWithSession(session: RecentAccountSession?) {
        guard case let .authTransfer(activeSessionsContext) = self.subject else {
            return
        }
        if let navigationController = navigationController as? NavigationController {
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
        self.displayNode = QrCodeScanScreenNode(context: self.context, presentationData: self.presentationData, controller: self, subject: self.subject)
        
        self.displayNodeDidLoad()
        
        self.codeDisposable = ((self.displayNode as! QrCodeScanScreenNode).focusedCode.get()
        |> map { code -> String? in
            return code?.message
        }
        |> distinctUntilChanged
        |> mapToSignal { code -> Signal<String?, NoError> in
            return .single(code)
            |> delay(0.5, queue: Queue.mainQueue())
        }).start(next: { [weak self] code in
            guard let strongSelf = self, !strongSelf.codeResolved else {
                return
            }
            guard let code = code else {
                return
            }
            switch strongSelf.subject {
                case let .authTransfer(activeSessionsContext):
                    if let url = URL(string: code), let parsedToken = parseAuthTransferUrl(url) {
                        strongSelf.approveDisposable.set((approveAuthTransferToken(account: strongSelf.context.account, token: parsedToken, activeSessionsContext: activeSessionsContext)
                        |> deliverOnMainQueue).start(next: { session in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.controllerNode.codeWithError = nil
                            if case let .authTransfer(activeSessionsContext) = strongSelf.subject {
                                Queue.mainQueue().after(1.5, {
                                    activeSessionsContext.loadMore()
                                })
                            }
                            strongSelf.dismissWithSession(session: session)
                        }, error: { _ in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.controllerNode.codeWithError = code
                            strongSelf.controllerNode.updateFocusedRect(nil)
                        }))
                    }
                case .peer:
                    if let _ = URL(string: code) {
                        strongSelf.controllerNode.resolveCode(code: code, completion: { [weak self] result in
                            if let strongSelf = self {
                                strongSelf.codeResolved = true
                            }
                        })
                    }
            }
        })
        
        self.controllerNode.present = { [weak self] c in
            self?.present(c, in: .window(.root))
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! QrCodeScanScreenNode).containerLayoutUpdated(layout: layout, navigationHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}

private final class QrCodeScanScreenNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private let context: AccountContext
    private var presentationData: PresentationData
    private weak var controller: QrCodeScanScreen?
    private let subject: QrCodeScanScreen.Subject
    
    private let previewNode: CameraPreviewNode
    private let fadeNode: ASDisplayNode
    private let topDimNode: ASDisplayNode
    private let bottomDimNode: ASDisplayNode
    private let leftDimNode: ASDisplayNode
    private let rightDimNode: ASDisplayNode
    private let centerDimNode: ASDisplayNode
    private let frameNode: ASImageNode
    private let galleryButtonNode: GlassButtonNode
    private let torchButtonNode: GlassButtonNode
    private let titleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let errorTextNode: ImmediateTextNode
    
    private let camera: Camera
    private let codeDisposable = MetaDisposable()
    private var torchDisposable: Disposable?
    private let resolveDisposable = MetaDisposable()
    
    fileprivate let focusedCode = ValuePromise<CameraCode?>(ignoreRepeated: true)
    private var focusedRect: CGRect?
    
    var present: (ViewController) -> Void = { _ in }
    
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
    
    init(context: AccountContext, presentationData: PresentationData, controller: QrCodeScanScreen, subject: QrCodeScanScreen.Subject) {
        self.context = context
        self.presentationData = presentationData
        self.controller = controller
        self.subject = subject
        
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
        
        self.galleryButtonNode = GlassButtonNode(icon: UIImage(bundleImageName: "Wallet/CameraGalleryIcon")!, label: nil)
        self.torchButtonNode = GlassButtonNode(icon: UIImage(bundleImageName: "Wallet/CameraFlashIcon")!, label: nil)
        
        let title: String
        var text: String
        switch subject {
            case .authTransfer:
                title = presentationData.strings.AuthSessions_AddDevice_ScanTitle
                text = presentationData.strings.AuthSessions_AddDevice_ScanInstallInfo
            case .peer:
                title = ""
                text = ""
        }
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.bold(32.0), textColor: .white)
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        
        let textFont = Font.regular(17.0)
        let boldFont = Font.bold(17.0)
        
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
        if case .peer = subject {
            self.addSubnode(self.galleryButtonNode)
        }
        self.addSubnode(self.torchButtonNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.errorTextNode)
      
        self.galleryButtonNode.addTarget(self, action: #selector(self.galleryPressed), forControlEvents: .touchUpInside)
        self.torchButtonNode.addTarget(self, action: #selector(self.torchPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.codeDisposable.dispose()
        self.torchDisposable?.dispose()
        self.resolveDisposable.dispose()
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
            let filteredCodes: [CameraCode]
            switch strongSelf.subject {
                case .authTransfer:
                    filteredCodes = codes.filter { $0.message.hasPrefix("tg://") }
                case .peer:
                    filteredCodes = codes.filter { $0.message.hasPrefix("https://t.me/") || $0.message.hasPrefix("t.me/") }
            }
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
        
        var galleryFrame = torchFrame
        if case .peer = self.subject {
            galleryFrame.origin.x -= buttonSize.width
            torchFrame.origin.x += buttonSize.width
        }
        transition.updateFrame(node: self.galleryButtonNode, frame: galleryFrame)
        transition.updateFrame(node: self.torchButtonNode, frame: torchFrame)
        
        transition.updateAlpha(node: self.textNode, alpha: controlsAlpha)
        transition.updateAlpha(node: self.errorTextNode, alpha: controlsAlpha)
        transition.updateAlpha(node: self.galleryButtonNode, alpha: controlsAlpha)
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
    
    @objc private func galleryPressed() {
        let context = self.context
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let presentError = { [weak self] in
            let alertController = textAlertController(context: context, title: nil, text: presentationData.strings.Contacts_QrCode_NoCodeFound, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
            self?.present(alertController)
        }
        
        let _ = legacyWallpaperPicker(context: context, presentationData: presentationData, subject: .qrCode).start(next: { [weak self] generator in
            let legacyController = LegacyController(presentation: .modal(animateIn: true), theme: presentationData.theme)
            legacyController.statusBar.statusBarStyle = presentationData.theme.rootController.statusBarStyle.style
            
            let controller = generator(legacyController.context)
            legacyController.bind(controller: controller)
            legacyController.deferScreenEdgeGestures = [.top]
            controller.selectionBlock = { [weak legacyController] asset, _ in
                if let asset = asset {
                    TGMediaAssetImageSignals.image(for: asset, imageType: TGMediaAssetImageTypeScreen, size: CGSize(width: 1280.0, height: 1280.0)).start(next: { image in
                        if let image = image as? UIImage {
                            let _ = (recognizeQRCode(in: image)
                            |> deliverOnMainQueue).start(next: { [weak self] result in
                                if let result = result, let strongSelf = self {
                                    strongSelf.resolveCode(code: result, completion: { result in
                                        if result {
                                            
                                        } else {
                                            presentError()
                                        }
                                    })
                                } else {
                                    presentError()
                                }
                            })
                        } else {
                            presentError()
                        }
                    }, error: { _ in
                        presentError()
                    }, completed: {
                    })
                    
                    legacyController?.dismiss()
                }
            }
            controller.dismissalBlock = { [weak legacyController] in
                if let legacyController = legacyController {
                    legacyController.dismiss()
                }
            }
            self?.present(legacyController)
        })
    }
    
    @objc private func torchPressed() {
        self.torchButtonNode.isSelected = !self.torchButtonNode.isSelected
        self.camera.setTorchActive(self.torchButtonNode.isSelected)
    }
    
    fileprivate func resolveCode(code: String, completion: @escaping (Bool) -> Void) {
        self.resolveDisposable.set((self.context.sharedContext.resolveUrl(context: self.context, peerId: nil, url: code, skipUrlAuth: false)
        |> deliverOnMainQueue).start(next: { [weak self] result in
            if let strongSelf = self {
                completion(strongSelf.openResolved(result))
            }
        }))
    }
    
    private func openResolved(_ result: ResolvedUrl) -> Bool {
        switch result {
            case .peer, .stickerPack, .join, .wallpaper, .theme:
                break
            default:
                return false
        }
        
        guard let navigationController = self.controller?.navigationController as? NavigationController else {
            return false
        }
        self.context.sharedContext.openResolvedUrl(result, context: self.context, urlContext: .generic, navigationController: navigationController, forceExternal: false, openPeer: { [weak self] peer, navigation in
            guard let strongSelf = self else {
                return
            }
            strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer), subject: nil, keepStack: .always, peekData: nil, completion: { [weak navigationController] _ in
                if let navigationController = navigationController {
                    var viewControllers = navigationController.viewControllers
                    viewControllers = viewControllers.filter { controller in
                        if controller is QrCodeScanScreen {
                            return false
                        }
                        return true
                    }
                    navigationController.setViewControllers(viewControllers, animated: false)
                }
            }))
        }, sendFile: nil,
        sendSticker: { _, _, _ in
            return false
        }, requestMessageActionUrlAuth: nil,
        joinVoiceChat: { peerId, invite, call in
        }, present: { [weak self] c, a in
            self?.controller?.present(c, in: .window(.root), with: a)
        }, dismissInput: { [weak self] in
            self?.view.endEditing(true)
        }, contentContext: nil)
        
        return true
    }
}

