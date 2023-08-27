import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import LottieComponent

public final class MoreHeaderButton: HighlightableButtonNode {
    public enum Content {
        case image(UIImage?)
        case more(UIImage?)
    }

    public let referenceNode: ContextReferenceContentNode
    public let containerNode: ContextControllerSourceNode
    private let iconNode: ASImageNode
    private let animationView = ComponentView<Empty>()

    public var contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?

    private var color: UIColor
    
    public var onPressed: (() -> Void)?

    public init(color: UIColor) {
        self.color = color

        self.referenceNode = ContextReferenceContentNode()
        self.containerNode = ContextControllerSourceNode()
        self.containerNode.animateScale = false
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.contentMode = .scaleToFill

        super.init()

        self.containerNode.addSubnode(self.referenceNode)
        self.referenceNode.addSubnode(self.iconNode)
        self.addSubnode(self.containerNode)

        self.containerNode.shouldBegin = { [weak self] location in
            guard let strongSelf = self, let _ = strongSelf.contextAction else {
                return false
            }
            return true
        }
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.contextAction?(strongSelf.containerNode, gesture)
        }

        self.containerNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 26.0, height: 44.0))
        self.referenceNode.frame = self.containerNode.bounds

        self.iconNode.image = MoreHeaderButton.optionsCircleImage(color: color)
        if let image = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: floor((self.containerNode.bounds.width - image.size.width) / 2.0), y: floor((self.containerNode.bounds.height - image.size.height) / 2.0)), size: image.size)
        }

        self.hitTestSlop = UIEdgeInsets(top: 0.0, left: -4.0, bottom: 0.0, right: -4.0)
        
        self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func pressed() {
        self.onPressed?()
    }

    private var content: Content?
    public func setContent(_ content: Content, animated: Bool = false) {
        if case .more = content {
            let animationSize = CGSize(width: 22.0, height: 22.0)
            let _ = self.animationView.update(
                transition: .immediate,
                component: AnyComponent(LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "anim_profilemore"),
                    color: self.color
                )),
                environment: {},
                containerSize: animationSize
            )
            if let animationComponentView = self.animationView.view {
                if animationComponentView.superview == nil {
                    self.view.addSubview(animationComponentView)
                }
                animationComponentView.frame = CGRect(origin: CGPoint(x: floor((self.containerNode.bounds.width - animationSize.width) / 2.0), y: floor((self.containerNode.bounds.height - animationSize.height) / 2.0)), size: animationSize)
            }
        }
        if animated {
            if let snapshotView = self.referenceNode.view.snapshotContentTree() {
                snapshotView.frame = self.referenceNode.frame
                self.view.addSubview(snapshotView)

                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                    snapshotView?.removeFromSuperview()
                })
                snapshotView.layer.animateScale(from: 1.0, to: 0.1, duration: 0.3, removeOnCompletion: false)

                self.iconNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                self.iconNode.layer.animateScale(from: 0.1, to: 1.0, duration: 0.3)

                if let animationComponentView = self.animationView.view {
                    animationComponentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    animationComponentView.layer.animateScale(from: 0.1, to: 1.0, duration: 0.3)
                }
            }

            switch content {
                case let .image(image):
                    if let image = image {
                        self.iconNode.frame = CGRect(origin: CGPoint(x: floor((self.containerNode.bounds.width - image.size.width) / 2.0), y: floor((self.containerNode.bounds.height - image.size.height) / 2.0)), size: image.size)
                    }

                    self.iconNode.image = image
                    self.iconNode.isHidden = false
                    if let animationComponentView = self.animationView.view {
                        animationComponentView.isHidden = true
                    }
                case let .more(image):
                    if let image = image {
                        self.iconNode.frame = CGRect(origin: CGPoint(x: floor((self.containerNode.bounds.width - image.size.width) / 2.0), y: floor((self.containerNode.bounds.height - image.size.height) / 2.0)), size: image.size)
                    }

                    self.iconNode.image = image
                    self.iconNode.isHidden = false
                    if let animationComponentView = self.animationView.view {
                        animationComponentView.isHidden = false
                    }
            }
        } else {
            self.content = content
            switch content {
                case let .image(image):
                    if let image = image {
                        self.iconNode.frame = CGRect(origin: CGPoint(x: floor((self.containerNode.bounds.width - image.size.width) / 2.0), y: floor((self.containerNode.bounds.height - image.size.height) / 2.0)), size: image.size)
                    }

                    self.iconNode.image = image
                    self.iconNode.isHidden = false
                    if let animationComponentView = self.animationView.view {
                        animationComponentView.isHidden = true
                    }
                case let .more(image):
                    if let image = image {
                        self.iconNode.frame = CGRect(origin: CGPoint(x: floor((self.containerNode.bounds.width - image.size.width) / 2.0), y: floor((self.containerNode.bounds.height - image.size.height) / 2.0)), size: image.size)
                    }

                    self.iconNode.image = image
                    self.iconNode.isHidden = false
                    if let animationComponentView = self.animationView.view {
                        animationComponentView.isHidden = false
                    }
            }
        }
    }

    override public func didLoad() {
        super.didLoad()
        self.view.isOpaque = false
    }

    override public func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 22.0, height: 44.0)
    }

    public func onLayout() {
    }

    public func play() {
        if let animationComponentView = self.animationView.view as? LottieComponent.View {
            animationComponentView.playOnce()
        }
    }
    
    public static func optionsCircleImage(color: UIColor) -> UIImage? {
        return generateImage(CGSize(width: 22.0, height: 22.0), contextGenerator: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))

            context.setStrokeColor(color.cgColor)
            let lineWidth: CGFloat = 1.3
            context.setLineWidth(lineWidth)

            context.strokeEllipse(in: CGRect(origin: CGPoint(), size: size).insetBy(dx: lineWidth, dy: lineWidth))
        })
    }
}
