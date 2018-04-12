import Foundation
import AsyncDisplayKit
import Display
import TelegramCore

private let textFont = Font.regular(17.0)

final class SecureIdValueFormFileItem: FormControllerItem {
    let account: Account
    let context: SecureIdAccessContext
    let document: SecureIdVerificationDocument
    let title: String
    let activated: () -> Void
    
    init(account: Account, context: SecureIdAccessContext, document: SecureIdVerificationDocument, title: String, activated: @escaping () -> Void) {
        self.account = account
        self.context = context
        self.document = document
        self.title = title
        self.activated = activated
    }
    
    func node() -> ASDisplayNode & FormControllerItemNode {
        return SecureIdValueFormFileItemNode()
    }
    
    func update(node: ASDisplayNode & FormControllerItemNode, theme: PresentationTheme, strings: PresentationStrings, width: CGFloat, previousNeighbor: FormControllerItemNeighbor, nextNeighbor: FormControllerItemNeighbor, transition: ContainedViewLayoutTransition) -> (FormControllerItemPreLayout, (FormControllerItemLayoutParams) -> CGFloat) {
        guard let node = node as? SecureIdValueFormFileItemNode else {
            assertionFailure()
            return (FormControllerItemPreLayout(aligningInset: 0.0), { _ in
                return 0.0
            })
        }
        return node.updateInternal(item: self, theme: theme, strings: strings, width: width, previousNeighbor: previousNeighbor, nextNeighbor: nextNeighbor, transition: transition)
    }
}

final class SecureIdValueFormFileItemNode: FormBlockItemNode<SecureIdValueFormFileItem> {
    private let titleNode: ImmediateTextNode
    let imageNode: TransformImageNode
    private let statusNode: RadialStatusNode
    
    private(set) var item: SecureIdValueFormFileItem?
    
    init() {
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.isLayerBacked = true
        self.titleNode.displaysAsynchronously = false
        
        self.imageNode = TransformImageNode()
        self.imageNode.isUserInteractionEnabled = false
        
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.5))
        
        super.init(selectable: true, topSeparatorInset: .custom(92))
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.imageNode)
        self.addSubnode(self.statusNode)
    }
    
    override func update(item: SecureIdValueFormFileItem, theme: PresentationTheme, strings: PresentationStrings, width: CGFloat, previousNeighbor: FormControllerItemNeighbor, nextNeighbor: FormControllerItemNeighbor, transition: ContainedViewLayoutTransition) -> (FormControllerItemPreLayout, (FormControllerItemLayoutParams) -> CGFloat) {
        var resourceUpdated = false
        if let previousItem = self.item {
            resourceUpdated = !previousItem.document.resource.isEqual(to: item.document.resource)
        } else {
            resourceUpdated = true
        }
        self.item = item
        
        var progress: CGFloat?
        switch item.document {
            case .remote:
                break
            case let .local(local):
                if case let .uploading(value) = local.state {
                    progress = CGFloat(value)
                }
        }
        
        let progressState: RadialStatusNodeState
        if let progress = progress {
            progressState = .progress(color: .white, value: progress, cancelEnabled: false)
        } else {
            progressState = .none
        }
        self.statusNode.transitionToState(progressState, completion: {})
        
        let imageSize = CGSize(width: 60.0, height: 44.0)
        let progressSize: CGFloat = 32.0
        let imageFrame = CGRect(origin: CGPoint(x: 10.0, y: 10.0), size: imageSize)
        transition.updateFrame(node: self.imageNode, frame: imageFrame)
        transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(x: imageFrame.minX + floor((imageFrame.width - progressSize) / 2.0), y: imageFrame.minY + floor((imageFrame.height - progressSize) / 2.0)), size: CGSize(width: progressSize, height: progressSize)))
        let makeLayout = self.imageNode.asyncLayout()
        makeLayout(TransformImageArguments(corners: ImageCorners(radius: 6.0), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
        if resourceUpdated {
            self.imageNode.setSignal(securePhoto(account: item.account, resource: item.document.resource, accessContext: item.context))
        }
        
        let leftInset: CGFloat = 92.0
        self.titleNode.attributedText = NSAttributedString(string: item.title, font: textFont, textColor: theme.list.itemPrimaryTextColor)
        let titleSize = self.titleNode.updateLayout(CGSize(width: width - leftInset - 16.0, height: CGFloat.greatestFiniteMagnitude))
        
        return (FormControllerItemPreLayout(aligningInset: 0.0), { params in
            transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset, y: 24.0), size: titleSize))
            return 64.0
        })
    }
    
    override func selected() {
        self.item?.activated()
    }
}
