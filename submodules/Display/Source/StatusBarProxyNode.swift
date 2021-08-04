import Foundation
import UIKit
import AsyncDisplayKit
import ObjCRuntimeUtils

public enum StatusBarStyle {
    case Black
    case White
    case Ignore
    case Hide
    
    public init(systemStyle: UIStatusBarStyle) {
        switch systemStyle {
        case .default:
            self = .Black
        case .lightContent:
            self = .White
        case .blackOpaque:
            self = .Black
        default:
            self = .Black
        }
    }
    
    public var systemStyle: UIStatusBarStyle {
        switch self {
            case .Black:
                if #available(iOS 13.0, *) {
                    return .darkContent
                } else {
                    return .default
                }
            case .White:
                return .lightContent
            default:
                return .default
        }
    }
}

private enum StatusBarItemType {
    case Generic
    case Battery
    case Activity
}

func makeStatusBarProxy(_ statusBarStyle: StatusBarStyle, statusBar: UIView) -> StatusBarProxyNode {
    return StatusBarProxyNode(statusBarStyle: statusBarStyle, statusBar: statusBar)
}

private func maxSubviewBounds(_ view: UIView) -> CGRect {
    var bounds = view.bounds
    for subview in view.subviews {
        let subviewFrame = subview.frame
        let subviewBounds = maxSubviewBounds(subview).offsetBy(dx: subviewFrame.minX, dy: subviewFrame.minY)
        bounds = bounds.union(subviewBounds)
    }
    return bounds
}

private let formatter: DateFormatter? = {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.locale = Locale.current
    return formatter
}()


private class StatusBarItemNode: ASDisplayNode {
    var statusBarStyle: StatusBarStyle
    var targetView: UIView
    var rootView: UIView
    private let contentNode: ASDisplayNode
    
    init(statusBarStyle: StatusBarStyle, targetView: UIView, rootView: UIView) {
        self.statusBarStyle = statusBarStyle
        self.targetView = targetView
        self.rootView = rootView
        self.contentNode = ASDisplayNode()
        self.contentNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.contentNode)
    }
    
    func update() {
        let containingBounds = maxSubviewBounds(self.targetView)
        let context = DrawingContext(size: containingBounds.size, clear: true)
        
        if let contents = self.targetView.layer.contents, (self.targetView.layer.sublayers?.count ?? 0) == 0 && CFGetTypeID(contents as CFTypeRef) == CGImage.typeID && false {
            let image = contents as! CGImage
            context.withFlippedContext { c in
                c.setAlpha(CGFloat(self.targetView.layer.opacity))
                c.draw(image, in: CGRect(origin: CGPoint(), size: context.size))
                c.setAlpha(1.0)
            }
            
            if let sublayers = self.targetView.layer.sublayers {
                for sublayer in sublayers {
                    let origin = sublayer.frame.origin
                    if let contents = sublayer.contents , CFGetTypeID(contents as CFTypeRef) == CGImage.typeID {
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
            if let timeViewClass = timeViewClass, self.targetView.checkIsKind(of: timeViewClass) {
                context.withContext { c in
                    c.translateBy(x: containingBounds.minX, y: -containingBounds.minY)
                    UIGraphicsPushContext(c)
                    
                    let color: UIColor
                    switch self.statusBarStyle {
                        case .Black, .Ignore, .Hide:
                            color = UIColor.black
                        case .White:
                            color = UIColor.white
                    }
                    
                    formatter?.locale = Locale.current
                    if let string = formatter?.string(from: Date()) {
                        let attributedString = NSAttributedString(string: string, attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 12.0), NSAttributedString.Key.foregroundColor: color])
                        
                        let line = CTLineCreateWithAttributedString(attributedString)

                        c.translateBy(x: containingBounds.width / 2.0, y: containingBounds.height / 2.0)
                        c.scaleBy(x: 1.0, y: -1.0)
                        c.translateBy(x: -containingBounds.width / 2.0, y: -containingBounds.height / 2.0)
                        
                        c.translateBy(x: 0.0, y: 5.0 + UIScreenPixel)
                        CTLineDraw(line, c)
                    }
                    
                    UIGraphicsPopContext()
                }
            } else {
                context.withContext { c in
                    c.translateBy(x: containingBounds.minX, y: -containingBounds.minY)
                    UIGraphicsPushContext(c)
                    self.targetView.layer.render(in: c)
                    UIGraphicsPopContext()
                }
            }
        }
        //dumpViews(self.targetView)
        var type: StatusBarItemType = .Generic
        if let batteryItemClass = batteryItemClass {
            if self.targetView.checkIsKind(of: batteryItemClass) {
                type = .Battery
            }
        }
        if let batteryViewClass = batteryViewClass {
            if self.targetView.checkIsKind(of: batteryViewClass) {
                type = .Battery
            }
        }
        if case .Generic = type {
            var hasActivityBackground = false
            var hasText = false
            for subview in self.targetView.subviews {
                if let stringClass = stringClass, subview.checkIsKind(of: stringClass) {
                    hasText = true
                } else if let activityClass = activityClass, subview.checkIsKind(of: activityClass) {
                    hasActivityBackground = true
                }
            }
            if hasActivityBackground && hasText {
                type = .Activity
            }
        }
        tintStatusBarItem(context, type: type, style: self.statusBarStyle)
        let image = context.generateImage()?.cgImage
        self.contentNode.contents = image
        
        let mappedFrame = self.targetView.convert(self.targetView.bounds, to: self.rootView)
        self.frame = mappedFrame
        self.contentNode.frame = containingBounds
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
                
                while baseX < maxX {
                    let pixel = baseMidRow + baseX
                    let alpha = pixel.pointee & 0xff000000
                    if alpha == 0 {
                        break
                    }
                    baseX += 1
                }
                
                while baseX < maxX {
                    let pixel = baseMidRow + baseX
                    let alpha = pixel.pointee & 0xff000000
                    if alpha != 0 {
                        break
                    }
                    baseX += 1
                }
                
                var targetX = baseX
                while targetX < maxX {
                    let pixel = baseMidRow + targetX
                    let alpha = pixel.pointee & 0xff000000
                    if alpha == 0 {
                        break
                    }
                    
                    targetX += 1
                }
                
                let batteryColor = (baseMidRow + baseX + 2).pointee
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
                    case .Black, .Ignore, .Hide:
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
                
                let whiteColor: UInt32 = 0xffffffff as UInt32
                let blackColor: UInt32 = 0xff000000 as UInt32
                if batteryColor != whiteColor && batteryColor != blackColor {
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
    case .Activity:
        break
    case .Generic:
        var pixel = context.bytes.assumingMemoryBound(to: UInt32.self)
        let end = context.bytes.advanced(by: context.length).assumingMemoryBound(to: UInt32.self)
        
        let baseColor: UInt32
        switch style {
            case .Black, .Ignore, .Hide:
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

private let foregroundClass: AnyClass? = {
    var nameString = "StatusBar"
    if CFAbsoluteTimeGetCurrent() > 0 {
        nameString += "ForegroundView"
    }
    return NSClassFromString("_UI" + nameString)
}()

private let foregroundClass2: AnyClass? = {
    var nameString = "StatusBar"
    if CFAbsoluteTimeGetCurrent() > 0 {
        nameString += "ForegroundView"
    }
    return NSClassFromString("UI" + nameString)
}()

private let batteryItemClass: AnyClass? = {
    var nameString = "StatusBarBattery"
    if CFAbsoluteTimeGetCurrent() > 0 {
        nameString += "ItemView"
    }
    return NSClassFromString("UI" + nameString)
}()

private let batteryViewClass: AnyClass? = {
    var nameString = "Battery"
    if CFAbsoluteTimeGetCurrent() > 0 {
        nameString += "View"
    }
    return NSClassFromString("_UI" + nameString)
}()

private let activityClass: AnyClass? = {
    var nameString = "StatusBarBackground"
    if CFAbsoluteTimeGetCurrent() > 0 {
        nameString += "ActivityView"
    }
    return NSClassFromString("_UI" + nameString)
}()

private let stringClass: AnyClass? = {
    var nameString = "StatusBar"
    if CFAbsoluteTimeGetCurrent() > 0 {
        nameString += "StringView"
    }
    return NSClassFromString("_UI" + nameString)
}()

private let timeViewClass: AnyClass? = {
    var nameString = "StatusBar"
    if CFAbsoluteTimeGetCurrent() > 0 {
        nameString += "TimeItemView"
    }
    return NSClassFromString("UI" + nameString)
}()

private func containsSubviewOfClass(view: UIView, of subviewClass: AnyClass?) -> Bool {
    guard let subviewClass = subviewClass else {
        return false
    }
    for subview in view.subviews {
        if subview.checkIsKind(of: subviewClass) {
            return true
        }
    }
    return false
}

private class StatusBarProxyNodeTimerTarget: NSObject {
    let action: () -> Void
    
    init(action: @escaping () -> Void) {
        self.action = action
    }
    
    @objc func tick() {
        action()
    }
}

private func forEachSubview(statusBar: UIView, _ f: (UIView, UIView) -> Bool) {
    var rootView: UIView = statusBar
    for subview in statusBar.subviews {
        if let foregroundClass = foregroundClass, subview.checkIsKind(of: foregroundClass) {
            rootView = subview
            break
        } else if let foregroundClass2 = foregroundClass2, subview.checkIsKind(of: foregroundClass2) {
            rootView = subview
            break
        }
    }
    for subview in rootView.subviews {
        if true || subview.subviews.isEmpty {
            if !f(rootView, subview) {
                break
            }
        } else {
            for subSubview in subview.subviews {
                if !f(rootView, subSubview) {
                    break
                }
            }
        }
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
                    RunLoop.main.add(self.timer!, forMode: .common)
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
        
        //dumpViews(statusBar)
        forEachSubview(statusBar: statusBar, { rootView, subview in
            let itemNode = StatusBarItemNode(statusBarStyle: statusBarStyle, targetView: subview, rootView: rootView)
            self.itemNodes.append(itemNode)
            self.addSubnode(itemNode)
            return true
        })
        
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
            forEachSubview(statusBar: statusBar, { rootView, subview in
                if self.itemNodes[i].rootView === rootView && self.itemNodes[i].targetView === subview {
                    found = true
                    return false
                } else {
                    return true
                }
            })
            if !found {
                self.itemNodes[i].removeFromSupernode()
                self.itemNodes.remove(at: i)
            } else {
                self.itemNodes[i].statusBarStyle = self.statusBarStyle
                self.itemNodes[i].update()
                i += 1
            }
        }
        
        forEachSubview(statusBar: statusBar, { rootView, subview in
            var found = false
            for itemNode in self.itemNodes {
                if itemNode.targetView == subview {
                    found = true
                    break
                }
            }
            if !found {
                let itemNode = StatusBarItemNode(statusBarStyle: self.statusBarStyle, targetView: subview, rootView: rootView)
                itemNode.update()
                self.itemNodes.append(itemNode)
                self.addSubnode(itemNode)
            }
            return true
        })
    }
}
