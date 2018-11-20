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

private func generateCheckIcon(color: UIColor) -> UIImage? {
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

private func generatePlusIcon(_ theme: PresentationTheme) -> UIImage? {
    return generateImage(CGSize(width: 18.0, height: 18.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(theme.list.itemAccentColor.cgColor)
        let lineWidth = min(1.5, UIScreenPixel * 4.0)
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
            return generateCheckIcon(color: theme.list.itemAccentColor)
        })
    }
    
    static func secondaryCheckIconImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListSecondaryCheckIcon.rawValue, { theme in
            return generateCheckIcon(color: theme.list.itemSecondaryTextColor)
        })
    }
    
    static func plusIconImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListPlusIcon.rawValue, generatePlusIcon)
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
            generateImage(CGSize(width: 22.0, height: 26.0), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(UIColor(white: 0.0, alpha: 0.06).cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 22.0, height: 22.0)))
                context.setFillColor(theme.list.itemDisclosureActions.destructive.fillColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 2.0), size: CGSize(width: 22.0, height: 22.0)))
                context.setFillColor(theme.list.itemDisclosureActions.destructive.foregroundColor.cgColor)
                context.fill(CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - 11.0) / 2.0), y: 2.0 + floorToScreenPixels((size.width - 1.0) / 2.0)), size: CGSize(width: 11.0, height: 1.0)))
            })
        })
    }
    
    static func itemListReorderIndicatorIcon(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListReorderIndicatorIcon.rawValue, { theme in
            generateImage(CGSize(width: 22.0, height: 9.0), contextGenerator: { size, context in
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
            generateImage(CGSize(width: 22.0, height: 26.0), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(UIColor(white: 0.0, alpha: 0.06).cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 22.0, height: 22.0)))
                context.setFillColor(theme.list.itemDisclosureActions.constructive.fillColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 2.0), size: CGSize(width: 22.0, height: 22.0)))
                context.setFillColor(theme.list.itemDisclosureActions.constructive.foregroundColor.cgColor)
                context.fill(CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - 11.0) / 2.0), y: 2.0 + floorToScreenPixels((size.width - 1.0) / 2.0)), size: CGSize(width: 11.0, height: 1.0)))
                context.fill(CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - 1.0) / 2.0), y: 2.0 + floorToScreenPixels((size.width - 11.0) / 2.0)), size: CGSize(width: 1.0, height: 11.0)))
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
}
