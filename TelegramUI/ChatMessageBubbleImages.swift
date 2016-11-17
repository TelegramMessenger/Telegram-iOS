import Foundation
import Display

private let incomingFillColor = UIColor(0xffffff)
private let incomingStrokeColor = UIColor(0x86A9C9, 0.5)

private let outgoingFillColor = UIColor(0xE1FFC7)
private let outgoingStrokeColor = UIColor(0x86A9C9, 0.5)

enum MessageBubbleImageNeighbors {
    case none
    case top
    case bottom
    case both
}

func messageBubbleImage(incoming: Bool, neighbors: MessageBubbleImageNeighbors) -> UIImage {
    let diameter: CGFloat = 36.0
    let corner: CGFloat = 7.0
    return generateImage(CGSize(width: 42.0, height: diameter), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        let additionalOffset: CGFloat
        switch neighbors {
            case .none, .bottom:
                additionalOffset = 0.0
            case .both, .top:
                additionalOffset = 6.0
        }
        
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.scaleBy(x: incoming ? 1.0 : -1.0, y: -1.0)
        context.translateBy(x: -size.width / 2.0 + 0.5 + additionalOffset, y: -size.height / 2.0 + 0.5)
        
        let lineWidth: CGFloat = 1.0
        
        context.setFillColor((incoming ? incomingFillColor : outgoingFillColor).cgColor)
        context.setLineWidth(lineWidth)
        context.setStrokeColor((incoming ? incomingStrokeColor : outgoingStrokeColor).cgColor)
        
        switch neighbors {
            case .none:
                let _ = try? drawSvgPath(context, path: "M6,17.5 C6,7.83289181 13.8350169,0 23.5,0 C33.1671082,0 41,7.83501688 41,17.5 C41,27.1671082 33.1649831,35 23.5,35 C19.2941198,35 15.4354328,33.5169337 12.4179496,31.0453367 C9.05531719,34.9894816 -2.41102995e-08,35 0,35 C5.972003,31.5499861 6,26.8616169 6,26.8616169 L6,17.5 L6,17.5 ")
                context.strokePath()
                let _ = try? drawSvgPath(context, path: "M6,17.5 C6,7.83289181 13.8350169,0 23.5,0 C33.1671082,0 41,7.83501688 41,17.5 C41,27.1671082 33.1649831,35 23.5,35 C19.2941198,35 15.4354328,33.5169337 12.4179496,31.0453367 C9.05531719,34.9894816 -2.41102995e-08,35 0,35 C5.972003,31.5499861 6,26.8616169 6,26.8616169 L6,17.5 L6,17.5 ")
                context.fillPath()
            case .top:
                let _ = try? drawSvgPath(context, path: "M35,17.5 C35,7.83501688 27.1671082,0 17.5,0 L17.5,0 C7.83501688,0 0,7.83289181 0,17.5 L0,29.0031815 C0,32.3151329 2.6882755,35 5.99681848,35 L17.5,35 C27.1649831,35 35,27.1671082 35,17.5 L35,17.5 L35,17.5 ")
                context.strokePath()
                let _ = try? drawSvgPath(context, path: "M35,17.5 C35,7.83501688 27.1671082,0 17.5,0 L17.5,0 C7.83501688,0 0,7.83289181 0,17.5 L0,29.0031815 C0,32.3151329 2.6882755,35 5.99681848,35 L17.5,35 C27.1649831,35 35,27.1671082 35,17.5 L35,17.5 L35,17.5 ")
                context.fillPath()
            case .bottom:
                let _ = try? drawSvgPath(context, path: "M6,17.5 L6,5.99681848 C6,2.6882755 8.68486709,0 11.9968185,0 L23.5,0 C33.1671082,0 41,7.83501688 41,17.5 C41,27.1671082 33.1649831,35 23.5,35 C19.2941198,35 15.4354328,33.5169337 12.4179496,31.0453367 C9.05531719,34.9894816 -2.41103066e-08,35 0,35 C5.972003,31.5499861 6,26.8616169 6,26.8616169 L6,17.5 L6,17.5 ")
                context.strokePath()
                let _ = try? drawSvgPath(context, path: "M6,17.5 L6,5.99681848 C6,2.6882755 8.68486709,0 11.9968185,0 L23.5,0 C33.1671082,0 41,7.83501688 41,17.5 C41,27.1671082 33.1649831,35 23.5,35 C19.2941198,35 15.4354328,33.5169337 12.4179496,31.0453367 C9.05531719,34.9894816 -2.41103066e-08,35 0,35 C5.972003,31.5499861 6,26.8616169 6,26.8616169 L6,17.5 L6,17.5 ")
                context.fillPath()
            case .both:
                let _ = try? drawSvgPath(context, path: "M35,17.5 C35,7.83501688 27.1671082,0 17.5,0 L5.99681848,0 C2.68486709,0 0,2.6882755 0,5.99681848 L0,29.0031815 C0,32.3151329 2.6882755,35 5.99681848,35 L17.5,35 C27.1649831,35 35,27.1671082 35,17.5 L35,17.5 L35,17.5 ")
                context.strokePath()
                let _ = try? drawSvgPath(context, path: "M35,17.5 C35,7.83501688 27.1671082,0 17.5,0 L5.99681848,0 C2.68486709,0 0,2.6882755 0,5.99681848 L0,29.0031815 C0,32.3151329 2.6882755,35 5.99681848,35 L17.5,35 C27.1649831,35 35,27.1671082 35,17.5 L35,17.5 L35,17.5 ")
                context.fillPath()
        }
    })!.stretchableImage(withLeftCapWidth: incoming ? Int(corner + diameter / 2.0) : Int(diameter / 2.0), topCapHeight: Int(diameter / 2.0))
}

enum MessageBubbleActionButtonPosition {
    case middle
    case bottomLeft
    case bottomRight
    case bottomSingle
}

func messageBubbleActionButtonImage(color: UIColor, position: MessageBubbleActionButtonPosition) -> UIImage {
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
        context.setFillColor(color.cgColor)
        context.setBlendMode(.copy)
        switch position {
            case .middle:
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
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
            case .bottomSingle:
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: smallRadius + smallRadius, height: smallRadius + smallRadius)))
                context.fillEllipse(in: CGRect(origin: CGPoint(x: size.width - smallRadius - smallRadius, y: 0.0), size: CGSize(width: smallRadius + smallRadius, height: smallRadius + smallRadius)))
                context.fill(CGRect(origin: CGPoint(x: smallRadius, y: 0.0), size: CGSize(width: size.width - smallRadius - smallRadius, height: smallRadius + smallRadius)))
                context.fill(CGRect(origin: CGPoint(x: 0.0, y: smallRadius), size: CGSize(width: size.width, height: size.height - largeRadius - smallRadius)))
        }
    })!.stretchableImage(withLeftCapWidth: Int(size.width / 2.0), topCapHeight: Int(size.height / 2.0))
}
