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
    
    public static func disclosureOptionArrowsImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.disclosureOptionArrowsImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Item List/ContextDisclosureArrow"), color: theme.list.disclosureArrowColor)
        })
    }
    
    public static func disclosureLockedImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListDisclosureLocked.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Stickers/SmallLock"), color: theme.list.disclosureArrowColor)
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
    
    public static func disabledCheckIconImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListDisabledCheckIcon.rawValue, { theme in
            return generateItemListCheckIcon(color: theme.list.itemDisabledTextColor)
        })
    }
    
    public static func plusIconImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListPlusIcon.rawValue, { theme in
            return generateItemListPlusIcon(theme.list.itemAccentColor)
        })
    }
    
    public static func roundPlusIconImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListRoundPlusIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/AddRoundIcon"), color: theme.list.itemAccentColor)
        })
    }
    
    public static func accentDeleteIconImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListAccentDeleteIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Accessory Panels/MessageSelectionTrash"), color: theme.list.itemAccentColor)
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
            if let backgroundImage = UIImage(bundleImageName: "Chat List/PeerVerifiedIconBackground"), let foregroundImage = UIImage(bundleImageName: "Chat List/PeerVerifiedIconForeground") {
                return generateImage(backgroundImage.size, contextGenerator: { size, context in
                    if let backgroundCgImage = backgroundImage.cgImage, let foregroundCgImage = foregroundImage.cgImage {
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.saveGState()
                        context.clip(to: CGRect(origin: .zero, size: size), mask: backgroundCgImage)

                        context.setFillColor(theme.chatList.unreadBadgeActiveBackgroundColor.cgColor)
                        context.fill(CGRect(origin: CGPoint(), size: size))
                        context.restoreGState()
                        
                        context.clip(to: CGRect(origin: .zero, size: size), mask: foregroundCgImage)
                        context.setFillColor(theme.chatList.unreadBadgeActiveTextColor.cgColor)
                        context.fill(CGRect(origin: CGPoint(), size: size))
                    }
                }, opaque: false)
            } else {
                return nil
            }
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
            return generateImage(CGSize(width: 17.0, height: 14.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(theme.list.itemBlocksSeparatorColor.cgColor)

                let lineHeight = 1.0 + UIScreenPixel
                context.addPath(CGPath(roundedRect: CGRect(x: 0.0, y: UIScreenPixel, width: 17.0, height: lineHeight), cornerWidth: lineHeight / 2.0, cornerHeight: lineHeight / 2.0, transform: nil))
                context.addPath(CGPath(roundedRect: CGRect(x: 0.0, y: UIScreenPixel + 6.0, width: 17.0, height: lineHeight), cornerWidth: lineHeight / 2.0, cornerHeight: lineHeight / 2.0, transform: nil))
                context.addPath(CGPath(roundedRect: CGRect(x: 0.0, y: UIScreenPixel + 12.0, width: 17.0, height: lineHeight), cornerWidth: lineHeight / 2.0, cornerHeight: lineHeight / 2.0, transform: nil))
                context.fillPath()
            })
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
    
    public static func addPhotoIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListAddPhotoIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Settings/SetAvatar"), color: theme.list.itemAccentColor)
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
    
    public static func itemListRemoveIconImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListRemoveIconImage.rawValue, { theme in
            return generateImage(CGSize(width: 15.0, height: 15.0), contextGenerator: { size, context in
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
    
    public static func addBoostsIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListAddBoostsIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Premium/Gift"), color: theme.list.itemAccentColor)
        })
    }
    
    public static func premiumIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListPremiumIcon.rawValue, { theme in
            return generateImage(CGSize(width: 16.0, height: 16.0), contextGenerator: { size, context in
                let bounds = CGRect(origin: .zero, size: size)
                context.clear(bounds)
                
                let image = UIImage(bundleImageName: "Item List/PremiumIcon")!
                context.clip(to: bounds, mask: image.cgImage!)
                
                let colorsArray: [CGColor] = [
                    UIColor(rgb: 0x6b93ff).cgColor,
                    UIColor(rgb: 0x6b93ff).cgColor,
                    UIColor(rgb: 0x8d77ff).cgColor,
                    UIColor(rgb: 0xb56eec).cgColor,
                    UIColor(rgb: 0xb56eec).cgColor
                ]
                var locations: [CGFloat] = [0.0, 0.3, 0.5, 0.7, 1.0]
                let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray as CFArray, locations: &locations)!

                context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: size.height), options: CGGradientDrawingOptions())
            })
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
    
    public static func topicArrowDescriptionIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListTopicArrowIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/TopicArrowIcon"), color: theme.list.itemSecondaryTextColor)
        })
    }
    
    public static func statsReactionsIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.statsReactionsIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chart/Reactions"), color: theme.list.itemSecondaryTextColor)
        })
    }
    
    public static func statsForwardsIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.statsForwardsIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chart/Forwards"), color: theme.list.itemSecondaryTextColor)
        })
    }
    
    public static func sharedLinkIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.sharedLinkIcon.rawValue, { theme in
            return generateImage(CGSize(width: 40.0, height: 40.0), rotatedContext: { size, context in
                UIGraphicsPushContext(context)
                defer {
                    UIGraphicsPopContext()
                }
                
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(theme.list.itemCheckColors.fillColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                
                if let image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.list.itemCheckColors.foregroundColor) {
                    image.draw(at: CGPoint(x: floor((size.width - image.size.width) * 0.5), y: floor((size.height - image.size.height) * 0.5)))
                }
            })
        })
    }
    
    public static func hideIconImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.hideIconImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat List/Archive/IconHide"), color: theme.list.itemAccentColor)
        })
    }
    
    public static func peerStatusLockedImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.peerStatusLockedImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Stickers/SmallLock"), color: theme.list.itemSecondaryTextColor)
        })
    }
    
    public static func expandDownArrowImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.expandDownArrowImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Item List/ExpandingItemVerticalRegularArrow"), color: .white)?.withRenderingMode(.alwaysTemplate)
        })
    }
    
    public static func expandSmallDownArrowImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.expandSmallDownArrowImage.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Item List/ExpandingItemVerticalSmallArrow"), color: .white)?.withRenderingMode(.alwaysTemplate)
        })
    }
    
    public static func itemListRoundTopupIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListRoundTopupIcon.rawValue, { theme in
            return generateImage(CGSize(width: 16.0, height: 18.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                
                context.translateBy(x: 0.0, y: 2.0 - UIScreenPixel)
                context.setFillColor(theme.list.itemCheckColors.foregroundColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.width)))
                
                context.setBlendMode(.clear)
                context.addPath(CGPath(roundedRect: CGRect(x: 7.0, y: 3.0, width: 2.0, height: 10.0), cornerWidth: 1.0, cornerHeight: 1.0, transform: nil))
                context.addPath(CGPath(roundedRect: CGRect(x: 3.0, y: 7.0, width: 10.0, height: 2.0), cornerWidth: 1.0, cornerHeight: 1.0, transform: nil))
                context.fillPath()
            })
        })
    }
    
    public static func itemListRoundWithdrawIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListRoundWithdrawIcon.rawValue, { theme in
            return generateImage(CGSize(width: 16.0, height: 18.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                
                context.translateBy(x: 0.0, y: 2.0 - UIScreenPixel)
                context.setFillColor(theme.list.itemCheckColors.foregroundColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.width)))
                
                context.setBlendMode(.clear)
                context.addPath(CGPath(roundedRect: CGRect(x: 3.0, y: 7.0, width: 10.0, height: 2.0), cornerWidth: 1.0, cornerHeight: 1.0, transform: nil))
                context.fillPath()
            })
        })
    }
    
    public static func itemListStatsIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListStatsIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Premium/Stars/Stats"), color: .white)?.withRenderingMode(.alwaysTemplate)
        })
    }
}
