import Foundation
import UIKit
import Display

final class EmojiTooltipView: UIView {
    let size: CGSize
    
    init(text: String) {
        self.size = CGSize()
        
        super.init(frame: CGRect())
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
