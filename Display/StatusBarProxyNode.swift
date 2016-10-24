import Foundation
import AsyncDisplayKit

public enum StatusBarStyle {
    case Black
    case White
}

private enum StatusBarItemType {
    case Generic
    case Battery
}

func makeStatusBarProxy(_ statusBarStyle: StatusBarStyle, statusBar: UIView) -> StatusBarProxyNode {
    return StatusBarProxyNode(statusBarStyle: statusBarStyle, statusBar: statusBar)
}

private class StatusBarItemNode: ASDisplayNode {
    var statusBarStyle: StatusBarStyle
    var targetView: UIView
    
    init(statusBarStyle: StatusBarStyle, targetView: UIView) {
        self.statusBarStyle = statusBarStyle
        self.targetView = targetView
        
        super.init()
    }
    
    func update() {
        let context = DrawingContext(size: self.targetView.frame.size, clear: true)
        
        if let contents = self.targetView.layer.contents, (self.targetView.layer.sublayers?.count ?? 0) == 0 && CFGetTypeID(contents as! CFTypeRef) == CGImage.typeID && false {
            let image = contents as! CGImage
            context.withFlippedContext { c in
                c.setAlpha(CGFloat(self.targetView.layer.opacity))
                c.draw(image, in: CGRect(origin: CGPoint(), size: context.size))
                c.setAlpha(1.0)
            }
            
            if let sublayers = self.targetView.layer.sublayers {
                for sublayer in sublayers {
                    let origin = sublayer.frame.origin
                    if let contents = sublayer.contents , CFGetTypeID(contents as! CFTypeRef) == CGImage.typeID {
                        let image = contents as! CGImage
                        context.withFlippedContext { c in
                            c.translateBy(x: origin.x, y: origin.y)
                            c.draw(image, in: CGRect(origin: CGPoint(), size: context.size))
                            c.translateBy(x: -origin.x, y: -origin.y)
                        }
                    } else {
                        context.withContext { c in
                            UIGraphicsPushContext(c)
                            c.translateBy(x: origin.x, y: origin.y)
                            sublayer.render(in: c)
                            c.translateBy(x: -origin.x, y: -origin.y)
                            UIGraphicsPopContext()
                        }
                    }
                }
            }
        } else {
            context.withContext { c in
                UIGraphicsPushContext(c)
                self.targetView.layer.render(in: c)
                UIGraphicsPopContext()
            }
        }
        
        let type: StatusBarItemType = self.targetView.checkIsKind(of: batteryItemClass!) ? .Battery : .Generic
        tintStatusBarItem(context, type: type, style: statusBarStyle)
        self.contents = context.generateImage()?.cgImage
        
        self.frame = self.targetView.frame
    }
}

private func tintStatusBarItem(_ context: DrawingContext, type: StatusBarItemType, style: StatusBarStyle) {
    switch type {
        case .Battery:
            let minY = 0
            let minX = 0
            let maxY = Int(context.size.height * context.scale)
            let maxX = Int(context.size.width * context.scale)
            if minY < maxY && minX < maxX {
                let basePixel = context.bytes.assumingMemoryBound(to: UInt32.self)
                let pixelsPerRow = context.bytesPerRow / 4
                
                let midX = (maxX + minX) / 2
                let midY = (maxY + minY) / 2
                let baseMidRow = basePixel + pixelsPerRow * midY
                var baseX = minX
                while baseX < maxX {
                    let pixel = baseMidRow + baseX
                    let alpha = pixel.pointee & 0xff000000
                    if alpha != 0 {
                        break
                    }
                    baseX += 1
                }
                
                baseX += 2
                
                var targetX = baseX
                while targetX < maxX {
                    let pixel = baseMidRow + targetX
                    let alpha = pixel.pointee & 0xff000000
                    if alpha == 0 {
                        break
                    }
                    
                    targetX += 1
                }
                
                let batteryColor = (baseMidRow + baseX).pointee
                let batteryR = (batteryColor >> 16) & 0xff
                let batteryG = (batteryColor >> 8) & 0xff
                let batteryB = batteryColor & 0xff
                
                var baseY = minY
                while baseY < maxY {
                    let baseRow = basePixel + pixelsPerRow * baseY
                    let pixel = baseRow + midX
                    let alpha = pixel.pointee & 0xff000000
                    if alpha != 0 {
                        break
                    }
                    baseY += 1
                }
                
                var targetY = maxY - 1
                while targetY >= baseY {
                    let baseRow = basePixel + pixelsPerRow * targetY
                    let pixel = baseRow + midX
                    let alpha = pixel.pointee & 0xff000000
                    if alpha != 0 {
                        break
                    }
                    targetY -= 1
                }
                
                targetY -= 1
                
                let baseColor: UInt32
                switch style {
                    case .Black:
                        baseColor = 0x000000
                    case .White:
                        baseColor = 0xffffff
                }
                
                let baseR = (baseColor >> 16) & 0xff
                let baseG = (baseColor >> 8) & 0xff
                let baseB = baseColor & 0xff
                
                var pixel = context.bytes.assumingMemoryBound(to: UInt32.self)
                let end = context.bytes.advanced(by: context.length).assumingMemoryBound(to: UInt32.self)
                while pixel != end {
                    let alpha = (pixel.pointee & 0xff000000) >> 24
                    
                    let r = (baseR * alpha) / 255
                    let g = (baseG * alpha) / 255
                    let b = (baseB * alpha) / 255
                    
                    pixel.pointee = (alpha << 24) | (r << 16) | (g << 8) | b
                    
                    pixel += 1
                }
                
                if batteryColor != 0xffffffff && batteryColor != 0xff000000 {
                    var y = baseY + 2
                    while y < targetY {
                        let baseRow = basePixel + pixelsPerRow * y
                        var x = baseX
                        while x < targetX {
                            let pixel = baseRow + x
                            let alpha = (pixel.pointee >> 24) & 0xff
                            
                            let r = (batteryR * alpha) / 255
                            let g = (batteryG * alpha) / 255
                            let b = (batteryB * alpha) / 255
                            
                            pixel.pointee = (alpha << 24) | (r << 16) | (g << 8) | b
                            
                            x += 1
                        }
                        y += 1
                    }
                }
            }
    case .Generic:
        var pixel = context.bytes.assumingMemoryBound(to: UInt32.self)
        let end = context.bytes.advanced(by: context.length).assumingMemoryBound(to: UInt32.self)
        
        let baseColor: UInt32
        switch style {
        case .Black:
            baseColor = 0x000000
        case .White:
            baseColor = 0xffffff
        }
        
        let baseR = (baseColor >> 16) & 0xff
        let baseG = (baseColor >> 8) & 0xff
        let baseB = baseColor & 0xff
        
        while pixel != end {
            let alpha = (pixel.pointee & 0xff000000) >> 24
            
            let r = (baseR * alpha) / 255
            let g = (baseG * alpha) / 255
            let b = (baseB * alpha) / 255
            
            pixel.pointee = (alpha << 24) | (r << 16) | (g << 8) | b
            
            pixel += 1
        }
    }
}

private let batteryItemClass: AnyClass? = NSClassFromString("UIStatusBarBatteryItemView")

private class StatusBarProxyNodeTimerTarget: NSObject {
    let action: () -> Void
    
    init(action: @escaping () -> Void) {
        self.action = action
    }
    
    @objc func tick() {
        action()
    }
}

class StatusBarProxyNode: ASDisplayNode {
    private let statusBar: UIView
    
    var timer: Timer?
    var statusBarStyle: StatusBarStyle {
        didSet {
            if oldValue != self.statusBarStyle {
                if !self.isHidden {
                    self.updateItems()
                }
            }
        }
    }
    
    private var itemNodes: [StatusBarItemNode] = []
    
    override var isHidden: Bool {
        get {
            return super.isHidden
        } set(value) {
            if super.isHidden != value {
                super.isHidden = value
                
                if !value {
                    self.updateItems()
                    self.timer = Timer(timeInterval: 5.0, target: StatusBarProxyNodeTimerTarget { [weak self] in
                        self?.updateItems()
                        }, selector: #selector(StatusBarProxyNodeTimerTarget.tick), userInfo: nil, repeats: true)
                    RunLoop.main.add(self.timer!, forMode: .commonModes)
                } else {
                    self.timer?.invalidate()
                    self.timer = nil
                }
            }
        }
    }
    
    init(statusBarStyle: StatusBarStyle, statusBar: UIView) {
        self.statusBarStyle = statusBarStyle
        self.statusBar = statusBar
        
        super.init()
        
        self.isHidden = true
        
        self.clipsToBounds = true
        //self.backgroundColor = UIColor.blueColor().colorWithAlphaComponent(0.2)
        
        for subview in statusBar.subviews {
            let itemNode = StatusBarItemNode(statusBarStyle: statusBarStyle, targetView: subview)
            self.itemNodes.append(itemNode)
            self.addSubnode(itemNode)
        }
        
        self.frame = statusBar.bounds
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
    private func updateItems() {
        let statusBar = self.statusBar
        
        var i = 0
        while i < self.itemNodes.count {
            var found = false
            for subview in statusBar.subviews {
                if self.itemNodes[i].targetView == subview {
                    found = true
                    break
                }
            }
            if !found {
                self.itemNodes[i].removeFromSupernode()
                self.itemNodes.remove(at: i)
            } else {
                self.itemNodes[i].statusBarStyle = self.statusBarStyle
                self.itemNodes[i].update()
                i += 1
            }
        }
        
        for subview in statusBar.subviews {
            var found = false
            for itemNode in self.itemNodes {
                if itemNode.targetView == subview {
                    found = true
                    break
                }
            }
            
            if !found {
                let itemNode = StatusBarItemNode(statusBarStyle: self.statusBarStyle, targetView: subview)
                itemNode.update()
                self.itemNodes.append(itemNode)
                self.addSubnode(itemNode)
            }
        }
    }
}
