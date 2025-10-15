import Foundation
import UIKit
import Display
import ManagedAnimationNode

final class SemanticStatusNodeIconContext: SemanticStatusNodeStateContext {
    final class DrawingState: NSObject, SemanticStatusNodeStateDrawingState {
        let transitionFraction: CGFloat
        let icon: SemanticStatusNodeIcon
        let iconImage: UIImage?
        let iconOffset: CGFloat
        
        init(transitionFraction: CGFloat, icon: SemanticStatusNodeIcon, iconImage: UIImage?, iconOffset: CGFloat) {
            self.transitionFraction = transitionFraction
            self.icon = icon
            self.iconImage = iconImage
            self.iconOffset = iconOffset
            
            super.init()
        }
        
        func draw(context: CGContext, size: CGSize, foregroundColor: UIColor) {
            let transitionScale = max(0.01, self.transitionFraction)
            
            context.saveGState()
            context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
            context.scaleBy(x: transitionScale, y: transitionScale)
            context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            
            if foregroundColor.alpha.isZero {
                context.setBlendMode(.destinationOut)
                context.setFillColor(UIColor(white: 0.0, alpha: self.transitionFraction).cgColor)
                context.setStrokeColor(UIColor(white: 0.0, alpha: self.transitionFraction).cgColor)
            } else {
                context.setBlendMode(.normal)
                context.setFillColor(foregroundColor.withAlphaComponent(foregroundColor.alpha * self.transitionFraction).cgColor)
                context.setStrokeColor(foregroundColor.withAlphaComponent(foregroundColor.alpha * self.transitionFraction).cgColor)
            }
            
            switch self.icon {
            case .none, .secretTimeout:
                break
            case .play, .pause:
                let diameter = size.width
                let factor = diameter / 50.0
               
                let size: CGSize
                let offset: CGFloat
                if let iconImage = self.iconImage {
                    size = iconImage.size
                    offset = self.iconOffset
                } else {
                    if case .play = self.icon {
                        offset = 1.5
                        size = CGSize(width: 15.0, height: 18.0)
                    } else {
                        size = CGSize(width: 15.0, height: 16.0)
                        offset = 0.0
                    }
                }
                context.translateBy(x: (diameter - size.width) / 2.0 + offset, y: (diameter - size.height) / 2.0)
                if (diameter < 40.0) {
                    context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                    context.scaleBy(x: factor, y: factor)
                    context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                }
                if let iconImage = self.iconImage {
                    context.saveGState()
                    let iconRect = CGRect(origin: CGPoint(), size: iconImage.size)//.applying(CGAffineTransformMakeScale(transitionScale, transitionScale))
                    context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                    context.scaleBy(x: 1.0, y: -1.0)
                    context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                    context.clip(to: iconRect, mask: iconImage.cgImage!)
                    context.fill(iconRect)
                    context.restoreGState()
                } else {
                    if case .play = self.icon {
                        let _ = try? drawSvgPath(context, path: "M1.71891969,0.209353049 C0.769586558,-0.350676705 0,0.0908839327 0,1.18800046 L0,16.8564753 C0,17.9569971 0.750549162,18.357187 1.67393713,17.7519379 L14.1073836,9.60224049 C15.0318735,8.99626906 15.0094718,8.04970371 14.062401,7.49100858 L1.71891969,0.209353049 ")
                    } else {
                        let _ = try? drawSvgPath(context, path: "M0,1.00087166 C0,0.448105505 0.443716645,0 0.999807492,0 L4.00019251,0 C4.55237094,0 5,0.444630861 5,1.00087166 L5,14.9991283 C5,15.5518945 4.55628335,16 4.00019251,16 L0.999807492,16 C0.447629061,16 0,15.5553691 0,14.9991283 L0,1.00087166 Z M10,1.00087166 C10,0.448105505 10.4437166,0 10.9998075,0 L14.0001925,0 C14.5523709,0 15,0.444630861 15,1.00087166 L15,14.9991283 C15,15.5518945 14.5562834,16 14.0001925,16 L10.9998075,16 C10.4476291,16 10,15.5553691 10,14.9991283 L10,1.00087166 ")
                    }
                    context.fillPath()
                }
            case let .custom(image):
                let diameter = size.width
                let imageRect = CGRect(origin: CGPoint(x: floor((diameter - image.size.width) / 2.0), y: floor((diameter - image.size.height) / 2.0)), size: image.size)
                
                context.translateBy(x: imageRect.midX, y: imageRect.midY)
                context.scaleBy(x: 1.0, y: -1.0)
                context.translateBy(x: -imageRect.midX, y: -imageRect.midY)
                context.clip(to: imageRect, mask: image.cgImage!)
                context.fill(imageRect)
            case .download:
                let diameter = size.width
                let factor = diameter / 50.0
                let lineWidth: CGFloat = max(1.6, 2.25 * factor)
                
                context.setLineWidth(lineWidth)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                
                let arrowHeadSize: CGFloat = 15.0 * factor
                let arrowLength: CGFloat = 18.0 * factor
                let arrowHeadOffset: CGFloat = 1.0 * factor

                let leftPath = UIBezierPath()
                leftPath.lineWidth = lineWidth
                leftPath.lineCapStyle = .round
                leftPath.lineJoinStyle = .round
                leftPath.move(to: CGPoint(x: diameter / 2.0, y: diameter / 2.0 + arrowLength / 2.0 + arrowHeadOffset))
                leftPath.addLine(to: CGPoint(x: diameter / 2.0 - arrowHeadSize / 2.0, y: diameter / 2.0 + arrowLength / 2.0 - arrowHeadSize / 2.0 + arrowHeadOffset))
                leftPath.stroke()
                
                let rightPath = UIBezierPath()
                rightPath.lineWidth = lineWidth
                rightPath.lineCapStyle = .round
                rightPath.lineJoinStyle = .round
                rightPath.move(to: CGPoint(x: diameter / 2.0, y: diameter / 2.0 + arrowLength / 2.0 + arrowHeadOffset))
                rightPath.addLine(to: CGPoint(x: diameter / 2.0 + arrowHeadSize / 2.0, y: diameter / 2.0 + arrowLength / 2.0 - arrowHeadSize / 2.0 + arrowHeadOffset))
                rightPath.stroke()
                
                let bodyPath = UIBezierPath()
                bodyPath.lineWidth = lineWidth
                bodyPath.lineCapStyle = .round
                bodyPath.lineJoinStyle = .round
                bodyPath.move(to: CGPoint(x: diameter / 2.0, y: diameter / 2.0 - arrowLength / 2.0))
                bodyPath.addLine(to: CGPoint(x: diameter / 2.0, y: diameter / 2.0 + arrowLength / 2.0))
                bodyPath.stroke()
            }
            context.restoreGState()
        }
    }
    
    private(set) var icon: SemanticStatusNodeIcon

    private var animationNode: PlayPauseIconNode?
    private var iconImage: UIImage?
    private var iconOffset: CGFloat = 0.0
    
    init(icon: SemanticStatusNodeIcon) {
        self.icon = icon
        
        if [.play, .pause].contains(icon) {
            self.animationNode = PlayPauseIconNode()
            self.animationNode?.imageUpdated = { [weak self] image in
                if let strongSelf = self {
                    strongSelf.iconImage = image
                    if var position = strongSelf.animationNode?.state?.position {
                        position = position * 2.0
                        if position > 1.0 {
                            position = 2.0 - position
                        }
                        strongSelf.iconOffset = (1.0 - position) * 1.5
                    }
                    strongSelf.requestUpdate()
                }
            }
            self.animationNode?.enqueueState(self.icon == .play ? .play : .pause, animated: false)
            self.iconImage = self.animationNode?.image
            self.iconOffset = 1.5
        }
    }
    
    var isAnimating: Bool {
        return false
    }
    
    var requestUpdate: () -> Void = {}
    
    func setIcon(icon: SemanticStatusNodeIcon, animated: Bool) {
        self.icon = icon
        self.animationNode?.enqueueState(self.icon == .play ? .play : .pause, animated: animated)
    }
    
    func drawingState(transitionFraction: CGFloat) -> SemanticStatusNodeStateDrawingState {
        return DrawingState(transitionFraction: transitionFraction, icon: self.icon, iconImage: self.iconImage, iconOffset: self.iconOffset)
    }
}

private enum PlayPauseIconNodeState: Equatable {
    case play
    case pause
}

private final class PlayPauseIconNode: ManagedAnimationNode {
    private let duration: Double = 0.35
    private var iconState: PlayPauseIconNodeState = .play
    
    init() {
        super.init(size: CGSize(width: 36.0, height: 36.0))
        
        self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.01))
    }
    
    func enqueueState(_ state: PlayPauseIconNodeState, animated: Bool) {
        guard self.iconState != state else {
            return
        }
        
        let previousState = self.iconState
        self.iconState = state
        
        switch previousState {
            case .pause:
                switch state {
                    case .play:
                        if animated {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 41, endFrame: 83), duration: self.duration))
                        } else {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.01))
                        }
                    case .pause:
                        break
                }
            case .play:
                switch state {
                    case .pause:
                        if animated {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 0, endFrame: 41), duration: self.duration))
                        } else {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 41, endFrame: 41), duration: 0.01))
                        }
                    case .play:
                        break
                }
        }
    }
}
