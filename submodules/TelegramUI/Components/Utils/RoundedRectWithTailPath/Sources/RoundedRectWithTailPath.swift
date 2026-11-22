import Foundation
import UIKit

public func generateRoundedRectWithTailPath(rectSize: CGSize, cornerRadius: CGFloat? = nil, tailSize: CGSize = CGSize(width: 20.0, height: 9.0), tailRadius: CGFloat = 4.0, tailPosition: CGFloat? = 0.5, transformTail: Bool = true) -> UIBezierPath {
    let cornerRadius: CGFloat = cornerRadius ?? rectSize.height / 2.0
    let tailWidth: CGFloat = tailSize.width
    let tailHeight: CGFloat = tailSize.height

    let rect = CGRect(origin: CGPoint(x: 0.0, y: tailHeight), size: rectSize)
    
    guard let tailPosition else {
        return UIBezierPath(cgPath: CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
    }

    let cutoff: CGFloat = 0.27
    
    let path = UIBezierPath()
    path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))

    var leftArcEndAngle: CGFloat = .pi / 2.0
    var leftConnectionArcRadius = tailRadius
    var tailLeftHalfWidth: CGFloat = tailWidth / 2.0
    var tailLeftArcStartAngle: CGFloat = -.pi / 4.0
    var tailLeftHalfRadius = tailRadius
    
    var rightArcStartAngle: CGFloat = -.pi / 2.0
    var rightConnectionArcRadius = tailRadius
    var tailRightHalfWidth: CGFloat = tailWidth / 2.0
    var tailRightArcStartAngle: CGFloat = .pi / 4.0
    var tailRightHalfRadius = tailRadius
    
    if transformTail {
        if tailPosition < 0.5 {
            let fraction = max(0.0, tailPosition - 0.15) / 0.35
            leftArcEndAngle *= fraction
            
            let connectionFraction = max(0.0, tailPosition - 0.35) / 0.15
            leftConnectionArcRadius *= connectionFraction
            
            if tailPosition < cutoff {
                let fraction = tailPosition / cutoff
                tailLeftHalfWidth *= fraction
                tailLeftArcStartAngle *= fraction
                tailLeftHalfRadius *= fraction
            }
        } else if tailPosition > 0.5 {
            let tailPosition = 1.0 - tailPosition
            let fraction = max(0.0, tailPosition - 0.15) / 0.35
            rightArcStartAngle *= fraction
            
            let connectionFraction = max(0.0, tailPosition - 0.35) / 0.15
            rightConnectionArcRadius *= connectionFraction
            
            if tailPosition < cutoff {
                let fraction = tailPosition / cutoff
                tailRightHalfWidth *= fraction
                tailRightArcStartAngle *= fraction
                tailRightHalfRadius *= fraction
            }
        }
    }
    
    path.addArc(
        withCenter: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
        radius: cornerRadius,
        startAngle: .pi,
        endAngle: .pi + max(0.0001, leftArcEndAngle),
        clockwise: true
    )

    let leftArrowStart = max(rect.minX, rect.minX + rectSize.width * tailPosition - tailLeftHalfWidth - leftConnectionArcRadius)
    path.addArc(
        withCenter: CGPoint(x: leftArrowStart, y: rect.minY - leftConnectionArcRadius),
        radius: leftConnectionArcRadius,
        startAngle: .pi / 2.0,
        endAngle: .pi / 4.0,
        clockwise: false
    )

    path.addLine(to: CGPoint(x: max(rect.minX, rect.minX + rectSize.width * tailPosition - tailLeftHalfRadius), y: rect.minY - tailHeight))

    path.addArc(
        withCenter: CGPoint(x: rect.minX + rectSize.width * tailPosition, y: rect.minY - tailHeight + tailRadius / 2.0),
        radius: tailRadius,
        startAngle: -.pi / 2.0 + tailLeftArcStartAngle,
        endAngle: -.pi / 2.0 + tailRightArcStartAngle,
        clockwise: true
    )
    
    path.addLine(to: CGPoint(x: min(rect.maxX, rect.minX + rectSize.width * tailPosition + tailRightHalfRadius), y: rect.minY - tailHeight))

    let rightArrowStart = min(rect.maxX, rect.minX + rectSize.width * tailPosition + tailRightHalfWidth + rightConnectionArcRadius)
    path.addArc(
        withCenter: CGPoint(x: rightArrowStart, y: rect.minY - rightConnectionArcRadius),
        radius: rightConnectionArcRadius,
        startAngle: .pi - .pi / 4.0,
        endAngle: .pi / 2.0,
        clockwise: false
    )

    path.addArc(
        withCenter: CGPoint(x: rect.minX + rectSize.width - cornerRadius, y: rect.minY + cornerRadius),
        radius: cornerRadius,
        startAngle: min(-0.0001, rightArcStartAngle),
        endAngle: 0.0,
        clockwise: true
    )

    path.addLine(to: CGPoint(x: rect.minX + rectSize.width, y: rect.minY + rectSize.height - cornerRadius))

    path.addArc(
        withCenter: CGPoint(x: rect.minX + rectSize.width - cornerRadius, y: rect.minY + rectSize.height - cornerRadius),
        radius: cornerRadius,
        startAngle: 0.0,
        endAngle: .pi / 2.0,
        clockwise: true
    )

    path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + rectSize.height))

    path.addArc(
        withCenter: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + rectSize.height - cornerRadius),
        radius: cornerRadius,
        startAngle: .pi / 2.0,
        endAngle: .pi,
        clockwise: true
    )
    
    return path
}
