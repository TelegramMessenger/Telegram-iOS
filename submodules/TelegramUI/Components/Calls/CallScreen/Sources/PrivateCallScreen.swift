import Foundation
import UIKit

public final class PrivateCallScreen: UIView {
    private let backgroundLayer: CallBackgroundLayer
    private let contentOverlayLayer: ContentOverlayLayer
    private let contentOverlayContainer: ContentOverlayContainer
    
    private let blurContentsLayer: SimpleLayer
    private let blurBackgroundLayer: CallBackgroundLayer
    
    private let contentView: ContentView
    
    private let buttonGroupView: ButtonGroupView
    
    public override init(frame: CGRect) {
        self.blurContentsLayer = SimpleLayer()
        
        self.backgroundLayer = CallBackgroundLayer(isBlur: false)
        
        self.contentOverlayLayer = ContentOverlayLayer()
        self.contentOverlayContainer = ContentOverlayContainer(overlayLayer: self.contentOverlayLayer)
        
        self.blurBackgroundLayer = CallBackgroundLayer(isBlur: true)
        
        self.contentView = ContentView(frame: CGRect())
        
        self.buttonGroupView = ButtonGroupView()
        
        super.init(frame: frame)
        
        self.contentOverlayLayer.contentsLayer = self.blurContentsLayer
        
        self.layer.addSublayer(self.backgroundLayer)
        
        self.blurContentsLayer.addSublayer(self.blurBackgroundLayer)
        
        self.addSubview(self.contentView)
        self.blurContentsLayer.addSublayer(self.contentView.blurContentsLayer)
        
        self.layer.addSublayer(self.contentOverlayLayer)
        
        self.addSubview(self.contentOverlayContainer)
        
        self.contentOverlayContainer.addSubview(self.buttonGroupView)
        
        self.buttonGroupView.toggleVideo = { [weak self] in
            guard let self else {
                return
            }
            self.contentView.toggleDisplayVideo()
        }
    }
    
    public required init?(coder: NSCoder) {
        fatalError()
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        
        return result
    }
    
    public func update(size: CGSize, insets: UIEdgeInsets) {
        let backgroundFrame = CGRect(origin: CGPoint(), size: size)
        
        let aspect: CGFloat = size.width / size.height
        let sizeNorm: CGFloat = 64.0
        let renderingSize = CGSize(width: floor(sizeNorm * aspect), height: sizeNorm)
        let edgeSize: Int = 2
        
        let visualBackgroundFrame = backgroundFrame.insetBy(dx: -CGFloat(edgeSize) / renderingSize.width * backgroundFrame.width, dy: -CGFloat(edgeSize) / renderingSize.height * backgroundFrame.height)
        
        self.backgroundLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(renderingSize.width) + edgeSize * 2, height: Int(renderingSize.height) + edgeSize * 2))
        self.backgroundLayer.frame = visualBackgroundFrame
        
        self.contentOverlayLayer.frame = CGRect(origin: CGPoint(), size: size)
        self.contentOverlayLayer.update(size: size, contentInsets: UIEdgeInsets())
        
        self.contentOverlayContainer.frame = CGRect(origin: CGPoint(), size: size)
        
        self.blurBackgroundLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(renderingSize.width) + edgeSize * 2, height: Int(renderingSize.height) + edgeSize * 2))
        self.blurBackgroundLayer.frame = visualBackgroundFrame
        
        self.buttonGroupView.frame = CGRect(origin: CGPoint(), size: size)
        self.buttonGroupView.update(size: size)
        
        self.contentView.frame = CGRect(origin: CGPoint(), size: size)
        self.contentView.update(size: size, insets: insets)
    }
}
