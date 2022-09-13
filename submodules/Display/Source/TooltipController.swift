import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

public protocol TooltipControllerCustomContentNode: ASDisplayNode {
    func animateIn()
    func updateLayout(size: CGSize) -> CGSize
}

public enum TooltipControllerContent: Equatable {
    case text(String)
    case attributedText(NSAttributedString)
    case iconAndText(UIImage, String)
    case custom(TooltipControllerCustomContentNode)
    
    var text: String {
        switch self {
            case let .text(text), let .iconAndText(_, text):
                return text
            case let .attributedText(text):
                return text.string
            case .custom:
                return ""
        }
    }
    
    var image: UIImage? {
        if case let .iconAndText(image, _) = self {
            return image
        }
        return nil
    }
    
    public static func == (lhs: TooltipControllerContent, rhs: TooltipControllerContent) -> Bool {
        switch lhs {
            case let .text(lhsText):
                if case let .text(rhsText) = rhs, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .attributedText(lhsText):
                if case let .attributedText(rhsText) = rhs, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .iconAndText(_, lhsText):
                if case let .iconAndText(_, rhsText) = rhs, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .custom(lhsNode):
                if case let .custom(rhsNode) = rhs, lhsNode === rhsNode {
                    return true
                } else {
                    return false
                }
        }
    }
}

public enum SourceAndRect {
    case node(() -> (ASDisplayNode, CGRect)?)
    case view(() -> (UIView, CGRect)?)
    
    func globalRect() -> CGRect? {
        switch self {
            case let .node(node):
                if let (sourceNode, sourceRect) = node() {
                    return sourceNode.view.convert(sourceRect, to: nil)
                }
            case let .view(view):
                if let (sourceView, sourceRect) = view() {
                    return sourceView.convert(sourceRect, to: nil)
                }
        }
        return nil
    }
}

public final class TooltipControllerPresentationArguments {
    public let sourceAndRect: SourceAndRect
    
    public init(sourceNodeAndRect: @escaping () -> (ASDisplayNode, CGRect)?) {
        self.sourceAndRect = .node(sourceNodeAndRect)
    }
    
    public init(sourceViewAndRect: @escaping () -> (UIView, CGRect)?) {
        self.sourceAndRect = .view(sourceViewAndRect)
    }
}

open class TooltipController: ViewController, StandalonePresentableController {
    private var controllerNode: TooltipControllerNode {
        return self.displayNode as! TooltipControllerNode
    }
    
    public private(set) var content: TooltipControllerContent
    private let baseFontSize: CGFloat
    
    open func updateContent(_ content: TooltipControllerContent, animated: Bool, extendTimer: Bool, arrowOnBottom: Bool = true) {
        if self.content != content {
            self.content = content
            if self.isNodeLoaded {
                self.controllerNode.updateText(self.content.text, transition: animated ? .animated(duration: 0.25, curve: .easeInOut) : .immediate)
                self.controllerNode.arrowOnBottom = arrowOnBottom
                if extendTimer, self.timeoutTimer != nil {
                    self.timeoutTimer?.invalidate()
                    self.timeoutTimer = nil
                    self.beginTimeout()
                }
            }
        }
    }
    
    private let timeout: Double
    private let dismissByTapOutside: Bool
    private let dismissByTapOutsideSource: Bool
    private let dismissImmediatelyOnLayoutUpdate: Bool
    private var timeoutTimer: SwiftSignalKit.Timer?
    
    private var padding: CGFloat
    
    private var layout: ContainerViewLayout?
    private var initialArrowOnBottom: Bool
    
    public var dismissed: ((Bool) -> Void)?
    
    public init(content: TooltipControllerContent, baseFontSize: CGFloat, timeout: Double = 2.0, dismissByTapOutside: Bool = false, dismissByTapOutsideSource: Bool = false, dismissImmediatelyOnLayoutUpdate: Bool = false, arrowOnBottom: Bool = true, padding: CGFloat = 8.0) {
        self.content = content
        self.baseFontSize = baseFontSize
        self.timeout = timeout
        self.dismissByTapOutside = dismissByTapOutside
        self.dismissByTapOutsideSource = dismissByTapOutsideSource
        self.dismissImmediatelyOnLayoutUpdate = dismissImmediatelyOnLayoutUpdate
        self.initialArrowOnBottom = arrowOnBottom
        self.padding = padding
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.timeoutTimer?.invalidate()
    }
    
    override open func loadDisplayNode() {
        self.displayNode = TooltipControllerNode(content: self.content, baseFontSize: self.baseFontSize, dismiss: { [weak self] tappedInside in
            self?.dismiss(tappedInside: tappedInside)
        }, dismissByTapOutside: self.dismissByTapOutside, dismissByTapOutsideSource: self.dismissByTapOutsideSource)
        self.controllerNode.padding = self.padding
        self.controllerNode.arrowOnBottom = self.initialArrowOnBottom
        self.displayNodeDidLoad()
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.controllerNode.animateIn()
        self.beginTimeout()
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        if self.layout != nil && self.layout! != layout {
            if self.dismissImmediatelyOnLayoutUpdate {
                self.dismissImmediately()
            } else {
                self.dismiss()
            }
        } else {
            self.layout = layout
            
            if let presentationArguments = self.presentationArguments as? TooltipControllerPresentationArguments, let sourceRect = presentationArguments.sourceAndRect.globalRect() {
                self.controllerNode.sourceRect = sourceRect
            } else {
                self.controllerNode.sourceRect = nil
            }
            
            self.controllerNode.containerLayoutUpdated(layout, transition: transition)
        }
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.controllerNode.animateIn()
        self.beginTimeout()
    }
    
    private func beginTimeout() {
        if self.timeoutTimer == nil {
            let timeoutTimer = SwiftSignalKit.Timer(timeout: self.timeout, repeat: false, completion: { [weak self] in
                if let strongSelf = self {
                    strongSelf.dismissed?(false)
                    strongSelf.controllerNode.animateOut {
                        self?.presentingViewController?.dismiss(animated: false)
                    }
                }
            }, queue: Queue.mainQueue())
            self.timeoutTimer = timeoutTimer
            timeoutTimer.start()
        }
    }
    
    private func dismiss(tappedInside: Bool, completion: (() -> Void)? = nil) {
        self.dismissed?(tappedInside)
        self.controllerNode.animateOut { [weak self] in
             self?.presentingViewController?.dismiss(animated: false)
             completion?()
        }
    }
    
    override open func dismiss(completion: (() -> Void)? = nil) {
        self.dismiss(tappedInside: false, completion: completion)
    }
    
    open func dismissImmediately() {
        self.dismissed?(false)
        self.controllerNode.hide()
        self.presentingViewController?.dismiss(animated: false)
    }
}
