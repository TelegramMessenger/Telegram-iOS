import Foundation
import Display
import AsyncDisplayKit

class ZoomableContentGalleryItemNode: GalleryItemNode, UIScrollViewDelegate {
    let scrollView: UIScrollView
    
    private var containerLayout: ContainerViewLayout?
    
    var zoomableContent: (CGSize, ASDisplayNode)? {
        didSet {
            if oldValue?.1 !== self.zoomableContent?.1 {
                if let node = oldValue?.1 {
                    node.view.removeFromSuperview()
                }
            }
            if let node = self.zoomableContent?.1 {
                self.scrollView.addSubview(node.view)
            }
            self.resetScrollViewContents()
        }
    }
    
    override init() {
        self.scrollView = UIScrollView()
        
        super.init()
        
        self.scrollView.delegate = self
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.clipsToBounds = false
        self.scrollView.scrollsToTop = false
        self.scrollView.delaysContentTouches = false
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.contentTap(_:)))
        
        self.scrollView.addGestureRecognizer(tapRecognizer)
        
        self.view.addSubview(self.scrollView)
    }
    
    @objc func contentTap(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            self.toggleControlsVisibility()
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        var shouldResetContents = false
        if let containerLayout = self.containerLayout {
            shouldResetContents = !containerLayout.size.equalTo(layout.size)
        } else {
            shouldResetContents = true
        }
        self.containerLayout = layout
        
        if shouldResetContents {
            self.scrollView.frame = CGRect(origin: CGPoint(), size: layout.size)
            self.resetScrollViewContents()
        }
    }
    
    private func resetScrollViewContents() {
        guard let (contentSize, contentNode) = self.zoomableContent else {
            return
        }
        
        self.scrollView.minimumZoomScale = 1.0
        self.scrollView.maximumZoomScale = 1.0
        //self.scrollView.normalZoomScale = 1.0
        self.scrollView.zoomScale = 1.0
        self.scrollView.contentSize = contentSize
        
        contentNode.transform = CATransform3DIdentity
        contentNode.frame = CGRect(origin: CGPoint(), size: contentSize)
        
        self.centerScrollViewContents()
        
        self.scrollView.zoomScale = self.scrollView.minimumZoomScale
    }
    
    private func centerScrollViewContents() {
        guard let (contentSize, contentNode) = self.zoomableContent else {
            return
        }
        
        let boundsSize = self.scrollView.bounds.size
        if contentSize.width.isLessThanOrEqualTo(0.0) || contentSize.height.isLessThanOrEqualTo(0.0) || boundsSize.width.isLessThanOrEqualTo(0.0) || boundsSize.height.isLessThanOrEqualTo(0.0) {
            return
        }
        
        let scaleWidth = boundsSize.width / contentSize.width
        let scaleHeight = boundsSize.height / contentSize.height
        let minScale = min(scaleWidth, scaleHeight)
        var maxScale = max(scaleWidth, scaleHeight)
        maxScale = max(maxScale, minScale * 3.0)
        
        if (abs(maxScale - minScale) < 0.01) {
            maxScale = minScale
        }
        
        if !self.scrollView.minimumZoomScale.isEqual(to: minScale) {
            self.scrollView.minimumZoomScale = minScale
        }
        
        /*if !self.scrollView.normalZoomScale.isEqual(to: minScale) {
         self.scrollView.normalZoomScale = minScale
         }*/
        
        if !self.scrollView.maximumZoomScale.isEqual(to: maxScale) {
            self.scrollView.maximumZoomScale = maxScale
        }
        
        var contentFrame = contentNode.view.frame
        
        if boundsSize.width > contentFrame.size.width {
            contentFrame.origin.x = (boundsSize.width - contentFrame.size.width) / 2.0
        } else {
            contentFrame.origin.x = 0.0
        }
        
        if boundsSize.height > contentFrame.size.height {
            contentFrame.origin.y = (boundsSize.height - contentFrame.size.height) / 2.0
        } else {
            contentFrame.origin.y = 0.0
        }
        
        contentNode.view.frame = contentFrame
        
        //self.scrollView.scrollEnabled = ABS(_scrollView.zoomScale - _scrollView.normalZoomScale) > FLT_EPSILON;
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.zoomableContent?.1.view
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        self.centerScrollViewContents()
    }
}
