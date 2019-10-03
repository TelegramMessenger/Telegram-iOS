import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

final class NavigationOverlayContainer: ASDisplayNode {
    let controller: ViewController
    
    private(set) var isReady: Bool = false
    var isReadyUpdated: (() -> Void)?
    private var isReadyDisposable: Disposable?
    
    private var validLayout: ContainerViewLayout?
    
    var keyboardViewManager: KeyboardViewManager? {
        didSet {
            if self.keyboardViewManager !== oldValue {
            }
        }
    }
    
    init(controller: ViewController, controllerRemoved: @escaping (ViewController) -> Void, statusBarUpdated: @escaping (ContainedViewLayoutTransition) -> Void) {
        self.controller = controller
        
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
        
        self.isReadyDisposable = (self.controller.ready.get()
        |> filter { $0 }
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            if !strongSelf.isReady {
                strongSelf.isReady = true
                strongSelf.isReadyUpdated?()
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
        let updateLayout = self.validLayout != layout
        
        self.validLayout = layout
        
        if updateLayout {
            transition.updateFrame(node: self.controller.displayNode, frame: CGRect(origin: CGPoint(), size: layout.size))
            self.controller.containerLayoutUpdated(layout, transition: transition)
        }
    }
    
    func transitionIn() {
        self.controller.viewWillAppear(false)
        self.controller.setIgnoreAppearanceMethodInvocations(true)
        self.addSubnode(self.controller.displayNode)
        self.controller.setIgnoreAppearanceMethodInvocations(false)
        self.controller.viewDidAppear(false)
    }
}
