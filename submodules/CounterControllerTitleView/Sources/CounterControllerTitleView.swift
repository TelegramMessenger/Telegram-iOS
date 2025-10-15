import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import ComponentFlow

public struct CounterControllerTitle: Equatable {
    public var title: String
    public var counter: String?
    
    public init(title: String, counter: String?) {
        self.title = title
        self.counter = counter
    }
}

public final class CounterControllerTitleView: UIView {
    private let titleNode: ImmediateTextNode

    private var subtitleNode: ImmediateTextNode
    private var disappearingSubtitleNode: ImmediateTextNode?
    
    public var title: CounterControllerTitle = CounterControllerTitle(title: "", counter: nil) {
        didSet {
            if self.title != oldValue {
                self.update(animated: oldValue.title.isEmpty == self.title.title.isEmpty)
            }
        }
    }
    
    public var theme: PresentationTheme {
        didSet {
            self.update(animated: false)
        }
    }
    
    private var primaryTextColor: UIColor?
    private var secondaryTextColor: UIColor?

    private var nextLayoutTransition: ContainedViewLayoutTransition?
    
    public func updateTextColors(primary: UIColor?, secondary: UIColor?, transition: ContainedViewLayoutTransition) {
        self.primaryTextColor = primary
        self.secondaryTextColor = secondary
        
        if case let .animated(duration, curve) = transition {
            if let snapshotView = self.snapshotContentTree() {
                snapshotView.frame = self.bounds
                self.addSubview(snapshotView)
                
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, timingFunction: curve.timingFunction, removeOnCompletion: false, completion: { _ in
                    snapshotView.removeFromSuperview()
                })
                self.titleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration, timingFunction: curve.timingFunction)
                self.subtitleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration, timingFunction: curve.timingFunction)
            }
        }
        
        self.update(animated: false)
    }
    
    private func update(animated: Bool) {
        let primaryTextColor = self.primaryTextColor ?? self.theme.rootController.navigationBar.primaryTextColor
        let secondaryTextColor = self.secondaryTextColor ?? self.theme.rootController.navigationBar.secondaryTextColor
        self.titleNode.attributedText = NSAttributedString(string: self.title.title, font: Font.semibold(17.0), textColor: primaryTextColor)

        let subtitleText = NSAttributedString(string: self.title.counter ?? "", font: Font.with(size: 13.0, traits: .monospacedNumbers), textColor: secondaryTextColor)
        if let previousSubtitleText = self.subtitleNode.attributedText, previousSubtitleText.string.isEmpty != subtitleText.string.isEmpty && subtitleText.string.isEmpty {
            if let disappearingSubtitleNode = self.disappearingSubtitleNode {
                self.disappearingSubtitleNode = nil
                disappearingSubtitleNode.removeFromSupernode()
            }

            self.disappearingSubtitleNode = self.subtitleNode

            self.subtitleNode = ImmediateTextNode()
            self.subtitleNode.displaysAsynchronously = false
            self.subtitleNode.maximumNumberOfLines = 1
            self.subtitleNode.truncationType = .end
            self.subtitleNode.isOpaque = false
            self.subtitleNode.attributedText = subtitleText
            self.addSubnode(self.subtitleNode)
        } else {
            self.subtitleNode.attributedText = subtitleText
        }
        
        self.accessibilityLabel = self.title.title
        self.accessibilityValue = self.title.counter
        
        if animated {
            self.nextLayoutTransition = .animated(duration: 0.4, curve: .spring)
        }
        self.setNeedsLayout()
    }
    
    public init(theme: PresentationTheme) {
        self.theme = theme
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationType = .end
        self.titleNode.isOpaque = false
        
        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.displaysAsynchronously = false
        self.subtitleNode.maximumNumberOfLines = 1
        self.subtitleNode.truncationType = .end
        self.subtitleNode.isOpaque = false
        
        super.init(frame: CGRect())
        
        self.isAccessibilityElement = true
        self.accessibilityTraits = .header
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        let spacing: CGFloat = 0.0
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: max(1.0, size.width), height: size.height))
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: max(1.0, size.width), height: size.height))
        
        let combinedHeight: CGFloat
        if self.title.counter != nil {
            combinedHeight = titleSize.height + subtitleSize.height + spacing
        } else {
            combinedHeight = titleSize.height
        }

        var transition: ContainedViewLayoutTransition = .immediate
        if let nextLayoutTransition = self.nextLayoutTransition {
            if !self.titleNode.bounds.isEmpty {
                transition = nextLayoutTransition
            }
            self.nextLayoutTransition = nil
        }
        
        let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: floor((size.height - combinedHeight) / 2.0)), size: titleSize)
        self.titleNode.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
        transition.updatePosition(node: self.titleNode, position: titleFrame.center)
        
        let subtitleFrame = CGRect(origin: CGPoint(x: floor((size.width - subtitleSize.width) / 2.0), y: floor((size.height - combinedHeight) / 2.0) + titleSize.height + spacing), size: subtitleSize)
        self.subtitleNode.bounds = CGRect(origin: CGPoint(), size: subtitleFrame.size)
        transition.updatePosition(node: self.subtitleNode, position: subtitleFrame.center)
        transition.updateTransformScale(node: self.subtitleNode, scale: self.title.counter != nil ? 1.0 : 0.001)
        transition.updateAlpha(node: self.subtitleNode, alpha: self.title.counter != nil ? 1.0 : 0.0)

        if let disappearingSubtitleNode = self.disappearingSubtitleNode {
            transition.updatePosition(node: disappearingSubtitleNode, position: subtitleFrame.center)
            transition.updateTransformScale(node: disappearingSubtitleNode, scale: self.title.counter != nil ? 1.0 : 0.001)
            transition.updateAlpha(node: disappearingSubtitleNode, alpha: self.title.counter != nil ? 1.0 : 0.0, completion: { [weak disappearingSubtitleNode] _ in
                disappearingSubtitleNode?.removeFromSupernode()
            })
        }
    }
}
