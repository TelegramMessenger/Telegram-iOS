import Foundation
import Display
import TelegramCore
import Postbox
import AsyncDisplayKit
import UIKit
import SwiftSignalKit

public final class ShareProxyServerActionSheetController: ActionSheetController {
    private var presentationDisposable: Disposable?
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private var isDismissed: Bool = false
        
    public init(theme: PresentationTheme, strings: PresentationStrings, updatedPresentationData: Signal<(theme: PresentationTheme, strings: PresentationStrings), NoError>, link: String) {
        let sheetTheme = ActionSheetControllerTheme(presentationTheme: theme)
        super.init(theme: sheetTheme)
        
        self._ready.set(.single(true))
        
        let presentActivityController: (Any) -> Void = { [weak self] item in
            let activityController = UIActivityViewController(activityItems: [item], applicationActivities: nil)
            if let window = self?.view.window, let rootViewController = window.rootViewController {
                activityController.popoverPresentationController?.sourceView = window
                activityController.popoverPresentationController?.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.size.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
                rootViewController.present(activityController, animated: true, completion: nil)
            }
        }
        
        var items: [ActionSheetItem] = []
        items.append(ProxyServerQRCodeItem(strings: strings, link: link))
        items.append(ActionSheetButtonItem(title: "Share QR Code", action: { [weak self] in
            self?.dismissAnimated()
            let _ = (qrCode(string: link, color: .black, backgroundColor: .white)
            |> map { generator -> UIImage? in
                let imageSize = CGSize(width: 512.0, height: 512.0)
                let context = generator(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))
                return context?.generateImage()
            }
            |> deliverOnMainQueue).start(next: { image in
                if let image = image {
                    presentActivityController(image)
                }
            })
        }))
        items.append(ActionSheetButtonItem(title: "Share Link", action: { [weak self] in
            self?.dismissAnimated()
            presentActivityController(link)
        }))
        self.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: strings.Common_Cancel, action: { [weak self] in
                    self?.dismissAnimated()
                })
                ])
            ])
        
        self.presentationDisposable = updatedPresentationData.start(next: { [weak self] theme, strings in
            if let strongSelf = self {
                strongSelf.theme = ActionSheetControllerTheme(presentationTheme: theme)
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
    
    init(strings: PresentationStrings, link: String) {
        self.strings = strings
        self.link = link
    }
    
    func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return ProxyServerQRCodeItemNode(theme: theme, strings: self.strings, link: self.link)
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
    
    init(theme: ActionSheetControllerTheme, strings: PresentationStrings, link: String) {
        self.theme = theme
        self.strings = strings
        self.link = link
        
        self.label = ASTextNode()
        self.label.isUserInteractionEnabled = false
        self.label.maximumNumberOfLines = 0
        self.label.displaysAsynchronously = false
        self.label.truncationMode = .byTruncatingTail
        self.label.isUserInteractionEnabled = false
        self.label.attributedText = NSAttributedString(string: "Your friends can add this proxy by scanning this code with phone or in-app camera.", font: ActionSheetTextNode.defaultFont, textColor: self.theme.secondaryTextColor, paragraphAlignment: .center)
        
        self.imageNode = TransformImageNode()
        self.imageNode.setSignal(qrCode(string: link, color: self.theme.primaryTextColor))
        
        super.init(theme: theme)
        
        self.addSubnode(self.label)
        self.addSubnode(self.imageNode)
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let labelSize = self.label.measure(CGSize(width: max(1.0, constrainedSize.width - 64.0), height: constrainedSize.height))
        return CGSize(width: constrainedSize.width, height: 14.0 + labelSize.height + 14.0 + constrainedSize.width - 88.0 + 14.0)
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        let inset: CGFloat = 32.0
        let imageInset: CGFloat = 44.0
        let spacing: CGFloat = 18.0
        
        let labelSize = self.label.measure(CGSize(width: max(1.0, size.width - inset * 2.0), height: size.height))
        self.label.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - labelSize.width) / 2.0), y: spacing), size: labelSize)
        
        let imageFrame = CGRect(x: imageInset, y: self.label.frame.maxY + spacing - 4.0, width: size.width - imageInset * 2.0, height: size.width - imageInset * 2.0)
        
        let makeLayout = self.imageNode.asyncLayout()
        let apply = makeLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageFrame.size, boundingSize: imageFrame.size, intrinsicInsets: UIEdgeInsets(), emptyColor: nil))
        apply()
        
        self.imageNode.frame = imageFrame
    }
}
