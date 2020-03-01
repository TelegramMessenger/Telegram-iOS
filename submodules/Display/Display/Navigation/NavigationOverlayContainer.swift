import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

final class NavigationOverlayContainer: ASDisplayNode {
    let controller: ViewController
    let blocksInteractionUntilReady: Bool
    
    private(set) var isReady: Bool = false
    var isReadyUpdated: (() -> Void)?
    private var isReadyDisposable: Disposable?
    
    private var validLayout: ContainerViewLayout?
    
    private var isUpdatingState: Bool = false
    
    var keyboardViewManager: KeyboardViewManager? {
        didSet {
            if self.keyboardViewManager !== oldValue {
            }
        }
    }
    
    init(controller: ViewController, blocksInteractionUntilReady: Bool, controllerRemoved: @escaping (ViewController) -> Void, statusBarUpdated: @escaping (ContainedViewLayoutTransition) -> Void, modalStyleOverlayTransitionFactorUpdated: @escaping (ContainedViewLayoutTransition) -> Void) {
        self.controller = controller
        self.blocksInteractionUntilReady = blocksInteractionUntilReady
        
        super.init()
        
        self.controller.navigation_setDismiss({ [weak self] in
            guard let strongSelf = self else {
                return
            }
            controllerRemoved(strongSelf.controller)
        }, rootController: nil)
        
        self.controller.statusBar.alphaUpdated = { transition in
            statusBarUpdated(transition)
        }
        
        self.controller.modalStyleOverlayTransitionFactorUpdated = { transition in
            modalStyleOverlayTransitionFactorUpdated(transition)
        }
        
        self.isReadyDisposable = (self.controller.ready.get()
        |> filter { $0 }
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            if !strongSelf.isReady {
                strongSelf.isReady = true
                if !strongSelf.isUpdatingState {
                    strongSelf.isReadyUpdated?()
                }
            }
        })
    }
    
    deinit {
        self.isReadyDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
    }
    
    func update(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.isUpdatingState = true
        
        let updateLayout = self.validLayout != layout
        
        self.validLayout = layout
        
        if updateLayout {
            transition.updateFrame(node: self.controller.displayNode, frame: CGRect(origin: CGPoint(), size: layout.size))
            self.controller.containerLayoutUpdated(layout, transition: transition)
        }
        
        self.isUpdatingState = false
    }
    
    func transitionIn() {
        self.controller.viewWillAppear(false)
        self.controller.setIgnoreAppearanceMethodInvocations(true)
        self.addSubnode(self.controller.displayNode)
        self.controller.setIgnoreAppearanceMethodInvocations(false)
        self.controller.viewDidAppear(false)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.controller.view.hitTest(point, with: event) {
            return result
        }
        return nil
    }
}
