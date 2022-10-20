import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import TelegramStringFormatting
import RadialStatusNode
import PhotoResources

private let textFont = Font.regular(16.0)
private let labelFont = Font.regular(13.0)

enum SecureIdValueFormFileItemLabel {
    case timestamp
    case error(String)
    case text(String)
}

private enum RevealOptionKey: Int32 {
    case delete
}

final class SecureIdValueFormFileItem: FormControllerItem {
    let account: Account
    let context: SecureIdAccessContext
    let document: SecureIdVerificationDocument?
    let placeholder: UIImage?
    let title: String
    let label: SecureIdValueFormFileItemLabel
    let activated: () -> Void
    let deleted: () -> Void
    
    init(account: Account, context: SecureIdAccessContext, document: SecureIdVerificationDocument?, placeholder: UIImage?, title: String, label: SecureIdValueFormFileItemLabel, activated: @escaping () -> Void, deleted: @escaping () -> Void) {
        self.account = account
        self.context = context
        self.document = document
        self.placeholder = placeholder
        self.title = title
        self.label = label
        self.activated = activated
        self.deleted = deleted
    }
    
    func node() -> ASDisplayNode & FormControllerItemNode {
        return SecureIdValueFormFileItemNode()
    }
    
    func update(node: ASDisplayNode & FormControllerItemNode, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, width: CGFloat, previousNeighbor: FormControllerItemNeighbor, nextNeighbor: FormControllerItemNeighbor, transition: ContainedViewLayoutTransition) -> (FormControllerItemPreLayout, (FormControllerItemLayoutParams) -> CGFloat) {
        guard let node = node as? SecureIdValueFormFileItemNode else {
            assertionFailure()
            return (FormControllerItemPreLayout(aligningInset: 0.0), { _ in
                return 0.0
            })
        }
        return node.updateInternal(item: self, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, width: width, previousNeighbor: previousNeighbor, nextNeighbor: nextNeighbor, transition: transition)
    }
}

final class SecureIdValueFormFileItemNode: FormEditableBlockItemNode<SecureIdValueFormFileItem> {
    private let titleNode: ImmediateTextNode
    private let labelNode: ImmediateTextNode
    let imageNode: TransformImageNode
    private let placeholderNode: ASImageNode
    private let statusNode: RadialStatusNode
    
    private(set) var item: SecureIdValueFormFileItem?
    
    init() {
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.labelNode = ImmediateTextNode()
        self.labelNode.maximumNumberOfLines = 1
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.displaysAsynchronously = false
        
        self.imageNode = TransformImageNode()
        self.imageNode.isUserInteractionEnabled = false
        
        self.placeholderNode = ASImageNode()
        self.placeholderNode.isUserInteractionEnabled = false
        self.placeholderNode.displaysAsynchronously = false
        self.placeholderNode.displayWithoutProcessing = true
        self.placeholderNode.contentMode = .center
        
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.5))
        
        super.init(selectable: true, topSeparatorInset: .custom(92))
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.imageNode)
        self.addSubnode(self.placeholderNode)
        self.addSubnode(self.statusNode)
    }
    
    override func update(item: SecureIdValueFormFileItem, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, width: CGFloat, previousNeighbor: FormControllerItemNeighbor, nextNeighbor: FormControllerItemNeighbor, transition: ContainedViewLayoutTransition) -> (FormControllerItemPreLayout, (FormControllerItemLayoutParams) -> CGFloat) {
        var resourceUpdated = false
        if let previousItem = self.item {
            if let previousDocument = previousItem.document, let document = item.document {
                resourceUpdated = !previousDocument.resource.isEqual(to: document.resource)
            } else if (previousItem.document != nil) != (item.document != nil) {
                resourceUpdated = true
            }
        } else {
            resourceUpdated = true
        }
        self.item = item
        
        self.placeholderNode.image = item.placeholder
        
        var progress: CGFloat?
        if let document = item.document {
            switch document {
                case .remote:
                    break
                case let .local(local):
                    if case let .uploading(value) = local.state {
                        progress = CGFloat(value)
                    }
            }
            self.imageNode.isHidden = false
            self.placeholderNode.isHidden = true
            
            self.setRevealOptions((left: [], right: [ItemListRevealOption(key: RevealOptionKey.delete.rawValue, title: strings.Common_Delete, icon: .none, color: theme.list.itemDisclosureActions.destructive.fillColor, textColor: theme.list.itemDisclosureActions.destructive.foregroundColor)]))
        } else {
            self.imageNode.isHidden = true
            self.placeholderNode.isHidden = false
            
            self.setRevealOptions((left: [], right: []))
        }
        
        let progressState: RadialStatusNodeState
        if let progress = progress {
            progressState = .progress(color: .white, lineWidth: nil, value: progress, cancelEnabled: false, animateRotation: true)
        } else {
            progressState = .none
        }
        self.statusNode.transitionToState(progressState, completion: {})
        
        let revealOffset = self.revealOffset
        
        let imageSize = CGSize(width: 60.0, height: 44.0)
        let progressSize: CGFloat = 32.0
        let imageFrame = CGRect(origin: CGPoint(x: 10.0 + revealOffset, y: 10.0), size: imageSize)
        transition.updateFrame(node: self.imageNode, frame: imageFrame)
        if let image = self.placeholderNode.image {
            transition.updateFrame(node: self.placeholderNode, frame: CGRect(origin: CGPoint(x: imageFrame.minX + floor((imageFrame.width - image.size.width) / 2.0), y: imageFrame.minY + floor((imageFrame.height - image.size.height) / 2.0)), size: image.size))
        }
        transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(x: imageFrame.minX + floor((imageFrame.width - progressSize) / 2.0), y: imageFrame.minY + floor((imageFrame.height - progressSize) / 2.0)), size: CGSize(width: progressSize, height: progressSize)))
        let makeLayout = self.imageNode.asyncLayout()
        makeLayout(TransformImageArguments(corners: ImageCorners(radius: 6.0), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: theme.list.mediaPlaceholderColor))()
        if resourceUpdated {
            if let resource = item.document?.resource {
                self.imageNode.setSignal(securePhoto(account: item.account, resource: resource, accessContext: item.context))
            } else {
                self.imageNode.setSignal(.single({ _ in return nil }))
            }
        }
        
        let leftInset: CGFloat = 92.0
        self.titleNode.attributedText = NSAttributedString(string: item.title, font: textFont, textColor: theme.list.itemPrimaryTextColor)
        let titleSize = self.titleNode.updateLayout(CGSize(width: width - leftInset - 16.0, height: CGFloat.greatestFiniteMagnitude))
        
        switch item.label {
            case .timestamp:
                self.labelNode.maximumNumberOfLines = 1
                if let document = item.document {
                    self.labelNode.attributedText = NSAttributedString(string: stringForFullDate(timestamp: document.timestamp, strings: strings, dateTimeFormat: dateTimeFormat), font: labelFont, textColor: theme.list.itemSecondaryTextColor)
                }
            case let .error(text):
                self.labelNode.maximumNumberOfLines = 40
                self.labelNode.attributedText = NSAttributedString(string: text, font: labelFont, textColor: theme.list.freeTextErrorColor)
            case let .text(text):
                self.labelNode.maximumNumberOfLines = 40
                self.labelNode.attributedText = NSAttributedString(string: text, font: labelFont, textColor: theme.list.itemSecondaryTextColor)
        }
        let labelSize = self.labelNode.updateLayout(CGSize(width: width - leftInset - 16.0, height: CGFloat.greatestFiniteMagnitude))
        
        return (FormControllerItemPreLayout(aligningInset: 0.0), { params in
            transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + revealOffset, y: 14.0), size: titleSize))
            let labelFrame = CGRect(origin: CGPoint(x: leftInset + revealOffset, y: 36.0), size: labelSize)
            transition.updateFrame(node: self.labelNode, frame: labelFrame)
            
            return max(64.0, labelFrame.maxY + 8.0)
        })
    }
    
    override func selected() {
        self.item?.activated()
    }
    
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        if let _ = self.item {
            let progressSize: CGFloat = 32.0
            let imageFrame = CGRect(origin: CGPoint(x: 10.0 + offset, y: self.imageNode.frame.minY), size: self.imageNode.frame.size)
            transition.updateFrame(node: self.imageNode, frame: imageFrame)
            if let image = self.placeholderNode.image {
                transition.updateFrame(node: self.placeholderNode, frame: CGRect(origin: CGPoint(x: imageFrame.minX + floor((imageFrame.width - image.size.width) / 2.0), y: self.placeholderNode.frame.minY), size: image.size))
            }
            transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(x: imageFrame.minX + floor((imageFrame.width - progressSize) / 2.0), y: self.statusNode.frame.minY), size: self.statusNode.frame.size))
            
            let leftInset: CGFloat = 92.0
            transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + offset, y: self.titleNode.frame.minY), size: self.titleNode.frame.size))
            transition.updateFrame(node: self.labelNode, frame: CGRect(origin: CGPoint(x: leftInset + offset, y: self.labelNode.frame.minY), size: self.labelNode.frame.size))
        }
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        if let item = self.item {
            switch option.key {
                case RevealOptionKey.delete.rawValue:
                    item.deleted()
                default:
                    break
            }
        }
    }
}
