import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

final class ChatMessageDeliveryFailedNode: ASImageNode {
    private let tapped: () -> Void
    private var theme: PresentationTheme?
    
    init(tapped: @escaping () -> Void) {
        self.tapped = tapped
        
        super.init()
        
        self.displaysAsynchronously = false
        self.displayWithoutProcessing = true
        self.isUserInteractionEnabled = true
    }
    
    override func didLoad() {
        super.didLoad()
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.tapped()
        }
    }
    
    func updateLayout(theme: PresentationTheme) -> CGSize {
        if self.theme !== theme {
            self.theme = theme
            self.image = PresentationResourcesChat.chatBubbleDeliveryFailedIcon(theme)
        }
        
        return CGSize(width: 22.0, height: 22.0)
    }
}
