import Foundation
import Display

private func generateArrowImage(_ theme: PresentationTheme) -> UIImage? {
    return generateImage(CGSize(width: 7.0, height: 13.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(theme.list.disclosureArrowColor.cgColor)
        context.setLineWidth(1.98)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.translateBy(x: 1.0, y: 1.0)
        
        let _ = try? drawSvgPath(context, path: "M0,0 L4.79819816,5.27801798 L4.79819816,5.27801798 C4.91262453,5.40388698 4.91262453,5.59611302 4.79819816,5.72198202 L0,11 S ")
    })
}

func generateItemListCheckIcon(color: UIColor) -> UIImage? {
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

func generateItemListPlusIcon(_ color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 18.0, height: 18.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        context.setLineCap(.round)
        let lineWidth: CGFloat = 2.0
        context.fill(CGRect(x: floorToScreenPixels((18.0 - lineWidth) / 2.0), y: 0.0, width: lineWidth, height: 18.0))
        context.fill(CGRect(x: 0.0, y: floorToScreenPixels((18.0 - lineWidth) / 2.0), width: 18.0, height: lineWidth))
    })
}

struct PresentationResourcesItemList {
    static func disclosureArrowImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListDisclosureArrow.rawValue, generateArrowImage)
    }
    
    static func checkIconImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListCheckIcon.rawValue, { theme in
            return generateItemListCheckIcon(color: theme.list.itemAccentColor)
        })
    }
    
    static func secondaryCheckIconImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListSecondaryCheckIcon.rawValue, { theme in
            return generateItemListCheckIcon(color: theme.list.itemSecondaryTextColor)
        })
    }
    
    static func plusIconImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListPlusIcon.rawValue, { theme in
            return generateItemListPlusIcon(theme.list.itemAccentColor)
        })
    }
    
    static func stickerUnreadDotImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListStickerItemUnreadDot.rawValue, { theme in
            return generateFilledCircleImage(diameter: 6.0, color: theme.list.itemAccentColor)
        })
    }
    
    static func verifiedPeerIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListVerifiedPeerIcon.rawValue, { theme in
            return UIImage(bundleImageName: "Item List/PeerVerifiedIcon")?.precomposed()
        })
    }
    
    static func itemListDeleteIndicatorIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListDeleteIndicatorIcon.rawValue, { theme in
            guard let image = generateTintedImage(image: UIImage(bundleImageName: "Item List/RemoveItemIcon"), color: theme.list.itemDestructiveColor) else {
                return nil
            }
            return generateImage(image.size, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(UIColor.white.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(x: 2, y: 2), size: CGSize(width: size.width - 4.0, height: size.height - 4.0)))
                context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
            })
        })
    }
    
    static func itemListReorderIndicatorIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListReorderIndicatorIcon.rawValue, { theme in
            generateImage(CGSize(width: 16.0, height: 9.0), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(theme.list.controlSecondaryColor.cgColor)
                
                context.fill(CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: 1.5)))
                context.fill(CGRect(origin: CGPoint(x: 0.0, y: 3.5), size: CGSize(width: size.width, height: 1.5)))
                context.fill(CGRect(origin: CGPoint(x: 0.0, y: 7), size: CGSize(width: size.width, height: 1.5)))
            })
        })
    }
    
    static func addPersonIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListAddPersonIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Contact List/AddMemberIcon"), color: theme.list.itemAccentColor)
        })
    }
    
    static func addExceptionIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListAddExceptionIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Item List/AddExceptionIcon"), color: theme.list.itemAccentColor)
        })
    }
    
    static func addPhoneIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListAddPhoneIcon.rawValue, { theme in
            guard let image = generateTintedImage(image: UIImage(bundleImageName: "Item List/AddItemIcon"), color: theme.list.itemAccentColor) else {
                return nil
            }
            return generateImage(image.size, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(UIColor.white.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(x: 2, y: 2), size: CGSize(width: size.width - 4.0, height: size.height - 4.0)))
                context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
            })
        })
    }
    
    static func itemListClearInputIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListClearInputIcon.rawValue, { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Components/Search Bar/Clear"), color: theme.rootController.activeNavigationSearchBar.inputIconColor)
        })
    }
    
    static func cloudFetchIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListCloudFetchIcon.rawValue, { theme in
            generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/FileCloudFetch"), color: theme.list.itemAccentColor)
        })
    }
    
    static func itemListCloseIconImage(_ theme: PresentationTheme) -> UIImage? {
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
}
