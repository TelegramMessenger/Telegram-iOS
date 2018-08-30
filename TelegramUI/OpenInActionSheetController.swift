import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

final class OpenInActionSheetController: ActionSheetController {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let openUrl: (String) -> Void
    
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    
    init(postbox: Postbox, applicationContext: TelegramApplicationContext, theme: PresentationTheme, strings: PresentationStrings, item: OpenInItem, openUrl: @escaping (String) -> Void) {
        self.theme = theme
        self.strings = strings
        self.openUrl = openUrl
        
        super.init(theme: ActionSheetControllerTheme(presentationTheme: theme))
        
        self._ready.set(.single(true))
        
        var items: [ActionSheetItem] = []
        items.append(OpenInActionSheetItem(postbox: postbox, applicationContext: applicationContext, strings: strings, options: availableOpenInOptions(applicationContext: applicationContext, item: item)))
        self.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: strings.Common_Cancel, action: { [weak self] in
                    self?.dismissAnimated()
                }),
                ])
            ])
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class OpenInActionSheetItem: ActionSheetItem {
    let postbox: Postbox
    let applicationContext: TelegramApplicationContext
    let strings: PresentationStrings
    let options: [OpenInOption]
    
    init(postbox: Postbox, applicationContext: TelegramApplicationContext, strings: PresentationStrings, options: [OpenInOption]) {
        self.postbox = postbox
        self.applicationContext = applicationContext
        self.strings = strings
        self.options = options
    }
    
    func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        return OpenInActionSheetItemNode(postbox: self.postbox, applicationContext: self.applicationContext, theme: theme, strings: self.strings, options: self.options)
    }
    
    func updateNode(_ node: ActionSheetItemNode) {
    }
}

private let titleFont = Font.medium(20.0)
private let textFont = Font.regular(11.0)

private final class OpenInActionSheetItemNode: ActionSheetItemNode {
    private let theme: ActionSheetControllerTheme
    private let strings: PresentationStrings
    
    private let titleNode: ASTextNode
    private let scrollNode: ASScrollNode
    
    private let openInNodes: [OpenInAppNode]
    
    init(postbox: Postbox, applicationContext: TelegramApplicationContext, theme: ActionSheetControllerTheme, strings: PresentationStrings, options: [OpenInOption]) {
        self.theme = theme
        self.strings = strings
        
        self.titleNode = ASTextNode()
        self.titleNode.isLayerBacked = true
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
            node.setup(postbox: postbox, applicationContext: applicationContext, theme: theme, option: option)
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
        self.textNode.isLayerBacked = true
        self.textNode.displaysAsynchronously = true
        
        super.init()
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.textNode)
    }
    
    func setup(postbox: Postbox, applicationContext: TelegramApplicationContext, theme: ActionSheetControllerTheme, option: OpenInOption) {
        self.textNode.attributedText = NSAttributedString(string: option.title, font: textFont, textColor: theme.primaryTextColor, paragraphAlignment: .center)
        
        let iconSize = CGSize(width: 60.0, height: 60.0)
        let makeLayout = self.iconNode.asyncLayout()
        let applyLayout = makeLayout(TransformImageArguments(corners: ImageCorners(radius: 16.0), imageSize: iconSize, boundingSize: iconSize, intrinsicInsets: UIEdgeInsets()))
        applyLayout()
        
        //option.a
        
//        switch option.action {
//            case .o
////            case .safari:
////                self.iconNode.setSignal(openInAppIcon(postbox: postbox, appIcon: nil))
////                self.action = {
////                    applicationContext.applicationBindings.openUrl("https://telegram.org")
////                }
////    //            //self.iconNode.setSignal(
////    //        case .maps:
////    //            nil
////            case let .external(identifier, _, _):
////                self.iconNode.setSignal(openInAppIcon(postbox: postbox, appIcon: OpenInAppIconResource(appStoreId: identifier)))
////                self.action = {
////                    applicationContext.applicationBindings.openUrl("googlechromes://telegram.org")
////                }
////            default:
////                break
////        }
//        }
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
