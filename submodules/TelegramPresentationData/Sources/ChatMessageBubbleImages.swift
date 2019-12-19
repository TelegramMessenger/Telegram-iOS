import Foundation
import UIKit
import Display
import TelegramCore
import SyncCore

public enum MessageBubbleImageNeighbors {
    case none
    case top(side: Bool)
    case bottom
    case both
    case side
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

public func messageBubbleImage(incoming: Bool, fillColor: UIColor, strokeColor: UIColor, neighbors: MessageBubbleImageNeighbors, theme: PresentationThemeChat, wallpaper: TelegramWallpaper, knockout knockoutValue: Bool, mask: Bool = false, extendedEdges: Bool = false, onlyOutline: Bool = false) -> UIImage {
    let diameter: CGFloat = 36.0
    let corner: CGFloat = 7.0
    let knockout = knockoutValue && !mask
    
    let inset: CGFloat = 1.0
    
    return generateImage(CGSize(width: 42.0 + inset * 2.0, height: diameter + inset * 2.0), contextGenerator: { rawSize, context in
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
        
        let additionalOffset: CGFloat
        switch neighbors {
        case .none, .bottom:
            additionalOffset = 0.0
        case .both, .side, .top:
            additionalOffset = 6.0
        }
        
        context.translateBy(x: rawSize.width / 2.0, y: rawSize.height / 2.0)
        context.scaleBy(x: incoming ? 1.0 : -1.0, y: -1.0)
        context.translateBy(x: -rawSize.width / 2.0, y: -rawSize.height / 2.0)
        
        context.translateBy(x: additionalOffset + 0.5, y: 0.5)
        
        let size = CGSize(width: rawSize.width - inset * 2.0, height: rawSize.height - inset * 2.0)
        context.translateBy(x: inset, y: inset)
        
        var lineWidth: CGFloat = 1.0
        
        if drawWithClearColor {
            context.setBlendMode(.copy)
            context.setFillColor(UIColor.clear.cgColor)
            context.setStrokeColor(UIColor.clear.cgColor)
        } else {
            context.setFillColor(fillColor.cgColor)
            context.setLineWidth(lineWidth)
            context.setStrokeColor(strokeColor.cgColor)
        }
        
        if onlyOutline {
            if knockout {
                lineWidth = max(UIScreenPixel, 1.0 - 0.5)
            }
            context.setLineWidth(lineWidth)
            context.setStrokeColor(strokeColor.cgColor)
        }
        
        switch neighbors {
        case .none:
            if onlyOutline {
                let _ = try? drawSvgPath(context, path: "M6,17.5 C6,7.83289181 13.8350169,0 23.5,0 C33.1671082,0 41,7.83501688 41,17.5 C41,27.1671082 33.1649831,35 23.5,35 C19.2941198,35 15.4354328,33.5169337 12.4179496,31.0453367 C9.05531719,34.9894816 -2.41102995e-08,35 0,35 C5.972003,31.5499861 6,26.8616169 6,26.8616169 L6,17.5 L6,17.5 ")
                context.strokePath()
            } else {
                let _ = try? drawSvgPath(context, path: "M6,17.5 C6,7.83289181 13.8350169,0 23.5,0 C33.1671082,0 41,7.83501688 41,17.5 C41,27.1671082 33.1649831,35 23.5,35 C19.2941198,35 15.4354328,33.5169337 12.4179496,31.0453367 C9.05531719,34.9894816 -2.41102995e-08,35 0,35 C5.972003,31.5499861 6,26.8616169 6,26.8616169 L6,17.5 L6,17.5 ")
                context.fillPath()
            }
        case .side:
            if onlyOutline {
                context.strokeEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 35.0, height: 35.0)))
            } else {
                context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: 35.0, height: 35.0)))
            }
        case let .top(side):
            if side {
                if onlyOutline {
                    let _ = try? drawSvgPath(context, path: "M17.5,0 L17.5,0 C27.1649831,-1.7754286e-15 35,7.83501688 35,17.5 L35,29 C35,32.3137085 32.3137085,35 29,35 L6,35 C2.6862915,35 4.05812251e-16,32.3137085 0,29 L0,17.5 C-1.18361906e-15,7.83501688 7.83501688,1.7754286e-15 17.5,0 ")
                    context.strokePath()
                } else {
                    let _ = try? drawSvgPath(context, path: "M17.5,0 L17.5,0 C27.1649831,-1.7754286e-15 35,7.83501688 35,17.5 L35,29 C35,32.3137085 32.3137085,35 29,35 L6,35 C2.6862915,35 4.05812251e-16,32.3137085 0,29 L0,17.5 C-1.18361906e-15,7.83501688 7.83501688,1.7754286e-15 17.5,0 ")
                    context.fillPath()
                }
            } else {
                if onlyOutline {
                    let _ = try? drawSvgPath(context, path: "M35,17.5 C35,7.83501688 27.1671082,0 17.5,0 L17.5,0 C7.83501688,0 0,7.83289181 0,17.5 L0,29.0031815 C0,32.3151329 2.6882755,35 5.99681848,35 L17.5,35 C27.1649831,35 35,27.1671082 35,17.5 L35,17.5 L35,17.5 ")
                    context.strokePath()
                } else {
                    let _ = try? drawSvgPath(context, path: "M35,17.5 C35,7.83501688 27.1671082,0 17.5,0 L17.5,0 C7.83501688,0 0,7.83289181 0,17.5 L0,29.0031815 C0,32.3151329 2.6882755,35 5.99681848,35 L17.5,35 C27.1649831,35 35,27.1671082 35,17.5 L35,17.5 L35,17.5 ")
                    context.fillPath()
                }
            }
        case .bottom:
            if onlyOutline {
                let _ = try? drawSvgPath(context, path: "M6,17.5 L6,5.99681848 C6,2.6882755 8.68486709,0 11.9968185,0 L23.5,0 C33.1671082,0 41,7.83501688 41,17.5 C41,27.1671082 33.1649831,35 23.5,35 C19.2941198,35 15.4354328,33.5169337 12.4179496,31.0453367 C9.05531719,34.9894816 -2.41103066e-08,35 0,35 C5.972003,31.5499861 6,26.8616169 6,26.8616169 L6,17.5 L6,17.5 ")
                context.strokePath()
            } else {
                let _ = try? drawSvgPath(context, path: "M6,17.5 L6,5.99681848 C6,2.6882755 8.68486709,0 11.9968185,0 L23.5,0 C33.1671082,0 41,7.83501688 41,17.5 C41,27.1671082 33.1649831,35 23.5,35 C19.2941198,35 15.4354328,33.5169337 12.4179496,31.0453367 C9.05531719,34.9894816 -2.41103066e-08,35 0,35 C5.972003,31.5499861 6,26.8616169 6,26.8616169 L6,17.5 L6,17.5 ")
                context.fillPath()
            }
        case .both:
            if onlyOutline {
                let _ = try? drawSvgPath(context, path: "M35,17.5 C35,7.83501688 27.1671082,0 17.5,0 L5.99681848,0 C2.68486709,0 0,2.6882755 0,5.99681848 L0,29.0031815 C0,32.3151329 2.6882755,35 5.99681848,35 L17.5,35 C27.1649831,35 35,27.1671082 35,17.5 L35,17.5 L35,17.5 ")
                context.strokePath()
            } else {
                let _ = try? drawSvgPath(context, path: "M35,17.5 C35,7.83501688 27.1671082,0 17.5,0 L5.99681848,0 C2.68486709,0 0,2.6882755 0,5.99681848 L0,29.0031815 C0,32.3151329 2.6882755,35 5.99681848,35 L17.5,35 C27.1649831,35 35,27.1671082 35,17.5 L35,17.5 L35,17.5 ")
                context.fillPath()
            }
        }
    })!.stretchableImage(withLeftCapWidth: incoming ? Int(inset + corner + diameter / 2.0 - 1.0) : Int(inset + diameter / 2.0), topCapHeight: Int(inset + diameter / 2.0))
}

public enum MessageBubbleActionButtonPosition {
    case middle
    case bottomLeft
    case bottomRight
    case bottomSingle
}

public func messageBubbleActionButtonImage(color: UIColor, strokeColor: UIColor, position: MessageBubbleActionButtonPosition) -> UIImage {
    let largeRadius: CGFloat = 17.0
    let smallRadius: CGFloat = 6.0
    let size: CGSize
    if case .middle = position {
        size = CGSize(width: smallRadius + smallRadius, height: smallRadius + smallRadius)
    } else {
        size = CGSize(width: 35.0, height: 35.0)
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
