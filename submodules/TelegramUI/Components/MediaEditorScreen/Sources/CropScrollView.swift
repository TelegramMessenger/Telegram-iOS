import Foundation
import UIKit

final class CropScrollView: UIScrollView, UIScrollViewDelegate {
    private var contentView: UIView?
    private var isUpdating = false
    
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
        
    func update(frame: CGRect, contentSize: CGSize, offset: CGPoint, scale: CGFloat) -> (offset: CGPoint, scale: CGFloat)? {
        guard let contentView = self.contentView, !self.isUpdating, frame.width > 0.0, frame.height > 0.0, contentSize.width > 0.0, contentSize.height > 0.0, scale > 0.0 else {
            return nil
        }

        let currentOffset = self.centerOffset
        let frameChanged = abs(self.frame.minX - frame.minX) > 0.001 || abs(self.frame.minY - frame.minY) > 0.001 || abs(self.bounds.width - frame.width) > 0.001 || abs(self.bounds.height - frame.height) > 0.001
        let contentSizeChanged = abs(contentView.bounds.width - contentSize.width) > 0.001 || abs(contentView.bounds.height - contentSize.height) > 0.001
        if !frameChanged, !contentSizeChanged, abs(self.zoomScale - scale) < 0.00001, abs(currentOffset.x - offset.x) < 0.001, abs(currentOffset.y - offset.y) < 0.001 {
            return nil
        }

        self.isUpdating = true
        defer {
            self.isUpdating = false
        }

        self.frame = frame
        if contentSizeChanged {
            self.minimumZoomScale = min(1.0, self.minimumZoomScale)
            self.setZoomScale(1.0, animated: false)
            contentView.frame = CGRect(origin: .zero, size: contentSize)
            self.contentSize = contentSize
        }

        let minimumScale = max(frame.width / contentSize.width, frame.height / contentSize.height)
        let maximumScale = max(4.0, minimumScale)
        let updatedScale = max(minimumScale, min(maximumScale, scale))
        self.maximumZoomScale = maximumScale
        self.minimumZoomScale = minimumScale
        self.setZoomScale(updatedScale, animated: false)
        self.setNeedsLayout()
        self.layoutIfNeeded()

        let offsetScale = updatedScale / scale
        let maxOffsetX = max(0.0, self.contentSize.width - self.bounds.width)
        let maxOffsetY = max(0.0, self.contentSize.height - self.bounds.height)
        self.setContentOffset(CGPoint(
            x: max(0.0, min(maxOffsetX, contentView.frame.midX - self.bounds.width / 2.0 - offset.x * offsetScale)),
            y: max(0.0, min(maxOffsetY, contentView.frame.midY - self.bounds.height / 2.0 - offset.y * offsetScale))
        ), animated: false)

        return (self.centerOffset, self.zoomScale)
    }

    private var centerOffset: CGPoint {
        let contentFrame = self.contentView?.frame ?? CGRect(origin: .zero, size: self.contentSize)
        return CGPoint(
            x: contentFrame.midX - self.contentOffset.x - self.bounds.width / 2.0,
            y: contentFrame.midY - self.contentOffset.y - self.bounds.height / 2.0
        )
    }
    
    private func notify() {
        guard !self.isUpdating else {
            return
        }
        self.updated(self.centerOffset, self.zoomScale)
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
