import UIKit
import Display

private let topLockedImage = generateTintedImage(image: UIImage(bundleImageName: "Chat List/LockLockedTop"), color: UIColor(0x007ee5))
private let topUnlockedImage = UIImage(bundleImageName: "Chat List/LockUnlockedTop")?.preloaded()
private let bottomLockedImage = generateTintedImage(image: UIImage(bundleImageName: "Chat List/LockLockedBottom"), color: UIColor(0x007ee5))
private let bottomUnlockedImage = UIImage(bundleImageName: "Chat List/LockUnlockedBottom")?.preloaded()

final class ChatListTitleLockView: UIView {
    private let topView: UIImageView
    private let bottomView: UIImageView
    
    private var isLocked: Bool = false
    
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
    
    func setIsLocked(_ isLocked: Bool, animated: Bool) {
        self.isLocked = isLocked
        if animated {
            let topViewCopy = UIImageView(image: self.topView.image)
            topViewCopy.frame = self.topView.frame
            self.addSubview(topViewCopy)
            
            let bottomViewCopy = UIImageView(image: self.bottomView.image)
            bottomViewCopy.frame = self.bottomView.frame
            self.addSubview(bottomViewCopy)
            
            self.topView.image = self.isLocked ? topLockedImage : topUnlockedImage
            self.bottomView.image = self.isLocked ? bottomLockedImage : bottomUnlockedImage
            
            self.topView.alpha = 0.5
            self.bottomView.alpha = 0.5
            
            let block: () -> Void = {
                self.layoutItems()
                topViewCopy.frame = self.topView.frame
                bottomViewCopy.frame = self.bottomView.frame
            }
            
            UIView.animate(withDuration: 0.1, animations: {
                topViewCopy.alpha = 0.0
                bottomViewCopy.alpha = 0.0
                
                self.topView.alpha = 1.0
                self.bottomView.alpha = 1.0
            })
            
            UIView.animate(withDuration: 0.3, delay: 0.0, usingSpringWithDamping: 0.39, initialSpringVelocity: 0.0, options: [], animations: {
                block()
            }, completion: { _ in
                topViewCopy.removeFromSuperview()
                bottomViewCopy.removeFromSuperview()
            })
        } else {
            self.topView.image = self.isLocked ? topLockedImage : topUnlockedImage
            self.bottomView.image = self.isLocked ? bottomLockedImage : bottomUnlockedImage
            self.layoutItems()
        }
    }
    
    private func layoutItems() {
        if self.isLocked {
            self.topView.frame = CGRect(x: (10.0 - 7.0) / 2.0, y: 0.0, width: 7.0, height: 5.0)
            self.bottomView.frame = CGRect(x: 0.0, y: 5.0, width: 10.0, height: 7.0)
        } else {
            self.topView.frame = CGRect(x: 6.0, y: 0.0, width: 7.0, height: 5.0)
            self.bottomView.frame = CGRect(x: 0.0, y: 5.0, width: 10.0, height: 7.0)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.layoutItems()
    }
}
