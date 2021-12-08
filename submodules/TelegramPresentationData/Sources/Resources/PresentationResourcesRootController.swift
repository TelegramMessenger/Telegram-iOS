import Foundation
import UIKit
import Display
import AppBundle

private func generateShareButtonImage(theme: PresentationTheme) -> UIImage? {
    return generateTintedImage(image: UIImage(bundleImageName: "Chat List/NavigationShare"), color: theme.rootController.navigationBar.accentTextColor)
}

public func generateIndefiniteActivityIndicatorImage(color: UIColor, diameter: CGFloat = 22.0, lineWidth: CGFloat = 2.0) -> UIImage? {
    return generateImage(CGSize(width: diameter, height: diameter), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        let cutoutAngle: CGFloat = CGFloat.pi * 30.0 / 180.0
        context.addArc(center: CGPoint(x: size.width / 2.0, y: size.height / 2.0), radius: size.width / 2.0 - lineWidth / 2.0, startAngle: 0.0, endAngle: CGFloat.pi * 2.0 - cutoutAngle, clockwise: false)
        context.strokePath()
    })
}

public func generatePlayerRateIcon(_ color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 19.0, height: 16.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(4.0)
        context.scaleBy(x: 0.3333, y: 0.3333)
        let _ = try? drawSvgPath(context, path: "M15.3637695,32.1972656 L23.7749023,32.1972656 C24.6127972,32.1972656 25.2519509,32.3691389 25.6923828,32.7128906 C26.1328147,33.0566423 26.3530273,33.5239228 26.3530273,34.1147461 C26.3530273,34.6411159 26.1784685,35.0869122 25.8293457,35.4521484 C25.4802229,35.8173846 24.9511754,36 24.2421875,36 L12.3828125,36 C11.5771444,36 10.9487327,35.7771018 10.4975586,35.3312988 C10.0463845,34.8854958 9.82080078,34.3618194 9.82080078,33.7602539 C9.82080078,33.3735332 9.96581886,32.8605989 10.2558594,32.2214355 C10.5458999,31.5822722 10.8627913,31.08008 11.206543,30.7148438 C12.635261,29.2324145 13.9243107,27.9621635 15.0737305,26.9040527 C16.2231503,25.845942 17.0449194,25.1503923 17.5390625,24.8173828 C18.4199263,24.1943328 19.1530732,23.5686067 19.7385254,22.9401855 C20.3239775,22.3117644 20.7697739,21.6672396 21.0759277,21.0065918 C21.3820816,20.345944 21.5351562,19.6987336 21.5351562,19.0649414 C21.5351562,18.377438 21.3713395,17.7624539 21.0437012,17.2199707 C20.7160628,16.6774875 20.2702665,16.2558609 19.7062988,15.9550781 C19.1423312,15.6542954 18.5273471,15.5039062 17.8613281,15.5039062 C16.4540945,15.5039062 15.3476603,16.1215759 14.5419922,17.3569336 C14.4345698,17.5180672 14.2546399,17.9584925 14.0021973,18.6782227 C13.7497546,19.3979528 13.4650895,19.9511699 13.1481934,20.3378906 C12.8312972,20.7246113 12.3667023,20.9179688 11.7543945,20.9179688 C11.2172825,20.9179688 10.7714861,20.7407244 10.4169922,20.3862305 C10.0624982,20.0317365 9.88525391,19.5483429 9.88525391,18.9360352 C9.88525391,18.1948205 10.0517561,17.4213907 10.3847656,16.6157227 C10.7177751,15.8100546 11.2145963,15.0795931 11.8752441,14.4243164 C12.535892,13.7690397 13.3737742,13.2399922 14.388916,12.8371582 C15.4040578,12.4343242 16.5937432,12.2329102 17.9580078,12.2329102 C19.6015707,12.2329102 21.0034122,12.4907201 22.1635742,13.0063477 C22.9155311,13.3500994 23.576169,13.8227509 24.1455078,14.4243164 C24.7148466,15.0258819 25.1579574,15.7214316 25.4748535,16.5109863 C25.7917496,17.3005411 25.9501953,18.1196247 25.9501953,18.9682617 C25.9501953,20.3002996 25.6198764,21.5114692 24.9592285,22.6018066 C24.2985807,23.6921441 23.6245152,24.5461395 22.9370117,25.1638184 C22.2495083,25.7814972 21.0974202,26.75097 19.4807129,28.0722656 C17.8640056,29.3935613 16.7548858,30.4194299 16.1533203,31.1499023 C15.8955065,31.4399429 15.6323256,31.7890605 15.3637695,32.1972656 Z M28.8464425,31.4077148 L34.1315987,23.6894531 L29.6843331,16.8251953 C29.2653857,16.1591764 28.9511799,15.5871606 28.7417062,15.1091309 C28.5322325,14.6311011 28.4274972,14.1718772 28.4274972,13.7314453 C28.4274972,13.2802712 28.6289112,12.8747577 29.0317452,12.5148926 C29.4345793,12.1550275 29.9260294,11.9750977 30.5061105,11.9750977 C31.1721294,11.9750977 31.6904348,12.1711406 32.0610421,12.5632324 C32.4316494,12.9553242 32.9445837,13.6831002 33.5998605,14.746582 L37.1447823,20.4829102 L40.9314034,14.746582 C41.2429284,14.2631812 41.5087949,13.8496111 41.7290109,13.5058594 C41.9492268,13.1621077 42.1613829,12.8774425 42.3654855,12.6518555 C42.569588,12.4262684 42.7978572,12.2570806 43.0502999,12.1442871 C43.3027426,12.0314936 43.5954643,11.9750977 43.9284737,11.9750977 C44.5300392,11.9750977 45.0214894,12.1550275 45.402839,12.5148926 C45.7841885,12.8747577 45.9748605,13.3017553 45.9748605,13.7958984 C45.9748605,14.5156286 45.5612904,15.4931579 44.7341378,16.7285156 L40.0773995,23.6894531 L45.08863,31.4077148 C45.5398041,32.084476 45.8674376,32.6457497 46.0715401,33.0915527 C46.2756427,33.5373557 46.3776925,33.9589824 46.3776925,34.3564453 C46.3776925,34.7324238 46.2863848,35.0761703 46.1037667,35.3876953 C45.9211486,35.6992203 45.6633387,35.9462881 45.3303292,36.1289062 C44.9973197,36.3115244 44.6213469,36.402832 44.2023995,36.402832 C43.7512254,36.402832 43.3698815,36.3088388 43.0583566,36.1208496 C42.7468316,35.9328604 42.4943927,35.6992201 42.3010323,35.4199219 C42.107672,35.1406236 41.7478123,34.5981486 41.2214425,33.7924805 L37.0642159,27.2504883 L32.6491769,33.9858398 C32.3054251,34.5229519 32.0610428,34.8989247 31.9160226,35.1137695 C31.7710023,35.3286144 31.5964435,35.5380849 31.3923409,35.7421875 C31.1882383,35.9462901 30.9465415,36.1074213 30.6672433,36.2255859 C30.387945,36.3437506 30.0603116,36.402832 29.6843331,36.402832 C29.1042521,36.402832 28.623544,36.2255877 28.2421944,35.8710938 C27.8608449,35.5165998 27.670173,35.0009799 27.670173,34.3242188 C27.670173,33.5292929 28.0622589,32.5571347 28.8464425,31.4077148 Z M8,2 C4.6862915,2 2,4.6862915 2,8 L2,40 C2,43.3137085 4.6862915,46 8,46 L48,46 C51.3137085,46 54,43.3137085 54,40 L54,8 C54,4.6862915 51.3137085,2 48,2 L8,2 S")
    })
}

public struct PresentationResourcesRootController {
    public static func navigationIndefiniteActivityImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.rootNavigationIndefiniteActivity.rawValue, { theme in
            generateIndefiniteActivityIndicatorImage(color: theme.rootController.navigationBar.accentTextColor)
        })
    }
        
    public static func navigationComposeIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationComposeIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/ComposeIcon"), color: theme.rootController.navigationBar.accentTextColor)
        })
    }
    
    public static func navigationShareIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationShareIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionForward"), color: theme.rootController.navigationBar.accentTextColor)
        })
//        return theme.image(PresentationResourceKey.navigationShareIcon.rawValue, generateShareButtonImage)
    }
    
    public static func navigationCallIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationCallIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Call List/CallIcon"), color: theme.rootController.navigationBar.accentTextColor)
        })
    }
    
    public static func navigationInfoIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationInfoIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/InfoIcon"), color: theme.rootController.navigationBar.accentTextColor)
        })
    }
    
    public static func navigationSearchIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationSearchIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/SearchIcon"), color: theme.rootController.navigationBar.accentTextColor)
        })
    }
    
    public static func navigationCompactSearchIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationCompactSearchIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/SearchIcon"), color: theme.rootController.navigationBar.accentTextColor)
        })
    }

    public static func navigationCalendarIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationCalendarIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Search/Calendar"), color: theme.rootController.navigationBar.accentTextColor)
        })
    }
    
    public static func navigationMoreIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationMoreIcon.rawValue, { theme in
            return generateImage(CGSize(width: 30.0, height: 30.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(theme.rootController.navigationBar.accentTextColor.cgColor)
                let dotSize: CGFloat = 4.0
                context.fillEllipse(in: CGRect(origin: CGPoint(x: 6.0, y: floor((size.height - dotSize) / 2.0)), size: CGSize(width: dotSize, height: dotSize)))
                context.fillEllipse(in: CGRect(origin: CGPoint(x: 13.0, y: floor((size.height - dotSize) / 2.0)), size: CGSize(width: dotSize, height: dotSize)))
                context.fillEllipse(in: CGRect(origin: CGPoint(x: 20.0, y: floor((size.height - dotSize) / 2.0)), size: CGSize(width: dotSize, height: dotSize)))
            })
        })
    }

    public static func navigationMoreCircledIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationMoreCircledIcon.rawValue, { theme in
            generateTintedImage(image: UIImage(bundleImageName: "Chat List/NavigationMore"), color: theme.rootController.navigationBar.accentTextColor)
        })
    }

    public static func navigationQrCodeIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationQrCodeIcon.rawValue, { theme in
            generateTintedImage(image: UIImage(bundleImageName: "Settings/QrIcon"), color: theme.rootController.navigationBar.accentTextColor)
        })
    }
    
    public static func navigationAddIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationAddIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/AddIcon"), color: theme.rootController.navigationBar.accentTextColor)
        })
    }
    
    public static func navigationPlayerCloseButton(_ theme: PresentationTheme) -> UIImage? {
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
    
    public static func navigationPlayerPlayIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationPlayerPlayIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/MinimizedPlay"), color: theme.rootController.navigationBar.accentTextColor)
        })
    }
    
    public static func navigationPlayerRateActiveIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationPlayerRateActiveIcon.rawValue, { theme in
            return generatePlayerRateIcon(theme.rootController.navigationBar.accentTextColor)
        })
    }
    
    public static func navigationPlayerRateInactiveIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationPlayerRateInactiveIcon.rawValue, { theme in
            return generatePlayerRateIcon(theme.rootController.navigationBar.controlColor)
        })
    }
    
    public static func navigationPlayerMaximizedRateActiveIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationPlayerMaximizedRateActiveIcon.rawValue, { theme in
            return generatePlayerRateIcon(theme.list.itemAccentColor)
        })
    }
    
    public static func navigationPlayerMaximizedRateInactiveIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationPlayerMaximizedRateInactiveIcon.rawValue, { theme in
            return generatePlayerRateIcon(theme.list.itemSecondaryTextColor)
        })
    }
    
    public static func navigationPlayerPauseIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationPlayerPauseIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "GlobalMusicPlayer/MinimizedPause"), color: theme.rootController.navigationBar.accentTextColor)
        })
    }
    
    public static func navigationLiveLocationIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.navigationLiveLocationIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/LiveLocationPanelIcon"), color: theme.rootController.navigationBar.accentTextColor)
        })
    }
        
    public static func inAppNotificationBackground(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.inAppNotificationBackground.rawValue, { theme in
            let inset: CGFloat = 16.0
            return generateImage(CGSize(width: 30.0 + inset * 2.0, height: 30.0 + 8.0 * 2.0 + 20.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setShadow(offset: CGSize(width: 0.0, height: -4.0), blur: 40.0, color: UIColor(white: 0.0, alpha: 0.3).cgColor)
                context.setFillColor(theme.inAppNotification.fillColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(x: inset, y: 8.0 * 2.0), size: CGSize(width: 30.0, height: 30.0)))
            })?.stretchableImage(withLeftCapWidth: Int(inset) + 15, topCapHeight: 8 * 2 + 15)
        })
    }
    
    public static func inAppNotificationSecretChatIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.inAppNotificationSecretChatIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Notification/SecretLock"), color: theme.inAppNotification.primaryTextColor)
        })
    }
}
