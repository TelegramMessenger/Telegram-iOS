import Foundation
import CoreGraphics

struct ChatTitleLeadingIconsLayout {
    var lockIconFrame: CGRect?
    var verificationIconFrame: CGRect?
}

/// The icons drawn before a chat's title, from the title's leading edge leftwards: the secret chat lock, then the
/// third-party verification icon.
func chatTitleLeadingIconsLayout(titleFrame: CGRect, lockIconSize: CGSize?, lockIconSpacing: CGFloat, verificationIconSize: CGSize?, verificationIconSpacing: CGFloat) -> ChatTitleLeadingIconsLayout {
    var result = ChatTitleLeadingIconsLayout()
    var nextIconX: CGFloat = titleFrame.minX
    
    if let lockIconSize {
        result.lockIconFrame = CGRect(origin: CGPoint(x: nextIconX - lockIconSpacing - lockIconSize.width, y: titleFrame.minY + lockIconSpacing), size: lockIconSize)
        nextIconX -= lockIconSpacing + lockIconSize.width
    }
    if let verificationIconSize {
        result.verificationIconFrame = CGRect(origin: CGPoint(x: nextIconX - verificationIconSpacing - verificationIconSize.width, y: titleFrame.minY), size: verificationIconSize)
    }
    
    return result
}
