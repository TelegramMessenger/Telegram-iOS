import Foundation
import AsyncDisplayKit

private let checkedImage = UIImage(bundleImageName: "Chat/Message/SelectionChecked")?.precomposed()
private let uncheckedImage = UIImage(bundleImageName: "Chat/Message/SelectionUnchecked")?.precomposed()

final class ChatMessageSelectionNode: ASDisplayNode {
    private let toggle: () -> Void
    
    private var selected = false
    private let checkNode: ASImageNode
    
    init(toggle: @escaping () -> Void) {
        self.toggle = toggle
        self.checkNode = ASImageNode()
        self.checkNode.displaysAsynchronously = false
        self.checkNode.displayWithoutProcessing = true
        self.checkNode.isLayerBacked = true
        
        super.init()
        
        self.checkNode.image = uncheckedImage
        self.addSubnode(self.checkNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    func updateSelected(_ selected: Bool, animated: Bool) {
        if self.selected != selected {
            self.selected = selected
            self.checkNode.image = selected ? checkedImage : uncheckedImage
        }
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.toggle()
        }
    }
    
    override func layout() {
        super.layout()
        
        let checkSize = self.checkNode.measure(CGSize(width: 200.0, height: 200.0))
        self.checkNode.frame = CGRect(origin: CGPoint(x: 4.0, y: floor((self.bounds.size.height - checkSize.height) / 2.0)), size: checkSize)
    }
}
