import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore

private let passwordFont = Font.regular(16.0)
private let buttonFont = Font.regular(17.0)

final class SecureIdAuthFormContentNode: ASDisplayNode, SecureIdAuthContentNode, UITextFieldDelegate {
    private let fieldBackgroundNode: ASDisplayNode
    private let fieldNodes: [SecureIdAuthFormFieldNode]
    
    private var validLayout: CGFloat?
    
    init(theme: PresentationTheme, strings: PresentationStrings, form: SecureIdForm, openField: @escaping (SecureIdRequestedFormField) -> Void) {
        self.fieldBackgroundNode = ASDisplayNode()
        self.fieldBackgroundNode.isLayerBacked = true
        self.fieldBackgroundNode.backgroundColor = theme.list.itemBlocksBackgroundColor
        
        var fieldNodes: [SecureIdAuthFormFieldNode] = []
        
        for type in form.requestedFields {
            fieldNodes.append(SecureIdAuthFormFieldNode(theme: theme, strings: strings, type: type, values: form.values, selected: {
                openField(type)
            }))
        }
        
        self.fieldNodes = fieldNodes
        
        super.init()
        
        self.addSubnode(self.fieldBackgroundNode)
        self.fieldNodes.forEach(self.addSubnode)
    }
    
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> SecureIdAuthContentLayout {
        let transition = self.validLayout == nil ? .immediate : transition
        self.validLayout = width
        
        var contentHeight: CGFloat = 0.0
        
        let fieldsOrigin = contentHeight
        for i in 0 ..< self.fieldNodes.count {
            let fieldHeight = self.fieldNodes[i].updateLayout(width: width, hasPrevious: i != 0, hasNext: i != self.fieldNodes.count - 1, transition: transition)
            transition.updateFrame(node: self.fieldNodes[i], frame: CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: width, height: fieldHeight)))
            contentHeight += fieldHeight
        }
        
        let fieldsHeight = contentHeight - fieldsOrigin
        
        transition.updateFrame(node: self.fieldBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: fieldsOrigin), size: CGSize(width: width, height: fieldsHeight)))
        
        return SecureIdAuthContentLayout(height: contentHeight, centerOffset: floor((contentHeight) / 2.0) - 34.0)
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

