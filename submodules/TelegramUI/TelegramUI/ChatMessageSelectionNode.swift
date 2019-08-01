import Foundation
import UIKit
import AsyncDisplayKit
import TelegramPresentationData
import CheckNode

final class ChatMessageSelectionNode: ASDisplayNode {
    private let toggle: (Bool) -> Void
    
    private(set) var selected = false
    private let checkNode: CheckNode
    
    init(theme: PresentationTheme, toggle: @escaping (Bool) -> Void) {
        self.toggle = toggle
        self.checkNode = CheckNode(strokeColor: theme.list.itemCheckColors.strokeColor, fillColor: theme.list.itemCheckColors.fillColor, foregroundColor: theme.list.itemCheckColors.foregroundColor, style: .overlay)
        self.checkNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.checkNode)
        
        //self.hitTestSlop = UIEdgeInsetsMake(0.0, 42.0, 0.0, 0.0)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    func updateSelected(_ selected: Bool, animated: Bool) {
        if self.selected != selected {
            self.selected = selected
            self.checkNode.setIsChecked(selected, animated: animated)
        }
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.toggle(!self.selected)
        }
    }
    
    override func layout() {
        super.layout()
        
        let checkSize = CGSize(width: 32.0, height: 32.0)
        self.checkNode.frame = CGRect(origin: CGPoint(x: 4.0, y: floor((self.bounds.size.height - checkSize.height) / 2.0)), size: checkSize)
    }
}
