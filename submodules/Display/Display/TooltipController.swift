import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

public enum TooltipControllerContent: Equatable {
    case text(String)
    case iconAndText(UIImage, String)
    
    var text: String {
        switch self {
            case let .text(text), let .iconAndText(_, text):
                return text
        }
    }
    
    var image: UIImage? {
        if case let .iconAndText(image, _) = self {
            return image
        }
        return nil
    }
}

private enum SourceAndRect {
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
    fileprivate let sourceAndRect: SourceAndRect
    
    public init(sourceNodeAndRect: @escaping () -> (ASDisplayNode, CGRect)?) {
        self.sourceAndRect = .node(sourceNodeAndRect)
    }
    
    public init(sourceViewAndRect: @escaping () -> (UIView, CGRect)?) {
        self.sourceAndRect = .view(sourceViewAndRect)
    }
}

public final class TooltipController: ViewController {
    private var controllerNode: TooltipControllerNode {
        return self.displayNode as! TooltipControllerNode
    }
    
    public var content: TooltipControllerContent {
        didSet {
            if self.content != oldValue {
                if self.isNodeLoaded {
                    self.controllerNode.updateText(self.content.text, transition: .animated(duration: 0.25, curve: .easeInOut))
                    if self.timeoutTimer != nil {
                        self.timeoutTimer?.invalidate()
                        self.timeoutTimer = nil
                        self.beginTimeout()
                    }
                }
            }
        }
    }
    
    private let timeout: Double
    private let dismissByTapOutside: Bool
    private let dismissImmediatelyOnLayoutUpdate: Bool
    private var timeoutTimer: SwiftSignalKit.Timer?
    
    private var layout: ContainerViewLayout?
    
    public var dismissed: (() -> Void)?
    
    public init(content: TooltipControllerContent, timeout: Double = 2.0, dismissByTapOutside: Bool = false, dismissImmediatelyOnLayoutUpdate: Bool = false) {
        self.content = content
        self.timeout = timeout
        self.dismissByTapOutside = dismissByTapOutside
        self.dismissImmediatelyOnLayoutUpdate = dismissImmediatelyOnLayoutUpdate
        
        super.init(navigationBarPresentationData: nil)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.timeoutTimer?.invalidate()
    }
    
    public override func loadDisplayNode() {
        self.displayNode = TooltipControllerNode(content: self.content, dismiss: { [weak self] in
            self?.dismiss()
        }, dismissByTapOutside: self.dismissByTapOutside)
        self.displayNodeDidLoad()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.controllerNode.animateIn()
        self.beginTimeout()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
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
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.controllerNode.animateIn()
        self.beginTimeout()
    }
    
    private func beginTimeout() {
        if self.timeoutTimer == nil {
            let timeoutTimer = SwiftSignalKit.Timer(timeout: self.timeout, repeat: false, completion: { [weak self] in
                if let strongSelf = self {
                    strongSelf.dismissed?()
                    strongSelf.controllerNode.animateOut {
                        self?.presentingViewController?.dismiss(animated: false)
                    }
                }
            }, queue: Queue.mainQueue())
            self.timeoutTimer = timeoutTimer
            timeoutTimer.start()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.dismissed?()
        self.controllerNode.animateOut { [weak self] in
            self?.presentingViewController?.dismiss(animated: false)
            completion?()
        }
    }
    
    public func dismissImmediately() {
        self.dismissed?()
        self.presentingViewController?.dismiss(animated: false)
    }
}
