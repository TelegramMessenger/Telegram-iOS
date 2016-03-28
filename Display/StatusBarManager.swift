import Foundation
import AsyncDisplayKit

private struct MappedStatusBar {
    let style: StatusBarStyle
    let frame: CGRect
    let statusBar: StatusBar?
}

private struct MappedStatusBarSurface {
    let statusBars: [MappedStatusBar]
    let surface: StatusBarSurface
}

private func mapStatusBar(statusBar: StatusBar) -> MappedStatusBar {
    let frame = CGRect(origin: statusBar.view.convertPoint(CGPoint(), toView: nil), size: statusBar.frame.size)
    return MappedStatusBar(style: statusBar.style, frame: frame, statusBar: statusBar)
}

private func mappedSurface(surface: StatusBarSurface) -> MappedStatusBarSurface {
    return MappedStatusBarSurface(statusBars: surface.statusBars.map(mapStatusBar), surface: surface)
}

private func optimizeMappedSurface(surface: MappedStatusBarSurface) -> MappedStatusBarSurface {
    if surface.statusBars.count > 1 {
        for i in 1 ..< surface.statusBars.count {
            if surface.statusBars[i].style != surface.statusBars[i - 1].style || abs(surface.statusBars[i].frame.origin.y - surface.statusBars[i - 1].frame.origin.y) > CGFloat(FLT_EPSILON) {
                return surface
            }
        }
        let size = UIApplication.sharedApplication().statusBarFrame.size
        return MappedStatusBarSurface(statusBars: [MappedStatusBar(style: surface.statusBars[0].style, frame: CGRect(origin: CGPoint(x: 0.0, y: surface.statusBars[0].frame.origin.y), size: size), statusBar: nil)], surface: surface.surface)
    } else {
        return surface
    }
}

private func displayHiddenAnimation() -> CAAnimation {
    let animation = CABasicAnimation(keyPath: "transform.translation.y")
    animation.fromValue = NSNumber(float: -40.0)
    animation.toValue = NSNumber(float: -40.0)
    animation.fillMode = kCAFillModeBoth
    animation.duration = 100000000.0
    animation.additive = true
    animation.removedOnCompletion = false
    
    return animation
}

class StatusBarManager {
    var surfaces: [StatusBarSurface] = [] {
        didSet {
            self.updateSurfaces(oldValue)
        }
    }
    
    private func updateSurfaces(previousSurfaces: [StatusBarSurface]) {
        let mappedSurfaces = self.surfaces.map({ optimizeMappedSurface(mappedSurface($0)) })
        
        var visibleStatusBars: [StatusBar] = []
        
        var globalStatusBar: (StatusBarStyle, CGFloat)?
        for i in 0 ..< mappedSurfaces.count {
            if i == mappedSurfaces.count - 1 && mappedSurfaces[i].statusBars.count == 1 {
                globalStatusBar = (mappedSurfaces[i].statusBars[0].style, mappedSurfaces[i].statusBars[0].frame.origin.y)
            } else {
                for mappedStatusBar in mappedSurfaces[i].statusBars {
                    if let statusBar = mappedStatusBar.statusBar {
                        visibleStatusBars.append(statusBar)
                    }
                }
            }
        }
        
        for surface in previousSurfaces {
            for statusBar in surface.statusBars {
                if !visibleStatusBars.contains({$0 === statusBar}) {
                    statusBar.removeProxyNode()
                }
            }
        }
        
        for surface in self.surfaces {
            for statusBar in surface.statusBars {
                if !visibleStatusBars.contains({$0 === statusBar}) {
                    statusBar.removeProxyNode()
                }
            }
        }
        
        for statusBar in visibleStatusBars {
            statusBar.updateProxyNode()
        }
        
        if let globalStatusBar = globalStatusBar {
            StatusBarUtils.statusBarWindow()!.hidden = false
            let statusBarStyle: UIStatusBarStyle = globalStatusBar.0 == .Black ? .Default : .LightContent
            if UIApplication.sharedApplication().statusBarStyle != statusBarStyle {
                UIApplication.sharedApplication().setStatusBarStyle(statusBarStyle, animated: false)
            }
            StatusBarUtils.statusBarWindow()!.layer.removeAnimationForKey("displayHidden")
            StatusBarUtils.statusBarWindow()!.transform = CGAffineTransformMakeTranslation(0.0, globalStatusBar.1)
        } else {
            if StatusBarUtils.statusBarWindow()!.layer.animationForKey("displayHidden") == nil {
                StatusBarUtils.statusBarWindow()!.layer.addAnimation(displayHiddenAnimation(), forKey: "displayHidden")
            }
        }
        
        /*if self.items.count == 1 {
            self.shouldHide = true
            dispatch_async(dispatch_get_main_queue(), {
                if self.shouldHide {
                    self.items[0].1.hidden = true
                    self.shouldHide = false
                }
            })
            //self.items[0].1.hidden = true
            StatusBarUtils.statusBarWindow()!.hidden = false
        } else if !self.items.isEmpty {
            self.shouldHide = false
            for (statusBar, node) in self.items {
                node.hidden = false
                var frame = statusBar.frame
                frame.size.width = self.bounds.size.width
                frame.size.height = 20.0
                node.frame = frame
                
                //print("origin: \(frame.origin.x)")
                //print("style: \(node.style)")
                
                let bounds = frame
                node.bounds = bounds
            }
            
            UIView.performWithoutAnimation {
                StatusBarUtils.statusBarWindow()!.hidden = true
            }
        }
        
        var statusBarStyle: UIStatusBarStyle = .Default
        if let lastItem = self.items.last {
            statusBarStyle = lastItem.0.style == .Black ? .Default : .LightContent
        }
        
        if UIApplication.sharedApplication().statusBarStyle != statusBarStyle {
           UIApplication.sharedApplication().setStatusBarStyle(statusBarStyle, animated: false)
        }
        
        //print("window \(StatusBarUtils.statusBarWindow()!)")*/
    }
}