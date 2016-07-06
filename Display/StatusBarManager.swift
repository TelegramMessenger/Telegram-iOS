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

private func mapStatusBar(_ statusBar: StatusBar) -> MappedStatusBar {
    let frame = CGRect(origin: statusBar.view.convert(CGPoint(), to: nil), size: statusBar.frame.size)
    return MappedStatusBar(style: statusBar.style, frame: frame, statusBar: statusBar)
}

private func mappedSurface(_ surface: StatusBarSurface) -> MappedStatusBarSurface {
    return MappedStatusBarSurface(statusBars: surface.statusBars.map(mapStatusBar), surface: surface)
}

private func optimizeMappedSurface(_ surface: MappedStatusBarSurface) -> MappedStatusBarSurface {
    if surface.statusBars.count > 1 {
        for i in 1 ..< surface.statusBars.count {
            if surface.statusBars[i].style != surface.statusBars[i - 1].style || abs(surface.statusBars[i].frame.origin.y - surface.statusBars[i - 1].frame.origin.y) > CGFloat(FLT_EPSILON) {
                return surface
            }
            if let lhsStatusBar = surface.statusBars[i - 1].statusBar, rhsStatusBar = surface.statusBars[i].statusBar where !lhsStatusBar.alpha.isEqual(to: rhsStatusBar.alpha) {
                return surface
            }
        }
        let size = UIApplication.shared().statusBarFrame.size
        return MappedStatusBarSurface(statusBars: [MappedStatusBar(style: surface.statusBars[0].style, frame: CGRect(origin: CGPoint(x: 0.0, y: surface.statusBars[0].frame.origin.y), size: size), statusBar: nil)], surface: surface.surface)
    } else {
        return surface
    }
}

private func displayHiddenAnimation() -> CAAnimation {
    let animation = CABasicAnimation(keyPath: "transform.translation.y")
    animation.fromValue = NSNumber(value: Float(-40.0))
    animation.toValue = NSNumber(value: Float(-40.0))
    animation.fillMode = kCAFillModeBoth
    animation.duration = 1.0
    animation.speed = 0.0
    animation.isAdditive = true
    animation.isRemovedOnCompletion = false
    
    return animation
}

class StatusBarManager {
    var surfaces: [StatusBarSurface] = [] {
        didSet {
            self.updateSurfaces(oldValue)
        }
    }
    
    private func updateSurfaces(_ previousSurfaces: [StatusBarSurface]) {
        var mappedSurfaces = self.surfaces.map({ optimizeMappedSurface(mappedSurface($0)) })
        
        var reduceSurfaces = true
        var reduceSurfacesStatusBarStyle: StatusBarStyle?
        outer: for surface in mappedSurfaces {
            for mappedStatusBar in surface.statusBars {
                if mappedStatusBar.frame.origin.equalTo(CGPoint()) {
                    if let reduceSurfacesStatusBarStyle = reduceSurfacesStatusBarStyle {
                        if mappedStatusBar.style != reduceSurfacesStatusBarStyle {
                            reduceSurfaces = false
                            break outer
                        }
                    } else {
                        reduceSurfacesStatusBarStyle = mappedStatusBar.style
                    }
                }
            }
        }
        
        if reduceSurfaces {
            outer: for surface in mappedSurfaces {
                for mappedStatusBar in surface.statusBars {
                    if mappedStatusBar.frame.origin.equalTo(CGPoint()) {
                        if let statusBar = mappedStatusBar.statusBar where !statusBar.layer.hasPositionOrOpacityAnimations() {
                            mappedSurfaces = [MappedStatusBarSurface(statusBars: [mappedStatusBar], surface: surface.surface)]
                            break outer
                        }
                    }
                }
            }
        }
        
        var visibleStatusBars: [StatusBar] = []
        
        var globalStatusBar: (StatusBarStyle, CGFloat)?
        
        var coveredIdentity = false
        for i in 0 ..< mappedSurfaces.count {
            for mappedStatusBar in mappedSurfaces[i].statusBars {
                if let statusBar = mappedStatusBar.statusBar {
                    if mappedStatusBar.frame.origin.equalTo(CGPoint()) && !statusBar.layer.hasPositionOrOpacityAnimations() {
                        if !coveredIdentity {
                            coveredIdentity = CGFloat(1.0).isLessThanOrEqualTo(statusBar.alpha)
                            if i == 0 && globalStatusBar == nil {
                                globalStatusBar = (mappedStatusBar.style, statusBar.alpha)
                            } else {
                                visibleStatusBars.append(statusBar)
                            }
                        }
                    } else {
                        visibleStatusBars.append(statusBar)
                    }
                } else {
                    if !coveredIdentity {
                        coveredIdentity = true
                        if i == 0 && globalStatusBar == nil {
                            globalStatusBar = (mappedStatusBar.style, 1.0)
                        }
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
            let statusBarStyle: UIStatusBarStyle = globalStatusBar.0 == .Black ? .default : .lightContent
            if UIApplication.shared().statusBarStyle != statusBarStyle {
                UIApplication.shared().setStatusBarStyle(statusBarStyle, animated: false)
            }
            StatusBarUtils.statusBarWindow()!.alpha = globalStatusBar.1
        } else {
            StatusBarUtils.statusBarWindow()!.alpha = 0.0
        }
    }
}
