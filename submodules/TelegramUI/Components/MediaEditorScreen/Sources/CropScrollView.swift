import Foundation
import UIKit

final class CropScrollView: UIScrollView, UIScrollViewDelegate {
    private var contentView: UIView?
    
    public var updated: (CGPoint, CGFloat) -> Void = { _, _ in }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundColor = .clear
        self.showsVerticalScrollIndicator = false
        self.showsHorizontalScrollIndicator = false
        self.contentInsetAdjustmentBehavior = .never
        
        self.clipsToBounds = false
        self.bouncesZoom = true
        self.delegate = self
        self.decelerationRate = .fast
        
        let transparentView = UIView(frame: bounds)
        transparentView.backgroundColor = .clear
        transparentView.isUserInteractionEnabled = false
        
        self.addSubview(transparentView)
        self.contentView = transparentView
        
        self.minimumZoomScale = 1.0
        self.maximumZoomScale = 4.0
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        guard let contentView = self.contentView else {
            return
        }
        let boundsSize = bounds.size
        var frameToCenter = contentView.frame
        
        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
        } else {
            frameToCenter.origin.x = 0
        }
        
        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
        } else {
            frameToCenter.origin.y = 0
        }
        
        contentView.frame = frameToCenter
    }
        
    func setContentSize(_ size: CGSize) {
        self.contentView?.frame = CGRect(origin: .zero, size: size)
        self.contentSize = size
        
        self.zoom(to: CGRect(origin: CGPoint(x: floor((size.width - self.bounds.width) / 2.0), y: floor((size.height - self.bounds.height) / 2.0)), size: self.bounds.size), animated: false)
    }
    
    private func notify() {
        let currentScale = self.zoomScale
        let contentOffset = self.contentOffset
        let centerOffset = CGPoint(
            x: -1.0 * (contentOffset.x + self.bounds.width / 2.0 - self.contentSize.width / 2.0),
            y: -1.0 * (contentOffset.y + self.bounds.height / 2.0 - self.contentSize.height / 2.0)
        )
        self.updated(centerOffset, currentScale)
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.contentView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        self.setNeedsLayout()
        self.layoutIfNeeded()
        self.notify()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.notify()
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        self.notify()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.notify()
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.notify()
    }
}
