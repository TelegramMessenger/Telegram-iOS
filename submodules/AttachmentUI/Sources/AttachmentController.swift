import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import TelegramStringFormatting
import UIKitRuntimeUtils

public enum AttachmentButtonType: Equatable {
    case camera
    case gallery
    case file
    case location
    case contact
    case poll
    case app(String)
}

public class AttachmentController: ViewController {
    private let context: AccountContext
    
    private final class Node: ASDisplayNode {
        private weak var controller: AttachmentController?
        private let dim: ASDisplayNode
        private let container: AttachmentContainer
        private let panel: AttachmentPanel
        
        private var validLayout: ContainerViewLayout?
        private var modalProgress: CGFloat = 0.0
        
        private var currentType: AttachmentButtonType?
        private var currentController: ViewController?
                
        init(controller: AttachmentController) {
            self.controller = controller
            
            self.dim = ASDisplayNode()
            self.dim.alpha = 0.0
            self.dim.backgroundColor = UIColor(white: 0.0, alpha: 0.25)
            
            self.container = AttachmentContainer(controllerRemoved: { _ in
            })
            self.panel = AttachmentPanel(context: controller.context)
                        
            super.init()
            
            self.addSubnode(self.dim)
            
            self.container.updateModalProgress = { [weak self] progress, transition in
                if let strongSelf = self, let layout = strongSelf.validLayout {
                    strongSelf.controller?.updateModalStyleOverlayTransitionFactor(progress, transition: transition)
                    
                    strongSelf.modalProgress = progress
                    strongSelf.containerLayoutUpdated(layout, transition: transition)
                }
            }
            self.container.isReadyUpdated = { [weak self] in
                if let strongSelf = self, let layout = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout, transition: .animated(duration: 0.4, curve: .spring))
                }
            }
            
            self.panel.selectionChanged = { [weak self] type, ascending in
                if let strongSelf = self {
                    strongSelf.switchToController(type, ascending)
                }
            }
            
            self.container.interactivelyDismissed = { [weak self] in
                if let strongSelf = self {
                    strongSelf.controller?.dismiss(animated: true)
                }
            }
        }
        
        override func didLoad() {
            super.didLoad()
            
            self.dim.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
            
            self.switchToController(.gallery, false)
        }
        
        @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
            if case .ended = recognizer.state {
                self.controller?.dismiss(animated: true)
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let controller = self.controller, controller.isInteractionDisabled() {
                return self.view
            } else {
                return super.hitTest(point, with: event)
            }
        }
        
        func dismiss(animated: Bool, completion: @escaping () -> Void = {}) {
            if animated {
                let positionTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
                positionTransition.updatePosition(node: self.container, position: CGPoint(x: self.container.position.x, y: self.bounds.height + self.container.bounds.height / 2.0 + self.bounds.height), beginWithCurrentState: true, completion: { [weak self] _ in
                    let _ = self?.container.dismiss(transition: .immediate, completion: completion)
                })
                let alphaTransition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
                alphaTransition.updateAlpha(node: self.dim, alpha: 0.0)
            } else {
                self.controller?.dismiss(animated: false, completion: nil)
            }
        }
        
        func switchToController(_ type: AttachmentButtonType, _ ascending: Bool) {
            guard self.currentType != type else {
                return
            }
            let previousType = self.currentType
            self.currentType = type
            self.controller?.requestController(type, { [weak self] controller in
                if let strongSelf = self, let controller = controller {
                    controller._presentedInModal = true
                    controller.navigation_setPresenting(strongSelf.controller)
                    
                    let animateTransition = previousType != nil
                    strongSelf.currentController = controller
                    
                    if animateTransition, let snapshotView = strongSelf.container.scrollNode.view.snapshotView(afterScreenUpdates: false) {
                        snapshotView.frame = strongSelf.container.scrollNode.frame
                        strongSelf.container.view.insertSubview(snapshotView, belowSubview: strongSelf.panel.view)
                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                            snapshotView?.removeFromSuperview()
                        })
                    }
                    
                    if let layout = strongSelf.validLayout {
                        strongSelf.containerLayoutUpdated(layout, transition: .animated(duration: 0.4, curve: .spring))
                    }
                }
            })
        }
        
        func animateIn(transition: ContainedViewLayoutTransition) {
            transition.updateAlpha(node: self.dim, alpha: 1.0)
            transition.animatePositionAdditive(node: self.container, offset: CGPoint(x: 0.0, y: self.bounds.height + self.container.bounds.height / 2.0 - (self.container.position.y - self.bounds.height)))
        }
        
        private var isCollapsed: Bool = false
        private var isUpdatingContainer = false
        func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
            self.validLayout = layout
            
            transition.updateFrame(node: self.dim, frame: CGRect(origin: CGPoint(), size: layout.size))
            
            let containerTransition: ContainedViewLayoutTransition
            if self.container.supernode == nil {
                containerTransition = .immediate
            } else {
                containerTransition = transition
            }
                        
            if !self.isUpdatingContainer {
                self.isUpdatingContainer = true
                
                let controllers = self.currentController.flatMap { [$0] } ?? []
                containerTransition.updateFrame(node: self.container, frame: CGRect(origin: CGPoint(), size: layout.size))
                self.container.update(layout: layout, controllers: controllers, coveredByModalTransition: 0.0, transition: .immediate)
                                    
                if self.container.supernode == nil, !controllers.isEmpty && self.container.isReady {
                    self.addSubnode(self.container)
                    self.container.addSubnode(self.panel)
                    
                    self.animateIn(transition: transition)
                }
                
                self.isUpdatingContainer = false
            }
            
            let buttons: [AttachmentButtonType] = [.camera, .gallery, .file, .location, .contact, .poll, .app("App")]
            
            let sideInset: CGFloat = 16.0
            let bottomInset: CGFloat
            if layout.intrinsicInsets.bottom > 0.0 {
                bottomInset = layout.intrinsicInsets.bottom - 4.0
            } else {
                bottomInset = 4.0
            }
            
            if self.modalProgress < 0.75 {
                self.isCollapsed = false
            } else if self.modalProgress == 1.0 {
                self.isCollapsed = true
            }
            
            let panelSize = CGSize(width: layout.size.width - sideInset * 2.0, height: panelButtonSize.height)
            transition.updateFrame(node: self.panel, frame: CGRect(origin: CGPoint(x: sideInset, y: layout.size.height - panelSize.height - bottomInset), size: panelSize))
            self.panel.update(buttons: buttons, isCollapsed: self.isCollapsed, size: panelSize, transition: transition)
        }
    }
    
    public var requestController: (AttachmentButtonType, @escaping (ViewController?) -> Void) -> Void = { _, completion in
        completion(nil)
    }
    
    public init(context: AccountContext) {
        self.context = context
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        self.blocksBackgroundWhenInOverlay = true
    }
    
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var node: Node {
        return self.displayNode as! Node
    }
    
    open override func loadDisplayNode() {
        self.displayNode = Node(controller: self)
        self.displayNodeDidLoad()
    }
    
    public override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        self.view.endEditing(true)
        if flag {
            self.node.dismiss(animated: true, completion: {
                super.dismiss(animated: flag, completion: {})
                completion?()
            })
        } else {
            super.dismiss(animated: false, completion: {})
            completion?()
        }
    }
    
    private func isInteractionDisabled() -> Bool {
        return false
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        self.node.containerLayoutUpdated(layout, transition: transition)
    }
}
