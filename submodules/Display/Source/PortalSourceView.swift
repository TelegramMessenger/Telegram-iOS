import UIKit

open class PortalSourceView: UIView {
    private final class PortalReference {
        weak var portalView: PortalView?
        
        init(portalView: PortalView) {
            self.portalView = portalView
        }
    }
    
    private var portalReferences: [PortalReference] = []
    private weak var globalPortalView: GlobalPortalView?
    
    public final var needsGlobalPortal: Bool = false {
        didSet {
            if self.needsGlobalPortal != oldValue {
                if self.needsGlobalPortal {
                    self.alpha = 0.0
                    
                    if let windowHost = self.windowHost {
                        windowHost.addGlobalPortalHostView(sourceView: self)
                    }
                } else {
                    self.alpha = 1.0
                    
                    if let globalPortalView = self.globalPortalView {
                        self.globalPortalView = nil
                        
                        globalPortalView.triggerWasRemoved()
                    }
                }
            }
        }
    }
    
    deinit {
        if let globalPortalView = self.globalPortalView {
            globalPortalView.triggerWasRemoved()
        }
    }
    
    public func addPortal(view: PortalView) {
        self.portalReferences.append(PortalReference(portalView: view))
        if self.window != nil {
            view.reloadPortal(sourceView: self)
        }
    }
    
    func setGlobalPortal(view: GlobalPortalView?) {
        if let globalPortalView = self.globalPortalView {
            self.globalPortalView = nil
            
            globalPortalView.triggerWasRemoved()
        }
        
        if let view = view {
            self.globalPortalView = view
            
            if self.window != nil {
                view.reloadPortal(sourceView: self)
            }
        }
    }
    
    override open func didMoveToWindow() {
        super.didMoveToWindow()
        
        if self.window != nil {
            for portalReference in self.portalReferences {
                if let portalView = portalReference.portalView {
                    portalView.reloadPortal(sourceView: self)
                }
            }
            
            if self.needsGlobalPortal, self.globalPortalView == nil, let windowHost = self.windowHost {
                windowHost.addGlobalPortalHostView(sourceView: self)
            }
        }
    }
}
