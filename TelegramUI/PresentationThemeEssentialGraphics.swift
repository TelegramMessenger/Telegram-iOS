import Foundation
import UIKit
import Display
import TelegramCore

private func generateCheckImage(partial: Bool, color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 11.0, height: 9.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
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

private func chatBubbleActionButtonImage(fillColor: UIColor, strokeColor: UIColor, foregroundColor: UIColor, image: UIImage?, iconOffset: CGPoint = CGPoint()) -> UIImage? {
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
    public let chatMessageBackgroundIncomingImage: UIImage
    public let chatMessageBackgroundIncomingHighlightedImage: UIImage
    public let chatMessageBackgroundIncomingMergedTopImage: UIImage
    public let chatMessageBackgroundIncomingMergedTopHighlightedImage: UIImage
    public let chatMessageBackgroundIncomingMergedTopSideImage: UIImage
    public let chatMessageBackgroundIncomingMergedTopSideHighlightedImage: UIImage
    public let chatMessageBackgroundIncomingMergedBottomImage: UIImage
    public let chatMessageBackgroundIncomingMergedBottomHighlightedImage: UIImage
    public let chatMessageBackgroundIncomingMergedBothImage: UIImage
    public let chatMessageBackgroundIncomingMergedBothHighlightedImage: UIImage
    public let chatMessageBackgroundIncomingMergedSideImage: UIImage
    public let chatMessageBackgroundIncomingMergedSideHighlightedImage: UIImage
    
    public let chatMessageBackgroundOutgoingImage: UIImage
    public let chatMessageBackgroundOutgoingHighlightedImage: UIImage
    public let chatMessageBackgroundOutgoingMergedTopImage: UIImage
    public let chatMessageBackgroundOutgoingMergedTopHighlightedImage: UIImage
    public let chatMessageBackgroundOutgoingMergedTopSideImage: UIImage
    public let chatMessageBackgroundOutgoingMergedTopSideHighlightedImage: UIImage
    public let chatMessageBackgroundOutgoingMergedBottomImage: UIImage
    public let chatMessageBackgroundOutgoingMergedBottomHighlightedImage: UIImage
    public let chatMessageBackgroundOutgoingMergedBothImage: UIImage
    public let chatMessageBackgroundOutgoingMergedBothHighlightedImage: UIImage
    public let chatMessageBackgroundOutgoingMergedSideImage: UIImage
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
    
    public let dateStaticBackground: UIImage
    public let dateFloatingBackground: UIImage
    
    public let radialIndicatorFileIconIncoming: UIImage
    public let radialIndicatorFileIconOutgoing: UIImage
    
    init(_ theme: PresentationThemeChat, wallpaper: TelegramWallpaper) {
        let incoming: PresentationThemeBubbleColorComponents = wallpaper.isEmpty ? theme.bubble.incoming.withoutWallpaper : theme.bubble.incoming.withWallpaper
        let outgoing: PresentationThemeBubbleColorComponents = wallpaper.isEmpty ? theme.bubble.outgoing.withoutWallpaper : theme.bubble.outgoing.withWallpaper
        
        self.chatMessageBackgroundIncomingImage = messageBubbleImage(incoming: true, fillColor: incoming.fill, strokeColor: incoming.stroke, neighbors: .none)
        self.chatMessageBackgroundIncomingHighlightedImage = messageBubbleImage(incoming: true, fillColor: incoming.highlightedFill, strokeColor: incoming.stroke, neighbors: .none)
        self.chatMessageBackgroundIncomingMergedTopImage = messageBubbleImage(incoming: true, fillColor: incoming.fill, strokeColor: incoming.stroke, neighbors: .top(side: false))
        self.chatMessageBackgroundIncomingMergedTopHighlightedImage = messageBubbleImage(incoming: true, fillColor: incoming.highlightedFill, strokeColor: incoming.stroke, neighbors: .top(side: false))
        self.chatMessageBackgroundIncomingMergedTopSideImage = messageBubbleImage(incoming: true, fillColor: incoming.fill, strokeColor: incoming.stroke, neighbors: .top(side: true))
        self.chatMessageBackgroundIncomingMergedTopSideHighlightedImage = messageBubbleImage(incoming: true, fillColor: incoming.highlightedFill, strokeColor: incoming.stroke, neighbors: .top(side: true))
        self.chatMessageBackgroundIncomingMergedBottomImage = messageBubbleImage(incoming: true, fillColor: incoming.fill, strokeColor: incoming.stroke, neighbors: .bottom)
        self.chatMessageBackgroundIncomingMergedBottomHighlightedImage = messageBubbleImage(incoming: true, fillColor: incoming.highlightedFill, strokeColor: incoming.stroke, neighbors: .bottom)
        self.chatMessageBackgroundIncomingMergedBothImage = messageBubbleImage(incoming: true, fillColor: incoming.fill, strokeColor: incoming.stroke, neighbors: .both)
        self.chatMessageBackgroundIncomingMergedBothHighlightedImage = messageBubbleImage(incoming: true, fillColor: incoming.highlightedFill, strokeColor: incoming.stroke, neighbors: .both)
        
        self.chatMessageBackgroundOutgoingImage = messageBubbleImage(incoming: false, fillColor: outgoing.fill, strokeColor: outgoing.stroke, neighbors: .none)
        self.chatMessageBackgroundOutgoingHighlightedImage = messageBubbleImage(incoming: false, fillColor: outgoing.highlightedFill, strokeColor: outgoing.stroke, neighbors: .none)
        self.chatMessageBackgroundOutgoingMergedTopImage = messageBubbleImage(incoming: false, fillColor: outgoing.fill, strokeColor: outgoing.stroke, neighbors: .top(side: false))
        self.chatMessageBackgroundOutgoingMergedTopHighlightedImage = messageBubbleImage(incoming: false, fillColor: outgoing.highlightedFill, strokeColor: outgoing.stroke, neighbors: .top(side: false))
        self.chatMessageBackgroundOutgoingMergedTopSideImage = messageBubbleImage(incoming: false, fillColor: outgoing.fill, strokeColor: outgoing.stroke, neighbors: .top(side: true))
        self.chatMessageBackgroundOutgoingMergedTopSideHighlightedImage = messageBubbleImage(incoming: false, fillColor: outgoing.highlightedFill, strokeColor: outgoing.stroke, neighbors: .top(side: true))
        self.chatMessageBackgroundOutgoingMergedBottomImage = messageBubbleImage(incoming: false, fillColor: outgoing.fill, strokeColor: outgoing.stroke, neighbors: .bottom)
        self.chatMessageBackgroundOutgoingMergedBottomHighlightedImage = messageBubbleImage(incoming: false, fillColor: outgoing.highlightedFill, strokeColor: outgoing.stroke, neighbors: .bottom)
        self.chatMessageBackgroundOutgoingMergedBothImage = messageBubbleImage(incoming: false, fillColor: outgoing.fill, strokeColor: outgoing.stroke, neighbors: .both)
        self.chatMessageBackgroundOutgoingMergedBothHighlightedImage = messageBubbleImage(incoming: false, fillColor: outgoing.highlightedFill, strokeColor: outgoing.stroke, neighbors: .both)

        self.chatMessageBackgroundIncomingMergedSideImage = messageBubbleImage(incoming: true, fillColor: incoming.fill, strokeColor: incoming.stroke, neighbors: .side)
        self.chatMessageBackgroundOutgoingMergedSideImage = messageBubbleImage(incoming: false, fillColor: outgoing.fill, strokeColor: outgoing.stroke, neighbors: .side)
        self.chatMessageBackgroundIncomingMergedSideHighlightedImage = messageBubbleImage(incoming: true, fillColor: incoming.highlightedFill, strokeColor: incoming.stroke, neighbors: .side)
        self.chatMessageBackgroundOutgoingMergedSideHighlightedImage = messageBubbleImage(incoming: false, fillColor: outgoing.highlightedFill, strokeColor: outgoing.stroke, neighbors: .side)
        
        self.checkBubbleFullImage = generateCheckImage(partial: false, color: theme.bubble.outgoingCheckColor)!
        self.checkBubblePartialImage = generateCheckImage(partial: true, color: theme.bubble.outgoingCheckColor)!
        
        self.checkMediaFullImage = generateCheckImage(partial: false, color: .white)!
        self.checkMediaPartialImage = generateCheckImage(partial: true, color: .white)!
        
        let serviceColor = serviceMessageColorComponents(chatTheme: theme, wallpaper: wallpaper)
        self.checkFreeFullImage = generateCheckImage(partial: false, color: serviceColor.primaryText)!
        self.checkFreePartialImage = generateCheckImage(partial: true, color: serviceColor.primaryText)!
        
        self.clockBubbleIncomingFrameImage = generateClockFrameImage(color: theme.bubble.incomingPendingActivityColor)!
        self.clockBubbleIncomingMinImage = generateClockMinImage(color: theme.bubble.incomingPendingActivityColor)!
        self.clockBubbleOutgoingFrameImage = generateClockFrameImage(color: theme.bubble.outgoingPendingActivityColor)!
        self.clockBubbleOutgoingMinImage = generateClockMinImage(color: theme.bubble.outgoingPendingActivityColor)!
        
        self.clockMediaFrameImage = generateClockFrameImage(color: .white)!
        self.clockMediaMinImage = generateClockMinImage(color: .white)!
        
        self.clockFreeFrameImage = generateClockFrameImage(color: serviceColor.primaryText)!
        self.clockFreeMinImage = generateClockMinImage(color: serviceColor.primaryText)!
        
        self.dateAndStatusMediaBackground = generateStretchableFilledCircleImage(diameter: 18.0, color: theme.bubble.mediaDateAndStatusFillColor)!
        self.dateAndStatusFreeBackground = generateStretchableFilledCircleImage(diameter: 18.0, color: serviceColor.dateFillStatic)!
        
        let impressionCountImage = UIImage(bundleImageName: "Chat/Message/ImpressionCount")!
        self.incomingDateAndStatusImpressionIcon = generateTintedImage(image: impressionCountImage, color: theme.bubble.incomingSecondaryTextColor)!
        self.outgoingDateAndStatusImpressionIcon = generateTintedImage(image: impressionCountImage, color: theme.bubble.outgoingSecondaryTextColor)!
        self.mediaImpressionIcon = generateTintedImage(image: impressionCountImage, color: .white)!
        self.freeImpressionIcon = generateTintedImage(image: impressionCountImage, color: serviceColor.primaryText)!
        
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
        
        self.radialIndicatorFileIconIncoming = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/RadialProgressIconDocumentIncoming"), color: incoming.fill)!
        self.radialIndicatorFileIconOutgoing = generateTintedImage(image: UIImage(bundleImageName: "Chat/Message/RadialProgressIconDocumentIncoming"), color: outgoing.fill)!
    }
}

public final class PrincipalThemeAdditionalGraphics {
    public let chatServiceBubbleFillImage: UIImage
    public let chatFreeformContentAdditionalInfoBackgroundImage: UIImage
    public let chatEmptyItemBackgroundImage: UIImage
    public let chatLoadingIndicatorBackgroundImage: UIImage
    
    public let chatBubbleShareButtonImage: UIImage
    public let chatBubbleNavigateButtonImage: UIImage
    public let chatBubbleActionButtonIncomingMiddleImage: UIImage
    public let chatBubbleActionButtonIncomingBottomLeftImage: UIImage
    public let chatBubbleActionButtonIncomingBottomRightImage: UIImage
    public let chatBubbleActionButtonIncomingBottomSingleImage: UIImage
    public let chatBubbleActionButtonOutgoingMiddleImage: UIImage
    public let chatBubbleActionButtonOutgoingBottomLeftImage: UIImage
    public let chatBubbleActionButtonOutgoingBottomRightImage: UIImage
    public let chatBubbleActionButtonOutgoingBottomSingleImage: UIImage
    
    init(_ theme: PresentationThemeChat, wallpaper: TelegramWallpaper) {
        let serviceColor = serviceMessageColorComponents(chatTheme: theme, wallpaper: wallpaper)
        self.chatServiceBubbleFillImage = generateImage(CGSize(width: 20.0, height: 20.0), contextGenerator: { size, context -> Void in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(serviceColor.fill.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        })!.stretchableImage(withLeftCapWidth: 8, topCapHeight: 8)
        self.chatFreeformContentAdditionalInfoBackgroundImage = generateStretchableFilledCircleImage(radius: 10.0, color: serviceColor.fill)!
        self.chatEmptyItemBackgroundImage = generateStretchableFilledCircleImage(radius: 14.0, color: serviceColor.fill)!
        self.chatLoadingIndicatorBackgroundImage = generateStretchableFilledCircleImage(diameter: 30.0, color: serviceColor.fill)!
        
        self.chatBubbleShareButtonImage = chatBubbleActionButtonImage(fillColor: bubbleVariableColor(variableColor: theme.bubble.shareButtonFillColor, wallpaper: wallpaper), strokeColor: theme.bubble.shareButtonStrokeColor, foregroundColor: theme.bubble.shareButtonForegroundColor, image: UIImage(bundleImageName: "Chat/Message/ShareIcon"))!
        self.chatBubbleNavigateButtonImage = chatBubbleActionButtonImage(fillColor: bubbleVariableColor(variableColor: theme.bubble.shareButtonFillColor, wallpaper: wallpaper), strokeColor: theme.bubble.shareButtonStrokeColor, foregroundColor: theme.bubble.shareButtonForegroundColor, image: UIImage(bundleImageName: "Chat/Message/NavigateToMessageIcon"), iconOffset: CGPoint(x: 0.0, y: 1.0))!
        self.chatBubbleActionButtonIncomingMiddleImage = messageBubbleActionButtonImage(color: bubbleVariableColor(variableColor: theme.bubble.actionButtonsIncomingFillColor, wallpaper: wallpaper), strokeColor: theme.bubble.actionButtonsIncomingStrokeColor, position: .middle)
        self.chatBubbleActionButtonIncomingBottomLeftImage = messageBubbleActionButtonImage(color: bubbleVariableColor(variableColor: theme.bubble.actionButtonsIncomingFillColor, wallpaper: wallpaper), strokeColor: theme.bubble.actionButtonsIncomingStrokeColor, position: .bottomLeft)
        self.chatBubbleActionButtonIncomingBottomRightImage = messageBubbleActionButtonImage(color: bubbleVariableColor(variableColor: theme.bubble.actionButtonsIncomingFillColor, wallpaper: wallpaper), strokeColor: theme.bubble.actionButtonsIncomingStrokeColor, position: .bottomRight)
        self.chatBubbleActionButtonIncomingBottomSingleImage = messageBubbleActionButtonImage(color: bubbleVariableColor(variableColor: theme.bubble.actionButtonsIncomingFillColor, wallpaper: wallpaper), strokeColor: theme.bubble.actionButtonsIncomingStrokeColor, position: .bottomSingle)
        self.chatBubbleActionButtonOutgoingMiddleImage = messageBubbleActionButtonImage(color: bubbleVariableColor(variableColor: theme.bubble.actionButtonsOutgoingFillColor, wallpaper: wallpaper), strokeColor: theme.bubble.actionButtonsOutgoingStrokeColor, position: .middle)
        self.chatBubbleActionButtonOutgoingBottomLeftImage = messageBubbleActionButtonImage(color: bubbleVariableColor(variableColor: theme.bubble.actionButtonsOutgoingFillColor, wallpaper: wallpaper), strokeColor: theme.bubble.actionButtonsOutgoingStrokeColor, position: .bottomLeft)
        self.chatBubbleActionButtonOutgoingBottomRightImage = messageBubbleActionButtonImage(color: bubbleVariableColor(variableColor: theme.bubble.actionButtonsOutgoingFillColor, wallpaper: wallpaper), strokeColor: theme.bubble.actionButtonsOutgoingStrokeColor, position: .bottomRight)
        self.chatBubbleActionButtonOutgoingBottomSingleImage = messageBubbleActionButtonImage(color: bubbleVariableColor(variableColor: theme.bubble.actionButtonsOutgoingFillColor, wallpaper: wallpaper), strokeColor: theme.bubble.actionButtonsOutgoingStrokeColor, position: .bottomSingle)
    }
}
