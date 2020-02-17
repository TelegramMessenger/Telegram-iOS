import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import MapKit
import TelegramPresentationData
import AccountContext
import PhotoResources
import AppBundle

public struct OpenInControllerAction {
    public let title: String
    public let action: () -> Void
    
    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
}

public final class OpenInActionSheetController: ActionSheetController {
    private var presentationDisposable: Disposable?
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    public init(context: AccountContext, item: OpenInItem, additionalAction: OpenInControllerAction? = nil, openUrl: @escaping (String) -> Void) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let theme = presentationData.theme
        let strings = presentationData.strings
        
        super.init(theme: ActionSheetControllerTheme(presentationData: presentationData))
        
        self.presentationDisposable = context.sharedContext.presentationData.start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.theme = ActionSheetControllerTheme(presentationData: presentationData)
            }
        })
        
        self._ready.set(.single(true))
        
        let invokeActionImpl: (OpenInAction) -> Void = { action in
            switch action {
            case let .openUrl(url):
                openUrl(url)
            case let .openLocation(latitude, longitude, withDirections):
                let placemark = MKPlacemark(coordinate: CLLocationCoordinate2DMake(latitude, longitude), addressDictionary: [:])
                let mapItem = MKMapItem(placemark: placemark)
                
                if withDirections {
                    let options = [ MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving ]
                    MKMapItem.openMaps(with: [MKMapItem.forCurrentLocation(), mapItem], launchOptions: options)
                } else {
                    mapItem.openInMaps(launchOptions: nil)
                }
            default:
                break
            }
        }
        
        var items: [ActionSheetItem] = []
        items.append(OpenInActionSheetItem(postbox: context.account.postbox, context: context, strings: strings, options: availableOpenInOptions(context: context, item: item), invokeAction: invokeActionImpl))
        
        if let action = additionalAction {
            items.append(ActionSheetButtonItem(title: action.title, action: { [weak self] in
                action.action()
                self?.dismissAnimated()
            }))
        }
        
        self.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: strings.Common_Cancel, action: { [weak self] in
                    self?.dismissAnimated()
                })
            ])
        ])
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDisposable?.dispose()
    }
}

private final class OpenInActionSheetItem: ActionSheetItem {
    let postbox: Postbox
    let context: AccountContext
    let strings: PresentationStrings
    let options: [OpenInOption]
    let invokeAction: (OpenInAction) -> Void
    
    init(postbox: Postbox, context: AccountContext, strings: PresentationStrings, options: [OpenInOption], invokeAction: @escaping (OpenInAction) -> Void) {
        self.postbox = postbox
        self.context = context
        self.strings = strings
        self.options = options
        self.invokeAction = invokeAction
    }
    
    func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return OpenInActionSheetItemNode(postbox: self.postbox, context: self.context, theme: theme, strings: self.strings, options: self.options, invokeAction: self.invokeAction)
    }
    
    func updateNode(_ node: ActionSheetItemNode) {
    }
}

private final class OpenInActionSheetItemNode: ActionSheetItemNode {
    let theme: ActionSheetControllerTheme
    let strings: PresentationStrings
    
    let titleNode: ASTextNode
    let scrollNode: ASScrollNode
    
    let openInNodes: [OpenInAppNode]
    
    init(postbox: Postbox, context: AccountContext, theme: ActionSheetControllerTheme, strings: PresentationStrings, options: [OpenInOption], invokeAction: @escaping (OpenInAction) -> Void) {
        self.theme = theme
        self.strings = strings
        
        let titleFont = Font.medium(floor(theme.baseFontSize * 20.0 / 17.0))
        let textFont = Font.regular(floor(theme.baseFontSize * 11.0 / 17.0))
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = true
        self.titleNode.attributedText = NSAttributedString(string: strings.Map_OpenIn, font: titleFont, textColor: theme.primaryTextColor, paragraphAlignment: .center)
        
        self.scrollNode = ASScrollNode()
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.clipsToBounds = false
        self.scrollNode.view.scrollsToTop = false
        self.scrollNode.view.delaysContentTouches = false
        self.scrollNode.scrollableDirections = [.left, .right]
        
        self.openInNodes = options.map { option in
            let node = OpenInAppNode()
            node.setup(postbox: postbox, context: context, theme: theme, option: option, invokeAction: invokeAction)
            return node
        }
        
        super.init(theme: theme)
        
        self.addSubnode(self.titleNode)
        
        if !self.openInNodes.isEmpty {
            for openInNode in openInNodes {
                self.scrollNode.addSubnode(openInNode)
            }
            self.addSubnode(self.scrollNode)
        }
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 148.0)
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        let titleSize = self.titleNode.measure(bounds.size)
        self.titleNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 16.0), size: CGSize(width: bounds.size.width, height: titleSize.height))
        
        self.scrollNode.frame = CGRect(origin: CGPoint(x: 0, y: 36.0), size: CGSize(width: bounds.size.width, height: bounds.height - 36.0))
        
        let nodeInset: CGFloat = 2.0
        let nodeSize = CGSize(width: 80.0, height: 112.0)
        var nodeOffset = nodeInset
        
        for node in self.openInNodes {
            node.frame = CGRect(origin: CGPoint(x: nodeOffset, y: 0.0), size: nodeSize)
            nodeOffset += nodeSize.width
        }
        
        if let lastNode = self.openInNodes.last {
            let contentSize = CGSize(width: lastNode.frame.maxX + nodeInset, height: self.scrollNode.frame.height)
            if self.scrollNode.view.contentSize != contentSize {
                self.scrollNode.view.contentSize = contentSize
            }
        }
    }
}

private final class OpenInAppNode : ASDisplayNode {
    private let iconNode: TransformImageNode
    private let textNode: ASTextNode
    private var action: (() -> Void)?
    
    override init() {
        self.iconNode = TransformImageNode()
        self.iconNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 60.0, height: 60.0))
        self.iconNode.isLayerBacked = true
        
        self.textNode = ASTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = true
        
        super.init()
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.textNode)
    }
    
    func setup(postbox: Postbox, context: AccountContext, theme: ActionSheetControllerTheme, option: OpenInOption, invokeAction: @escaping (OpenInAction) -> Void) {
        let textFont = Font.regular(floor(theme.baseFontSize * 11.0 / 17.0))
        self.textNode.attributedText = NSAttributedString(string: option.title, font: textFont, textColor: theme.primaryTextColor, paragraphAlignment: .center)
        
        let iconSize = CGSize(width: 60.0, height: 60.0)
        let makeLayout = self.iconNode.asyncLayout()
        let applyLayout = makeLayout(TransformImageArguments(corners: ImageCorners(radius: 16.0), imageSize: iconSize, boundingSize: iconSize, intrinsicInsets: UIEdgeInsets()))
        applyLayout()
        
        switch option.application {
            case .safari:
                if let image = UIImage(bundleImageName: "Open In/Safari") {
                    self.iconNode.setSignal(openInAppIcon(postbox: postbox, appIcon: .image(image: image)))
                }
            case .maps:
                if let image = UIImage(bundleImageName: "Open In/Maps") {
                    self.iconNode.setSignal(openInAppIcon(postbox: postbox, appIcon: .image(image: image)))
                }
            case let .other(_, identifier, _, store):
                self.iconNode.setSignal(openInAppIcon(postbox: postbox, appIcon: .resource(resource: OpenInAppIconResource(appStoreId: identifier, store: store))))
        }
        
        self.action = {
            invokeAction(option.action())
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.action?()
        }
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        self.iconNode.frame = CGRect(origin: CGPoint(x: 10.0, y: 14.0), size: CGSize(width: 60.0, height: 60.0))
        self.textNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 14.0 + 60.0 + 4.0), size: CGSize(width: bounds.size.width, height: 16.0))
    }
}
