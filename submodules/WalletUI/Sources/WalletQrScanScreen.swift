import Foundation
import UIKit
import AppBundle
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Camera
import GlassButtonNode
import CoreImage
import AlertUI
import WalletUrl

private func generateFrameImage() -> UIImage? {
    return generateImage(CGSize(width: 64.0, height: 64.0), contextGenerator: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(4.0)
        context.setLineCap(.round)
        
        var path = CGMutablePath();
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

public final class WalletQrScanScreen: ViewController {
    private let context: WalletContext
    private let completion: (ParsedWalletUrl) -> Void
    private var presentationData: WalletPresentationData
    
    private var codeDisposable: Disposable?
    private var inForegroundDisposable: Disposable?
    
    public init(context: WalletContext, completion: @escaping (ParsedWalletUrl) -> Void) {
        self.context = context
        self.completion = completion
        
        self.presentationData = context.presentationData
        
        let navigationBarTheme = NavigationBarTheme(buttonColor: .white, disabledButtonColor: .white, primaryTextColor: .white, backgroundColor: .clear, separatorColor: .clear, badgeBackgroundColor: .clear, badgeStrokeColor: .clear, badgeTextColor: .clear)
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: navigationBarTheme, strings: NavigationBarStrings(back: self.presentationData.strings.Wallet_Navigation_Back, close: self.presentationData.strings.Wallet_Navigation_Close)))
        
        self.statusBar.statusBarStyle = .White
        
        self.navigationPresentation = .modalInLargeLayout
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.navigationBar?.intrinsicCanTransitionInline = false
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Wallet_Navigation_Back, style: .plain, target: nil, action: nil)
        
        self.inForegroundDisposable = (context.inForeground
        |> deliverOnMainQueue).start(next: { [weak self] inForeground in
            guard let strongSelf = self else {
                return
            }
            (strongSelf.displayNode as! WalletQrScanScreenNode).updateInForeground(inForeground)
        })
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.codeDisposable?.dispose()
        self.inForegroundDisposable?.dispose()
    }
    
    @objc private func backPressed() {
        self.dismiss()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = WalletQrScanScreenNode(presentationData: self.presentationData)
        
        self.displayNodeDidLoad()
        
        self.codeDisposable = ((self.displayNode as! WalletQrScanScreenNode).focusedCode.get()
        |> map { code -> String? in
            return code?.message
        }
        |> distinctUntilChanged
        |> mapToSignal { code -> Signal<String?, NoError> in
            return .single(code) |> delay(0.5, queue: Queue.mainQueue())
        }).start(next: { [weak self] code in
            guard let strongSelf = self, let code = code else {
                return
            }
            if let url = URL(string: code), let parsedWalletUrl = parseWalletUrl(url) {
                strongSelf.completion(parsedWalletUrl)
            }
        })
        
        (self.displayNode as! WalletQrScanScreenNode).presentGallery = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.context.pickImage(present: { c in
                strongSelf.push(c)
            }, completion: { image in
                let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])!
                if let ciImage = CIImage(image: image) {
                    var options: [String: Any]
                    if ciImage.properties.keys.contains((kCGImagePropertyOrientation as String)) {
                        options = [CIDetectorImageOrientation: ciImage.properties[(kCGImagePropertyOrientation as String)] ?? 1]
                    } else {
                        options = [CIDetectorImageOrientation: 1]
                    }
                    
                    let features = detector.features(in: ciImage, options: options)
                    for case let row as CIQRCodeFeature in features {
                        guard let message = row.messageString else {
                            continue
                        }
                        if let url = URL(string: message), let parsedWalletUrl = parseWalletUrl(url) {
                            strongSelf.completion(parsedWalletUrl)
                            return
                        }
                    }
                }
                let theme = strongSelf.context.presentationData.theme
                let controller = textAlertController(alertContext: AlertControllerContext(theme: theme.alert, themeSignal: .single(theme.alert)), title: nil, text: "No valid QR code detected.", actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Wallet_Alert_OK, action: {})])
                strongSelf.present(controller, in: .window(.root))
            })
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        (self.displayNode as! WalletQrScanScreenNode).containerLayoutUpdated(layout: layout, navigationHeight: self.navigationHeight, transition: transition)
    }
}

private final class WalletQrScanScreenNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private var presentationData: WalletPresentationData

    private let previewNode: CameraPreviewNode
    private let fadeNode: ASDisplayNode
    private let topDimNode: ASDisplayNode
    private let bottomDimNode: ASDisplayNode
    private let leftDimNode: ASDisplayNode
    private let rightDimNode: ASDisplayNode
    private let frameNode: ASImageNode
    private let galleryButtonNode: GlassButtonNode
    private let torchButtonNode: GlassButtonNode
    private let titleNode: ImmediateTextNode
    
    private let camera: Camera
    private let codeDisposable = MetaDisposable()
    
    fileprivate let focusedCode = ValuePromise<CameraCode?>(ignoreRepeated: true)
    private var focusedRect: CGRect?
    
    var presentGallery: (() -> Void)?
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    init(presentationData: WalletPresentationData) {
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
        
        self.frameNode = ASImageNode()
        self.frameNode.image = generateFrameImage()
        
        self.galleryButtonNode = GlassButtonNode(icon: UIImage(bundleImageName: "Wallet/CameraGalleryIcon")!, label: nil)
        self.torchButtonNode = GlassButtonNode(icon: UIImage(bundleImageName: "Wallet/CameraFlashIcon")!, label: nil)
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: presentationData.strings.Wallet_Qr_ScanCode, font: Font.bold(32.0), textColor: .white)
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        
        self.camera = Camera(configuration: .init(preset: .hd1920x1080, position: .back, audio: false))
        
        super.init()
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.addSubnode(self.previewNode)
        self.addSubnode(self.fadeNode)
        self.addSubnode(self.topDimNode)
        self.addSubnode(self.bottomDimNode)
        self.addSubnode(self.leftDimNode)
        self.addSubnode(self.rightDimNode)
        self.addSubnode(self.frameNode)
        self.addSubnode(self.galleryButtonNode)
        self.addSubnode(self.torchButtonNode)
        self.addSubnode(self.titleNode)
      
        self.galleryButtonNode.addTarget(self, action: #selector(self.galleryPressed), forControlEvents: .touchUpInside)
        self.torchButtonNode.addTarget(self, action: #selector(self.torchPressed), forControlEvents: .touchUpInside)
    }
    
    deinit {
        self.codeDisposable.dispose()
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
            let filteredCodes = codes.filter { $0.message.hasPrefix("ton://") }
            if let code = filteredCodes.first, CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4).contains(code.boundingBox.center) {
                strongSelf.focusedCode.set(code)
                strongSelf.updateFocusedRect(code.boundingBox)
            } else {
                strongSelf.focusedCode.set(nil)
                strongSelf.updateFocusedRect(nil)
            }
        }))
    }
    
    private func updateFocusedRect(_ rect: CGRect?) {
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
        
        transition.updateFrame(node: self.topDimNode, frame: CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: dimRect.minY))
        transition.updateFrame(node: self.bottomDimNode, frame: CGRect(x: 0.0, y: dimRect.maxY, width: layout.size.width, height: max(0.0, layout.size.height - dimRect.maxY)))
        transition.updateFrame(node: self.leftDimNode, frame: CGRect(x: 0.0, y: dimRect.minY, width: max(0.0, dimRect.minX), height: dimRect.height))
        transition.updateFrame(node: self.rightDimNode, frame: CGRect(x: dimRect.maxX, y: dimRect.minY, width: max(0.0, layout.size.width - dimRect.maxX), height: dimRect.height))
        transition.updateFrame(node: self.frameNode, frame: dimRect.insetBy(dx: -2.0, dy: -2.0))
        
        let buttonSize = CGSize(width: 72.0, height: 72.0)
        transition.updateFrame(node: self.galleryButtonNode, frame: CGRect(origin: CGPoint(x: floor(layout.size.width / 2.0) - buttonSize.width - 28.0, y: dimHeight + frameSide + 50.0), size: buttonSize))
        transition.updateFrame(node: self.torchButtonNode, frame: CGRect(origin: CGPoint(x: floor(layout.size.width / 2.0) + 28.0, y: dimHeight + frameSide + 50.0), size: buttonSize))
        
        transition.updateAlpha(node: self.titleNode, alpha: controlsAlpha)
        transition.updateAlpha(node: self.galleryButtonNode, alpha: controlsAlpha)
        transition.updateAlpha(node: self.torchButtonNode, alpha: controlsAlpha)
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: layout.size.width - sideInset * 2.0, height: layout.size.height))
        let titleFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width) / 2.0), y: dimHeight - titleSize.height - titleSpacing), size: titleSize)
        transition.updateFrameAdditive(node: self.titleNode, frame: titleFrame)
    }
    
    @objc private func galleryPressed() {
        self.presentGallery?()
    }
    
    @objc private func torchPressed() {
        self.torchButtonNode.isSelected = !self.torchButtonNode.isSelected
        self.camera.setTorchActive(self.torchButtonNode.isSelected)
    }
}
