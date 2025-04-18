import Foundation
import UIKit
import Display
import AppBundle

private func addRoundedRectPath(context: CGContext, rect: CGRect, radius: CGFloat) {
    context.saveGState()
    context.translateBy(x: rect.minX, y: rect.minY)
    context.scaleBy(x: radius, y: radius)
    let fw = rect.width / radius
    let fh = rect.height / radius
    context.move(to: CGPoint(x: fw, y: fh / 2.0))
    context.addArc(tangent1End: CGPoint(x: fw, y: fh), tangent2End: CGPoint(x: fw/2, y: fh), radius: 1.0)
    context.addArc(tangent1End: CGPoint(x: 0, y: fh), tangent2End: CGPoint(x: 0, y: fh/2), radius: 1)
    context.addArc(tangent1End: CGPoint(x: 0, y: 0), tangent2End: CGPoint(x: fw/2, y: 0), radius: 1)
    context.addArc(tangent1End: CGPoint(x: fw, y: 0), tangent2End: CGPoint(x: fw, y: fh/2), radius: 1)
    context.closePath()
    context.restoreGState()
}

final class EmojiTooltipView: OverlayMaskContainerView {
    private struct Params: Equatable {
        var constrainedWidth: CGFloat
        var subjectWidth: CGFloat
        
        init(constrainedWidth: CGFloat, subjectWidth: CGFloat) {
            self.constrainedWidth = constrainedWidth
            self.subjectWidth = subjectWidth
        }
    }
    
    private struct Layout {
        var params: Params
        var size: CGSize
        
        init(params: Params, size: CGSize) {
            self.params = params
            self.size = size
        }
    }
    
    private let text: String
    
    private let backgroundView: UIImageView
    private let iconView: UIImageView
    private let textView: TextView
    
    private var currentLayout: Layout?
    
    init(text: String) {
        self.text = text
        
        self.backgroundView = UIImageView()
        
        self.iconView = UIImageView()
        self.textView = TextView()
        
        super.init(frame: CGRect())
        
        self.maskContents.addSubview(self.backgroundView)
        self.addSubview(self.iconView)
        self.addSubview(self.textView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func animateIn() {
        let anchorPoint = CGPoint(x: self.bounds.width * 0.5, y: 0.0)
        
        self.layer.animateSpring(from: 0.001 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5)
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: anchorPoint.x - self.bounds.width * 0.5, y: anchorPoint.y - self.bounds.height * 0.5)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: 0.5, additive: true)
    }
    
    func animateOut(completion: @escaping () -> Void) {
        let anchorPoint = CGPoint(x: self.bounds.width * 0.5, y: 0.0)
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
            completion()
        })
        self.layer.animateScale(from: 1.0, to: 0.4, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        self.layer.animatePosition(from: CGPoint(), to: CGPoint(x: anchorPoint.x - self.bounds.width * 0.5, y: anchorPoint.y - self.bounds.height * 0.5), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
    }
    
    func update(constrainedWidth: CGFloat, subjectWidth: CGFloat) -> CGSize {
        let params = Params(constrainedWidth: constrainedWidth, subjectWidth: subjectWidth)
        if let currentLayout = self.currentLayout, currentLayout.params == params {
            return currentLayout.size
        }
        let size = self.update(params: params)
        self.currentLayout = Layout(params: params, size: size)
        return size
    }
        
    private func update(params: Params) -> CGSize {
        let horizontalInset: CGFloat = 13.0
        let verticalInset: CGFloat = 10.0
        let arrowHeight: CGFloat = 8.0
        let iconSpacing: CGFloat = 5.0
        
        if self.iconView.image == nil {
            self.iconView.image = UIImage(bundleImageName: "Call/EmojiTooltipLock")?.withRenderingMode(.alwaysTemplate)
            self.iconView.tintColor = .white
        }
        let iconSize = self.iconView.image?.size ?? CGSize(width: 12.0, height: 12.0)
        
        let textSize = self.textView.update(
            string: self.text,
            fontSize: 15.0,
            fontWeight: 0.0,
            color: .white,
            constrainedWidth: params.constrainedWidth - horizontalInset * 2.0,
            transition: .immediate
        )
        
        let size = CGSize(width: iconSize.width + iconSpacing + textSize.width + horizontalInset * 2.0, height: arrowHeight + textSize.height + verticalInset * 2.0)
        
        self.iconView.frame = CGRect(origin: CGPoint(x: horizontalInset, y: arrowHeight + verticalInset + floorToScreenPixels((textSize.height - iconSize.height) * 0.5)), size: iconSize)
        
        self.textView.frame = CGRect(origin: CGPoint(x: horizontalInset + iconSize.width + iconSpacing, y: arrowHeight + verticalInset), size: textSize)
        
        self.backgroundView.image = generateImage(size, rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(UIColor.white.cgColor)
            addRoundedRectPath(context: context, rect: CGRect(origin: CGPoint(x: 0.0, y: arrowHeight), size: CGSize(width: size.width, height: size.height - arrowHeight)), radius: 14.0)
            context.fillPath()
            
            context.translateBy(x: size.width * 0.5 - 10.0, y: 0.0)
            let _ = try? drawSvgPath(context, path: "M9.0981,1.1979 C9.547,0.6431 10.453,0.6431 10.9019,1.1979 C12.4041,3.0542 15.6848,6.5616 20,8 H-0.0002 C4.3151,6.5616 7.5959,3.0542 9.0981,1.1978 Z ")
        })
        self.backgroundView.frame = CGRect(origin: CGPoint(), size: size)
        
        return size
    }
}
