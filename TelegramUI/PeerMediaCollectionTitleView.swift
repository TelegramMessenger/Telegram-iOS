import Foundation
import AsyncDisplayKit
import Display

private let arrowImage = UIImage(bundleImageName: "Media Grid/TitleViewModeSelectionArrow")?.precomposed()

final class PeerMediaCollectionTitleView: UIView {
    private let toggle: () -> Void
    
    private let titleNode: ASTextNode
    private let arrowView: UIImageView
    private let button: HighlightTrackingButton
    
    private var mediaCollectionInterfaceState = PeerMediaCollectionInterfaceState()
    
    init(toggle: @escaping () -> Void) {
        self.toggle = toggle
        
        self.titleNode = ASTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
        self.titleNode.isOpaque = false
        
        self.arrowView = UIImageView(image: arrowImage)
        
        self.button = HighlightTrackingButton(frame: CGRect())
        
        super.init(frame: CGRect())
        
        self.titleNode.attributedText = NSAttributedString(string: titleForPeerMediaCollectionMode(self.mediaCollectionInterfaceState.mode), font: Font.medium(17.0), textColor: UIColor.black)
        self.addSubnode(self.titleNode)
        self.addSubview(self.arrowView)
        
        self.button.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.titleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.arrowView.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleNode.alpha = 0.4
                    strongSelf.arrowView.alpha = 0.4
                } else {
                    strongSelf.titleNode.alpha = 1.0
                    strongSelf.arrowView.alpha = 1.0
                    strongSelf.titleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.arrowView.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.button.addTarget(self, action: #selector(self.buttonPressed), for: [.touchUpInside])
        self.addSubview(self.button)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        
        self.button.frame = CGRect(origin: CGPoint(), size: size)
        
        let arrowSize = self.arrowView.bounds.size
        let titleArrowSpacing: CGFloat = 4.0
        let titleSize = self.titleNode.measure(CGSize(width: size.width - arrowSize.width - titleArrowSpacing, height: size.height))
        
        let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)
        self.titleNode.frame = titleFrame
        self.arrowView.frame = CGRect(origin: CGPoint(x: titleFrame.maxX + titleArrowSpacing, y: titleFrame.minY + floor((titleSize.height - arrowSize.height) / 2.0 + 2.0)), size: arrowSize)
    }
    
    func updateMediaCollectionInterfaceState(_ mediaCollectionInterfaceState: PeerMediaCollectionInterfaceState, animated: Bool) {
        if self.mediaCollectionInterfaceState != mediaCollectionInterfaceState {
            if mediaCollectionInterfaceState.mode != self.mediaCollectionInterfaceState.mode {
                self.titleNode.attributedText = NSAttributedString(string: titleForPeerMediaCollectionMode(mediaCollectionInterfaceState.mode), font: Font.medium(17.0), textColor: UIColor.black)
                self.setNeedsLayout()
            }
            
            if mediaCollectionInterfaceState.selectingMode != self.mediaCollectionInterfaceState.selectingMode {
                let previousSelectingMode = self.mediaCollectionInterfaceState.selectingMode
                let arrowTransform = CATransform3DMakeScale(1.0, previousSelectingMode ? 1.0 : -1.0, 1.0)
                if animated {
                    self.arrowView.layer.animate(from: NSNumber(value: Float(previousSelectingMode ? -1.0 : 1.0)), to: NSNumber(value: Float(previousSelectingMode ? 1.0 : -1.0)), keyPath: "transform.scale.y", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.3)
                }
                self.arrowView.layer.transform = arrowTransform
            }
            self.mediaCollectionInterfaceState = mediaCollectionInterfaceState
        }
    }
    
    @objc func buttonPressed() {
        self.toggle()
    }
}
