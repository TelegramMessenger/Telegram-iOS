import Foundation
import Display

private func generateArrowImage(_ theme: PresentationTheme) -> UIImage? {
    return generateTintedImage(image: UIImage(bundleImageName: "Peer Info/DisclosureArrow"), color: theme.list.disclosureArrowColor)
}

private func generateCheckIcon(_ theme: PresentationTheme) -> UIImage? {
    return generateImage(CGSize(width: 14.0, height: 11.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(theme.list.itemAccentColor.cgColor)
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
        return theme.image(PresentationResourceKey.itemListCheckIcon.rawValue, generateCheckIcon)
    }
    
    static func plusIconImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListPlusIcon.rawValue, generatePlusIcon)
    }
    
    static func stickerUnreadDotImage(_ theme: PresentationTheme) -> UIImage? {
        return theme.image(PresentationResourceKey.itemListStickerItemUnreadDot.rawValue, { theme in
            return generateFilledCircleImage(diameter: 6.0, color: theme.list.itemAccentColor)
        })
    }
}
