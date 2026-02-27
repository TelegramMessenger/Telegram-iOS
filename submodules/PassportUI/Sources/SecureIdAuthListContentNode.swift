import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData

final class SecureIdAuthListContentNode: ASDisplayNode, SecureIdAuthContentNode, UITextFieldDelegate {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let dateTimeFormat: PresentationDateTimeFormat
    
    private let fieldBackgroundNode: ASDisplayNode
    private let fieldNodes: [SecureIdAuthListFieldNode]
    private let headerNode: ImmediateTextNode
    
    private let deleteItem: FormControllerActionItem
    private let deleteNode: FormControllerActionItemNode
    
    private let requestLayout: () -> Void
    private var validLayout: CGFloat?
    
    init(theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, openField: @escaping (SecureIdAuthListContentField) -> Void, deleteAll: @escaping () -> Void, requestLayout: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        
        self.fieldBackgroundNode = ASDisplayNode()
        self.fieldBackgroundNode.isLayerBacked = true
        self.fieldBackgroundNode.backgroundColor = theme.list.itemBlocksBackgroundColor
        
        var fieldNodes: [SecureIdAuthListFieldNode] = []
        fieldNodes.append(SecureIdAuthListFieldNode(theme: theme, strings: strings, field: .identity, values: [], selected: {
            openField(.identity)
        }))
        fieldNodes.append(SecureIdAuthListFieldNode(theme: theme, strings: strings, field: .address, values: [], selected: {
            openField(.address)
        }))
        fieldNodes.append(SecureIdAuthListFieldNode(theme: theme, strings: strings, field: .phone, values: [], selected: {
            openField(.phone)
        }))
        fieldNodes.append(SecureIdAuthListFieldNode(theme: theme, strings: strings, field: .email, values: [], selected: {
            openField(.email)
        }))
        
        self.fieldNodes = fieldNodes
        
        self.headerNode = ImmediateTextNode()
        self.headerNode.displaysAsynchronously = false
        self.headerNode.attributedText = NSAttributedString(string: strings.Passport_PassportInformation, font: Font.regular(14.0), textColor: theme.list.sectionHeaderTextColor)
        
        self.deleteItem = FormControllerActionItem(type: .destructive, title: strings.Passport_DeletePassport, activated: {
            deleteAll()
        })
        self.deleteNode = self.deleteItem.node() as! FormControllerActionItemNode
        
        self.requestLayout = requestLayout
        
        super.init()
        
        self.addSubnode(self.headerNode)
        self.addSubnode(self.fieldBackgroundNode)
        self.addSubnode(self.deleteNode)
        self.fieldNodes.forEach(self.addSubnode)
    }
    
    func updateValues(_ values: [SecureIdValueWithContext]) {
        for fieldNode in self.fieldNodes {
            fieldNode.updateValues(values)
        }
        
        self.deleteNode.isHidden = values.isEmpty
        
        self.requestLayout()
    }
    
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> SecureIdAuthContentLayout {
        let transition = self.validLayout == nil ? .immediate : transition
        self.validLayout = width
        
        var contentHeight: CGFloat = 0.0
        
        let headerSpacing: CGFloat = 6.0
        let headerSize = self.headerNode.updateLayout(CGSize(width: width - 14.0 * 2.0, height: CGFloat.greatestFiniteMagnitude))
        transition.updateFrame(node: self.headerNode, frame: CGRect(origin: CGPoint(x: 14.0, y: 0.0), size: headerSize))
        contentHeight += headerSize.height + headerSpacing
        
        let fieldsOrigin = contentHeight
        for i in 0 ..< self.fieldNodes.count {
            let fieldHeight = self.fieldNodes[i].updateLayout(width: width, hasPrevious: i != 0, hasNext: i != self.fieldNodes.count - 1, transition: transition)
            transition.updateFrame(node: self.fieldNodes[i], frame: CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: width, height: fieldHeight)))
            contentHeight += fieldHeight
        }
        
        let fieldsHeight = contentHeight - fieldsOrigin
        
        transition.updateFrame(node: self.fieldBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: fieldsOrigin), size: CGSize(width: width, height: fieldsHeight)))
        
        let deleteSpacing: CGFloat = 32.0
        contentHeight += deleteSpacing
        
        let (preLayout, apply) = self.deleteItem.update(node: self.deleteNode, theme: self.theme, strings: self.strings, dateTimeFormat: self.dateTimeFormat, width: width, previousNeighbor: .spacer, nextNeighbor: .spacer, transition: transition)
        let deleteHeight = apply(FormControllerItemLayoutParams(maxAligningInset: preLayout.aligningInset))
        transition.updateFrame(node: self.deleteNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: width, height: deleteHeight)))
        
        contentHeight += deleteHeight
        contentHeight += deleteSpacing
        
        return SecureIdAuthContentLayout(height: contentHeight, centerOffset: floor((contentHeight) / 2.0))
    }
    
    func animateIn() {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    func didAppear() {
    }
    
    func willDisappear() {
    }
}

