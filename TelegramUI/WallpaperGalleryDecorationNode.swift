import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox

final class WallpaperOptionButtonNode: HighlightTrackingButtonNode {
    private let backgroundNode: ASDisplayNode
    private let checkNode: CheckNode
    private let textNode: ASTextNode
    
    private var _isSelected: Bool = false
    override var isSelected: Bool {
        get {
            return self._isSelected
        }
        set {
            self._isSelected = newValue
            self.checkNode.setIsChecked(newValue, animated: false)
        }
    }
    
    init(title: String) {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.3)
        self.backgroundNode.cornerRadius = 8.0
        self.checkNode = CheckNode(strokeColor: .white, fillColor: .white, foregroundColor: .black, style: .plain)
        self.checkNode.isUserInteractionEnabled = false
        self.textNode = ASTextNode()
        self.textNode.attributedText = NSAttributedString(string: title, font: Font.regular(13), textColor: .white)
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.checkNode)
        self.addSubnode(self.textNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.backgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.backgroundNode.alpha = 0.4
                    
                    strongSelf.checkNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.checkNode.alpha = 0.4
                    
                    strongSelf.textNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.textNode.alpha = 0.4
                } else {
                    strongSelf.backgroundNode.alpha = 1.0
                    strongSelf.backgroundNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    
                    strongSelf.checkNode.alpha = 1.0
                    strongSelf.checkNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    
                    strongSelf.textNode.alpha = 1.0
                    strongSelf.textNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    func setSelected(_ selected: Bool, animated: Bool = false) {
        self._isSelected = selected
        self.checkNode.setIsChecked(selected, animated: animated)
    }
    
    func setEnabled(_ enabled: Bool) {
        self.alpha = enabled ? 1.0 : 0.3
        self.isUserInteractionEnabled = enabled
    }
    
    //    override func measure(_ constrainedSize: CGSize) -> CGSize {
    //        let size = self.textNode.measure(constrainedSize)
    //        return CGSize(width: size.width + 56.0, height: 30.0)
    //    }
    
    override func layout() {
        super.layout()
        
        self.backgroundNode.frame = self.bounds
        
        let checkSize = CGSize(width: 32.0, height: 32.0)
        self.checkNode.frame = CGRect(origin: CGPoint(x: 5.0, y: -1.0), size: checkSize)
        
        self.textNode.frame = CGRect(x: 39.0, y: 6.0 + UIScreenPixel, width: 100.0, height: 20.0)
    }
}

final class WallpaperGalleryDecorationNode: ASDisplayNode {
    private let dismiss: () -> Void
    private let apply: () -> Void
    
//    private var messageNodes: [ListViewItemNode]?
//    private var blurredButtonNode: WallpaperOptionButtonNode?
//    private var motionButtonNode: WallpaperOptionButtonNode?
//    private var toolbarNode: WallpaperGalleryToolbarNode?
    
    init(source: WallpaperListSource, dismiss: @escaping () -> Void, apply: @escaping () -> Void) {
        self.dismiss = dismiss
        self.apply = apply
        
        super.init()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if result != self.view {
            return result
        } else {
            return nil
        }
    }
}
