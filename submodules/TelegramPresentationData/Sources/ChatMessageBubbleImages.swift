import Foundation
import UIKit
import Display
import TelegramCore

public enum MessageBubbleImageNeighbors {
    case none
    case top(side: Bool)
    case bottom
    case both
    case side
    case extracted
}

public func messageSingleBubbleLikeImage(fillColor: UIColor, strokeColor: UIColor) -> UIImage {
    let diameter: CGFloat = 36.0
    return generateImage(CGSize(width: 36.0, height: diameter), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        let lineWidth: CGFloat = 0.5
        
        context.setFillColor(strokeColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        context.setFillColor(fillColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: lineWidth, y: lineWidth), size: CGSize(width: size.width - lineWidth * 2.0, height: size.height - lineWidth * 2.0)))
    })!.stretchableImage(withLeftCapWidth: Int(diameter / 2.0), topCapHeight: Int(diameter / 2.0))
}

private let minRadiusForFullTailCorner: CGFloat = 14.0

func mediaBubbleCornerImage(incoming: Bool, radius: CGFloat, inset: CGFloat) -> UIImage {
    let imageSize = CGSize(width: radius + 7.0, height: 8.0)
    let fixedMainDiameter: CGFloat = 33.0
    
    let formContext = DrawingContext(size: imageSize)
    formContext.withFlippedContext { context in
        context.clear(CGRect(origin: CGPoint(), size: imageSize))
        context.translateBy(x: imageSize.width / 2.0, y: imageSize.height / 2.0)
        context.scaleBy(x: incoming ? -1.0 : 1.0, y: -1.0)
        context.translateBy(x: -imageSize.width / 2.0, y: -imageSize.height / 2.0)
        
        context.setFillColor(UIColor.black.cgColor)
        
        let bottomEllipse = CGRect(origin: CGPoint(x: 24.0, y: 16.0), size: CGSize(width: 27.0, height: 17.0)).insetBy(dx: inset, dy: inset).offsetBy(dx: inset, dy: inset)
        let topEllipse = CGRect(origin: CGPoint(x: 33.0, y: 14.0), size: CGSize(width: 23.0, height: 21.0)).insetBy(dx: -inset, dy: -inset).offsetBy(dx: inset, dy: inset)
        
        context.translateBy(x: -fixedMainDiameter + imageSize.width - 6.0, y: -fixedMainDiameter + imageSize.height)
        
        let topLeftRadius: CGFloat = 2.0
        let topRightRadius: CGFloat = 2.0
        let bottomLeftRadius: CGFloat = 2.0
        let bottomRightRadius: CGFloat = radius
        
        context.move(to: CGPoint(x: 0.0, y: topLeftRadius))
        context.addArc(tangent1End: CGPoint(x: 0.0, y: 0.0), tangent2End: CGPoint(x: topLeftRadius, y: 0.0), radius: topLeftRadius)
        context.addLine(to: CGPoint(x: fixedMainDiameter - topRightRadius, y: 0.0))
        context.addArc(tangent1End: CGPoint(x: fixedMainDiameter, y: 0.0), tangent2End: CGPoint(x: fixedMainDiameter, y: topRightRadius), radius: topRightRadius)
        context.addLine(to: CGPoint(x: fixedMainDiameter, y: fixedMainDiameter - bottomRightRadius))
        context.addArc(tangent1End: CGPoint(x: fixedMainDiameter, y: fixedMainDiameter), tangent2End: CGPoint(x: fixedMainDiameter - bottomRightRadius, y: fixedMainDiameter), radius: bottomRightRadius)
        context.addLine(to: CGPoint(x: bottomLeftRadius, y: fixedMainDiameter))
        context.addArc(tangent1End: CGPoint(x: 0.0, y: fixedMainDiameter), tangent2End: CGPoint(x: 0.0, y: fixedMainDiameter - bottomLeftRadius), radius: bottomLeftRadius)
        context.addLine(to: CGPoint(x: 0.0, y: topLeftRadius))
        context.fillPath()
        
        if radius >= minRadiusForFullTailCorner {
            context.move(to: CGPoint(x: bottomEllipse.minX, y: bottomEllipse.midY))
            context.addQuadCurve(to: CGPoint(x: bottomEllipse.midX, y: bottomEllipse.maxY), control: CGPoint(x: bottomEllipse.minX, y: bottomEllipse.maxY))
            context.addQuadCurve(to: CGPoint(x: bottomEllipse.maxX, y: bottomEllipse.midY), control: CGPoint(x: bottomEllipse.maxX, y: bottomEllipse.maxY))
            context.fillPath()
        } else {
            context.fill(CGRect(origin: CGPoint(x: bottomEllipse.minX - 5.0, y: bottomEllipse.midY), size: CGSize(width: bottomEllipse.width + 5.0, height: bottomEllipse.height / 2.0)))
        }
        context.fill(CGRect(origin: CGPoint(x: fixedMainDiameter / 2.0, y: floor(fixedMainDiameter / 2.0)), size: CGSize(width: fixedMainDiameter / 2.0, height: ceil(bottomEllipse.midY) - floor(fixedMainDiameter / 2.0))))
        context.setFillColor(UIColor.clear.cgColor)
        context.setBlendMode(.copy)
        context.fillEllipse(in: topEllipse)
    }
    
    return formContext.generateImage()!
}

public func messageBubbleImage(maxCornerRadius: CGFloat, minCornerRadius: CGFloat, incoming: Bool, fillColor: UIColor, strokeColor: UIColor, neighbors: MessageBubbleImageNeighbors, theme: PresentationThemeChat, wallpaper: TelegramWallpaper, knockout knockoutValue: Bool, mask: Bool = false, extendedEdges: Bool = false, onlyOutline: Bool = false, onlyShadow: Bool = false, alwaysFillColor: Bool = false) -> UIImage {
    let bubbleColors = incoming ? theme.message.incoming : theme.message.outgoing
    return messageBubbleImage(maxCornerRadius: maxCornerRadius, minCornerRadius: minCornerRadius, incoming: incoming, fillColor: fillColor, strokeColor: strokeColor, neighbors: neighbors, shadow: bubbleColors.bubble.withWallpaper.shadow, wallpaper: wallpaper, knockout: knockoutValue, mask: mask, extendedEdges: extendedEdges, onlyOutline: onlyOutline, onlyShadow: onlyShadow, alwaysFillColor: alwaysFillColor)
}

public func messageBubbleArguments(maxCornerRadius: CGFloat, minCornerRadius: CGFloat, incoming: Bool, neighbors: MessageBubbleImageNeighbors) -> (topLeftRadius: CGFloat, topRightRadius: CGFloat, bottomLeftRadius: CGFloat, bottomRightRadius: CGFloat, drawTail: Bool) {
    var topLeftRadius: CGFloat
    var topRightRadius: CGFloat
    var bottomLeftRadius: CGFloat
    var bottomRightRadius: CGFloat
    var drawTail: Bool
    
    switch neighbors {
    case .none:
        topLeftRadius = maxCornerRadius
        topRightRadius = maxCornerRadius
        bottomLeftRadius = maxCornerRadius
        bottomRightRadius = maxCornerRadius
        drawTail = true
    case .both:
        topLeftRadius = maxCornerRadius
        topRightRadius = minCornerRadius
        bottomLeftRadius = maxCornerRadius
        bottomRightRadius = minCornerRadius
        drawTail = false
    case .bottom:
        topLeftRadius = maxCornerRadius
        topRightRadius = minCornerRadius
        bottomLeftRadius = maxCornerRadius
        bottomRightRadius = maxCornerRadius
        drawTail = true
    case .side:
        topLeftRadius = maxCornerRadius
        topRightRadius = maxCornerRadius
        bottomLeftRadius = minCornerRadius
        bottomRightRadius = minCornerRadius
        drawTail = false
    case let .top(side):
        topLeftRadius = maxCornerRadius
        topRightRadius = maxCornerRadius
        bottomLeftRadius = side ? minCornerRadius : maxCornerRadius
        bottomRightRadius = minCornerRadius
        drawTail = false
    case .extracted:
        topLeftRadius = maxCornerRadius
        topRightRadius = maxCornerRadius
        bottomLeftRadius = maxCornerRadius
        bottomRightRadius = maxCornerRadius
        drawTail = false
    }
    
    if incoming {
        var tmp = topRightRadius
        topRightRadius = topLeftRadius
        topLeftRadius = tmp
        
        tmp = bottomRightRadius
        bottomRightRadius = bottomLeftRadius
        bottomLeftRadius = tmp
    }
    
    return (topLeftRadius, topRightRadius, bottomLeftRadius, bottomRightRadius, drawTail)
}

public func messageBubbleImage(maxCornerRadius: CGFloat, minCornerRadius: CGFloat, incoming: Bool, fillColor: UIColor, strokeColor: UIColor, neighbors: MessageBubbleImageNeighbors, shadow: PresentationThemeBubbleShadow?, wallpaper: TelegramWallpaper, knockout knockoutValue: Bool, mask: Bool = false, extendedEdges: Bool = false, onlyOutline: Bool = false, onlyShadow: Bool = false, alwaysFillColor: Bool = false) -> UIImage {
    let topLeftRadius: CGFloat
    let topRightRadius: CGFloat
    let bottomLeftRadius: CGFloat
    let bottomRightRadius: CGFloat
    let drawTail: Bool
    
    switch neighbors {
    case .none:
        topLeftRadius = maxCornerRadius
        topRightRadius = maxCornerRadius
        bottomLeftRadius = maxCornerRadius
        bottomRightRadius = maxCornerRadius
        drawTail = true
    case .both:
        topLeftRadius = maxCornerRadius
        topRightRadius = minCornerRadius
        bottomLeftRadius = maxCornerRadius
        bottomRightRadius = minCornerRadius
        drawTail = false
    case .bottom:
        topLeftRadius = maxCornerRadius
        topRightRadius = minCornerRadius
        bottomLeftRadius = maxCornerRadius
        bottomRightRadius = maxCornerRadius
        drawTail = true
    case .side:
        topLeftRadius = maxCornerRadius
        topRightRadius = maxCornerRadius
        bottomLeftRadius = minCornerRadius
        bottomRightRadius = minCornerRadius
        drawTail = false
    case let .top(side):
        topLeftRadius = maxCornerRadius
        topRightRadius = maxCornerRadius
        bottomLeftRadius = side ? minCornerRadius : maxCornerRadius
        bottomRightRadius = minCornerRadius
        drawTail = false
    case .extracted:
        topLeftRadius = maxCornerRadius
        topRightRadius = maxCornerRadius
        bottomLeftRadius = maxCornerRadius
        bottomRightRadius = maxCornerRadius
        drawTail = false
    }
    
    let fixedMainDiameter: CGFloat = 33.0
    let innerSize = CGSize(width: fixedMainDiameter + 6.0, height: fixedMainDiameter)
    let strokeInset: CGFloat = 1.0
    let sourceRawSize = CGSize(width: innerSize.width + strokeInset * 2.0, height: innerSize.height + strokeInset * 2.0)
    let additionalInset: CGFloat = onlyShadow ? 10.0 : 1.0
    let imageSize = CGSize(width: sourceRawSize.width + additionalInset * 2.0, height: sourceRawSize.height + additionalInset * 2.0)
    let outgoingStretchPoint: (x: Int, y: Int) = (Int(additionalInset + strokeInset + round(fixedMainDiameter / 2.0)) - 1, Int(additionalInset + strokeInset + round(fixedMainDiameter / 2.0)))
    let incomingStretchPoint: (x: Int, y: Int) = (Int(sourceRawSize.width) - outgoingStretchPoint.x + Int(additionalInset), outgoingStretchPoint.y)
    
    let knockout = knockoutValue && !mask
    
    let rawSize = imageSize
    
    let bottomEllipse = CGRect(origin: CGPoint(x: 24.0, y: 16.0), size: CGSize(width: 27.0, height: 17.0))
    let topEllipse = CGRect(origin: CGPoint(x: 33.0, y: 14.0), size: CGSize(width: 23.0, height: 21.0))
    
    let formContext = DrawingContext(size: imageSize)
    formContext.withFlippedContext { context in
        context.clear(CGRect(origin: CGPoint(), size: rawSize))
        context.translateBy(x: additionalInset + strokeInset, y: additionalInset + strokeInset)
        
        context.setFillColor(UIColor.black.cgColor)
        
        context.move(to: CGPoint(x: 0.0, y: topLeftRadius))
        context.addArc(tangent1End: CGPoint(x: 0.0, y: 0.0), tangent2End: CGPoint(x: topLeftRadius, y: 0.0), radius: topLeftRadius)
        context.addLine(to: CGPoint(x: fixedMainDiameter - topRightRadius, y: 0.0))
        context.addArc(tangent1End: CGPoint(x: fixedMainDiameter, y: 0.0), tangent2End: CGPoint(x: fixedMainDiameter, y: topRightRadius), radius: topRightRadius)
        context.addLine(to: CGPoint(x: fixedMainDiameter, y: fixedMainDiameter - bottomRightRadius))
        context.addArc(tangent1End: CGPoint(x: fixedMainDiameter, y: fixedMainDiameter), tangent2End: CGPoint(x: fixedMainDiameter - bottomRightRadius, y: fixedMainDiameter), radius: bottomRightRadius)
        context.addLine(to: CGPoint(x: bottomLeftRadius, y: fixedMainDiameter))
        context.addArc(tangent1End: CGPoint(x: 0.0, y: fixedMainDiameter), tangent2End: CGPoint(x: 0.0, y: fixedMainDiameter - bottomLeftRadius), radius: bottomLeftRadius)
        context.addLine(to: CGPoint(x: 0.0, y: topLeftRadius))
        context.fillPath()
        
        if drawTail {
            if maxCornerRadius >= minRadiusForFullTailCorner {
                context.move(to: CGPoint(x: bottomEllipse.minX, y: bottomEllipse.midY))
                context.addQuadCurve(to: CGPoint(x: bottomEllipse.midX, y: bottomEllipse.maxY), control: CGPoint(x: bottomEllipse.minX, y: bottomEllipse.maxY))
                context.addQuadCurve(to: CGPoint(x: bottomEllipse.maxX, y: bottomEllipse.midY), control: CGPoint(x: bottomEllipse.maxX, y: bottomEllipse.maxY))
                context.fillPath()
            } else {
                context.fill(CGRect(origin: CGPoint(x: bottomEllipse.minX - 2.0, y: bottomEllipse.midY), size: CGSize(width: bottomEllipse.width + 2.0, height: bottomEllipse.height / 2.0)))
            }
            context.fill(CGRect(origin: CGPoint(x: fixedMainDiameter / 2.0, y: floor(fixedMainDiameter / 2.0)), size: CGSize(width: fixedMainDiameter / 2.0, height: ceil(bottomEllipse.midY) - floor(fixedMainDiameter / 2.0))))
            context.setFillColor(UIColor.clear.cgColor)
            context.setBlendMode(.copy)
            context.fillEllipse(in: topEllipse)
        }
    }
    let formImage = formContext.generateImage()!
    
    let outlineContext = DrawingContext(size: imageSize)
    outlineContext.withFlippedContext { context in
        context.clear(CGRect(origin: CGPoint(), size: rawSize))
        context.translateBy(x: additionalInset + strokeInset, y: additionalInset + strokeInset)
        
        context.setStrokeColor(UIColor.black.cgColor)
        let borderWidth: CGFloat
        let borderOffset: CGFloat
        
        let innerExtension: CGFloat
        if knockout && !mask {
            innerExtension = 0.25
        } else {
            innerExtension = 0.25
        }
        
        if abs(UIScreenPixel - 0.5) < CGFloat.ulpOfOne {
            borderWidth = UIScreenPixel + innerExtension
            borderOffset = -innerExtension / 2.0 + UIScreenPixel / 2.0
        } else {
            borderWidth = UIScreenPixel + innerExtension
            borderOffset = -innerExtension / 2.0// + UIScreenPixel * 2.0 / 2.0
        }
        context.setLineWidth(borderWidth)
        
        context.move(to: CGPoint(x: -borderOffset, y: topLeftRadius + borderOffset))
        context.addArc(tangent1End: CGPoint(x: -borderOffset, y: -borderOffset), tangent2End: CGPoint(x: topLeftRadius + borderOffset, y: -borderOffset), radius: topLeftRadius + borderOffset * 2.0)
        context.addLine(to: CGPoint(x: fixedMainDiameter - topRightRadius - borderOffset, y: -borderOffset))
        context.addArc(tangent1End: CGPoint(x: fixedMainDiameter + borderOffset, y: -borderOffset), tangent2End: CGPoint(x: fixedMainDiameter + borderOffset, y: topRightRadius + borderOffset), radius: topRightRadius + borderOffset * 2.0)
        context.addLine(to: CGPoint(x: fixedMainDiameter + borderOffset, y: fixedMainDiameter - bottomRightRadius - borderOffset))
        context.addArc(tangent1End: CGPoint(x: fixedMainDiameter + borderOffset, y: fixedMainDiameter + borderOffset), tangent2End: CGPoint(x: fixedMainDiameter - bottomRightRadius - borderOffset, y: fixedMainDiameter + borderOffset), radius: bottomRightRadius + borderOffset * 2.0)
        context.addLine(to: CGPoint(x: bottomLeftRadius + borderOffset, y: fixedMainDiameter + borderOffset))
        context.addArc(tangent1End: CGPoint(x: -borderOffset, y: fixedMainDiameter + borderOffset), tangent2End: CGPoint(x: -borderOffset, y: fixedMainDiameter - bottomLeftRadius - borderOffset), radius: bottomLeftRadius + borderOffset * 2.0)
        context.closePath()
        context.strokePath()
        
        if drawTail {
            let outlineBottomEllipse = bottomEllipse.insetBy(dx: -borderOffset, dy: -borderOffset)
            let outlineInnerTopEllipse = topEllipse.insetBy(dx: borderOffset, dy: borderOffset)
            
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            
            if maxCornerRadius >= minRadiusForFullTailCorner {
                context.move(to: CGPoint(x: bottomEllipse.minX, y: bottomEllipse.midY))
                context.addQuadCurve(to: CGPoint(x: bottomEllipse.midX, y: bottomEllipse.maxY), control: CGPoint(x: bottomEllipse.minX, y: bottomEllipse.maxY))
                context.addQuadCurve(to: CGPoint(x: bottomEllipse.maxX, y: bottomEllipse.midY), control: CGPoint(x: bottomEllipse.maxX, y: bottomEllipse.maxY))
                context.fillPath()
            } else {
                context.fill(CGRect(origin: CGPoint(x: bottomEllipse.minX - 2.0, y: floor(bottomEllipse.midY)), size: CGSize(width: bottomEllipse.width + 2.0, height: ceil(bottomEllipse.height / 2.0))))
            }
            context.fill(CGRect(origin: CGPoint(x: floor(fixedMainDiameter / 2.0), y: fixedMainDiameter / 2.0), size: CGSize(width: fixedMainDiameter / 2.0 + borderWidth, height: ceil(bottomEllipse.midY) - floor(fixedMainDiameter / 2.0))))
            
            context.setBlendMode(.normal)
            context.move(to: CGPoint(x: fixedMainDiameter + borderOffset, y: fixedMainDiameter / 2.0))
            context.addLine(to: CGPoint(x: fixedMainDiameter + borderOffset, y: outlineBottomEllipse.midY))
            context.strokePath()
            
            let bubbleTailContext = DrawingContext(size: imageSize)
            bubbleTailContext.withFlippedContext { context in
                context.clear(CGRect(origin: CGPoint(), size: rawSize))
                context.translateBy(x: additionalInset + strokeInset, y: additionalInset + strokeInset)
                
                context.setStrokeColor(UIColor.black.cgColor)
                context.setLineWidth(borderWidth)
                
                if maxCornerRadius >= minRadiusForFullTailCorner {
                    context.move(to: CGPoint(x: outlineBottomEllipse.minX, y: outlineBottomEllipse.midY))
                    context.addQuadCurve(to: CGPoint(x: outlineBottomEllipse.midX, y: outlineBottomEllipse.maxY), control: CGPoint(x: outlineBottomEllipse.minX, y: outlineBottomEllipse.maxY))
                    context.addQuadCurve(to: CGPoint(x: outlineBottomEllipse.maxX, y: outlineBottomEllipse.midY), control: CGPoint(x: outlineBottomEllipse.maxX, y: outlineBottomEllipse.maxY))
                } else {
                    context.move(to: CGPoint(x: outlineBottomEllipse.minX - 2.0, y: outlineBottomEllipse.maxY))
                    context.addLine(to: CGPoint(x: outlineBottomEllipse.minX, y: outlineBottomEllipse.maxY))
                    context.addLine(to: CGPoint(x: outlineBottomEllipse.maxX, y: outlineBottomEllipse.maxY))
                }
                context.strokePath()
                context.setFillColor(UIColor.clear.cgColor)
                context.setBlendMode(.copy)
                context.fillEllipse(in: outlineInnerTopEllipse)
                
                context.move(to: CGPoint(x: 0.0, y: topLeftRadius))
                context.addArc(tangent1End: CGPoint(x: 0.0, y: 0.0), tangent2End: CGPoint(x: topLeftRadius, y: 0.0), radius: topLeftRadius)
                context.addLine(to: CGPoint(x: fixedMainDiameter - topRightRadius, y: 0.0))
                context.addArc(tangent1End: CGPoint(x: fixedMainDiameter, y: 0.0), tangent2End: CGPoint(x: fixedMainDiameter, y: topRightRadius), radius: topRightRadius)
                context.addLine(to: CGPoint(x: fixedMainDiameter, y: fixedMainDiameter - bottomRightRadius))
                context.addArc(tangent1End: CGPoint(x: fixedMainDiameter, y: fixedMainDiameter), tangent2End: CGPoint(x: fixedMainDiameter - bottomRightRadius, y: fixedMainDiameter), radius: bottomRightRadius)
                context.addLine(to: CGPoint(x: bottomLeftRadius, y: fixedMainDiameter))
                context.addArc(tangent1End: CGPoint(x: 0.0, y: fixedMainDiameter), tangent2End: CGPoint(x: 0.0, y: fixedMainDiameter - bottomLeftRadius), radius: bottomLeftRadius)
                context.addLine(to: CGPoint(x: 0.0, y: topLeftRadius))
                context.fillPath()
                
                let bottomEllipseMask = generateImage(bottomEllipse.insetBy(dx: -1.0, dy: -1.0).size, contextGenerator: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setFillColor(UIColor.black.cgColor)
                    if maxCornerRadius >= minRadiusForFullTailCorner {
                        context.fillEllipse(in: CGRect(origin: CGPoint(x: 1.0 - borderOffset, y: 1.0 - borderOffset), size: CGSize(width: outlineBottomEllipse.width, height: outlineBottomEllipse.height)))
                    } else {
                        context.fill(CGRect(origin: CGPoint(x: 1.0 - borderOffset, y: 1.0 - borderOffset), size: CGSize(width: outlineBottomEllipse.width, height: outlineBottomEllipse.height)))
                    }
                    context.clear(CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height / 2.0)))
                })!
                
                context.clip(to: bottomEllipse.insetBy(dx: -1.0, dy: -1.0), mask: bottomEllipseMask.cgImage!)
                context.strokeEllipse(in: outlineInnerTopEllipse)
                context.resetClip()
            }
            
            context.translateBy(x: -(additionalInset + strokeInset), y: -(additionalInset + strokeInset))
            context.draw(bubbleTailContext.generateImage()!.cgImage!, in: CGRect(origin: CGPoint(), size: rawSize))
            context.translateBy(x: additionalInset + strokeInset, y: additionalInset + strokeInset)
        }
    }
    let outlineImage = generateImage(outlineContext.size, contextGenerator: { size, context in
        context.setBlendMode(.copy)
        let image = outlineContext.generateImage()!
        context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
    })!
    
    let drawingContext = DrawingContext(size: imageSize)
    drawingContext.withFlippedContext { context in
        if onlyShadow {
            context.clear(CGRect(origin: CGPoint(), size: rawSize))
            
            if let shadow = shadow {
                context.translateBy(x: rawSize.width / 2.0, y: rawSize.height / 2.0)
                context.scaleBy(x: incoming ? -1.0 : 1.0, y: -1.0)
                context.translateBy(x: -rawSize.width / 2.0, y: -rawSize.height / 2.0)
                
                context.setShadow(offset: CGSize(width: 0.0, height: -shadow.verticalOffset), blur: shadow.radius, color: shadow.color.cgColor)
                context.draw(formImage.cgImage!, in: CGRect(origin: CGPoint(), size: rawSize))
                
                context.setBlendMode(.copy)
                context.setFillColor(UIColor.clear.cgColor)
                context.clip(to: CGRect(origin: CGPoint(), size: rawSize), mask: formImage.cgImage!)
                context.fill(CGRect(origin: CGPoint(), size: rawSize))
            }
        } else {
            var drawWithClearColor = false
            
            if knockout {
                drawWithClearColor = !mask
                if case let .color(color) = wallpaper {
                    context.setFillColor(UIColor(rgb: UInt32(color)).cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: rawSize))
                } else {
                    context.clear(CGRect(origin: CGPoint(), size: rawSize))
                }
            } else {
                context.clear(CGRect(origin: CGPoint(), size: rawSize))
            }
            
            if drawWithClearColor {
                context.setBlendMode(.copy)
                context.setFillColor(UIColor.clear.cgColor)
            } else {
                context.setBlendMode(.normal)
                context.setFillColor(fillColor.cgColor)
            }
            
            context.saveGState()
            
            context.translateBy(x: rawSize.width / 2.0, y: rawSize.height / 2.0)
            context.scaleBy(x: incoming ? -1.0 : 1.0, y: -1.0)
            context.translateBy(x: -rawSize.width / 2.0, y: -rawSize.height / 2.0)
            
            if !onlyOutline {
                context.clip(to: CGRect(origin: CGPoint(), size: rawSize), mask: formImage.cgImage!)
                context.fill(CGRect(origin: CGPoint(), size: rawSize))
                
                if alwaysFillColor && drawWithClearColor {
                    context.setBlendMode(.normal)
                    context.setFillColor(fillColor.cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: rawSize))
                }
            } else {
                context.setFillColor(strokeColor.cgColor)
                context.clip(to: CGRect(origin: CGPoint(), size: rawSize), mask: outlineImage.cgImage!)
                context.fill(CGRect(origin: CGPoint(), size: rawSize))
            }
            
            context.restoreGState()
        }
    }
    
    return drawingContext.generateImage()!.stretchableImage(withLeftCapWidth: incoming ? incomingStretchPoint.x : outgoingStretchPoint.x, topCapHeight: incoming ? incomingStretchPoint.y : outgoingStretchPoint.y)
}

public enum MessageBubbleActionButtonPosition {
    case middle
    case bottomLeft
    case bottomRight
    case bottomSingle
}

public func messageBubbleActionButtonImage(color: UIColor, strokeColor: UIColor, position: MessageBubbleActionButtonPosition, bubbleCorners: PresentationChatBubbleCorners) -> UIImage {
    let largeRadius: CGFloat = bubbleCorners.mainRadius
    let smallRadius: CGFloat = (bubbleCorners.mergeBubbleCorners && largeRadius >= 10.0) ? bubbleCorners.auxiliaryRadius : bubbleCorners.mainRadius
    let size: CGSize
    if case .middle = position {
        size = CGSize(width: smallRadius + smallRadius, height: smallRadius + smallRadius)
    } else {
        size = CGSize(width: largeRadius + largeRadius, height: largeRadius + largeRadius)
    }
    return generateImage(size, contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        if case .bottomRight = position {
            context.scaleBy(x: -1.0, y: -1.0)
        } else {
            context.scaleBy(x: 1.0, y: -1.0)
        }
        context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
        context.setBlendMode(.copy)
        var effectiveStrokeColor: UIColor?
        var strokeAlpha: CGFloat = 0.0
        strokeColor.getRed(nil, green: nil, blue: nil, alpha: &strokeAlpha)
        if !strokeAlpha.isZero {
            effectiveStrokeColor = strokeColor
        }
        context.setFillColor(color.cgColor)
        let lineWidth: CGFloat = 1.0
        let halfLineWidth = lineWidth / 2.0
        if let effectiveStrokeColor = effectiveStrokeColor {
            context.setStrokeColor(effectiveStrokeColor.cgColor)
            context.setLineWidth(lineWidth)
        }
        switch position {
            case .middle:
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                if effectiveStrokeColor != nil {
                    context.setBlendMode(.normal)
                    context.strokeEllipse(in: CGRect(origin: CGPoint(x: halfLineWidth, y: halfLineWidth), size: CGSize(width: size.width - lineWidth, height: size.height - lineWidth)))
                    context.setBlendMode(.copy)
                }
            case .bottomLeft, .bottomRight:
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: smallRadius + smallRadius, height: smallRadius + smallRadius)))
                context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - smallRadius - smallRadius, y: 0.0), size: CGSize(width: smallRadius + smallRadius, height: smallRadius + smallRadius)))
                context.fill(CGRect(origin: CGPoint(x: smallRadius, y: 0.0), size: CGSize(width: size.width - smallRadius - smallRadius, height: smallRadius + smallRadius)))
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: smallRadius + smallRadius, height: smallRadius + smallRadius)))
                context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - smallRadius - smallRadius, y: 0.0), size: CGSize(width: smallRadius + smallRadius, height: smallRadius + smallRadius)))
                context.fill(CGRect(origin: CGPoint(x: smallRadius, y: 0.0), size: CGSize(width: size.width - smallRadius - smallRadius, height: smallRadius + smallRadius)))
                context.fill(CGRect(origin: CGPoint(x: 0.0, y: smallRadius), size: CGSize(width: size.width, height: size.height - largeRadius - smallRadius)))
                context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - smallRadius - smallRadius, y: size.height - smallRadius - smallRadius), size: CGSize(width: smallRadius + smallRadius, height: smallRadius + smallRadius)))
                context.fill(CGRect(origin: CGPoint(x: largeRadius, y: size.height - largeRadius - largeRadius), size: CGSize(width: size.width - smallRadius - largeRadius, height: largeRadius + largeRadius)))
                context.fill(CGRect(origin: CGPoint(x: size.width - smallRadius, y: size.height - largeRadius), size: CGSize(width: smallRadius, height: largeRadius - smallRadius)))
                if effectiveStrokeColor != nil {
                    context.setBlendMode(.normal)
                    context.beginPath()
                    context.move(to: CGPoint(x: halfLineWidth, y: smallRadius + halfLineWidth))
                    context.addArc(tangent1End: CGPoint(x: halfLineWidth, y: halfLineWidth), tangent2End: CGPoint(x: halfLineWidth + smallRadius, y: halfLineWidth), radius: smallRadius)
                    context.addLine(to: CGPoint(x: size.width - smallRadius, y: halfLineWidth))
                    context.addArc(tangent1End: CGPoint(x: size.width - halfLineWidth, y: halfLineWidth), tangent2End: CGPoint(x: size.width - halfLineWidth, y: halfLineWidth + smallRadius), radius: smallRadius)
                    context.addLine(to: CGPoint(x: size.width - halfLineWidth, y: size.height - halfLineWidth - smallRadius))
                    context.addArc(tangent1End: CGPoint(x: size.width - halfLineWidth, y: size.height - halfLineWidth), tangent2End: CGPoint(x: size.width - halfLineWidth - smallRadius, y: size.height - halfLineWidth), radius: smallRadius)
                    context.addLine(to: CGPoint(x: halfLineWidth + largeRadius, y: size.height - halfLineWidth))
                    context.addArc(tangent1End: CGPoint(x: halfLineWidth, y: size.height - halfLineWidth), tangent2End: CGPoint(x: halfLineWidth, y: size.height - halfLineWidth - largeRadius), radius: largeRadius)
                    
                    context.closePath()
                    context.strokePath()
                    context.setBlendMode(.copy)
                }
            case .bottomSingle:
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: smallRadius + smallRadius, height: smallRadius + smallRadius)))
                context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - smallRadius - smallRadius, y: 0.0), size: CGSize(width: smallRadius + smallRadius, height: smallRadius + smallRadius)))
                context.fill(CGRect(origin: CGPoint(x: smallRadius, y: 0.0), size: CGSize(width: size.width - smallRadius - smallRadius, height: smallRadius + smallRadius)))
                context.fill(CGRect(origin: CGPoint(x: 0.0, y: smallRadius), size: CGSize(width: size.width, height: size.height - largeRadius - smallRadius)))
            
                if effectiveStrokeColor != nil {
                    context.setBlendMode(.normal)
                    context.beginPath()
                    context.move(to: CGPoint(x: halfLineWidth, y: smallRadius + halfLineWidth))
                    context.addArc(tangent1End: CGPoint(x: halfLineWidth, y: halfLineWidth), tangent2End: CGPoint(x: halfLineWidth + smallRadius, y: halfLineWidth), radius: smallRadius)
                    context.addLine(to: CGPoint(x: size.width - smallRadius, y: halfLineWidth))
                    context.addArc(tangent1End: CGPoint(x: size.width - halfLineWidth, y: halfLineWidth), tangent2End: CGPoint(x: size.width - halfLineWidth, y: halfLineWidth + smallRadius), radius: smallRadius)
                    context.addLine(to: CGPoint(x: size.width - halfLineWidth, y: size.height - halfLineWidth - largeRadius))
                    context.addArc(tangent1End: CGPoint(x: size.width - halfLineWidth, y: size.height - halfLineWidth), tangent2End: CGPoint(x: size.width - halfLineWidth - largeRadius, y: size.height - halfLineWidth), radius: largeRadius)
                    context.addLine(to: CGPoint(x: halfLineWidth + largeRadius, y: size.height - halfLineWidth))
                    context.addArc(tangent1End: CGPoint(x: halfLineWidth, y: size.height - halfLineWidth), tangent2End: CGPoint(x: halfLineWidth, y: size.height - halfLineWidth - largeRadius), radius: largeRadius)
                    
                    context.closePath()
                    context.strokePath()
                    context.setBlendMode(.copy)
                }
        }
    })!.stretchableImage(withLeftCapWidth: Int(size.width / 2.0), topCapHeight: Int(size.height / 2.0))
}
