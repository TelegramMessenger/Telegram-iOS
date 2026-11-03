import Foundation
import UIKit
import Display
import ComponentFlow

public final class MaskedContainerView: UIView {
    public struct Item: Equatable {
        public enum Shape: Equatable {
            case ellipse
            case roundedRect(cornerRadius: CGFloat)
        }

        public var frame: CGRect
        public var shape: Shape

        public init(frame: CGRect, shape: Shape) {
            self.frame = frame
            self.shape = shape
        }
    }

    private struct Params: Equatable {
        let size: CGSize
        let items: [Item]
        let isInverted: Bool
        
        init(size: CGSize, items: [Item], isInverted: Bool) {
            self.size = size
            self.items = items
            self.isInverted = isInverted
        }
    }

    public let contentView: UIView
    public let contentMaskView: UIImageView
    
    private var params: Params?

    override public init(frame: CGRect) {
        self.contentView = UIView()
        self.contentMaskView = UIImageView()

        super.init(frame: frame)

        self.addSubview(self.contentView)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(size: CGSize, items: [Item], isInverted: Bool) {
        let params = Params(size: size, items: items, isInverted: isInverted)
        if self.params == params {
            return
        }
        self.params = params
        self.contentView.frame = CGRect(origin: CGPoint(), size: size)
        self.contentMaskView.frame = CGRect(origin: CGPoint(), size: size)
        
        if items.isEmpty {
            self.contentMaskView.image = nil
            self.contentView.mask = nil
        } else {
            let renderer = UIGraphicsImageRenderer(bounds: CGRect(origin: CGPoint(), size: size))
            let image = renderer.image { context in
                UIGraphicsPushContext(context.cgContext)
                
                if isInverted {
                    context.cgContext.setFillColor(UIColor.black.cgColor)
                    context.cgContext.fill(CGRect(origin: CGPoint(), size: size))
                    
                    context.cgContext.setFillColor(UIColor.clear.cgColor)
                    context.cgContext.setBlendMode(.copy)
                }
                
                for item in items {
                    switch item.shape {
                    case .ellipse:
                        context.cgContext.fillEllipse(in: item.frame)
                    case let .roundedRect(cornerRadius):
                        context.cgContext.addPath(UIBezierPath(roundedRect: item.frame, cornerRadius: cornerRadius).cgPath)
                        context.cgContext.fillPath()
                    }
                }
                
                UIGraphicsPopContext()
            }
            self.contentMaskView.image = image
            
            self.contentView.mask = self.contentMaskView
        }
    }
}
