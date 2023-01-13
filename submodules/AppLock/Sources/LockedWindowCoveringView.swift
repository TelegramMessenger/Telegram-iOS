import Foundation
import Display
import TelegramPresentationData
import AsyncDisplayKit
import TelegramCore
import PasscodeUI
import GradientBackground

final class LockedWindowCoveringView: WindowCoveringView {
    private let theme: PresentationTheme
    private let wallpaper: TelegramWallpaper
    private let accountManager: AccountManager<TelegramAccountManagerTypes>
    private var contentView: UIView?
    
    init(theme: PresentationTheme, wallpaper: TelegramWallpaper, accountManager: AccountManager<TelegramAccountManagerTypes>) {
        self.theme = theme
        self.wallpaper = wallpaper
        self.accountManager = accountManager
        
        super.init(frame: CGRect())
        
        self.backgroundColor =  theme.chatList.backgroundColor
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayout(_ size: CGSize) {
        if let contentView = self.contentView, contentView.frame.size == size {
            return
        }

        self.contentView?.removeFromSuperview()
        self.contentView = nil

        let background = PasscodeEntryControllerNode.background(size: size, wallpaper: self.wallpaper, theme: self.theme, accountManager: self.accountManager)
        if let backgroundImage = background.backgroundImage {
            let imageView = UIImageView(image: backgroundImage)
            imageView.frame = CGRect(origin: CGPoint(), size: size)
            self.addSubview(imageView)
            self.contentView = imageView
        } else if let customBackgroundNode = background.makeBackgroundNode() {
            customBackgroundNode.frame = CGRect(origin: CGPoint(), size: size)
            (customBackgroundNode as? GradientBackgroundNode)?.updateLayout(size: size, transition: .immediate, extendAnimation: false, backwards: false, completion: {})
            let backgroundDimNode = ASDisplayNode()
            if let background = background as? CustomPasscodeBackground, background.inverted {
                backgroundDimNode.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.75)
            } else {
                backgroundDimNode.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.15)
            }
            backgroundDimNode.frame = customBackgroundNode.frame
            customBackgroundNode.addSubnode(backgroundDimNode)
            self.addSubview(customBackgroundNode.view)
            self.contentView = customBackgroundNode.view
        }
    }
}
