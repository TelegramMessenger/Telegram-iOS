import Foundation
import Display

private func generateShareButtonImage(theme: PresentationTheme) -> UIImage? {
    return generateTintedImage(image: UIImage(bundleImageName: "Chat List/NavigationShare"), color: theme.rootController.navigationBar.accentTextColor)
}

func generateIndefiniteActivityIndicatorImage(color: UIColor, diameter: CGFloat = 22.0) -> UIImage? {
    return generateImage(CGSize(width: diameter, height: diameter), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(color.cgColor)
        let lineWidth: CGFloat = 2.0
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        let cutoutAngle: CGFloat = CGFloat.pi * 30.0 / 180.0
        context.addArc(center: CGPoint(x: size.width / 2.0, y: size.height / 2.0), radius: size.width / 2.0 - lineWidth / 2.0, startAngle: 0.0, endAngle: CGFloat.pi * 2.0 - cutoutAngle, clockwise: false)
        context.strokePath()
    })
}

struct PresentationResourcesRootController {
    static func navigationIndefiniteActivityImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.rootNavigationIndefiniteActivity.rawValue, { theme in
            generateIndefiniteActivityIndicatorImage(color: theme.rootController.navigationBar.accentTextColor)
        })
    }
    
    static func tabContactsIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.rootTabContactsIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/Tabs/IconContacts"), color: theme.rootController.tabBar.iconColor)
        })
    }
    
    static func tabContactsSelectedIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.rootTabContactsSelectedIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/Tabs/IconContacts"), color: theme.rootController.tabBar.selectedIconColor)
        })
    }
    
    static func tabChatsIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.rootTabChatsIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/Tabs/IconChats"), color: theme.rootController.tabBar.iconColor)
        })
    }
    
    static func tabChatsSelectedIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.rootTabChatsSelectedIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/Tabs/IconChats"), color: theme.rootController.tabBar.selectedIconColor)
        })
    }
    
    static func tabSettingsIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.rootTabSettingsIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/Tabs/IconSettings"), color: theme.rootController.tabBar.iconColor)
        })
    }
    
    static func tabSettingsSelectedIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.rootTabSettingsSelectedIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/Tabs/IconSettings"), color: theme.rootController.tabBar.selectedIconColor)
        })
    }
    
    static func navigationComposeIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationComposeIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/ComposeIcon"), color: theme.rootController.navigationBar.accentTextColor)
        })
    }
    
    static func navigationShareIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationShareIcon.rawValue, generateShareButtonImage)
    }
    
    static func navigationCallIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationCallIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Info/CallButton"), color: theme.rootController.navigationBar.accentTextColor)
        })
    }
    
    static func navigationSearchIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationSearchIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/SearchIcon"), color: theme.rootController.navigationBar.accentTextColor)
        })
    }
    
    static func navigationPlayerCloseButton(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationPlayerCloseButton.rawValue, { theme in
            return generateImage(CGSize(width: 12.0, height: 12.0), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setStrokeColor(theme.rootController.navigationBar.controlColor.cgColor)
                context.setLineWidth(2.0)
                context.setLineCap(.round)
                context.move(to: CGPoint(x: 1.0, y: 1.0))
                context.addLine(to: CGPoint(x: size.width - 1.0, y: size.height - 1.0))
                context.strokePath()
                context.move(to: CGPoint(x: size.width - 1.0, y: 1.0))
                context.addLine(to: CGPoint(x: 1.0, y: size.height - 1.0))
                context.strokePath()
            })
        })
    }
    
    static func navigationPlayerPlayIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationPlayerPlayIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/MinimizedPlay"), color: theme.rootController.navigationBar.accentTextColor)
        })
    }
    
    static func navigationPlayerPauseIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationPlayerPauseIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/MinimizedPause"), color: theme.rootController.navigationBar.accentTextColor)
        })
    }
    
    static func navigationLiveLocationIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationLiveLocationIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/LiveLocationPanelIcon"), color: theme.rootController.navigationBar.accentTextColor)
        })
    }
    
    static func navigationPlayerMaximizedPlayIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationPlayerMaximizedPlayIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/Play"), color: theme.rootController.navigationBar.primaryTextColor)
        })
    }
    
    static func navigationPlayerMaximizedPauseIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationPlayerMaximizedPauseIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/Pause"), color: theme.rootController.navigationBar.primaryTextColor)
        })
    }
    
    static func navigationPlayerMaximizedPreviousIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationPlayerMaximizedPreviousIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/Previous"), color: theme.rootController.navigationBar.primaryTextColor)
        })
    }
    
    static func navigationPlayerMaximizedNextIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationPlayerMaximizedNextIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/Next"), color: theme.rootController.navigationBar.primaryTextColor)
        })
    }
    
    static func navigationPlayerMaximizedShuffleIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationPlayerMaximizedShuffleIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/Shuffle"), color: theme.rootController.navigationBar.primaryTextColor)
        })
    }
    
    static func navigationPlayerMaximizedRepeatIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationPlayerMaximizedRepeatIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/Repeat"), color: theme.rootController.navigationBar.primaryTextColor)
        })
    }
    
    static func navigationPlayerHandleIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationPlayerHandleIcon.rawValue, { theme in
            return generateStretchableFilledCircleImage(diameter: 7.0, color: theme.rootController.navigationBar.controlColor)
        })
    }
    
    static func inAppNotificationBackground(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.inAppNotificationBackground.rawValue, { theme in
            return generateImage(CGSize(width: 30.0 + 8.0 * 2.0, height: 30.0 + 8.0 + 20.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setShadow(offset: CGSize(width: 0.0, height: -4.0), blur: 40.0, color: UIColor(white: 0.0, alpha: 0.3).cgColor)
                context.setFillColor(theme.inAppNotification.fillColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(x: 8.0, y: 8.0), size: CGSize(width: 30.0, height: 30.0)))
            })?.stretchableImage(withLeftCapWidth: 8 + 15, topCapHeight: 8 + 15)
        })
    }
}
