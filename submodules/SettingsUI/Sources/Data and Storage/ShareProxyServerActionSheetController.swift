import Foundation
import UIKit
import Display
import TelegramCore
import Postbox
import AsyncDisplayKit
import UIKit
import SwiftSignalKit
import TelegramPresentationData
import QrCode
import ShareController

public final class ShareProxyServerActionSheetController: ActionSheetController {
    private var presentationDisposable: Disposable?
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private var isDismissed: Bool = false
        
    public init(presentationData: PresentationData, updatedPresentationData: Signal<PresentationData, NoError>, link: String) {
        let sheetTheme = ActionSheetControllerTheme(presentationData: presentationData)
        super.init(theme: sheetTheme)
        
        let presentActivityController: (Any) -> Void = { [weak self] item in
            let activityController = UIActivityViewController(activityItems: [item], applicationActivities: nil)
            if let window = self?.view.window, let rootViewController = window.rootViewController {
                activityController.popoverPresentationController?.sourceView = window
                activityController.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.size.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
                rootViewController.present(activityController, animated: true, completion: nil)
            }
        }
        
        var items: [ActionSheetItem] = []
        items.append(ProxyServerQRCodeItem(strings: presentationData.strings, link: link, ready: { [weak self] in
            self?._ready.set(.single(true))
        }))
        items.append(ActionSheetButtonItem(title: presentationData.strings.SocksProxySetup_ShareQRCode, action: { [weak self] in
            self?.dismissAnimated()
            let _ = (qrCode(string: link, color: .black, backgroundColor: .white, icon: .proxy)
            |> map { _, generator -> UIImage? in
                let imageSize = CGSize(width: 768.0, height: 768.0)
                let context = generator(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), scale: 1.0))
                return context?.generateImage()
            }
            |> deliverOnMainQueue).start(next: { image in
                if let image = image {
                    presentActivityController(image)
                }
            })
        }))
        items.append(ActionSheetButtonItem(title: presentationData.strings.SocksProxySetup_ShareLink, action: { [weak self] in
            self?.dismissAnimated()
            presentActivityController(link)
        }))
        self.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { [weak self] in
                    self?.dismissAnimated()
                })
                ])
            ])
        
        self.presentationDisposable = updatedPresentationData.start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.theme = ActionSheetControllerTheme(presentationData: presentationData)
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDisposable?.dispose()
    }
}

private final class ProxyServerQRCodeItem: ActionSheetItem {
    private let strings: PresentationStrings
    private let link: String
    private let ready: () -> Void
    
    init(strings: PresentationStrings, link: String, ready: @escaping () -> Void = {}) {
        self.strings = strings
        self.link = link
        self.ready = ready
    }
    
    func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return ProxyServerQRCodeItemNode(theme: theme, strings: self.strings, link: self.link, ready: self.ready)
    }
    
    func updateNode(_ node: ActionSheetItemNode) {
    }
}

private final class ProxyServerQRCodeItemNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    private let strings: PresentationStrings
    private let link: String
    
    private let label: ASTextNode
    private let imageNode: TransformImageNode
    
    private let ready: () -> Void
    
    private var cachedHasLabel = true
    private var cachedHasImage = true
    
    init(theme: ActionSheetControllerTheme, strings: PresentationStrings, link: String, ready: @escaping () -> Void = {}) {
        self.theme = theme
        self.strings = strings
        self.link = link
        self.ready = ready
        
        let textFont = Font.regular(floor(theme.baseFontSize * 13.0 / 17.0))
        
        self.label = ASTextNode()
        self.label.isUserInteractionEnabled = false
        self.label.maximumNumberOfLines = 0
        self.label.displaysAsynchronously = false
        self.label.truncationMode = .byTruncatingTail
        self.label.isUserInteractionEnabled = false
        self.label.attributedText = NSAttributedString(string: strings.SocksProxySetup_ShareQRCodeInfo, font: textFont, textColor: self.theme.secondaryTextColor, paragraphAlignment: .center)
        
        self.imageNode = TransformImageNode()
        self.imageNode.clipsToBounds = true
        self.imageNode.setSignal(qrCode(string: link, color: .black, backgroundColor: .white, icon: .proxy) |> map { $0.1 }, attemptSynchronously: true)
        self.imageNode.cornerRadius = 14.0
        
        super.init(theme: theme)
        
        self.addSubnode(self.label)
        self.addSubnode(self.imageNode)
    }
    
    override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let imageInset: CGFloat = 44.0
        let side = constrainedSize.width - imageInset * 2.0
        var imageSize = CGSize(width: side, height: side)
        
        let makeLayout = self.imageNode.asyncLayout()
        let apply = makeLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: nil))
        apply()
        
        var labelSize = self.label.measure(CGSize(width: max(1.0, constrainedSize.width - 64.0), height: constrainedSize.height))
        
        self.cachedHasImage = constrainedSize.width < constrainedSize.height
        if !self.cachedHasImage {
            imageSize = CGSize()
        }
        
        self.ready()
        
        self.cachedHasLabel = constrainedSize.height > 480 || !self.cachedHasImage
        if !self.cachedHasLabel {
            labelSize = CGSize()
        }
        let size = CGSize(width: constrainedSize.width, height: 14.0 + (labelSize.height > 0.0 ? labelSize.height + 14.0 : 0.0) + (imageSize.height > 0.0 ? imageSize.height + 14.0 : 8.0))
        
        let inset: CGFloat = 32.0
        let spacing: CGFloat = 18.0
        if self.cachedHasLabel {
            labelSize = self.label.measure(CGSize(width: max(1.0, size.width - inset * 2.0), height: size.height))
            self.label.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - labelSize.width) / 2.0), y: spacing), size: labelSize)
        } else {
            labelSize = CGSize()
        }
        
        if !self.cachedHasImage {
            imageSize = CGSize()
        } else {
            imageSize =  CGSize(width: size.width - imageInset * 2.0, height: size.width - imageInset * 2.0)
        }
        let imageOrigin = CGPoint(x: imageInset, y: self.label.frame.maxY + spacing - 4.0)
        self.imageNode.frame = CGRect(origin: imageOrigin, size: imageSize)

        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }
}
