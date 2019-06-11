import Foundation
import UIKit
import AsyncDisplayKit

private final class SwitchNodeViewLayer: CALayer {
    override func setNeedsDisplay() {
    }
}

private final class SwitchNodeView: UISwitch {
    override class var layerClass: AnyClass {
        return SwitchNodeViewLayer.self
    }
}

open class SwitchNode: ASDisplayNode {
    public var valueUpdated: ((Bool) -> Void)?
    
    public var frameColor = UIColor(rgb: 0xe0e0e0) {
        didSet {
            if self.isNodeLoaded {
                (self.view as! UISwitch).tintColor = self.frameColor
            }
        }
    }
    public var handleColor = UIColor(rgb: 0xffffff) {
        didSet {
            if self.isNodeLoaded {
                //(self.view as! UISwitch).thumbTintColor = self.handleColor
            }
        }
    }
    public var contentColor = UIColor(rgb: 0x42d451) {
        didSet {
            if self.isNodeLoaded {
                (self.view as! UISwitch).onTintColor = self.contentColor
            }
        }
    }
    
    private var _isOn: Bool = false
    public var isOn: Bool {
        get {
            return self._isOn
        } set(value) {
            if (value != self._isOn) {
                self._isOn = value
                if self.isNodeLoaded {
                    (self.view as! UISwitch).setOn(value, animated: false)
                }
            }
        }
    }
    
    override public init() {
        super.init()
        
        self.setViewBlock({
            return SwitchNodeView()
        })
    }
    
    override open func didLoad() {
        super.didLoad()
        
        self.view.isAccessibilityElement = false
        
        (self.view as! UISwitch).backgroundColor = self.backgroundColor
        (self.view as! UISwitch).tintColor = self.frameColor
        //(self.view as! UISwitch).thumbTintColor = self.handleColor
        (self.view as! UISwitch).onTintColor = self.contentColor
        
        (self.view as! UISwitch).setOn(self._isOn, animated: false)
        
        (self.view as! UISwitch).addTarget(self, action: #selector(switchValueChanged(_:)), for: .valueChanged)
    }
    
    public func setOn(_ value: Bool, animated: Bool) {
        self._isOn = value
        if self.isNodeLoaded {
            (self.view as! UISwitch).setOn(value, animated: animated)
        }
    }
    
    override open func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 51.0, height: 31.0)
    }
    
    @objc func switchValueChanged(_ view: UISwitch) {
        self._isOn = view.isOn
        self.valueUpdated?(view.isOn)
    }
}
