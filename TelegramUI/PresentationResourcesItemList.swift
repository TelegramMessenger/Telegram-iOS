import Foundation
import Display

private func generateArrowImage(_ theme: PresentationTheme) -> UIImage? {
    return generateImage(CGSize(width: 8.0, height: 14.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(theme.list.disclosureArrowColor.cgColor)
        
        let _ = try? drawSvgPath(context, path: "M5.41663691,6.58336309 L0,12 L1.16672619,13.1667262 L7.75008928,6.58336309 L1.16672619,0 L0,1.16672619 Z ")
    })
}

private func generateCheckIcon(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 14.0, height: 11.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2.0)
        context.move(to: CGPoint(x: 12.0, y: 1.0))
        context.addLine(to: CGPoint(x: 4.16482734, y: 9.0))
        context.addLine(to: CGPoint(x: 1.0, y: 5.81145833))
        context.strokePath()
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
}
