import Foundation
import UIKit
import Display
import AppBundle

public func generateItemListCheckIcon(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 12.0, height: 10.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1.98)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.translateBy(x: 1.0, y: 1.0)
        
        let _ = try? drawSvgPath(context, path: "M0.215053763,4.36080467 L3.31621263,7.70466293 L3.31621263,7.70466293 C3.35339229,7.74475231 3.41603123,7.74711109 3.45612061,7.70993143 C3.45920681,7.70706923 3.46210733,7.70401312 3.46480451,7.70078171 L9.89247312,0 S ")
    })
}

public func generateItemListPlusIcon(_ color: UIColor) -> UIImage? {
    return generateTintedImage(image: UIImage(bundleImageName: "Chat List/AddIcon"), color: color)
}

public struct PresentationResourcesItemList {
    public static func downArrowImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListDownArrow.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Search/DownButton"), color: theme.list.itemAccentColor)
        })
    }
    
    public static func disclosureArrowImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListDisclosureArrow.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Item List/DisclosureArrow"), color: theme.list.disclosureArrowColor)
        })
    }
    
    public static func checkIconImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListCheckIcon.rawValue, { theme in
            return generateItemListCheckIcon(color: theme.list.itemAccentColor)
        })
    }
    
    public static func secondaryCheckIconImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListSecondaryCheckIcon.rawValue, { theme in
            return generateItemListCheckIcon(color: theme.list.itemSecondaryTextColor)
        })
    }
    
    public static func plusIconImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListPlusIcon.rawValue, { theme in
            return generateItemListPlusIcon(theme.list.itemAccentColor)
        })
    }
    
    public static func deleteIconImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListDeleteIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: theme.list.itemDestructiveColor)
        })
    }
    
    public static func stickerUnreadDotImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListStickerItemUnreadDot.rawValue, { theme in
            return generateFilledCircleImage(diameter: 6.0, color: theme.list.itemAccentColor)
        })
    }
    
    public static func verifiedPeerIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListVerifiedPeerIcon.rawValue, { theme in
            return UIImage(bundleImageName: "Item List/PeerVerifiedIcon")?.precomposed()
        })
    }
    
    public static func itemListDeleteIndicatorIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListDeleteIndicatorIcon.rawValue, { theme in
            guard let image = generateTintedImage(image: UIImage(bundleImageName: "Item List/RemoveItemIcon"), color: theme.list.itemDestructiveColor) else {
                return nil
            }
            return generateImage(image.size, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(theme.rootController.tabBar.badgeTextColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(x: 2, y: 2), size: CGSize(width: size.width - 4.0, height: size.height - 4.0)))
                context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
            })
        })
    }
    
    public static func itemListReorderIndicatorIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListReorderIndicatorIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Item List/Reorder"), color: theme.list.controlSecondaryColor)
        })
    }
    
    public static func linkIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListLinkIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Contact List/LinkActionIcon"), color: theme.list.itemAccentColor)
        })
    }
    
    public static func addPersonIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListAddPersonIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Contact List/AddMemberIcon"), color: theme.list.itemAccentColor)
        })
    }
    
    public static func createGroupIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListCreateGroupIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Location/CreateGroupIcon"), color: theme.list.itemAccentColor)
        })
    }
    
    public static func addChannelIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListAddExceptionIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Item List/AddChannelIcon"), color: theme.list.itemAccentColor)
        })
    }
    
    public static func voiceCallIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListVoiceCallIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Info/CallButton"), color: theme.list.itemAccentColor)
        })
    }
    
    public static func videoCallIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListVideoCallIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Info/VideoCallButton"), color: theme.list.itemAccentColor)
        })
    }
    
    public static func addPhoneIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListAddPhoneIcon.rawValue, { theme in
            guard let image = generateTintedImage(image: UIImage(bundleImageName: "Item List/AddItemIcon"), color: theme.list.itemAccentColor) else {
                return nil
            }
            return generateImage(image.size, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(theme.rootController.tabBar.badgeTextColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(x: 2, y: 2), size: CGSize(width: size.width - 4.0, height: size.height - 4.0)))
                context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
            })
        })
    }
    
    public static func itemListClearInputIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListClearInputIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Components/Search Bar/Clear"), color: theme.list.inputClearButtonColor)
        })
    }
    
    public static func cloudFetchIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListCloudFetchIcon.rawValue, { theme in
            generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/FileCloudFetch"), color: theme.list.itemAccentColor)
        })
    }
    
    public static func itemListCloseIconImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListCloseIconImage.rawValue, { theme in
            return generateImage(CGSize(width: 12.0, height: 12.0), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setBlendMode(.copy)
                context.setStrokeColor(theme.list.disclosureArrowColor.cgColor)
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
    
    public static func makeVisibleIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListMakeVisibleIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Contact List/MakeVisibleIcon"), color: theme.list.itemAccentColor)
        })
    }
    
    public static func makeInvisibleIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListMakeInvisibleIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Contact List/MakeInvisibleIcon"), color: theme.list.itemDestructiveColor)
        })
    }
    
    public static func editThemeIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListEditThemeIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Settings/EditTheme"), color: theme.list.itemAccentColor)
        })
    }
    
    public static func knobImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListKnob.rawValue, { theme in
            return generateImage(CGSize(width: 40.0, height: 40.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setShadow(offset: CGSize(width: 0.0, height: -3.0), blur: 12.0, color: UIColor(white: 0.0, alpha: 0.25).cgColor)
                context.setFillColor(UIColor.white.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(x: 6.0, y: 6.0), size: CGSize(width: 28.0, height: 28.0)))
            })
        })
    }
    
    public static func blockAccentIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListBlockAccentIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Item List/Block"), color: theme.list.itemAccentColor)
        })
    }
    
    public static func blockDestructiveIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListBlockDestructiveIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Item List/Block"), color: theme.list.itemDestructiveColor)
        })
    }
    
    public static func addDeviceIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListAddDeviceIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Settings/QrIcon"), color: theme.list.itemAccentColor)
        })
    }
    
    public static func resetIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListResetIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Settings/Reset"), color: theme.list.itemAccentColor)
        })
    }
    
    public static func imageIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListImageIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Attach Menu/Image"), color: theme.list.itemAccentColor)
        })
    }
    
    public static func cloudIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListCloudIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Attach Menu/Cloud"), color: theme.list.itemAccentColor)
        })
    }
    
    public static func cornersImage(_ theme: PresentationTheme, top: Bool, bottom: Bool) -> UIImage? {
        if !top && !bottom {
            return nil
        }
        let key: PresentationResourceKey
        if top && bottom {
            key = PresentationResourceKey.itemListCornersBoth
        } else if top {
            key = PresentationResourceKey.itemListCornersTop
        } else {
            key = PresentationResourceKey.itemListCornersBottom
        }
        return theme.image(key.rawValue, { theme in
            return generateImage(CGSize(width: 50.0, height: 50.0), rotatedContext: { (size, context) in
                let bounds = CGRect(origin: CGPoint(), size: size)
                context.setFillColor(theme.list.blocksBackgroundColor.cgColor)
                context.fill(bounds)
                
                context.setBlendMode(.clear)
                
                var corners: UIRectCorner = []
                if top {
                    corners.insert(.topLeft)
                    corners.insert(.topRight)
                }
                if bottom {
                    corners.insert(.bottomLeft)
                    corners.insert(.bottomRight)
                }
                let path = UIBezierPath(roundedRect: bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: 11.0, height: 11.0))
                context.addPath(path.cgPath)
                context.fillPath()
            })?.stretchableImage(withLeftCapWidth: 25, topCapHeight: 25)
        })
    }
    
    public static func uploadToneIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.uploadToneIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Settings/UploadTone"), color: theme.list.itemAccentColor)
        })
    }
}
