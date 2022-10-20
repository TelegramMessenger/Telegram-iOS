import Foundation
import UIKit
import Display
import TelegramPresentationData

final class ChatListTitleLockView: UIView {
    private let topView: UIImageView
    private let bottomView: UIImageView
    
    override init(frame: CGRect) {
        self.topView = UIImageView()
        self.bottomView = UIImageView()
        
        super.init(frame: frame)
        
        self.addSubview(self.topView)
        self.addSubview(self.bottomView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        self.topView.image = PresentationResourcesChatList.lockTopUnlockedImage(theme)
        self.bottomView.image = PresentationResourcesChatList.lockBottomUnlockedImage(theme)
        self.layoutItems()
    }
    
    private func layoutItems() {
        self.topView.frame = CGRect(x: 7.0, y: 0.0, width: 7.0, height: 6.0)
        self.bottomView.frame = CGRect(x: 0.0, y: 6.0, width: 10.0, height: 8.0)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.layoutItems()
    }
}
