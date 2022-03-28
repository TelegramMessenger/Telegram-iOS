import Foundation
import UIKit
import Display
import Postbox
import TelegramCore
import TelegramUIPreferences
import AppBundle

func generateCheckImage(partial: Bool, color: UIColor, width: CGFloat) -> UIImage? {
    return generateImage(CGSize(width: width, height: floor(width * 9.0 / 11.0)), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.scaleBy(x: width / 11.0, y: width / 11.0)
        
        context.translateBy(x: 1.0, y: 1.0)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(0.99)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        if partial {
            let _ = try? drawSvgPath(context, path: "M0.5,7 L7,0 S ")
        } else {
            let _ = try? drawSvgPath(context, path: "M0,4 L2.95157047,6.95157047 L2.95157047,6.95157047 C2.97734507,6.97734507 3.01913396,6.97734507 3.04490857,6.95157047 C3.04548448,6.95099456 3.04604969,6.95040803 3.04660389,6.9498112 L9.5,0 S ")
        }
    })
}

private func generateClockFrameImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 11.0, height: 11.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(color.cgColor)
        context.setFillColor(color.cgColor)
        let strokeWidth: CGFloat = 1.0
        context.setLineWidth(strokeWidth)
        context.strokeEllipse(in: CGRect(x: strokeWidth / 2.0, y: strokeWidth / 2.0, width: size.width - strokeWidth, height: size.height - strokeWidth))
        context.fill(CGRect(x: (11.0 - strokeWidth) / 2.0, y: strokeWidth * 3.0, width: strokeWidth, height: 11.0 / 2.0 - strokeWidth * 3.0))
    })
}

private func generateClockMinImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 11.0, height: 11.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        let strokeWidth: CGFloat = 1.0
        context.fill(CGRect(x: (11.0 - strokeWidth) / 2.0, y: (11.0 - strokeWidth) / 2.0, width: 11.0 / 2.0 - strokeWidth, height: strokeWidth))
    })
}

public func chatBubbleActionButtonImage(fillColor: UIColor, strokeColor: UIColor, foregroundColor: UIColor, image: UIImage?, iconOffset: CGPoint = CGPoint()) -> UIImage? {
    return generateImage(CGSize(width: 29.0, height: 29.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(fillColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        let lineWidth: CGFloat = 1.0
        let halfLineWidth = lineWidth / 2.0
        var strokeAlpha: CGFloat = 0.0
        strokeColor.getRed(nil, green: nil, blue: nil, alpha: &strokeAlpha)
        if !strokeAlpha.isZero {
            context.setStrokeColor(strokeColor.cgColor)
            context.setLineWidth(lineWidth)
            context.strokeEllipse(in: CGRect(origin: CGPoint(x: halfLineWidth, y: halfLineWidth), size: CGSize(width: size.width - lineWidth, height: size.width - lineWidth)))
        }
        
        if let image = image {
            let imageRect = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0) + iconOffset.x, y: floor((size.height - image.size.height) / 2.0) + iconOffset.y), size: image.size)
            
            context.translateBy(x: imageRect.midX, y: imageRect.midY)
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: -imageRect.midX, y: -imageRect.midY)
            context.clip(to: imageRect, mask: image.cgImage!)
            context.setFillColor(foregroundColor.cgColor)
            context.fill(imageRect)
        }
    })
}

public final class PrincipalThemeEssentialGraphics {
    public let chatMessageBackgroundIncomingMaskImage: UIImage
    public let chatMessageBackgroundIncomingExtractedMaskImage: UIImage
    public let chatMessageBackgroundIncomingImage: UIImage
    public let chatMessageBackgroundIncomingExtractedImage: UIImage
    public let chatMessageBackgroundIncomingOutlineImage: UIImage
    public let chatMessageBackgroundIncomingExtractedOutlineImage: UIImage
    public let chatMessageBackgroundIncomingShadowImage: UIImage
    public let chatMessageBackgroundIncomingHighlightedImage: UIImage
    public let chatMessageBackgroundIncomingMergedTopMaskImage: UIImage
    public let chatMessageBackgroundIncomingMergedTopImage: UIImage
    public let chatMessageBackgroundIncomingMergedTopOutlineImage: UIImage
    public let chatMessageBackgroundIncomingMergedTopShadowImage: UIImage
    public let chatMessageBackgroundIncomingMergedTopHighlightedImage: UIImage
    public let chatMessageBackgroundIncomingMergedTopSideMaskImage: UIImage
    public let chatMessageBackgroundIncomingMergedTopSideImage: UIImage
    public let chatMessageBackgroundIncomingMergedTopSideOutlineImage: UIImage
    public let chatMessageBackgroundIncomingMergedTopSideShadowImage: UIImage
    public let chatMessageBackgroundIncomingMergedTopSideHighlightedImage: UIImage
    public let chatMessageBackgroundIncomingMergedBottomMaskImage: UIImage
    public let chatMessageBackgroundIncomingMergedBottomImage: UIImage
    public let chatMessageBackgroundIncomingMergedBottomOutlineImage: UIImage
    public let chatMessageBackgroundIncomingMergedBottomShadowImage: UIImage
    public let chatMessageBackgroundIncomingMergedBottomHighlightedImage: UIImage
    public let chatMessageBackgroundIncomingMergedBothMaskImage: UIImage
    public let chatMessageBackgroundIncomingMergedBothImage: UIImage
    public let chatMessageBackgroundIncomingMergedBothOutlineImage: UIImage
    public let chatMessageBackgroundIncomingMergedBothShadowImage: UIImage
    public let chatMessageBackgroundIncomingMergedBothHighlightedImage: UIImage
    public let chatMessageBackgroundIncomingMergedSideMaskImage: UIImage
    public let chatMessageBackgroundIncomingMergedSideImage: UIImage
    public let chatMessageBackgroundIncomingMergedSideOutlineImage: UIImage
    public let chatMessageBackgroundIncomingMergedSideShadowImage: UIImage
    public let chatMessageBackgroundIncomingMergedSideHighlightedImage: UIImage
    
    public let chatMessageBackgroundOutgoingMaskImage: UIImage
    public let chatMessageBackgroundOutgoingExtractedMaskImage: UIImage
    public let chatMessageBackgroundOutgoingImage: UIImage
    public let chatMessageBackgroundOutgoingExtractedImage: UIImage
    public let chatMessageBackgroundOutgoingOutlineImage: UIImage
    public let chatMessageBackgroundOutgoingExtractedOutlineImage: UIImage
    public let chatMessageBackgroundOutgoingShadowImage: UIImage
    public let chatMessageBackgroundOutgoingHighlightedImage: UIImage
    public let chatMessageBackgroundOutgoingMergedTopMaskImage: UIImage
    public let chatMessageBackgroundOutgoingMergedTopImage: UIImage
    public let chatMessageBackgroundOutgoingMergedTopOutlineImage: UIImage
    public let chatMessageBackgroundOutgoingMergedTopShadowImage: UIImage
    public let chatMessageBackgroundOutgoingMergedTopHighlightedImage: UIImage
    public let chatMessageBackgroundOutgoingMergedTopSideMaskImage: UIImage
    public let chatMessageBackgroundOutgoingMergedTopSideImage: UIImage
    public let chatMessageBackgroundOutgoingMergedTopSideOutlineImage: UIImage
    public let chatMessageBackgroundOutgoingMergedTopSideShadowImage: UIImage
    public let chatMessageBackgroundOutgoingMergedTopSideHighlightedImage: UIImage
    public let chatMessageBackgroundOutgoingMergedBottomMaskImage: UIImage
    public let chatMessageBackgroundOutgoingMergedBottomImage: UIImage
    public let chatMessageBackgroundOutgoingMergedBottomOutlineImage: UIImage
    public let chatMessageBackgroundOutgoingMergedBottomShadowImage: UIImage
    public let chatMessageBackgroundOutgoingMergedBottomHighlightedImage: UIImage
    public let chatMessageBackgroundOutgoingMergedBothMaskImage: UIImage
    public let chatMessageBackgroundOutgoingMergedBothImage: UIImage
    public let chatMessageBackgroundOutgoingMergedBothOutlineImage: UIImage
    public let chatMessageBackgroundOutgoingMergedBothShadowImage: UIImage
    public let chatMessageBackgroundOutgoingMergedBothHighlightedImage: UIImage
    public let chatMessageBackgroundOutgoingMergedSideMaskImage: UIImage
    public let chatMessageBackgroundOutgoingMergedSideImage: UIImage
    public let chatMessageBackgroundOutgoingMergedSideOutlineImage: UIImage
    public let chatMessageBackgroundOutgoingMergedSideShadowImage: UIImage
    public let chatMessageBackgroundOutgoingMergedSideHighlightedImage: UIImage
    
    public let checkBubbleFullImage: UIImage
    public let checkBubblePartialImage: UIImage
    
    public let checkMediaFullImage: UIImage
    public let checkMediaPartialImage: UIImage
    
    public let checkFreeFullImage: UIImage
    public let checkFreePartialImage: UIImage
    
    public let clockBubbleIncomingFrameImage: UIImage
    public let clockBubbleIncomingMinImage: UIImage
    public let clockBubbleOutgoingFrameImage: UIImage
    public let clockBubbleOutgoingMinImage: UIImage
    public let clockMediaFrameImage: UIImage
    public let clockMediaMinImage: UIImage
    public let clockFreeFrameImage: UIImage
    public let clockFreeMinImage: UIImage
    
    public let dateAndStatusMediaBackground: UIImage
    public let dateAndStatusFreeBackground: UIImage
    public let incomingDateAndStatusImpressionIcon: UIImage
    public let outgoingDateAndStatusImpressionIcon: UIImage
    public let mediaImpressionIcon: UIImage
    public let freeImpressionIcon: UIImage
    public let incomingDateAndStatusRepliesIcon: UIImage
    public let outgoingDateAndStatusRepliesIcon: UIImage
    public let mediaRepliesIcon: UIImage
    public let freeRepliesIcon: UIImage
    public let incomingDateAndStatusPinnedIcon: UIImage
    public let outgoingDateAndStatusPinnedIcon: UIImage
    public let mediaPinnedIcon: UIImage
    public let freePinnedIcon: UIImage
    public let incomingDateAndStatusSelfExpiringIcon: UIImage
    public let outgoingDateAndStatusSelfExpiringIcon: UIImage
    public let mediaSelfExpiringIcon: UIImage
    public let freeSelfExpiringIcon: UIImage
    
    public let dateStaticBackground: UIImage
    public let dateFloatingBackground: UIImage
    
    public let radialIndicatorFileIconIncoming: UIImage
    public let radialIndicatorFileIconOutgoing: UIImage
    
    public let incomingBubbleGradientImage: UIImage?
    public let outgoingBubbleGradientImage: UIImage?
    
    public let hasWallpaper: Bool
    
    init(presentationTheme: PresentationTheme, wallpaper initialWallpaper: TelegramWallpaper, preview: Bool = false, bubbleCorners: PresentationChatBubbleCorners) {
        let theme = presentationTheme.chat
        let wallpaper = initialWallpaper
        self.hasWallpaper = !wallpaper.isEmpty
        
        let incoming: PresentationThemeBubbleColorComponents = wallpaper.isEmpty ? theme.message.incoming.bubble.withoutWallpaper : theme.message.incoming.bubble.withWallpaper
        let outgoing: PresentationThemeBubbleColorComponents = wallpaper.isEmpty ? theme.message.outgoing.bubble.withoutWallpaper : theme.message.outgoing.bubble.withWallpaper

        var incomingGradientColors: [UIColor]?
        if Set(incoming.fill.map(\.argb)).count > 1 {
            incomingGradientColors = incoming.fill
        }
        if let incomingGradientColors = incomingGradientColors {
            self.incomingBubbleGradientImage = generateImage(CGSize(width: 1.0, height: 512.0), opaque: true, scale: 1.0, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                var locations: [CGFloat] = []
                var colors: [CGColor] = []
                for i in 0 ..< incomingGradientColors.count {
                    let t = CGFloat(i) / CGFloat(incomingGradientColors.count - 1)
                    locations.append(t)
                    colors.append(incomingGradientColors[i].cgColor)
                }

                let colorSpace = deviceColorSpace
                let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as NSArray, locations: &locations)!

                context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
            })
        } else {
            self.incomingBubbleGradientImage = nil
        }

        var outgoingGradientColors: [UIColor]?
        if Set(outgoing.fill.map(\.argb)).count > 1 {
            outgoingGradientColors = outgoing.fill
        }
        if let outgoingGradientColors = outgoingGradientColors {
            self.outgoingBubbleGradientImage = generateImage(CGSize(width: 1.0, height: 512.0), opaque: true, scale: 1.0, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                var locations: [CGFloat] = []
                var colors: [CGColor] = []
                for i in 0 ..< outgoingGradientColors.count {
                    let t = CGFloat(i) / CGFloat(outgoingGradientColors.count - 1)
                    locations.append(t)
                    colors.append(outgoingGradientColors[i].cgColor)
                }

                let colorSpace = deviceColorSpace
                let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as NSArray, locations: &locations)!

                context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
            })
        } else {
            self.outgoingBubbleGradientImage = nil
        }
        
        let incomingKnockout = self.incomingBubbleGradientImage != nil
        let outgoingKnockout = self.outgoingBubbleGradientImage != nil
        
        let highlightKnockout: Bool
        if case .color = wallpaper {
            highlightKnockout = true
        } else {
            highlightKnockout = false
        }
        
        let serviceColor = serviceMessageColorComponents(chatTheme: theme, wallpaper: wallpaper)
        
        let maxCornerRadius = bubbleCorners.mainRadius
        let minCornerRadius = (bubbleCorners.mergeBubbleCorners && maxCornerRadius >= 10.0) ? bubbleCorners.auxiliaryRadius : bubbleCorners.mainRadius
        
        let emptyImage = UIImage()
        if preview {
            self.chatMessageBackgroundIncomingMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: .black, strokeColor: .clear, neighbors: .none, theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundIncomingExtractedMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: UIColor.black, strokeColor: UIColor.clear, neighbors: .extracted, theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundIncomingImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .none, theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true)
            self.chatMessageBackgroundIncomingExtractedImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .extracted, theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true)
            self.chatMessageBackgroundIncomingOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .none, theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundIncomingExtractedOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .extracted, theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundIncomingShadowImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .none, theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true, onlyShadow: true)
            self.chatMessageBackgroundOutgoingMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: .black, strokeColor: .clear, neighbors: .none, theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundOutgoingExtractedMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: .black, strokeColor: .clear, neighbors: .extracted, theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundOutgoingImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .none, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true)
            self.chatMessageBackgroundOutgoingExtractedImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .extracted, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true)
            self.chatMessageBackgroundOutgoingOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .none, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundOutgoingExtractedOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .extracted, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundOutgoingShadowImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .none, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyShadow: true)
            self.checkBubbleFullImage = generateCheckImage(partial: false, color: theme.message.outgoingCheckColor, width: 11.0)!
            self.checkBubblePartialImage = generateCheckImage(partial: true, color: theme.message.outgoingCheckColor, width: 11.0)!
            self.chatMessageBackgroundIncomingHighlightedImage = emptyImage
            self.chatMessageBackgroundIncomingMergedTopMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: .black, strokeColor: .clear, neighbors: .top(side: false), theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundIncomingMergedTopImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .top(side: false), theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true)
            self.chatMessageBackgroundIncomingMergedTopOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .top(side: false), theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundIncomingMergedTopShadowImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .top(side: false), theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true, onlyShadow: true)
            self.chatMessageBackgroundIncomingMergedTopHighlightedImage = emptyImage
            self.chatMessageBackgroundIncomingMergedTopSideMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: .black, strokeColor: .clear, neighbors: .top(side: true), theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundIncomingMergedTopSideImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .top(side: true), theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true)
            self.chatMessageBackgroundIncomingMergedTopSideOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .top(side: true), theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundIncomingMergedTopSideShadowImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .top(side: true), theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true, onlyShadow: true)
            self.chatMessageBackgroundIncomingMergedTopSideHighlightedImage = emptyImage
            self.chatMessageBackgroundIncomingMergedBottomMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: .black, strokeColor: .clear, neighbors: .bottom, theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundIncomingMergedBottomImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .bottom, theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true)
            self.chatMessageBackgroundIncomingMergedBottomOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .bottom, theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundIncomingMergedBottomShadowImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .bottom, theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true, onlyShadow: true)
            self.chatMessageBackgroundIncomingMergedBottomHighlightedImage = emptyImage
            self.chatMessageBackgroundIncomingMergedBothMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: .black, strokeColor: .clear, neighbors: .both, theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)

            self.chatMessageBackgroundIncomingMergedBothImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .both, theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true)
            self.chatMessageBackgroundIncomingMergedBothOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .both, theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundIncomingMergedBothShadowImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .both, theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true, onlyShadow: true)
            self.chatMessageBackgroundIncomingMergedBothHighlightedImage = emptyImage
            self.chatMessageBackgroundIncomingMergedSideMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: .black, strokeColor: .clear, neighbors: .side, theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundIncomingMergedSideImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .side, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true)

            self.chatMessageBackgroundIncomingMergedSideOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .side, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundIncomingMergedSideShadowImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .side, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyShadow: true)
            self.chatMessageBackgroundOutgoingMergedSideMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: .black, strokeColor: .clear, neighbors: .side, theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundIncomingMergedSideHighlightedImage = emptyImage
            self.chatMessageBackgroundOutgoingHighlightedImage = emptyImage
            self.chatMessageBackgroundOutgoingMergedTopMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: .black, strokeColor: .clear, neighbors: .top(side: false), theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundOutgoingMergedTopImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .top(side: false), theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true)
            self.chatMessageBackgroundOutgoingMergedTopOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .top(side: false), theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundOutgoingMergedTopShadowImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .top(side: false), theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyShadow: true)
            self.chatMessageBackgroundOutgoingMergedTopHighlightedImage = emptyImage
            self.chatMessageBackgroundOutgoingMergedTopSideMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: .black, strokeColor: .clear, neighbors: .top(side: true), theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundOutgoingMergedTopSideImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .top(side: true), theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true)
            self.chatMessageBackgroundOutgoingMergedTopSideOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .top(side: true), theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundOutgoingMergedTopSideShadowImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .top(side: true), theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyShadow: true)
            self.chatMessageBackgroundOutgoingMergedTopSideHighlightedImage = emptyImage
            self.chatMessageBackgroundOutgoingMergedBottomMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: .black, strokeColor: .clear, neighbors: .bottom, theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundOutgoingMergedBottomImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .bottom, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true)
            self.chatMessageBackgroundOutgoingMergedBottomOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .bottom, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundOutgoingMergedBottomShadowImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .bottom, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyShadow: true)
            self.chatMessageBackgroundOutgoingMergedBottomHighlightedImage = emptyImage
            self.chatMessageBackgroundOutgoingMergedBothMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: .black, strokeColor: .clear, neighbors: .both, theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundOutgoingMergedBothImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .both, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true)
            self.chatMessageBackgroundOutgoingMergedBothOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .both, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundOutgoingMergedBothShadowImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .both, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyShadow: true)
            self.chatMessageBackgroundOutgoingMergedBothHighlightedImage = emptyImage
            self.chatMessageBackgroundOutgoingMergedSideImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .side, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true)
            self.chatMessageBackgroundOutgoingMergedSideOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .side, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundOutgoingMergedSideShadowImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .side, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyShadow: true)
            self.chatMessageBackgroundOutgoingMergedSideHighlightedImage = emptyImage
            self.checkMediaFullImage = emptyImage
            self.checkMediaPartialImage = emptyImage
            self.checkFreeFullImage = emptyImage
            self.checkFreePartialImage = emptyImage
            self.clockBubbleIncomingFrameImage = emptyImage
            self.clockBubbleIncomingMinImage = emptyImage
            self.clockBubbleOutgoingFrameImage = emptyImage
            self.clockBubbleOutgoingMinImage = emptyImage
            self.clockMediaFrameImage = emptyImage
            self.clockMediaMinImage = emptyImage
            self.clockFreeFrameImage = emptyImage
            self.clockFreeMinImage = emptyImage
            self.dateAndStatusMediaBackground = emptyImage
            self.dateAndStatusFreeBackground = emptyImage
                
            let impressionCountImage = UIImage(bundleImageName: "Chat/Message/ImpressionCount")!
            self.incomingDateAndStatusImpressionIcon = generateTintedImage(image: impressionCountImage, color: theme.message.incoming.secondaryTextColor)!
            self.outgoingDateAndStatusImpressionIcon = generateTintedImage(image: impressionCountImage, color: theme.message.outgoing.secondaryTextColor)!
            self.mediaImpressionIcon = generateTintedImage(image: impressionCountImage, color: .white)!
            self.freeImpressionIcon = generateTintedImage(image: impressionCountImage, color: serviceColor.primaryText)!
            
            let repliesImage = UIImage(bundleImageName: "Chat/Message/ReplyCount")!
            self.incomingDateAndStatusRepliesIcon = generateTintedImage(image: repliesImage, color: theme.message.incoming.secondaryTextColor)!
            self.outgoingDateAndStatusRepliesIcon = generateTintedImage(image: repliesImage, color: theme.message.outgoing.secondaryTextColor)!
            self.mediaRepliesIcon = generateTintedImage(image: repliesImage, color: .white)!
            self.freeRepliesIcon = generateTintedImage(image: repliesImage, color: serviceColor.primaryText)!
            
            let pinnedImage = UIImage(bundleImageName: "Chat/Message/Pinned")!
            self.incomingDateAndStatusPinnedIcon = generateTintedImage(image: pinnedImage, color: theme.message.incoming.secondaryTextColor)!
            self.outgoingDateAndStatusPinnedIcon = generateTintedImage(image: pinnedImage, color: theme.message.outgoing.secondaryTextColor)!
            self.mediaPinnedIcon = generateTintedImage(image: pinnedImage, color: .white)!
            self.freePinnedIcon = generateTintedImage(image: pinnedImage, color: serviceColor.primaryText)!
            
            let selfExpiringImage = UIImage(bundleImageName: "Chat/Message/SelfExpiring")!
            self.incomingDateAndStatusSelfExpiringIcon = generateTintedImage(image: selfExpiringImage, color: theme.message.incoming.secondaryTextColor)!
            self.outgoingDateAndStatusSelfExpiringIcon = generateTintedImage(image: selfExpiringImage, color: theme.message.outgoing.secondaryTextColor)!
            self.mediaSelfExpiringIcon = generateTintedImage(image: selfExpiringImage, color: .white)!
            self.freeSelfExpiringIcon = generateTintedImage(image: selfExpiringImage, color: serviceColor.primaryText)!
            
            self.radialIndicatorFileIconIncoming = emptyImage
            self.radialIndicatorFileIconOutgoing = emptyImage
        } else {
            self.chatMessageBackgroundIncomingMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: .black, strokeColor: .clear, neighbors: .none, theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundIncomingExtractedMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: .black, strokeColor: .clear, neighbors: .extracted, theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundIncomingImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .none, theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true)
            self.chatMessageBackgroundIncomingExtractedImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .extracted, theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true)
            self.chatMessageBackgroundIncomingOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .none, theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundIncomingExtractedOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .extracted, theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundIncomingShadowImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .none, theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true, onlyShadow: true)
            self.chatMessageBackgroundIncomingHighlightedImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.highlightedFill, strokeColor: incoming.stroke, neighbors: .none, theme: theme, wallpaper: wallpaper, knockout: highlightKnockout, extendedEdges: true, alwaysFillColor: true)
            self.chatMessageBackgroundIncomingMergedTopMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: .black, strokeColor: .clear, neighbors: .top(side: false), theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundIncomingMergedTopImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .top(side: false), theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true)
            self.chatMessageBackgroundIncomingMergedTopOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .top(side: false), theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundIncomingMergedTopShadowImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .top(side: false), theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true, onlyShadow: true)
            self.chatMessageBackgroundIncomingMergedTopHighlightedImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.highlightedFill, strokeColor: incoming.stroke, neighbors: .top(side: false), theme: theme, wallpaper: wallpaper, knockout: highlightKnockout, extendedEdges: true, alwaysFillColor: true)
            self.chatMessageBackgroundIncomingMergedTopSideMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: .black, strokeColor: .clear, neighbors: .top(side: true), theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundIncomingMergedTopSideImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .top(side: true), theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true)
            self.chatMessageBackgroundIncomingMergedTopSideOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .top(side: true), theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundIncomingMergedTopSideShadowImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .top(side: true), theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true, onlyShadow: true)
            self.chatMessageBackgroundIncomingMergedTopSideHighlightedImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.highlightedFill, strokeColor: incoming.stroke, neighbors: .top(side: true), theme: theme, wallpaper: wallpaper, knockout: highlightKnockout, extendedEdges: true, alwaysFillColor: true)
            self.chatMessageBackgroundIncomingMergedBottomMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: .black, strokeColor: .clear, neighbors: .bottom, theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundIncomingMergedBottomImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .bottom, theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true)
            self.chatMessageBackgroundIncomingMergedBottomOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .bottom, theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundIncomingMergedBottomShadowImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .bottom, theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true, onlyShadow: true)
            self.chatMessageBackgroundIncomingMergedBottomHighlightedImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.highlightedFill, strokeColor: incoming.stroke, neighbors: .bottom, theme: theme, wallpaper: wallpaper, knockout: highlightKnockout, extendedEdges: true, alwaysFillColor: true)
            self.chatMessageBackgroundIncomingMergedBothMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: .black, strokeColor: .clear, neighbors: .both, theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundIncomingMergedBothImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .both, theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true)
            self.chatMessageBackgroundIncomingMergedBothOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .both, theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundIncomingMergedBothShadowImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .both, theme: theme, wallpaper: wallpaper, knockout: incomingKnockout, extendedEdges: true, onlyShadow: true)
            self.chatMessageBackgroundIncomingMergedBothHighlightedImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.highlightedFill, strokeColor: incoming.stroke, neighbors: .both, theme: theme, wallpaper: wallpaper, knockout: highlightKnockout, extendedEdges: true, alwaysFillColor: true)
            
            self.chatMessageBackgroundOutgoingMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: .black, strokeColor: .clear, neighbors: .none, theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundOutgoingExtractedMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: .black, strokeColor: .clear, neighbors: .extracted, theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundOutgoingImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .none, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true)
            self.chatMessageBackgroundOutgoingExtractedImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .extracted, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true)
            self.chatMessageBackgroundOutgoingOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .none, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundOutgoingExtractedOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .extracted, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundOutgoingShadowImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .none, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyShadow: true)
            self.chatMessageBackgroundOutgoingHighlightedImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.highlightedFill, strokeColor: outgoing.stroke, neighbors: .none, theme: theme, wallpaper: wallpaper, knockout: highlightKnockout, extendedEdges: true, alwaysFillColor: true)
            self.chatMessageBackgroundOutgoingMergedTopMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: .black, strokeColor: .clear, neighbors: .top(side: false), theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundOutgoingMergedTopImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .top(side: false), theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true)
            self.chatMessageBackgroundOutgoingMergedTopOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .top(side: false), theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundOutgoingMergedTopShadowImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .top(side: false), theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyShadow: true)
            self.chatMessageBackgroundOutgoingMergedTopHighlightedImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.highlightedFill, strokeColor: outgoing.stroke, neighbors: .top(side: false), theme: theme, wallpaper: wallpaper, knockout: highlightKnockout, extendedEdges: true, alwaysFillColor: true)
            self.chatMessageBackgroundOutgoingMergedTopSideMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: .black, strokeColor: .clear, neighbors: .top(side: true), theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundOutgoingMergedTopSideImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .top(side: true), theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true)
            self.chatMessageBackgroundOutgoingMergedTopSideOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .top(side: true), theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundOutgoingMergedTopSideShadowImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .top(side: true), theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyShadow: true)
            self.chatMessageBackgroundOutgoingMergedTopSideHighlightedImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.highlightedFill, strokeColor: outgoing.stroke, neighbors: .top(side: true), theme: theme, wallpaper: wallpaper, knockout: highlightKnockout, extendedEdges: true, alwaysFillColor: true)
            self.chatMessageBackgroundOutgoingMergedBottomMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: .black, strokeColor: .clear, neighbors: .bottom, theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundOutgoingMergedBottomImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .bottom, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true)
            self.chatMessageBackgroundOutgoingMergedBottomOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .bottom, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundOutgoingMergedBottomShadowImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .bottom, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyShadow: true)
            self.chatMessageBackgroundOutgoingMergedBottomHighlightedImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.highlightedFill, strokeColor: outgoing.stroke, neighbors: .bottom, theme: theme, wallpaper: wallpaper, knockout: highlightKnockout, extendedEdges: true, alwaysFillColor: true)
            self.chatMessageBackgroundOutgoingMergedBothMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: .black, strokeColor: .clear, neighbors: .both, theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundOutgoingMergedBothImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .both, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true)
            self.chatMessageBackgroundOutgoingMergedBothOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .both, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundOutgoingMergedBothShadowImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .both, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyShadow: true)
            self.chatMessageBackgroundOutgoingMergedBothHighlightedImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.highlightedFill, strokeColor: outgoing.stroke, neighbors: .both, theme: theme, wallpaper: wallpaper, knockout: highlightKnockout, extendedEdges: true, alwaysFillColor: true)

            self.chatMessageBackgroundIncomingMergedSideMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: .black, strokeColor: .clear, neighbors: .side, theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundIncomingMergedSideImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .side, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true)
            self.chatMessageBackgroundIncomingMergedSideOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .side, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundIncomingMergedSideShadowImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.fill[0], strokeColor: incoming.stroke, neighbors: .side, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyShadow: true)
            self.chatMessageBackgroundOutgoingMergedSideMaskImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: .black, strokeColor: .clear, neighbors: .side, theme: theme, wallpaper: .color(0xffffff), knockout: true, mask: true, extendedEdges: true)
            self.chatMessageBackgroundOutgoingMergedSideImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .side, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true)
            self.chatMessageBackgroundOutgoingMergedSideOutlineImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .side, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyOutline: true)
            self.chatMessageBackgroundOutgoingMergedSideShadowImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.fill[0], strokeColor: outgoing.stroke, neighbors: .side, theme: theme, wallpaper: wallpaper, knockout: outgoingKnockout, extendedEdges: true, onlyShadow: true)
            self.chatMessageBackgroundIncomingMergedSideHighlightedImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: true, fillColor: incoming.highlightedFill, strokeColor: incoming.stroke, neighbors: .side, theme: theme, wallpaper: wallpaper, knockout: highlightKnockout, extendedEdges: true, alwaysFillColor: true)
            self.chatMessageBackgroundOutgoingMergedSideHighlightedImage = messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: false, fillColor: outgoing.highlightedFill, strokeColor: outgoing.stroke, neighbors: .side, theme: theme, wallpaper: wallpaper, knockout: highlightKnockout, extendedEdges: true, alwaysFillColor: true)
            
            self.checkBubbleFullImage = generateCheckImage(partial: false, color: theme.message.outgoingCheckColor, width: 11.0)!
            self.checkBubblePartialImage = generateCheckImage(partial: true, color: theme.message.outgoingCheckColor, width: 11.0)!
            
            self.checkMediaFullImage = generateCheckImage(partial: false, color: .white, width: 11.0)!
            self.checkMediaPartialImage = generateCheckImage(partial: true, color: .white, width: 11.0)!
            
            self.checkFreeFullImage = generateCheckImage(partial: false, color: serviceColor.primaryText, width: 11.0)!
            self.checkFreePartialImage = generateCheckImage(partial: true, color: serviceColor.primaryText, width: 11.0)!
            
            self.clockBubbleIncomingFrameImage = generateClockFrameImage(color: theme.message.incoming.pendingActivityColor)!
            self.clockBubbleIncomingMinImage = generateClockMinImage(color: theme.message.incoming.pendingActivityColor)!
            self.clockBubbleOutgoingFrameImage = generateClockFrameImage(color: theme.message.outgoing.pendingActivityColor)!
            self.clockBubbleOutgoingMinImage = generateClockMinImage(color: theme.message.outgoing.pendingActivityColor)!
            
            self.clockMediaFrameImage = generateClockFrameImage(color: .white)!
            self.clockMediaMinImage = generateClockMinImage(color: .white)!
            
            self.clockFreeFrameImage = generateClockFrameImage(color: serviceColor.primaryText)!
            self.clockFreeMinImage = generateClockMinImage(color: serviceColor.primaryText)!
            
            self.dateAndStatusMediaBackground = generateStretchableFilledCircleImage(diameter: 18.0, color: theme.message.mediaDateAndStatusFillColor)!
            self.dateAndStatusFreeBackground = generateStretchableFilledCircleImage(diameter: 18.0, color: serviceColor.dateFillStatic)!
            
            let impressionCountImage = UIImage(bundleImageName: "Chat/Message/ImpressionCount")!
            self.incomingDateAndStatusImpressionIcon = generateTintedImage(image: impressionCountImage, color: theme.message.incoming.secondaryTextColor)!
            self.outgoingDateAndStatusImpressionIcon = generateTintedImage(image: impressionCountImage, color: theme.message.outgoing.secondaryTextColor)!
            self.mediaImpressionIcon = generateTintedImage(image: impressionCountImage, color: .white)!
            self.freeImpressionIcon = generateTintedImage(image: impressionCountImage, color: serviceColor.primaryText)!
            
            let repliesImage = UIImage(bundleImageName: "Chat/Message/ReplyCount")!
            self.incomingDateAndStatusRepliesIcon = generateTintedImage(image: repliesImage, color: theme.message.incoming.secondaryTextColor)!
            self.outgoingDateAndStatusRepliesIcon = generateTintedImage(image: repliesImage, color: theme.message.outgoing.secondaryTextColor)!
            self.mediaRepliesIcon = generateTintedImage(image: repliesImage, color: .white)!
            self.freeRepliesIcon = generateTintedImage(image: repliesImage, color: serviceColor.primaryText)!
            
            let pinnedImage = UIImage(bundleImageName: "Chat/Message/Pinned")!
            self.incomingDateAndStatusPinnedIcon = generateTintedImage(image: pinnedImage, color: theme.message.incoming.secondaryTextColor)!
            self.outgoingDateAndStatusPinnedIcon = generateTintedImage(image: pinnedImage, color: theme.message.outgoing.secondaryTextColor)!
            self.mediaPinnedIcon = generateTintedImage(image: pinnedImage, color: .white)!
            self.freePinnedIcon = generateTintedImage(image: pinnedImage, color: serviceColor.primaryText)!
            
            let selfExpiringImage = UIImage(bundleImageName: "Chat/Message/SelfExpiring")!
            self.incomingDateAndStatusSelfExpiringIcon = generateTintedImage(image: selfExpiringImage, color: theme.message.incoming.secondaryTextColor)!
            self.outgoingDateAndStatusSelfExpiringIcon = generateTintedImage(image: selfExpiringImage, color: theme.message.outgoing.secondaryTextColor)!
            self.mediaSelfExpiringIcon = generateTintedImage(image: selfExpiringImage, color: .white)!
            self.freeSelfExpiringIcon = generateTintedImage(image: selfExpiringImage, color: serviceColor.primaryText)!
            
            self.radialIndicatorFileIconIncoming = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/RadialProgressIconDocument"), color: .black)!
            self.radialIndicatorFileIconOutgoing = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/RadialProgressIconDocument"), color: .black)!
        }
        
        let chatDateSize: CGFloat = 20.0
        self.dateStaticBackground = generateImage(CGSize(width: chatDateSize, height: chatDateSize), contextGenerator: { size, context -> Void in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(serviceColor.dateFillStatic.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        })!.stretchableImage(withLeftCapWidth: Int(chatDateSize) / 2, topCapHeight: Int(chatDateSize) / 2)
        
        self.dateFloatingBackground = generateImage(CGSize(width: chatDateSize, height: chatDateSize), contextGenerator: { size, context -> Void in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(serviceColor.dateFillFloating.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        })!.stretchableImage(withLeftCapWidth: Int(chatDateSize) / 2, topCapHeight: Int(chatDateSize) / 2)
    }
}

public final class PrincipalThemeAdditionalGraphics {
    public let chatServiceBubbleFillImage: UIImage
    public let chatServiceVerticalLineImage: UIImage
    public let chatFreeformContentAdditionalInfoBackgroundImage: UIImage
    public let chatEmptyItemBackgroundImage: UIImage
    public let chatLoadingIndicatorBackgroundImage: UIImage
    

    public let chatBubbleNavigateButtonImage: UIImage
    public let chatBubbleActionButtonIncomingMiddleImage: UIImage
    public let chatBubbleActionButtonMiddleMaskImage: UIImage
    public let chatBubbleActionButtonIncomingBottomLeftImage: UIImage
    public let chatBubbleActionButtonBottomLeftMaskImage: UIImage
    public let chatBubbleActionButtonIncomingBottomRightImage: UIImage
    public let chatBubbleActionButtonBottomRightMaskImage: UIImage
    public let chatBubbleActionButtonIncomingBottomSingleImage: UIImage
    public let chatBubbleActionButtonBottomSingleMaskImage: UIImage
    public let chatBubbleActionButtonOutgoingMiddleImage: UIImage
    public let chatBubbleActionButtonOutgoingBottomLeftImage: UIImage
    public let chatBubbleActionButtonOutgoingBottomRightImage: UIImage
    public let chatBubbleActionButtonOutgoingBottomSingleImage: UIImage
    
    public let chatBubbleActionButtonIncomingMessageIconImage: UIImage
    public let chatBubbleActionButtonIncomingLinkIconImage: UIImage
    public let chatBubbleActionButtonIncomingShareIconImage: UIImage
    public let chatBubbleActionButtonIncomingPhoneIconImage: UIImage
    public let chatBubbleActionButtonIncomingLocationIconImage: UIImage
    public let chatBubbleActionButtonIncomingPaymentIconImage: UIImage
    public let chatBubbleActionButtonIncomingProfileIconImage: UIImage
    public let chatBubbleActionButtonIncomingAddToChatIconImage: UIImage
    public let chatBubbleActionButtonIncomingWebAppIconImage: UIImage
    
    public let chatBubbleActionButtonOutgoingMessageIconImage: UIImage
    public let chatBubbleActionButtonOutgoingLinkIconImage: UIImage
    public let chatBubbleActionButtonOutgoingShareIconImage: UIImage
    public let chatBubbleActionButtonOutgoingPhoneIconImage: UIImage
    public let chatBubbleActionButtonOutgoingLocationIconImage: UIImage
    public let chatBubbleActionButtonOutgoingPaymentIconImage: UIImage
    public let chatBubbleActionButtonOutgoingProfileIconImage: UIImage
    public let chatBubbleActionButtonOutgoingAddToChatIconImage: UIImage
    public let chatBubbleActionButtonOutgoingWebAppIconImage: UIImage
        
    public let chatEmptyItemLockIcon: UIImage
    public let emptyChatListCheckIcon: UIImage
    
    init(_ theme: PresentationThemeChat, wallpaper: TelegramWallpaper, bubbleCorners: PresentationChatBubbleCorners) {
        let serviceColor = serviceMessageColorComponents(chatTheme: theme, wallpaper: wallpaper)
        self.chatServiceBubbleFillImage = generateImage(CGSize(width: 20.0, height: 20.0), contextGenerator: { size, context -> Void in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(serviceColor.fill.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        })!.stretchableImage(withLeftCapWidth: 8, topCapHeight: 8)
        
        self.chatServiceVerticalLineImage = generateImage(CGSize(width: 2.0, height: 3.0), contextGenerator: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(serviceColor.primaryText.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: 2.0, height: 2.0)))
            context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 1.0), size: CGSize(width: 2.0, height: 2.0)))
        })!.stretchableImage(withLeftCapWidth: 0, topCapHeight: 1)
        
        self.chatFreeformContentAdditionalInfoBackgroundImage = generateStretchableFilledCircleImage(radius: 10.0, color: serviceColor.fill)!
        self.chatEmptyItemBackgroundImage = generateStretchableFilledCircleImage(radius: 14.0, color: serviceColor.fill)!
        self.chatLoadingIndicatorBackgroundImage = generateStretchableFilledCircleImage(diameter: 30.0, color: serviceColor.fill)!
        
        self.chatBubbleNavigateButtonImage = chatBubbleActionButtonImage(fillColor: bubbleVariableColor(variableColor: theme.message.shareButtonFillColor, wallpaper: wallpaper), strokeColor: bubbleVariableColor(variableColor: theme.message.shareButtonStrokeColor, wallpaper: wallpaper), foregroundColor: bubbleVariableColor(variableColor: theme.message.shareButtonForegroundColor, wallpaper: wallpaper), image: UIImage(bundleImageName: "Chat/Message/NavigateToMessageIcon"), iconOffset: CGPoint(x: 0.0, y: 1.0))!
        self.chatBubbleActionButtonIncomingMiddleImage = messageBubbleActionButtonImage(color: bubbleVariableColor(variableColor: theme.message.incoming.actionButtonsFillColor, wallpaper: wallpaper), strokeColor: bubbleVariableColor(variableColor: theme.message.incoming.actionButtonsStrokeColor, wallpaper: wallpaper), position: .middle, bubbleCorners: bubbleCorners)
        self.chatBubbleActionButtonMiddleMaskImage = messageBubbleActionButtonImage(color: .white, strokeColor: .clear, position: .middle, bubbleCorners: bubbleCorners)
        self.chatBubbleActionButtonIncomingBottomLeftImage = messageBubbleActionButtonImage(color: bubbleVariableColor(variableColor: theme.message.incoming.actionButtonsFillColor, wallpaper: wallpaper), strokeColor: bubbleVariableColor(variableColor: theme.message.incoming.actionButtonsStrokeColor, wallpaper: wallpaper), position: .bottomLeft, bubbleCorners: bubbleCorners)
        self.chatBubbleActionButtonBottomLeftMaskImage = messageBubbleActionButtonImage(color: .black, strokeColor: .clear, position: .bottomLeft, bubbleCorners: bubbleCorners)
        self.chatBubbleActionButtonIncomingBottomRightImage = messageBubbleActionButtonImage(color: bubbleVariableColor(variableColor: theme.message.incoming.actionButtonsFillColor, wallpaper: wallpaper), strokeColor: bubbleVariableColor(variableColor: theme.message.incoming.actionButtonsStrokeColor, wallpaper: wallpaper), position: .bottomRight, bubbleCorners: bubbleCorners)
        self.chatBubbleActionButtonBottomRightMaskImage = messageBubbleActionButtonImage(color: .black, strokeColor: .clear, position: .bottomRight, bubbleCorners: bubbleCorners)
        self.chatBubbleActionButtonIncomingBottomSingleImage = messageBubbleActionButtonImage(color: bubbleVariableColor(variableColor: theme.message.incoming.actionButtonsFillColor, wallpaper: wallpaper), strokeColor: bubbleVariableColor(variableColor: theme.message.incoming.actionButtonsStrokeColor, wallpaper: wallpaper), position: .bottomSingle, bubbleCorners: bubbleCorners)
        self.chatBubbleActionButtonBottomSingleMaskImage = messageBubbleActionButtonImage(color: .black, strokeColor: .clear, position: .bottomSingle, bubbleCorners: bubbleCorners)
        self.chatBubbleActionButtonOutgoingMiddleImage = messageBubbleActionButtonImage(color: bubbleVariableColor(variableColor: theme.message.outgoing.actionButtonsFillColor, wallpaper: wallpaper), strokeColor: bubbleVariableColor(variableColor: theme.message.outgoing.actionButtonsStrokeColor, wallpaper: wallpaper), position: .middle, bubbleCorners: bubbleCorners)
        self.chatBubbleActionButtonOutgoingBottomLeftImage = messageBubbleActionButtonImage(color: bubbleVariableColor(variableColor: theme.message.outgoing.actionButtonsFillColor, wallpaper: wallpaper), strokeColor: bubbleVariableColor(variableColor: theme.message.outgoing.actionButtonsStrokeColor, wallpaper: wallpaper), position: .bottomLeft, bubbleCorners: bubbleCorners)
        self.chatBubbleActionButtonOutgoingBottomRightImage = messageBubbleActionButtonImage(color: bubbleVariableColor(variableColor: theme.message.outgoing.actionButtonsFillColor, wallpaper: wallpaper), strokeColor: bubbleVariableColor(variableColor: theme.message.outgoing.actionButtonsStrokeColor, wallpaper: wallpaper), position: .bottomRight, bubbleCorners: bubbleCorners)
        self.chatBubbleActionButtonOutgoingBottomSingleImage = messageBubbleActionButtonImage(color: bubbleVariableColor(variableColor: theme.message.outgoing.actionButtonsFillColor, wallpaper: wallpaper), strokeColor: bubbleVariableColor(variableColor: theme.message.outgoing.actionButtonsStrokeColor, wallpaper: wallpaper), position: .bottomSingle, bubbleCorners: bubbleCorners)
        self.chatBubbleActionButtonIncomingMessageIconImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/BotMessage"), color: bubbleVariableColor(variableColor: theme.message.incoming.actionButtonsTextColor, wallpaper: wallpaper))!
        self.chatBubbleActionButtonIncomingLinkIconImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/BotLink"), color: bubbleVariableColor(variableColor: theme.message.incoming.actionButtonsTextColor, wallpaper: wallpaper))!
        self.chatBubbleActionButtonIncomingShareIconImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/BotShare"), color: bubbleVariableColor(variableColor: theme.message.incoming.actionButtonsTextColor, wallpaper: wallpaper))!
        self.chatBubbleActionButtonIncomingPhoneIconImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/BotPhone"), color: bubbleVariableColor(variableColor: theme.message.incoming.actionButtonsTextColor, wallpaper: wallpaper))!
        self.chatBubbleActionButtonIncomingLocationIconImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/BotLocation"), color: bubbleVariableColor(variableColor: theme.message.incoming.actionButtonsTextColor, wallpaper: wallpaper))!
        self.chatBubbleActionButtonIncomingPaymentIconImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/BotPayment"), color: bubbleVariableColor(variableColor: theme.message.incoming.actionButtonsTextColor, wallpaper: wallpaper))!
        self.chatBubbleActionButtonIncomingProfileIconImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/BotProfile"), color: bubbleVariableColor(variableColor: theme.message.incoming.actionButtonsTextColor, wallpaper: wallpaper))!
        self.chatBubbleActionButtonIncomingAddToChatIconImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/BotAddToChat"), color: bubbleVariableColor(variableColor: theme.message.incoming.actionButtonsTextColor, wallpaper: wallpaper))!
        self.chatBubbleActionButtonIncomingWebAppIconImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/BotWebApp"), color: bubbleVariableColor(variableColor: theme.message.incoming.actionButtonsTextColor, wallpaper: wallpaper))!
        self.chatBubbleActionButtonOutgoingMessageIconImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/BotMessage"), color: bubbleVariableColor(variableColor: theme.message.outgoing.actionButtonsTextColor, wallpaper: wallpaper))!
        self.chatBubbleActionButtonOutgoingLinkIconImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/BotLink"), color: bubbleVariableColor(variableColor: theme.message.outgoing.actionButtonsTextColor, wallpaper: wallpaper))!
        self.chatBubbleActionButtonOutgoingShareIconImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/BotShare"), color: bubbleVariableColor(variableColor: theme.message.outgoing.actionButtonsTextColor, wallpaper: wallpaper))!
        self.chatBubbleActionButtonOutgoingPhoneIconImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/BotPhone"), color: bubbleVariableColor(variableColor: theme.message.outgoing.actionButtonsTextColor, wallpaper: wallpaper))!
        self.chatBubbleActionButtonOutgoingLocationIconImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/BotLocation"), color: bubbleVariableColor(variableColor: theme.message.outgoing.actionButtonsTextColor, wallpaper: wallpaper))!
        self.chatBubbleActionButtonOutgoingPaymentIconImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/BotPayment"), color: bubbleVariableColor(variableColor: theme.message.outgoing.actionButtonsTextColor, wallpaper: wallpaper))!
        self.chatBubbleActionButtonOutgoingProfileIconImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/BotProfile"), color: bubbleVariableColor(variableColor: theme.message.outgoing.actionButtonsTextColor, wallpaper: wallpaper))!
        self.chatBubbleActionButtonOutgoingAddToChatIconImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/BotAddToChat"), color: bubbleVariableColor(variableColor: theme.message.outgoing.actionButtonsTextColor, wallpaper: wallpaper))!
        self.chatBubbleActionButtonOutgoingWebAppIconImage = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/BotWebApp"), color: bubbleVariableColor(variableColor: theme.message.outgoing.actionButtonsTextColor, wallpaper: wallpaper))!
        
        self.chatEmptyItemLockIcon = generateImage(CGSize(width: 9.0, height: 13.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            context.translateBy(x: 0.0, y: 1.0)
            
            context.setFillColor(serviceColor.primaryText.cgColor)
            context.setStrokeColor(serviceColor.primaryText.cgColor)
            context.setLineWidth(1.32)
            
            let _ = try? drawSvgPath(context, path: "M4.5,0.600000024 C5.88071187,0.600000024 7,1.88484952 7,3.46979169 L7,7.39687502 C7,8.9818172 5.88071187,10.2666667 4.5,10.2666667 C3.11928813,10.2666667 2,8.9818172 2,7.39687502 L2,3.46979169 C2,1.88484952 3.11928813,0.600000024 4.5,0.600000024 S ")
            let _ = try? drawSvgPath(context, path: "M1.32,5.65999985 L7.68,5.65999985 C8.40901587,5.65999985 9,6.25098398 9,6.97999985 L9,10.6733332 C9,11.4023491 8.40901587,11.9933332 7.68,11.9933332 L1.32,11.9933332 C0.59098413,11.9933332 1.11022302e-16,11.4023491 0,10.6733332 L2.22044605e-16,6.97999985 C1.11022302e-16,6.25098398 0.59098413,5.65999985 1.32,5.65999985 Z ")
        })!
        self.emptyChatListCheckIcon = generateTintedImage(image: UIImage(bundleImageName: "Chat/Empty Chat/ListCheckIcon"), color: serviceColor.primaryText)!
    }
}
