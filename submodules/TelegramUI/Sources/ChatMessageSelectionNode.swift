import Foundation
import UIKit
import AsyncDisplayKit
import TelegramPresentationData
import CheckNode
import TelegramCore

final class ChatMessageSelectionNode: ASDisplayNode {
    private let toggle: (Bool) -> Void
    
    private(set) var selected = false
    private let checkNode: CheckNode
    
    init(wallpaper: TelegramWallpaper, theme: PresentationTheme, toggle: @escaping (Bool) -> Void) {
        self.toggle = toggle
        
        let style: CheckNodeTheme.Style
        if wallpaper == theme.chat.defaultWallpaper, case .color = wallpaper {
            style = .plain
        } else {
            style = .overlay
        }
        
        self.checkNode = CheckNode(theme: CheckNodeTheme(theme: theme, style: style, hasInset: true))
        self.checkNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.checkNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    func updateSelected(_ selected: Bool, animated: Bool) {
        if self.selected != selected {
            self.selected = selected
            self.checkNode.setSelected(selected, animated: animated)
        }
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.toggle(!self.selected)
        }
    }
    
    func updateLayout(size: CGSize, leftInset: CGFloat) {
        let checkSize = CGSize(width: 28.0, height: 28.0)
        self.checkNode.frame = CGRect(origin: CGPoint(x: 6.0 + leftInset, y: floor((size.height - checkSize.height) / 2.0)), size: checkSize)
    }
}
