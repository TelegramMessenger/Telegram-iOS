import Foundation
import AsyncDisplayKit
import SwiftSignalKit

public final class TooltipControllerPresentationArguments {
    fileprivate let sourceNodeAndRect: () -> (ASDisplayNode, CGRect)?
    
    public init(sourceNodeAndRect: @escaping () -> (ASDisplayNode, CGRect)?) {
        self.sourceNodeAndRect = sourceNodeAndRect
    }
}

public final class TooltipController: ViewController {
    private var controllerNode: TooltipControllerNode {
        return self.displayNode as! TooltipControllerNode
    }
    
    public var text: String {
        didSet {
            if self.text != oldValue {
                if self.isNodeLoaded {
                    self.controllerNode.updateText(self.text, transition: .animated(duration: 0.25, curve: .easeInOut))
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
    private var timeoutTimer: SwiftSignalKit.Timer?
    
    private var layout: ContainerViewLayout?
    
    public var dismissed: (() -> Void)?
    
    public init(text: String, timeout: Double = 1.0) {
        self.text = text
        self.timeout = timeout
        
        super.init(navigationBarTheme: nil)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.timeoutTimer?.invalidate()
    }
    
    open override func loadDisplayNode() {
        self.displayNode = TooltipControllerNode(text: self.text, dismiss: { [weak self] in
            self?.dismissed?()
            self?.controllerNode.animateOut { [weak self] in
                self?.presentingViewController?.dismiss(animated: false)
            }
        })
        self.displayNodeDidLoad()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.controllerNode.animateIn()
        self.beginTimeout()
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        if self.layout != nil && self.layout! != layout {
            self.dismissed?()
            self.controllerNode.animateOut { [weak self] in
                self?.presentingViewController?.dismiss(animated: false)
            }
        } else {
            self.layout = layout
            
            if let presentationArguments = self.presentationArguments as? TooltipControllerPresentationArguments, let (sourceNode, sourceRect) = presentationArguments.sourceNodeAndRect() {
                self.controllerNode.sourceRect = sourceNode.view.convert(sourceRect, to: nil)
            } else {
                self.controllerNode.sourceRect = nil
            }
            
            self.controllerNode.containerLayoutUpdated(layout, transition: transition)
        }
    }
    
    open override func viewWillAppear(_ animated: Bool) {
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
}
