import Foundation
import UIKit
import AsyncDisplayKit

private func generateShadowImage(mirror: Bool) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 45.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        if mirror {
            context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
        }
        
        context.setShadow(offset: CGSize(width: 0.0, height: 0.0), blur: 18.0, color: UIColor(white: 0.0, alpha: 0.35).cgColor)
        context.setFillColor(UIColor(white: 0.0, alpha: 1.0).cgColor)
        for _ in 0 ..< 1 {
            context.fill(CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: 15.0)))
        }
        context.clear(CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: 15.0)))
    })
}

private final class CopyView: UIView {
    let topShadow: UIImageView
    let bottomShadow: UIImageView
    
    init(frame: CGRect, hasShadow: Bool) {
        self.topShadow = UIImageView()
        self.bottomShadow = UIImageView()
        
        super.init(frame: frame)
        
        if hasShadow {
            self.topShadow.image = generateShadowImage(mirror: true)
            self.bottomShadow.image = generateShadowImage(mirror: false)
        }
        
        self.addSubview(self.topShadow)
        self.addSubview(self.bottomShadow)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class ListViewReorderingItemNode: ASDisplayNode {
    weak var itemNode: ListViewItemNode?
    
    var currentState: (Int, Int)?
    
    private let copyView: CopyView
    private let initialLocation: CGPoint
    
    init(itemNode: ListViewItemNode, initialLocation: CGPoint, hasShadow: Bool) {
        self.itemNode = itemNode
        self.copyView = CopyView(frame: CGRect(), hasShadow: hasShadow)
        let snapshotView = itemNode.snapshotForReordering()
        self.initialLocation = initialLocation
        
        super.init()
        
        if let snapshotView = snapshotView {
            snapshotView.frame = CGRect(origin: CGPoint(), size: itemNode.bounds.size)
            snapshotView.bounds.origin = itemNode.bounds.origin
            self.copyView.addSubview(snapshotView)
        }
        self.view.addSubview(self.copyView)
        self.copyView.frame = CGRect(origin: CGPoint(x: initialLocation.x, y: initialLocation.y), size: itemNode.bounds.size)
        
        self.copyView.topShadow.frame = CGRect(origin: CGPoint(x: 0.0, y: -30.0), size: CGSize(width: copyView.bounds.size.width, height: 45.0))
        self.copyView.bottomShadow.frame = CGRect(origin: CGPoint(x: 0.0, y: self.copyView.bounds.size.height - 15.0), size: CGSize(width: self.copyView.bounds.size.width, height: 45.0))
        
        self.copyView.topShadow.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
        self.copyView.bottomShadow.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    func updateOffset(offset: CGFloat) {
        self.copyView.frame = CGRect(origin: CGPoint(x: initialLocation.x, y: initialLocation.y + offset), size: copyView.bounds.size)
    }
    
    func currentOffset() -> CGFloat? {
        return self.copyView.center.y
    }
    
    func animateCompletion(completion: @escaping () -> Void) {
        if let itemNode = self.itemNode {
            let offset = itemNode.frame.midY - copyView.frame.midY
            itemNode.isHidden = false
            self.copyView.isHidden = true
            itemNode.transitionOffset = offset
            itemNode.addTransitionOffsetAnimation(0.0, duration: 0.3 * UIView.animationDurationFactor(), beginAt: CACurrentMediaTime())
            completion()
                
            /*itemNode.transitionOffset = 0.0
            itemNode.setAnimationForKey("transitionOffset", animation: nil)
            self.copyView.topShadow.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
            self.copyView.bottomShadow.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
            self.copyView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: itemNode.frame.midY - copyView.frame.midY), duration: 0.2, removeOnCompletion: false, additive: true, force: true, completion: { [weak itemNode] _ in
                itemNode?.isHidden = false
                completion()
            })*/
        } else {
            completion()
        }
    }
}
