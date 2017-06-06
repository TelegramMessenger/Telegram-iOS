import Foundation
import AsyncDisplayKit
import Display

final class ThemeGalleryToolbarNode: ASDisplayNode {
    private let cancelButton = HighlightableButtonNode()
    private let doneButton = HighlightableButtonNode()
    private let separatorNode = ASDisplayNode()
    private let topSeparatorNode = ASDisplayNode()
    
    var cancel: (() -> Void)?
    var done: (() -> Void)?
    
    override init() {
        super.init()
        
        self.addSubnode(self.cancelButton)
        self.addSubnode(self.doneButton)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.topSeparatorNode)
        
        self.backgroundColor = UIColor(rgb: 0xeaebeb)
        self.separatorNode.backgroundColor = .black
        self.topSeparatorNode.backgroundColor = .black
        
        self.cancelButton.setTitle("Cancel", with: Font.regular(17.0), with: .black, for: [])
        self.doneButton.setTitle("Set", with: Font.regular(17.0), with: .black, for: [])
        
        self.cancelButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.cancelButton.backgroundColor = UIColor(rgb: 0xd4d4d4)
                } else {
                    UIView.animate(withDuration: 0.3, animations: {
                        strongSelf.cancelButton.backgroundColor = .clear
                    })
                }
            }
        }
        
        self.doneButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.doneButton.backgroundColor = UIColor(rgb: 0xd4d4d4)
                } else {
                    UIView.animate(withDuration: 0.3, animations: {
                        strongSelf.doneButton.backgroundColor = .clear
                    })
                }
            }
        }
        
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
        self.doneButton.addTarget(self, action: #selector(self.donePressed), forControlEvents: .touchUpInside)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.cancelButton.frame = CGRect(origin: CGPoint(), size: CGSize(width: floor(size.width / 2.0), height: size.height))
        self.doneButton.frame = CGRect(origin: CGPoint(x: floor(size.width / 2.0), y: 0.0), size: CGSize(width: size.width - floor(size.width / 2.0), height: size.height))
        self.separatorNode.frame = CGRect(origin: CGPoint(x: floor(size.width / 2.0), y: 0.0), size: CGSize(width: UIScreenPixel, height: size.height))
        self.topSeparatorNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: UIScreenPixel))
    }
    
    @objc func cancelPressed() {
        self.cancel?()
    }
    
    @objc func donePressed() {
        self.done?()
    }
}
