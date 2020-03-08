import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AnimatedStickerNode
import AppBundle

private final class TooltipScreenNode: ViewControllerTracingNode {
    private let location: CGPoint
    private let requestDismiss: () -> Void
    
    private let containerNode: ASDisplayNode
    private let backgroundNode: ASImageNode
    private let arrowNode: ASImageNode
    private let animatedStickerNode: AnimatedStickerNode
    private let textNode: ImmediateTextNode
    
    init(text: String, location: CGPoint, requestDismiss: @escaping () -> Void) {
        self.location = location
        self.requestDismiss = requestDismiss
        
        self.containerNode = ASDisplayNode()
        
        let fillColor = UIColor(white: 0.0, alpha: 0.8)
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.image = generateAdjustedStretchableFilledCircleImage(diameter: 15.0, color: fillColor)
        
        self.arrowNode = ASImageNode()
        let arrowSize = CGSize(width: 29.0, height: 10.0)
        self.arrowNode.image = generateImage(arrowSize, rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(fillColor.cgColor)
            context.scaleBy(x: 0.333, y: 0.333)
            let _ = try? drawSvgPath(context, path: "M85.882251,0 C79.5170552,0 73.4125613,2.52817247 68.9116882,7.02834833 L51.4264069,24.5109211 C46.7401154,29.1964866 39.1421356,29.1964866 34.4558441,24.5109211 L16.9705627,7.02834833 C12.4696897,2.52817247 6.36519576,0 0,0 L85.882251,0 ")
            context.fillPath()
        })
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.maximumNumberOfLines = 0
        self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(14.0), textColor: .white)
        
        self.animatedStickerNode = AnimatedStickerNode()
        if let path = getAppBundle().path(forResource: "ChatListFoldersTooltip", ofType: "json") {
            self.animatedStickerNode.setup(source: AnimatedStickerNodeLocalFileSource(path: path), width: Int(70 * UIScreenScale), height: Int(70 * UIScreenScale), playbackMode: .once, mode: .direct)
            self.animatedStickerNode.automaticallyLoadFirstFrame = true
        }
        
        super.init()
        
        self.backgroundNode.addSubnode(self.arrowNode)
        self.containerNode.addSubnode(self.backgroundNode)
        self.containerNode.addSubnode(self.textNode)
        self.containerNode.addSubnode(self.animatedStickerNode)
        self.addSubnode(self.containerNode)
    }
    
    func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let sideInset: CGFloat = 13.0
        let bottomInset: CGFloat = 10.0
        let contentInset: CGFloat = 9.0
        let contentVerticalInset: CGFloat = 11.0
        let animationSize = CGSize(width: 32.0, height: 32.0)
        let animationInset: CGFloat = (70 - animationSize.width) / 2.0
        let animationSpacing: CGFloat = 8.0
        let textSize = self.textNode.updateLayout(CGSize(width: layout.size.width - contentInset * 2.0 - sideInset * 2.0 - animationSize.width - animationSpacing, height: .greatestFiniteMagnitude))
        
        let backgroundHeight = max(animationSize.height, textSize.height) + contentVerticalInset * 2.0
        let backgroundFrame = CGRect(origin: CGPoint(x: sideInset, y: self.location.y - bottomInset - backgroundHeight), size: CGSize(width: layout.size.width - sideInset * 2.0, height: backgroundHeight))
        transition.updateFrame(node: self.containerNode, frame: backgroundFrame)
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: backgroundFrame.size))
        if let image = self.arrowNode.image {
            let arrowSize = image.size
            let arrowCenterX = self.location.x
            transition.updateFrame(node: self.arrowNode, frame: CGRect(origin: CGPoint(x: floor(arrowCenterX - arrowSize.width / 2.0), y: backgroundFrame.height), size: arrowSize))
        }
        
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: contentInset + animationSize.width + animationSpacing, y: floor((backgroundHeight - textSize.height) / 2.0)), size: textSize))
        
        transition.updateFrame(node: self.animatedStickerNode, frame: CGRect(origin: CGPoint(x: contentInset - animationInset, y: floor((backgroundHeight - animationSize.height) / 2.0) - animationInset), size: CGSize(width: animationSize.width + animationInset * 2.0, height: animationSize.height + animationInset * 2.0)))
        self.animatedStickerNode.updateLayout(size: CGSize(width: animationSize.width + animationInset * 2.0, height: animationSize.height + animationInset * 2.0))
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let event = event {
            var eventIsPresses = false
            if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                eventIsPresses = event.type == .presses
            }
            if event.type == .touches || eventIsPresses {
                //self.requestDismiss()
                return nil
            }
        }
        return super.hitTest(point, with: event)
    }
    
    func animateIn() {
        self.containerNode.layer.animateSpring(from: NSNumber(value: Float(0.01)), to: NSNumber(value: Float(1.0)), keyPath: "transform.scale", duration: 0.6)
        self.containerNode.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: self.arrowNode.frame.midX - self.containerNode.bounds.width / 2.0, y: self.arrowNode.frame.maxY - self.containerNode.bounds.height / 2.0)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: 0.6, additive: true)
        self.containerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.6, execute: { [weak self] in
            self?.animatedStickerNode.visibility = true
        })
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.containerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
            completion()
        })
        self.containerNode.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
        self.containerNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: self.arrowNode.frame.midX - self.containerNode.bounds.width / 2.0, y: self.arrowNode.frame.maxY - self.containerNode.bounds.height / 2.0), duration: 0.2, removeOnCompletion: false, additive: true)
    }
}

public final class TooltipScreen: ViewController {
    private let text: String
    private let location: CGPoint
    
    private var controllerNode: TooltipScreenNode {
        return self.displayNode as! TooltipScreenNode
    }
    
    private var validLayout: ContainerViewLayout?
    private var isDismissed: Bool = false
    
    public init(text: String, location: CGPoint) {
        self.text = text
        self.location = location
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.controllerNode.animateIn()
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 5.0, execute: { [weak self] in
            self?.dismiss()
        })
    }
    
    override public func loadDisplayNode() {
        self.displayNode = TooltipScreenNode(text: self.text, location: self.location, requestDismiss: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.dismiss()
        })
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        if let validLayout = self.validLayout {
            if validLayout.size.width != layout.size.width {
                self.dismiss()
            }
        }
        self.validLayout = layout
        
        self.controllerNode.updateLayout(layout: layout, transition: transition)
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if self.isDismissed {
            return
        }
        self.isDismissed = true
        self.controllerNode.animateOut(completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.presentingViewController?.dismiss(animated: false, completion: nil)
        })
    }
}
