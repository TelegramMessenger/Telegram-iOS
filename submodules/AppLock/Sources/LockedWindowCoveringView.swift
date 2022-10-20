import Foundation
import Display
import TelegramPresentationData
import AsyncDisplayKit

final class LockedWindowCoveringView: WindowCoveringView {
    private let contentView: UIImageView
    
    init(theme: PresentationTheme) {
        self.contentView = UIImageView()
        
        super.init(frame: CGRect())
        
        self.backgroundColor =  theme.chatList.backgroundColor
        self.addSubview(self.contentView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        self.backgroundColor = theme.chatList.backgroundColor
    }
    
    func updateSnapshot(_ image: UIImage?) {
        if image != nil {
            self.contentView.image = image   
        }
    }
    
    override func updateLayout(_ size: CGSize) {
        self.contentView.frame = CGRect(origin: CGPoint(), size: size)
    }
}
