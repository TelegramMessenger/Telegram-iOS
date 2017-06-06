import Foundation
import Display

private func generateStatusCheckImage(theme: PresentationTheme, single: Bool) -> UIImage? {
    return generateImage(CGSize(width: single ? 13.0 : 18.0, height: 13.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -size.width / 2.0 + 1.0, y: -size.height / 2.0 + 1.0)
        
        context.scaleBy(x: 0.5, y: 0.5)
        context.setStrokeColor(theme.chatList.checkmarkColor.cgColor)
        context.setLineWidth(2.8)
        if single {
            let _ = try? drawSvgPath(context, path: "M0,12 L6.75230742,19.080349 L22.4821014,0.277229071 ")
        } else {
            let _ = try? drawSvgPath(context, path: "M0,12 L6.75230742,19.080349 L22.4821014,0.277229071 ")
            let _ = try? drawSvgPath(context, path: "M13.4492402,16.500967 L15.7523074,18.8031199 L31.4821014,0 ")
        }
        context.strokePath()
    })
}

private func generateBadgeBackgroundImage(theme: PresentationTheme, active: Bool) -> UIImage? {
    return generateImage(CGSize(width: 20.0, height: 20.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        if active {
            context.setFillColor(theme.chatList.unreadBadgeActiveBackgroundColor.cgColor)
        } else {
            context.setFillColor(theme.chatList.unreadBadgeInactiveBackgroundColor.cgColor)
        }
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
    })?.stretchableImage(withLeftCapWidth: 10, topCapHeight: 10)
}

struct PresentationResourcesChatList {
    static func singleCheckImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatListSingleCheck.rawValue, { theme in
            return generateStatusCheckImage(theme: theme, single: true)
        })
    }
    
    static func doubleCheckImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatListDoubleCheck.rawValue, { theme in
            return generateStatusCheckImage(theme: theme, single: false)
        })
    }
    
    static func lockTopLockedImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatListLockTopLockedImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/LockLockedTop"), color: theme.rootController.navigationBar.accentTextColor)
        })
    }
    
    static func lockBottomLockedImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatListLockBottomLockedImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/LockLockedBottom"), color: theme.rootController.navigationBar.accentTextColor)
        })
    }
    
    static func lockTopUnlockedImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatListLockTopUnlockedImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/LockUnlockedTop"), color: theme.rootController.navigationBar.primaryTextColor)
        })
    }
    
    static func lockBottomUnlockedImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatListLockBottomUnlockedImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/LockUnlockedBottom"), color: theme.rootController.navigationBar.primaryTextColor)
        })
    }
    
    static func badgeBackgroundActive(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatListBadgeBackgroundActive.rawValue, { theme in
            return generateBadgeBackgroundImage(theme: theme, active: true)
        })
    }
    
    static func badgeBackgroundInactive(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.chatListBadgeBackgroundInactive.rawValue, { theme in
            return generateBadgeBackgroundImage(theme: theme, active: false)
        })
    }
}
