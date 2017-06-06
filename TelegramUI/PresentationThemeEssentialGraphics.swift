import Foundation
import UIKit
import Display

private func generateCheckImage(partial: Bool, color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 11.0, height: 9.0), contextGenerator: { size, context in
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
        
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.scaleBy(x: 0.5, y: 0.5)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2.5)
        if partial {
            let _ = try? drawSvgPath(context, path: "M1,14.5 L2.5,16 L16.4985125,1 ")
        } else {
            let _ = try? drawSvgPath(context, path: "M1,10 L7,16 L20.9985125,1 ")
        }
        context.strokePath()
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

public final class PrincipalThemeEssentialGraphics {
    public let chatMessageBackgroundIncomingImage: UIImage
    public let chatMessageBackgroundIncomingHighlightedImage: UIImage
    public let chatMessageBackgroundIncomingMergedTopImage: UIImage
    public let chatMessageBackgroundIncomingMergedTopHighlightedImage: UIImage
    public let chatMessageBackgroundIncomingMergedBottomImage: UIImage
    public let chatMessageBackgroundIncomingMergedBottomHighlightedImage: UIImage
    public let chatMessageBackgroundIncomingMergedBothImage: UIImage
    public let chatMessageBackgroundIncomingMergedBothHighlightedImage: UIImage
    
    public let chatMessageBackgroundOutgoingImage: UIImage
    public let chatMessageBackgroundOutgoingHighlightedImage: UIImage
    public let chatMessageBackgroundOutgoingMergedTopImage: UIImage
    public let chatMessageBackgroundOutgoingMergedTopHighlightedImage: UIImage
    public let chatMessageBackgroundOutgoingMergedBottomImage: UIImage
    public let chatMessageBackgroundOutgoingMergedBottomHighlightedImage: UIImage
    public let chatMessageBackgroundOutgoingMergedBothImage: UIImage
    public let chatMessageBackgroundOutgoingMergedBothHighlightedImage: UIImage
    
    public let checkBubbleFullImage: UIImage
    public let checkBubblePartialImage: UIImage
    
    public let checkMediaFullImage: UIImage
    public let checkMediaPartialImage: UIImage
    
    public let clockBubbleIncomingFrameImage: UIImage
    public let clockBubbleIncomingMinImage: UIImage
    public let clockBubbleOutgoingFrameImage: UIImage
    public let clockBubbleOutgoingMinImage: UIImage
    public let clockMediaFrameImage: UIImage
    public let clockMediaMinImage: UIImage
    
    public let dateAndStatusMediaBackground: UIImage
    public let dateAndStatusFreeBackground: UIImage
    public let incomingDateAndStatusImpressionIcon: UIImage
    public let outgoingDateAndStatusImpressionIcon: UIImage
    public let mediaImpressionIcon: UIImage
    
    public let dateStaticBackground: UIImage
    public let dateFloatingBackground: UIImage
    
    init(_ theme: PresentationThemeChat) {
        let bubble = theme.bubble
        self.chatMessageBackgroundIncomingImage = messageBubbleImage(incoming: true, fillColor: bubble.incomingFillColor, strokeColor: bubble.incomingStrokeColor, neighbors: .none)
        self.chatMessageBackgroundIncomingHighlightedImage = messageBubbleImage(incoming: true, fillColor: bubble.incomingFillHighlightedColor, strokeColor: bubble.incomingStrokeColor, neighbors: .none)
        self.chatMessageBackgroundIncomingMergedTopImage = messageBubbleImage(incoming: true, fillColor: bubble.incomingFillColor, strokeColor: bubble.incomingStrokeColor, neighbors: .top)
        self.chatMessageBackgroundIncomingMergedTopHighlightedImage = messageBubbleImage(incoming: true, fillColor: bubble.incomingFillHighlightedColor, strokeColor: bubble.incomingStrokeColor, neighbors: .top)
        self.chatMessageBackgroundIncomingMergedBottomImage = messageBubbleImage(incoming: true, fillColor: bubble.incomingFillColor, strokeColor: bubble.incomingStrokeColor, neighbors: .bottom)
        self.chatMessageBackgroundIncomingMergedBottomHighlightedImage = messageBubbleImage(incoming: true, fillColor: bubble.incomingFillHighlightedColor, strokeColor: bubble.incomingStrokeColor, neighbors: .bottom)
        self.chatMessageBackgroundIncomingMergedBothImage = messageBubbleImage(incoming: true, fillColor: bubble.incomingFillColor, strokeColor: bubble.incomingStrokeColor, neighbors: .both)
        self.chatMessageBackgroundIncomingMergedBothHighlightedImage = messageBubbleImage(incoming: true, fillColor: bubble.incomingFillHighlightedColor, strokeColor: bubble.incomingStrokeColor, neighbors: .both)
        
        self.chatMessageBackgroundOutgoingImage = messageBubbleImage(incoming: false, fillColor: bubble.outgoingFillColor, strokeColor: bubble.outgoingStrokeColor, neighbors: .none)
        self.chatMessageBackgroundOutgoingHighlightedImage = messageBubbleImage(incoming: false, fillColor: bubble.outgoingFillHighlightedColor, strokeColor: bubble.outgoingStrokeColor, neighbors: .none)
        self.chatMessageBackgroundOutgoingMergedTopImage = messageBubbleImage(incoming: false, fillColor: bubble.outgoingFillColor, strokeColor: bubble.outgoingStrokeColor, neighbors: .top)
        self.chatMessageBackgroundOutgoingMergedTopHighlightedImage = messageBubbleImage(incoming: false, fillColor: bubble.outgoingFillHighlightedColor, strokeColor: bubble.outgoingStrokeColor, neighbors: .top)
        self.chatMessageBackgroundOutgoingMergedBottomImage = messageBubbleImage(incoming: false, fillColor: bubble.outgoingFillColor, strokeColor: bubble.outgoingStrokeColor, neighbors: .bottom)
        self.chatMessageBackgroundOutgoingMergedBottomHighlightedImage = messageBubbleImage(incoming: false, fillColor: bubble.outgoingFillHighlightedColor, strokeColor: bubble.outgoingStrokeColor, neighbors: .bottom)
        self.chatMessageBackgroundOutgoingMergedBothImage = messageBubbleImage(incoming: false, fillColor: bubble.outgoingFillColor, strokeColor: bubble.outgoingStrokeColor, neighbors: .both)
        self.chatMessageBackgroundOutgoingMergedBothHighlightedImage = messageBubbleImage(incoming: false, fillColor: bubble.outgoingFillHighlightedColor, strokeColor: bubble.outgoingStrokeColor, neighbors: .both)
        
        self.checkBubbleFullImage = generateCheckImage(partial: false, color: theme.bubble.outgoingCheckColor)!
        self.checkBubblePartialImage = generateCheckImage(partial: true, color: theme.bubble.outgoingCheckColor)!
        
        self.checkMediaFullImage = generateCheckImage(partial: false, color: .white)!
        self.checkMediaPartialImage = generateCheckImage(partial: true, color: .white)!
        
        self.clockBubbleIncomingFrameImage = generateClockFrameImage(color: theme.bubble.incomingPendingActivityColor)!
        self.clockBubbleIncomingMinImage = generateClockMinImage(color: theme.bubble.incomingPendingActivityColor)!
        self.clockBubbleOutgoingFrameImage = generateClockFrameImage(color: theme.bubble.outgoingPendingActivityColor)!
        self.clockBubbleOutgoingMinImage = generateClockMinImage(color: theme.bubble.outgoingPendingActivityColor)!
        
        self.clockMediaFrameImage = generateClockFrameImage(color: .white)!
        self.clockMediaMinImage = generateClockMinImage(color: .white)!
        
        self.dateAndStatusMediaBackground = generateStretchableFilledCircleImage(diameter: 18.0, color: theme.bubble.mediaDateAndStatusFillColor)!
        self.dateAndStatusFreeBackground = generateStretchableFilledCircleImage(diameter: 18.0, color: theme.serviceMessage.serviceMessageFillColor)!
        
        let impressionCountImage = UIImage(bundleImageName: "Chat/Message/ImpressionCount")!
        self.incomingDateAndStatusImpressionIcon = generateTintedImage(image: impressionCountImage, color: theme.bubble.incomingSecondaryTextColor)!
        self.outgoingDateAndStatusImpressionIcon = generateTintedImage(image: impressionCountImage, color: theme.bubble.outgoingSecondaryTextColor)!
        self.mediaImpressionIcon = generateTintedImage(image: impressionCountImage, color: .white)!
        
        self.dateStaticBackground = generateImage(CGSize(width: 26.0, height: 26.0), contextGenerator: { size, context -> Void in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(theme.serviceMessage.dateFillStaticColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        })!.stretchableImage(withLeftCapWidth: 13, topCapHeight: 13)
        
        self.dateFloatingBackground = generateImage(CGSize(width: 26.0, height: 26.0), contextGenerator: { size, context -> Void in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(theme.serviceMessage.dateFillFloatingColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        })!.stretchableImage(withLeftCapWidth: 13, topCapHeight: 13)
    }
}
